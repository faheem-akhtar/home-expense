import 'package:flutter_test/flutter_test.dart';
import 'package:home_expense/utils/budget_colors.dart';
import 'package:home_expense/utils/format.dart';

void main() {
  test('month keys sort and shift across year boundaries', () {
    expect(monthKeyOf(DateTime(2026, 10, 2)), '2026-10');
    expect(shiftMonth('2026-12', 1), '2027-01');
    expect(shiftMonth('2026-01', -1), '2025-12');
  });

  test('aed formats with thousands separators', () {
    expect(aed(6350), 'AED 6,350');
    expect(aed(120.5), 'AED 120.5');
  });

  test('usage colour thresholds', () {
    expect(usageColor(0.5), budgetGreen);
    expect(usageColor(0.8), budgetYellow);
    expect(usageColor(0.95), budgetRed);
  });
}
