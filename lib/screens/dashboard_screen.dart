import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/budget_colors.dart';
import '../utils/format.dart';
import '../widgets/budget_bar.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final statuses = state.statuses;

    return Scaffold(
      appBar: AppBar(title: Text(state.household?.name ?? 'Home Expenses')),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => AddExpenseScreen.open(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _SummaryCard(state: state),
          const SizedBox(height: 20),
          Text('BUCKETS', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (statuses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No buckets yet. Add some under Settings.', textAlign: TextAlign.center),
            ),
          for (final s in statuses)
            _BucketCard(
              status: s,
              onTap: () => AddExpenseScreen.open(context, bucketId: s.bucketId),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final budget = state.totalBudget;
    final spent = state.totalSpent;
    final ratio = budget <= 0 ? 0.0 : spent / budget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(monthLabel(state.monthKey).toUpperCase(), style: text.labelLarge),
            const SizedBox(height: 8),
            Text('Total left', style: text.bodyMedium),
            Text(
              aed(state.totalRemaining),
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: usageColor(ratio),
              ),
            ),
            const SizedBox(height: 12),
            BudgetBar(usedRatio: ratio, height: 14),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Budget', value: aed(budget))),
                Expanded(child: _Figure(label: 'Spent', value: aed(spent))),
                _Figure(label: 'Used', value: '${(ratio * 100).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        Text(value, style: text.titleSmall),
      ],
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.status, required this.onTap});

  final BucketStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = status;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(s.icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.name, style: text.titleMedium)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Left', style: text.bodySmall),
                      Text(
                        aed(s.remaining),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: usageColor(s.usedRatio),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BudgetBar(usedRatio: s.usedRatio, height: 6),
              const SizedBox(height: 6),
              Text(
                'Spent ${aed(s.spent)} of ${aed(s.budget)}'
                '${s.carryIn > 0 ? ' (incl. ${aed(s.carryIn)} carried over)' : ''}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
