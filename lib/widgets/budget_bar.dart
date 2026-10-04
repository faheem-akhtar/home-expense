import 'package:flutter/material.dart';

import '../utils/budget_colors.dart';

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.usedRatio, this.height = 10});

  final double usedRatio;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: usedRatio.clamp(0, 1).toDouble(),
        minHeight: height,
        color: usageColor(usedRatio),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
