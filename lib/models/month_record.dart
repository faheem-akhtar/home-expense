import 'package:cloud_firestore/cloud_firestore.dart';

/// One bucket's budget as frozen for a given month.
class MonthAllocation {
  const MonthAllocation({
    required this.bucketId,
    required this.name,
    required this.icon,
    required this.budget,
    required this.carryIn,
    required this.order,
  });

  final String bucketId;
  final String name;
  final String icon;
  final double budget;

  /// Unspent amount carried over from the previous month.
  final double carryIn;
  final int order;

  double get total => budget + carryIn;

  factory MonthAllocation.fromMap(String id, Map<String, dynamic> m) => MonthAllocation(
        bucketId: id,
        name: m['name'] as String? ?? '',
        icon: m['icon'] as String? ?? '💰',
        budget: (m['budget'] as num?)?.toDouble() ?? 0,
        carryIn: (m['carryIn'] as num?)?.toDouble() ?? 0,
        order: (m['order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon,
        'budget': budget,
        'carryIn': carryIn,
        'order': order,
      };
}

/// households/{id}/months/{yyyy-MM}: the budget snapshot for one month,
/// plus a closing summary once the month has rolled over.
class MonthRecord {
  const MonthRecord({
    required this.key,
    required this.allocations,
    required this.closed,
    this.summary,
  });

  final String key;
  final Map<String, MonthAllocation> allocations;
  final bool closed;
  final Map<String, dynamic>? summary;

  List<MonthAllocation> get sortedAllocations =>
      allocations.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  double get totalBudget => allocations.values.fold(0, (s, a) => s + a.total);

  factory MonthRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final raw = Map<String, dynamic>.from(m['allocations'] as Map? ?? const {});
    return MonthRecord(
      key: m['key'] as String? ?? doc.id,
      allocations: raw.map(
        (id, v) => MapEntry(id, MonthAllocation.fromMap(id, Map<String, dynamic>.from(v as Map))),
      ),
      closed: m['closed'] == true,
      summary: m['summary'] == null ? null : Map<String, dynamic>.from(m['summary'] as Map),
    );
  }
}
