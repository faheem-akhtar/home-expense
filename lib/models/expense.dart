import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/format.dart';
import 'payment_method.dart';

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.bucketId,
    required this.bucketName,
    required this.bucketIcon,
    required this.paymentMethod,
    required this.note,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.receiptUrl,
    this.updatedByName,
  });

  final String id;
  final double amount;
  final String bucketId;
  final String bucketName;
  final String bucketIcon;
  final PaymentMethod paymentMethod;
  final String note;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final String? receiptUrl;
  final String? updatedByName;

  String get monthKey => monthKeyOf(createdAt);

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Expense(
      id: doc.id,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      bucketId: m['bucketId'] as String? ?? '',
      bucketName: m['bucketName'] as String? ?? '',
      bucketIcon: m['bucketIcon'] as String? ?? '💰',
      paymentMethod: PaymentMethod.parse(m['paymentMethod'] as String?),
      note: m['note'] as String? ?? '',
      userId: m['userId'] as String? ?? '',
      userName: m['userName'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receiptUrl: m['receiptUrl'] as String?,
      updatedByName: m['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'bucketId': bucketId,
        'bucketName': bucketName,
        'bucketIcon': bucketIcon,
        'paymentMethod': paymentMethod.name,
        'note': note,
        'userId': userId,
        'userName': userName,
        'createdAt': Timestamp.fromDate(createdAt),
        'monthKey': monthKey,
        'receiptUrl': receiptUrl,
        if (updatedByName != null) 'updatedByName': updatedByName,
      };

  /// "Faheem added AED 120 (Playtomic)"
  String get auditLine {
    final suffix = note.isEmpty ? '' : ' ($note)';
    return '$userName added ${aed(amount)}$suffix';
  }
}
