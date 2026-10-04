import 'package:intl/intl.dart';

final _amount = NumberFormat('#,##0.##', 'en_US');

/// Formats a number as "AED 1,234.5".
String aed(num value) => 'AED ${_amount.format(value)}';

/// Month keys look like "2026-10" and sort lexically in time order.
String monthKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime monthStart(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

String shiftMonth(String key, int delta) {
  final start = monthStart(key);
  return monthKeyOf(DateTime(start.year, start.month + delta));
}

String monthLabel(String key) => DateFormat('MMMM yyyy').format(monthStart(key));
