import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, required this.isMine, this.onTap});

  final Expense expense;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = expense;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isMine ? scheme.primaryContainer : scheme.tertiaryContainer,
        child: Text(e.bucketIcon, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(e.auditLine),
      subtitle: Text([
        e.bucketName,
        e.paymentMethod.label,
        DateFormat('d MMM, HH:mm').format(e.createdAt),
        if (e.updatedByName != null) 'edited by ${e.updatedByName}',
      ].join(' · ')),
      trailing: e.receiptUrl != null ? const Icon(Icons.receipt_long, size: 20) : null,
    );
  }
}
