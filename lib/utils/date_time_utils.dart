import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Centralized date-time formatting utilities.
///
/// Target format: `yyyy-MM-dd h.mm a`, e.g., `2026-01-18 7.15 PM`.
class DateTimeUtils {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd h.mm a');

  /// Formats a [DateTime] into the target string.
  static String formatDateTime(DateTime dt) => _fmt.format(dt);

  /// Formats various date representations: DateTime, Firestore [Timestamp], ISO-8601 [String].
  /// Returns 'N/A' when value is null or cannot be parsed.
  static String formatAny(dynamic value) {
    if (value == null) return 'N/A';

    try {
      if (value is DateTime) {
        return formatDateTime(value);
      }
      if (value is Timestamp) {
        return formatDateTime(value.toDate());
      }
      if (value is String && value.isNotEmpty) {
        // Try ISO-8601 parsing. If input lacks time, default to midnight.
        final dt = DateTime.tryParse(value);
        if (dt != null) return formatDateTime(dt);
        // Fallback: best-effort parse by adding T00:00:00 for date-only strings
        if (_isDateOnly(value)) {
          final dt2 = DateTime.tryParse(value.trim() + 'T00:00:00');
          if (dt2 != null) return formatDateTime(dt2);
        }
      }
    } catch (_) {
      // Ignore and fall through to N/A
    }
    return 'N/A';
  }

  static bool _isDateOnly(String s) {
    // Simple check for YYYY-MM-DD shape
    final parts = s.split('-');
    return parts.length == 3 && parts[0].length == 4 && parts[1].length == 2 && parts[2].length == 2;
  }
}

extension DateTimePretty on DateTime {
  String pretty() => DateTimeUtils.formatDateTime(this);
}

extension TimestampPretty on Timestamp {
  String pretty() => DateTimeUtils.formatDateTime(toDate());
}
