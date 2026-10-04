import 'package:cloud_firestore/cloud_firestore.dart';

/// A budget category template. Its budget applies to every new month.
class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.icon,
    required this.budget,
    required this.order,
    this.archived = false,
  });

  final String id;
  final String name;
  final String icon;
  final double budget;
  final int order;
  final bool archived;

  factory Bucket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Bucket(
      id: doc.id,
      name: m['name'] as String? ?? '',
      icon: m['icon'] as String? ?? '💰',
      budget: (m['budget'] as num?)?.toDouble() ?? 0,
      order: (m['order'] as num?)?.toInt() ?? 0,
      archived: m['archived'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon,
        'budget': budget,
        'order': order,
        'archived': archived,
      };
}
