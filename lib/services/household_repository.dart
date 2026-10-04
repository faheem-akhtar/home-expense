import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bucket.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/month_record.dart';

/// All reads/writes for one household's data in Firestore.
///
/// Layout:
///   households/{hid}                  name, members[], carryOver
///   households/{hid}/buckets/{id}     category templates
///   households/{hid}/months/{yyyy-MM} budget snapshot + closing summary
///   households/{hid}/expenses/{id}    transactions (with monthKey)
class HouseholdRepository {
  HouseholdRepository(this.householdId, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final String householdId;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _household =>
      _db.collection('households').doc(householdId);
  CollectionReference<Map<String, dynamic>> get _buckets => _household.collection('buckets');
  CollectionReference<Map<String, dynamic>> get _months => _household.collection('months');
  CollectionReference<Map<String, dynamic>> get _expenses => _household.collection('expenses');

  // ---- Streams -----------------------------------------------------------

  Stream<Household> household() => _household.snapshots().map(Household.fromDoc);

  Stream<List<Bucket>> buckets() => _buckets.snapshots().map((s) => s.docs
      .map(Bucket.fromDoc)
      .where((b) => !b.archived)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order)));

  Stream<MonthRecord?> month(String key) =>
      _months.doc(key).snapshots().map((d) => d.exists ? MonthRecord.fromDoc(d) : null);

  Stream<List<MonthRecord>> monthsInYear(int year) => _months
      .where('key', isGreaterThanOrEqualTo: '$year-01')
      .where('key', isLessThanOrEqualTo: '$year-12')
      .snapshots()
      .map((s) => s.docs.map(MonthRecord.fromDoc).toList());

  /// Newest first. Sorted client-side to avoid needing a composite index.
  Stream<List<Expense>> expensesForMonth(String key) => _expenses
      .where('monthKey', isEqualTo: key)
      .snapshots()
      .map((s) => _newestFirst(s.docs.map(Expense.fromDoc)));

  Stream<List<Expense>> expensesInYear(int year) => _expenses
      .where('monthKey', isGreaterThanOrEqualTo: '$year-01')
      .where('monthKey', isLessThanOrEqualTo: '$year-12')
      .snapshots()
      .map((s) => _newestFirst(s.docs.map(Expense.fromDoc)));

  static List<Expense> _newestFirst(Iterable<Expense> items) =>
      items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ---- Household ---------------------------------------------------------

  Future<void> setCarryOver(bool value) => _household.update({'carryOver': value});

  // ---- Buckets -----------------------------------------------------------

  String newBucketId() => _buckets.doc().id;

  /// Saves the template and applies the same budget to the current month.
  Future<void> saveBucket(Bucket bucket, {required String currentMonthKey}) {
    final batch = _db.batch();
    batch.set(_buckets.doc(bucket.id), bucket.toMap());
    batch.set(
      _months.doc(currentMonthKey),
      {
        'key': currentMonthKey,
        'allocations': {
          bucket.id: {
            'name': bucket.name,
            'icon': bucket.icon,
            'budget': bucket.budget,
            'order': bucket.order,
          },
        },
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  /// Archives the bucket (past expenses keep their bucket name) and removes
  /// it from the current month.
  Future<void> deleteBucket(String bucketId, {required String currentMonthKey}) {
    final batch = _db.batch();
    batch.update(_buckets.doc(bucketId), {'archived': true});
    batch.update(_months.doc(currentMonthKey), {'allocations.$bucketId': FieldValue.delete()});
    return batch.commit();
  }

  // ---- Expenses ----------------------------------------------------------

  String newExpenseId() => _expenses.doc().id;

  Future<void> saveExpense(Expense expense) => _expenses.doc(expense.id).set(expense.toMap());

  Future<void> deleteExpense(String id) => _expenses.doc(id).delete();

  // ---- Monthly reset -----------------------------------------------------

  /// Makes sure the month document for [key] exists. On the first call in a
  /// new month this closes the previous month (logging spent/unspent per
  /// bucket into its `summary`) and opens the new one from the bucket
  /// templates, carrying unspent balances over if the household opted in.
  ///
  /// Safe to call from both devices at once: the final write is a
  /// transaction that does nothing if the month already exists.
  Future<void> ensureMonth(String key) async {
    final monthRef = _months.doc(key);
    if ((await monthRef.get()).exists) return;

    final household = Household.fromDoc(await _household.get());
    final templates = (await _buckets.get()).docs.map(Bucket.fromDoc).where((b) => !b.archived);

    final prevSnap = await _months
        .where('key', isLessThan: key)
        .orderBy('key', descending: true)
        .limit(1)
        .get();

    MonthRecord? prev;
    Map<String, dynamic>? prevSummary;
    final carry = <String, double>{};

    if (prevSnap.docs.isNotEmpty) {
      prev = MonthRecord.fromDoc(prevSnap.docs.first);
      final prevExpenses = (await _expenses.where('monthKey', isEqualTo: prev.key).get())
          .docs
          .map(Expense.fromDoc);
      final spent = <String, double>{};
      for (final e in prevExpenses) {
        spent[e.bucketId] = (spent[e.bucketId] ?? 0) + e.amount;
      }
      prevSummary = {};
      for (final a in prev.allocations.values) {
        final s = spent[a.bucketId] ?? 0;
        final unspent = a.total - s;
        prevSummary[a.bucketId] = {
          'name': a.name,
          'budget': a.total,
          'spent': s,
          'unspent': unspent,
        };
        if (household.carryOver) carry[a.bucketId] = math.max(0, unspent);
      }
    }

    final allocations = {
      for (final b in templates)
        b.id: MonthAllocation(
          bucketId: b.id,
          name: b.name,
          icon: b.icon,
          budget: b.budget,
          carryIn: carry[b.id] ?? 0,
          order: b.order,
        ).toMap(),
    };

    final closing = prev != null && !prev.closed ? prev.key : null;
    await _db.runTransaction((tx) async {
      if ((await tx.get(monthRef)).exists) return;
      tx.set(monthRef, {
        'key': key,
        'allocations': allocations,
        'closed': false,
        'carryOverApplied': household.carryOver,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (closing != null) {
        tx.update(_months.doc(closing), {
          'closed': true,
          'summary': prevSummary,
          'closedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
