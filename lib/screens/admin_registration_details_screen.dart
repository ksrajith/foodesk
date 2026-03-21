import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../utils/date_time_utils.dart';
import '../utils/registration_stats.dart';
import '../utils/registration_report_pdf.dart';

/// Optional navigation args when opening from Registration History counts.
class RegistrationDetailsArgs {
  const RegistrationDetailsArgs({
    this.initialStatus = 'pending',
    this.initialRole,
    this.initialRespondedByEmail,
    this.initialDateFrom,
    this.initialDateTo,
  });

  /// `pending`, `approved`, `rejected`, or `all`
  final String initialStatus;
  final String? initialRole;
  final String? initialRespondedByEmail;
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;
}

/// Filterable table of registration requests (pending / approved / rejected).
class AdminRegistrationDetailsScreen extends StatefulWidget {
  const AdminRegistrationDetailsScreen({Key? key, this.args}) : super(key: key);

  final RegistrationDetailsArgs? args;

  @override
  State<AdminRegistrationDetailsScreen> createState() => _AdminRegistrationDetailsScreenState();
}

class _AdminRegistrationDetailsScreenState extends State<AdminRegistrationDetailsScreen> {
  static const int _pageSize = 15;

  late String _statusFilter;
  String? _roleFilter;
  String? _respondedByFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    _statusFilter = (a?.initialStatus ?? 'pending').toLowerCase();
    if (!['pending', 'approved', 'rejected', 'all'].contains(_statusFilter)) {
      _statusFilter = 'pending';
    }
    _roleFilter = a?.initialRole;
    if (_roleFilter != null && !kRegistrationRoleLabels.contains(_roleFilter)) {
      _roleFilter = null;
    }
    _respondedByFilter = a?.initialRespondedByEmail?.trim();
    if (_respondedByFilter != null && _respondedByFilter!.isEmpty) _respondedByFilter = null;
    _dateFrom = a?.initialDateFrom;
    _dateTo = a?.initialDateTo;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((d) {
      if (d.id == '_init') return false;
      final data = d.data();
      final status = (data['status'] as String? ?? '').toLowerCase();

      if (_statusFilter != 'all') {
        if (status != _statusFilter) return false;
      }

      if (_roleFilter != null) {
        final roleForRow = _roleForRequest(data, status);
        if (roleForRow != _roleFilter) return false;
      }

      if (_respondedByFilter != null && _respondedByFilter!.isNotEmpty) {
        if (status == 'pending') return false;
        final by = (data['respondedByEmail'] as String? ?? '').trim().toLowerCase();
        if (by != _respondedByFilter!.toLowerCase()) return false;
      }

      if (!registrationInDateRange(data, _dateFrom, _dateTo)) return false;
      return true;
    }).toList();
  }

  static String _roleForRequest(Map<String, dynamic> data, String status) {
    if (status == 'approved') {
      return normalizeRegistrationRole(data['approvedRole'] as String? ?? data['requestedRole'] as String?);
    }
    return normalizeRegistrationRole(data['requestedRole'] as String?);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
      _page = 0;
    });
  }

  Future<void> _printDetailsPdf(List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered) async {
    final rows = <Map<String, String>>[];
    for (final d in filtered) {
      final data = d.data();
      final status = (data['status'] as String? ?? '').toLowerCase();
      final role = _roleForRequest(data, status);
      final decision = status == 'approved'
          ? 'Approved'
          : status == 'rejected'
              ? 'Rejected'
              : 'Pending';
      String dateStr = '—';
      final dt = status == 'pending' ? registrationCreatedAt(data) : registrationRespondedAt(data);
      if (dt != null) dateStr = DateTimeUtils.formatDateTime(dt);

      final byEmail = (data['respondedByEmail'] as String?)?.trim() ?? '';
      final byName = (data['respondedByName'] as String?)?.trim() ?? '';
      final by = byEmail.isNotEmpty ? byEmail : (byName.isNotEmpty ? byName : '—');
      final comment = (data['adminComment'] as String?)?.trim() ?? '';

      rows.add({
        'name': data['name'] as String? ?? '—',
        'email': data['email'] as String? ?? '—',
        'role': role,
        'status': decision,
        'date': dateStr,
        'by': status == 'pending' ? '—' : by,
        'comment': comment.isEmpty ? '—' : comment,
      });
    }

    final buf = StringBuffer()
      ..write('Status: $_statusFilter')
      ..write(' · Role: ${_roleFilter ?? "All"}')
      ..write(' · By: ${_respondedByFilter ?? "All"}');
    if (_dateFrom != null) buf.write(' · From: ${_dateFrom!.toIso8601String().split("T").first}');
    if (_dateTo != null) buf.write(' · To: ${_dateTo!.toIso8601String().split("T").first}');

    await printRegistrationDetailsPdf(
      title: 'Registration details',
      rows: rows,
      filterSummary: buf.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Details'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Print PDF',
            onPressed: () async {
              final regSnap = await FirebaseFirestore.instance.collection(AppConstants.collectionRegistrationRequests).get();
              final userSnap = await FirebaseFirestore.instance.collection(AppConstants.collectionUsers).get();
              final usersById = {for (final d in userSnap.docs) d.id: d.data()};
              final filtered = _applyFilters(regSnap.docs);
              if (!context.mounted) return;
              await _printDetailsPdf(filtered);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(AppConstants.collectionRegistrationRequests).snapshots(),
        builder: (context, regSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(AppConstants.collectionUsers).snapshots(),
            builder: (context, userSnapshot) {
              if (!regSnapshot.hasData || !userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final usersById = <String, Map<String, dynamic>>{
                for (final d in userSnapshot.data!.docs) d.id: d.data(),
              };
              final responders = _collectResponderEmails(regSnapshot.data!.docs);
              var filtered = _applyFilters(regSnapshot.data!.docs);
              filtered.sort((a, b) {
                final sa = (a.data()['status'] as String? ?? '').toLowerCase();
                final sb = (b.data()['status'] as String? ?? '').toLowerCase();
                final da = sa == 'pending' ? registrationCreatedAt(a.data()) : registrationRespondedAt(a.data());
                final db = sb == 'pending' ? registrationCreatedAt(b.data()) : registrationRespondedAt(b.data());
                final ma = da?.millisecondsSinceEpoch ?? 0;
                final mb = db?.millisecondsSinceEpoch ?? 0;
                return mb.compareTo(ma);
              });

              final total = filtered.length;
              final start = _page * _pageSize;
              final pageDocs = filtered.skip(start).take(_pageSize).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 160,
                                child: DropdownButtonFormField<String>(
                                  value: _statusFilter,
                                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('All')),
                                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _statusFilter = v;
                                      if (v == 'pending') _respondedByFilter = null;
                                      _page = 0;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<String?>(
                                  value: _roleFilter,
                                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), isDense: true),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('All roles')),
                                    ...kRegistrationRoleLabels.map(
                                      (r) => DropdownMenuItem<String?>(value: r, child: Text(r)),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _roleFilter = v;
                                    _page = 0;
                                  }),
                                ),
                              ),
                              if (_statusFilter != 'pending')
                                SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String?>(
                                    value: _respondedByFilter != null && responders.contains(_respondedByFilter!)
                                        ? _respondedByFilter
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Approved / Rejected by',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(value: null, child: Text('All')),
                                      ...responders.map(
                                        (e) => DropdownMenuItem<String?>(value: e, child: Text(e, overflow: TextOverflow.ellipsis)),
                                      ),
                                    ],
                                    onChanged: (v) => setState(() {
                                      _respondedByFilter = v;
                                      _page = 0;
                                    }),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(isFrom: true),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dateFrom == null ? 'From date' : 'From: ${_dateFrom!.toLocal().toString().split(" ").first}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(isFrom: false),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dateTo == null ? 'To date' : 'To: ${_dateTo!.toLocal().toString().split(" ").first}'),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _dateFrom = null;
                                  _dateTo = null;
                                  _page = 0;
                                }),
                                child: const Text('Clear dates'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Showing $total record(s)', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: total == 0
                        ? Center(child: Text('No records match filters.', style: TextStyle(color: Colors.grey.shade600)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(label: Text('User Name')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Approved / Rejected by')),
                                  DataColumn(label: Text('Comments')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: pageDocs.map((doc) => _buildRow(doc, usersById)).toList(),
                              ),
                            ),
                          ),
                  ),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                          ),
                          Text('${start + 1}-${start + pageDocs.length} of $total'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: start + pageDocs.length < total ? () => setState(() => _page++) : null,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<String> _collectResponderEmails(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final set = <String>{};
    for (final d in docs) {
      final e = (d.data()['respondedByEmail'] as String?)?.trim();
      if (e != null && e.isNotEmpty) set.add(e);
    }
    final list = set.toList()..sort();
    return list;
  }

  DataRow _buildRow(
    QueryDocumentSnapshot<Map<String, dynamic>> regDoc,
    Map<String, Map<String, dynamic>> usersById,
  ) {
    final data = regDoc.data();
    final uid = regDoc.id;
    final name = data['name'] as String? ?? '—';
    final email = data['email'] as String? ?? '—';
    final status = (data['status'] as String? ?? '').toLowerCase();
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final role = _roleForRequest(data, status);

    String decisionLabel;
    Color decisionColor;
    if (isApproved) {
      decisionLabel = 'Approved';
      decisionColor = Colors.green.shade700;
    } else if (status == 'rejected') {
      decisionLabel = 'Rejected';
      decisionColor = Colors.red.shade700;
    } else {
      decisionLabel = 'Pending';
      decisionColor = Colors.orange.shade800;
    }

    String dateStr = '—';
    final dt = isPending ? registrationCreatedAt(data) : registrationRespondedAt(data);
    if (dt != null) dateStr = DateTimeUtils.formatAny(dt);

    final byEmail = (data['respondedByEmail'] as String?)?.trim();
    final byName = (data['respondedByName'] as String?)?.trim();
    final byDisplay = (byEmail != null && byEmail.isNotEmpty)
        ? byEmail
        : (byName != null && byName.isNotEmpty)
            ? byName
            : '—';
    final comment = data['adminComment'] as String? ?? '';
    final commentDisplay = comment.isEmpty ? '—' : comment;

    final userData = usersById[uid];
    final accountStatus = (userData?['accountStatus'] as String?)?.toLowerCase() == 'deactivated' ? 'Deactivated' : 'Active';
    final isDeactivated = accountStatus == 'Deactivated';

    return DataRow(
      cells: [
        DataCell(Text(name)),
        DataCell(Text(email)),
        DataCell(Text(role)),
        DataCell(Text(decisionLabel, style: TextStyle(color: decisionColor, fontWeight: FontWeight.w600))),
        DataCell(Text(dateStr)),
        DataCell(
          Tooltip(
            message: isPending || byDisplay == '—' ? '' : [if (byEmail != null && byEmail.isNotEmpty) byEmail, if (byName != null && byName.isNotEmpty && byName != byEmail) byName].join('\n'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(isPending ? '—' : byDisplay, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        DataCell(
          InkWell(
            onTap: comment.isEmpty
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Admin comment'),
                        content: SingleChildScrollView(child: Text(comment)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                commentDisplay,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(color: comment.isEmpty ? Colors.grey : null),
              ),
            ),
          ),
        ),
        DataCell(
          isApproved && userData != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('View'),
                      onPressed: () => _showUserProfile(context, uid, userData),
                    ),
                    if (isDeactivated)
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Activate'),
                        onPressed: () => _setStatus(context, uid, true, name, email),
                      )
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Deactivate'),
                        onPressed: () => _setStatus(context, uid, false, name, email),
                      ),
                  ],
                )
              : isApproved
                  ? const Text('User not signed in yet', style: TextStyle(fontSize: 11, color: Colors.grey))
                  : const Text('—'),
        ),
      ],
    );
  }

  void _showUserProfile(BuildContext context, String uid, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('User profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileRow('User ID', uid),
              _profileRow('Name', data['name'] as String? ?? '—'),
              _profileRow('Email', data['email'] as String? ?? '—'),
              _profileRow('Role', data['role'] as String? ?? '—'),
              _profileRow('Status', (data['accountStatus'] as String?) ?? 'Active'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, String userId, bool activate, String userName, String userEmail) async {
    if (activate) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Activate account'),
          content: Text('Activate $userName ($userEmail)?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activate')),
          ],
        ),
      );
      if (confirm != true) return;
    } else {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Deactivate account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Deactivate $userName ($userEmail)?'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'reason': controller.text.trim()}),
                child: Text('Deactivate', style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          );
        },
      );
      if (result == null) return;
      await _updateUserStatus(context, userId, activate, result['reason'] as String?);
      return;
    }
    await _updateUserStatus(context, userId, activate, null);
  }

  Future<void> _updateUserStatus(BuildContext context, String userId, bool activate, String? reason) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (userId == adminUid && !activate) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot deactivate your own account.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      await FirebaseFirestore.instance.collection(AppConstants.collectionUsers).doc(userId).update({
        'accountStatus': activate ? 'Active' : 'Deactivated',
        if (!activate && reason != null && reason.isNotEmpty) 'deactivationReason': reason,
      });
      await FirebaseFirestore.instance.collection('audit_log').add({
        'adminId': adminUid,
        'adminEmail': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'action': activate ? 'activate' : 'deactivate',
        'targetUserId': userId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activate ? 'User activated.' : 'User deactivated.'),
          backgroundColor: activate ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }
}
