import 'package:flutter_test/flutter_test.dart';
import 'package:food_desk/utils/date_time_utils.dart';

void main() {
  test('formats DateTime to yyyy-MM-dd h.mm a', () {
    final dt = DateTime(2026, 1, 18, 19, 15); // 7:15 PM
    expect(DateTimeUtils.formatDateTime(dt), '2026-01-18 7.15 PM');
  });

  test('formats ISO string date-time', () {
    const iso = '2026-01-18T19:15:00';
    expect(DateTimeUtils.formatAny(iso), '2026-01-18 7.15 PM');
  });

  test('formats date-only string', () {
    const day = '2025-01-08';
    expect(DateTimeUtils.formatAny(day), '2025-01-08 12.00 AM');
  });

  test('handles null safely', () {
    expect(DateTimeUtils.formatAny(null), 'N/A');
  });
}
