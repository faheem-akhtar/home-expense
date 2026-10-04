import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../services/receipt_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/expense_tile.dart';
import '../widgets/month_switcher.dart';
import 'add_expense_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _monthKey;
  String? _streamKey;
  Stream<List<Expense>>? _stream;

  Stream<List<Expense>> _expensesFor(AppState state, String key) {
    if (_streamKey != key) {
      _streamKey = key;
      _stream = state.repo.expensesForMonth(key);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final key = _monthKey ?? state.monthKey;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          MonthSwitcher(monthKey: key, onChanged: (k) => setState(() => _monthKey = k)),
          Expanded(
            child: key == state.monthKey
                ? _ExpenseList(expenses: state.currentExpenses)
                : StreamBuilder<List<Expense>>(
                    stream: _expensesFor(state, key),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      return _ExpenseList(expenses: snap.data!);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const Center(child: Text('No expenses logged'));
    final me = context.read<AppState>().user.uid;
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);

    return ListView.separated(
      itemCount: expenses.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${expenses.length} entries · ${aed(total)}',
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        final e = expenses[i - 1];
        return ExpenseTile(
          expense: e,
          isMine: e.userId == me,
          onTap: () => _showActions(context, e),
        );
      },
    );
  }

  void _showActions(BuildContext context, Expense e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(e.auditLine),
              subtitle: Text('${e.bucketName} · ${e.paymentMethod.label} · '
                  '${DateFormat('EEE d MMM yyyy, HH:mm').format(e.createdAt)}'),
            ),
            if (e.receiptUrl != null)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('View receipt'),
                onTap: () {
                  Navigator.pop(sheet);
                  _showReceipt(context, e.receiptUrl!);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheet);
                AddExpenseScreen.open(context, existing: e);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(sheet);
                _confirmDelete(context, e);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Expense e) async {
    final repo = context.read<AppState>().repo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e.auditLine}\n\nThe amount goes back into ${e.bucketName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    repo.deleteExpense(e.id);
    if (e.receiptUrl != null) ReceiptService.instance.delete(e.receiptUrl!);
  }
}
