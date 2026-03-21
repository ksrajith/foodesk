import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical role labels for registration / user role grouping.
String normalizeRegistrationRole(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  if (r == 'admin') return 'Admin';
  if (r == 'supplier' || r == 'vendor') return 'Supplier';
  return 'Customer';
}

const List<String> kRegistrationRoleLabels = ['Customer', 'Supplier', 'Admin'];

DateTime? registrationCreatedAt(Map<String, dynamic> data) {
  final v = data['createdAt'];
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime? registrationRespondedAt(Map<String, dynamic> data) {
  final v = data['respondedAt'];
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Start of local day for range compare.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// End-exclusive upper bound for "through end of day".
DateTime endOfDayExclusive(DateTime d) => DateTime(d.year, d.month, d.day).add(const Duration(days: 1));

bool registrationInDateRange(
  Map<String, dynamic> data,
  DateTime? from,
  DateTime? to,
) {
  if (from == null && to == null) return true;
  final status = (data['status'] as String? ?? '').toLowerCase();
  final dt = status == 'pending' ? registrationCreatedAt(data) : registrationRespondedAt(data);
  if (dt == null) return false;
  if (from != null && dt.isBefore(startOfDay(from))) return false;
  if (to != null && !dt.isBefore(endOfDayExclusive(to))) return false;
  return true;
}
