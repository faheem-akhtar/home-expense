import 'package:flutter/material.dart';

import '../utils/format.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.monthKey, required this.onChanged});

  final String monthKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCurrent = monthKey == monthKeyOf(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(shiftMonth(monthKey, -1)),
        ),
        Text(monthLabel(monthKey), style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrent ? null : () => onChanged(shiftMonth(monthKey, 1)),
        ),
      ],
    );
  }
}
