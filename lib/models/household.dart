import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.members,
    required this.carryOver,
  });

  final String id;
  final String name;
  final List<String> members;

  /// When true, unspent balances roll into next month's buckets.
  final bool carryOver;

  factory Household.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Household(
      id: doc.id,
      name: m['name'] as String? ?? 'Home',
      members: List<String>.from(m['members'] as List? ?? const []),
      carryOver: m['carryOver'] == true,
    );
  }
}
