import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/month_record.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/budget_bar.dart';
import '../widgets/month_switcher.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(tabs: [Tab(text: 'Monthly'), Tab(text: 'Yearly')]),
        ),
        body: const TabBarView(children: [_MonthlyReport(), _YearlyReport()]),
      ),
    );
  }
}

String _compact(double v) => NumberFormat.compact().format(v);

// ---------------------------------------------------------------------------
// Monthly

class _MonthlyReport extends StatefulWidget {
  const _MonthlyReport();

  @override
  State<_MonthlyReport> createState() => _MonthlyReportState();
}

class _MonthlyReportState extends State<_MonthlyReport> {
  String? _key;
  String? _streamKey;
  Stream<MonthRecord?>? _month;
  Stream<List<Expense>>? _expenses;

  void _subscribe(AppState state, String key) {
    if (_streamKey == key) return;
    _streamKey = key;
    _month = state.repo.month(key);
    _expenses = state.repo.expensesForMonth(key);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final key = _key ?? state.monthKey;
    _subscribe(state, key);

    return Column(
      children: [
        MonthSwitcher(monthKey: key, onChanged: (k) => setState(() => _key = k)),
        Expanded(
          child: StreamBuilder<MonthRecord?>(
            stream: _month,
            builder: (context, monthSnap) => StreamBuilder<List<Expense>>(
              stream: _expenses,
              builder: (context, expSnap) {
                if (!expSnap.hasData) return const Center(child: CircularProgressIndicator());
                return _MonthlyBody(month: monthSnap.data, expenses: expSnap.data!);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow {
  _CategoryRow(this.id, this.name, this.icon, this.budget);
  final String id;
  final String name;
  final String icon;
  final double budget;
  double spent = 0;
  final byUser = <String, double>{};
}

class _MonthlyBody extends StatelessWidget {
  const _MonthlyBody({required this.month, required this.expenses});

  final MonthRecord? month;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppState>().user.uid;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final rows = <String, _CategoryRow>{
      for (final a in month?.sortedAllocations ?? const <MonthAllocation>[])
        a.bucketId: _CategoryRow(a.bucketId, a.name, a.icon, a.total),
    };
    final users = <String, String>{}; // uid -> name
    for (final e in expenses) {
      final row = rows.putIfAbsent(
          e.bucketId, () => _CategoryRow(e.bucketId, e.bucketName, e.bucketIcon, 0));
      row.spent += e.amount;
      row.byUser[e.userId] = (row.byUser[e.userId] ?? 0) + e.amount;
      users[e.userId] = e.userName;
    }
    final userIds = users.keys.toList()..sort((a, b) => a == me ? -1 : (b == me ? 1 : 0));
    final userColors = [scheme.primary, scheme.tertiary];
    final rowList = rows.values.toList();

    final totalBudget = rowList.fold<double>(0, (s, r) => s + r.budget);
    final totalSpent = rowList.fold<double>(0, (s, r) => s + r.spent);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Spent ${aed(totalSpent)} of ${aed(totalBudget)}', style: text.titleMedium),
        const SizedBox(height: 16),
        Text('By category', style: text.labelLarge),
        const SizedBox(height: 8),
        for (final r in rowList)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${r.icon}  ${r.name}'),
                    const Spacer(),
                    Text('${aed(r.spent)} / ${aed(r.budget)}', style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                BudgetBar(
                  usedRatio: r.budget <= 0 ? (r.spent > 0 ? 1 : 0) : r.spent / r.budget,
                  height: 6,
                ),
              ],
            ),
          ),
        if (userIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Who spent what', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              for (var i = 0; i < userIds.length; i++)
                _Legend(color: userColors[i % userColors.length], label: users[userIds[i]]!),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, meta) => Text(_compact(v), style: text.bodySmall),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= rowList.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(rowList[i].icon, style: const TextStyle(fontSize: 18)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < rowList.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      for (var u = 0; u < userIds.length; u++)
                        BarChartRodData(
                          toY: rowList[i].byUser[userIds[u]] ?? 0,
                          color: userColors[u % userColors.length],
                          width: 10,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                    ],
                  ),
              ],
            )),
          ),
          const SizedBox(height: 12),
          for (final uid in userIds)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(users[uid]!),
              trailing: Text(aed(
                  expenses.where((e) => e.userId == uid).fold<double>(0, (s, e) => s + e.amount))),
            ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Yearly

class _YearlyReport extends StatefulWidget {
  const _YearlyReport();

  @override
  State<_YearlyReport> createState() => _YearlyReportState();
}

class _YearlyReportState extends State<_YearlyReport> {
  int _year = DateTime.now().year;
  int? _streamYear;
  Stream<List<MonthRecord>>? _months;
  Stream<List<Expense>>? _expenses;
  bool _exporting = false;

  void _subscribe(AppState state) {
    if (_streamYear == _year) return;
    _streamYear = _year;
    _months = state.repo.monthsInYear(_year);
    _expenses = state.repo.expensesInYear(_year);
  }

  Future<void> _export(bool pdf, List<MonthRecord> months, List<Expense> expenses) async {
    setState(() => _exporting = true);
    try {
      if (pdf) {
        await ExportService.instance.sharePdf(year: _year, months: months, expenses: expenses);
      } else {
        await ExportService.instance.shareCsv(year: _year, months: months, expenses: expenses);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _subscribe(state);
    final now = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _year--),
            ),
            Text('$_year', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _year >= now.year ? null : () => setState(() => _year++),
            ),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<MonthRecord>>(
            stream: _months,
            builder: (context, monthSnap) => StreamBuilder<List<Expense>>(
              stream: _expenses,
              builder: (context, expSnap) {
                if (!monthSnap.hasData || !expSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _YearlyBody(
                  year: _year,
                  months: monthSnap.data!,
                  expenses: expSnap.data!,
                  exporting: _exporting,
                  onExport: (pdf) => _export(pdf, monthSnap.data!, expSnap.data!),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _YearlyBody extends StatelessWidget {
  const _YearlyBody({
    required this.year,
    required this.months,
    required this.expenses,
    required this.exporting,
    required this.onExport,
  });

  final int year;
  final List<MonthRecord> months;
  final List<Expense> expenses;
  final bool exporting;
  final ValueChanged<bool> onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final budgetByKey = {for (final m in months) m.key: m.totalBudget};
    final spent = List<double>.filled(12, 0);
    for (final e in expenses) {
      spent[e.createdAt.month - 1] += e.amount;
    }
    final budget = [
      for (var m = 1; m <= 12; m++) budgetByKey[monthKeyOf(DateTime(year, m))] ?? 0.0,
    ];
    final totalSpent = spent.fold<double>(0, (s, v) => s + v);
    final totalBudget = budget.fold<double>(0, (s, v) => s + v);
    final monthLetters = DateFormat.MMM();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Spent ${aed(totalSpent)} of ${aed(totalBudget)}', style: text.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 16, children: [
          _Legend(color: scheme.primary, label: 'Spent'),
          _Legend(color: scheme.outlineVariant, label: 'Budget'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, meta) => Text(_compact(v), style: text.bodySmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(monthLetters.format(DateTime(year, v.toInt() + 1)).substring(0, 1),
                        style: text.bodySmall),
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < 12; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(toY: budget[i], color: scheme.outlineVariant, width: 6),
                    BarChartRodData(toY: spent[i], color: scheme.primary, width: 6),
                  ],
                ),
            ],
          )),
        ),
        const SizedBox(height: 16),
        for (var i = 11; i >= 0; i--)
          if (budget[i] > 0 || spent[i] > 0)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(monthLabel(monthKeyOf(DateTime(year, i + 1)))),
              subtitle: BudgetBar(
                usedRatio: budget[i] <= 0 ? 1 : spent[i] / budget[i],
                height: 4,
              ),
              trailing: Text('${aed(spent[i])} / ${_compact(budget[i])}'),
            ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: exporting ? null : () => onExport(false),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Export CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: exporting ? null : () => onExport(true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
