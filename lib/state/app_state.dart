import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_user.dart';
import '../models/bucket.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/month_record.dart';
import '../services/household_repository.dart';
import '../utils/format.dart';

/// Live budget status for one bucket in the current month.
class BucketStatus {
  const BucketStatus({
    required this.bucketId,
    required this.name,
    required this.icon,
    required this.budget,
    required this.carryIn,
    required this.spent,
  });

  final String bucketId;
  final String name;
  final String icon;

  /// Total available this month, including any carry-over.
  final double budget;
  final double carryIn;
  final double spent;

  double get remaining => budget - spent;
  double get usedRatio => budget <= 0 ? (spent > 0 ? 1 : 0) : spent / budget;
}

/// Holds the signed-in user's household data for the current month and keeps
/// it in sync with Firestore. Rolls over to a new month at local midnight on
/// the 1st (and whenever the app is resumed into a new month).
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({required this.user}) : repo = HouseholdRepository(user.householdId);

  final AppUser user;
  final HouseholdRepository repo;

  Household? household;
  List<Bucket> buckets = const [];
  MonthRecord? currentMonth;
  List<Expense> currentExpenses = const [];
  String monthKey = monthKeyOf(DateTime.now());
  Object? rolloverError;

  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<dynamic>? _monthSub;
  StreamSubscription<dynamic>? _expenseSub;
  Timer? _rolloverTimer;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _subs.add(repo.household().listen((h) {
      household = h;
      notifyListeners();
    }));
    _subs.add(repo.buckets().listen((b) {
      buckets = b;
      notifyListeners();
    }));
    await _openMonth(monthKey);
  }

  Future<void> _openMonth(String key) async {
    monthKey = key;
    currentMonth = null;
    currentExpenses = const [];
    notifyListeners();

    try {
      await repo.ensureMonth(key);
      rolloverError = null;
    } catch (e) {
      // Usually offline on first launch of the month; the dashboard falls
      // back to bucket templates and we retry on the next resume.
      rolloverError = e;
    }

    await _monthSub?.cancel();
    await _expenseSub?.cancel();
    _monthSub = repo.month(key).listen((m) {
      currentMonth = m;
      notifyListeners();
    });
    _expenseSub = repo.expensesForMonth(key).listen((e) {
      currentExpenses = e;
      notifyListeners();
    });
    _scheduleRollover();
  }

  void _scheduleRollover() {
    _rolloverTimer?.cancel();
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    _rolloverTimer = Timer(nextMonth.difference(now) + const Duration(seconds: 1), checkRollover);
  }

  Future<void> checkRollover() async {
    final key = monthKeyOf(DateTime.now());
    if (key != monthKey) {
      await _openMonth(key);
    } else if (rolloverError != null || currentMonth == null) {
      await _openMonth(key);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkRollover();
  }

  // ---- Derived values ----------------------------------------------------

  Map<String, double> get spentByBucket {
    final out = <String, double>{};
    for (final e in currentExpenses) {
      out[e.bucketId] = (out[e.bucketId] ?? 0) + e.amount;
    }
    return out;
  }

  List<BucketStatus> get statuses {
    final spent = spentByBucket;
    final month = currentMonth;
    if (month != null) {
      return [
        for (final a in month.sortedAllocations)
          BucketStatus(
            bucketId: a.bucketId,
            name: a.name,
            icon: a.icon,
            budget: a.total,
            carryIn: a.carryIn,
            spent: spent[a.bucketId] ?? 0,
          ),
      ];
    }
    return [
      for (final b in buckets)
        BucketStatus(
          bucketId: b.id,
          name: b.name,
          icon: b.icon,
          budget: b.budget,
          carryIn: 0,
          spent: spent[b.id] ?? 0,
        ),
    ];
  }

  BucketStatus? statusFor(String bucketId) {
    for (final s in statuses) {
      if (s.bucketId == bucketId) return s;
    }
    return null;
  }

  double get totalBudget => statuses.fold(0, (s, b) => s + b.budget);
  double get totalSpent => currentExpenses.fold(0, (s, e) => s + e.amount);
  double get totalRemaining => totalBudget - totalSpent;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rolloverTimer?.cancel();
    _monthSub?.cancel();
    _expenseSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
