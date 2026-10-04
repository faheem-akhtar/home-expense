import 'package:flutter/material.dart';

const budgetGreen = Color(0xFF2E7D32);
const budgetYellow = Color(0xFFF9A825);
const budgetRed = Color(0xFFC62828);

/// Green below 75% used, yellow 75–90%, red above 90%.
Color usageColor(double usedRatio) {
  if (usedRatio < 0.75) return budgetGreen;
  if (usedRatio <= 0.90) return budgetYellow;
  return budgetRed;
}
