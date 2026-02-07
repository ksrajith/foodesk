import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';

/// Lists approved users (from users collection) with search, status, and Activate/Deactivate actions.
class AdminApprovedRegistrationsScreen extends StatefulWidget {
  const AdminApprovedRegistrationsScreen({Key? key}) : super(key: key);

  @override
  State<AdminApprovedRegistrationsScreen> createState() => _AdminApprovedRegistrationsScreenState();
}

class _AdminApprovedRegistrationsScreenState extends State<AdminApprovedRegistrationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  static const int _pageSize = 20;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Registrations'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: (_) => setState(() => _page = 0),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                var docs = snapshot.data!.docs;
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data();
                    final name = (data['name'] as String? ?? '').toLowerCase();
                    final email = (data['email'] as String? ?? '').toLowerCase();
                    return name.contains(query) || email.contains(query);
                  }).toList();
                }
                final total = docs.length;
                final start = _page * _pageSize;
                final pageDocs = docs.skip(start).take(_pageSize).toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No users found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('User Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Date Approved')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: pageDocs.map((doc) => _buildRow(doc)).toList(),
                          ),
                        ),
                      ),
                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final uid = doc.id;
    final name = data['name'] as String? ?? '—';
    final email = data['email'] as String? ?? '—';
    final role = data['role'] as String? ?? '—';
    final status = (data['accountStatus'] as String?)?.toLowerCase() == 'deactivated' ? 'Deactivated' : 'Active';
    final approvedAt = data['approvedAt'];
    String dateStr = '—';
    if (approvedAt != null) {
      if (approvedAt is Timestamp) dateStr = DateTimeUtils.formatAny(approvedAt);
      else if (approvedAt is DateTime) dateStr = DateTimeUtils.formatDateTime(approvedAt);
      else if (approvedAt is String) dateStr = DateTimeUtils.formatAny(approvedAt);
    }
    final isDeactivated = status == 'Deactivated';

    return DataRow(
      cells: [
        DataCell(Text(name)),
        DataCell(Text(email)),
        DataCell(Text(role)),
        DataCell(
          Text(
            status,
            style: TextStyle(
              color: isDeactivated ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(Text(dateStr)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.person, size: 18),
                label: const Text('View'),
                onPressed: () => _showUserProfile(context, uid, data),
              ),
              const SizedBox(width: 4),
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
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
          content: Text('Activate $userName ($userEmail)? They will be able to sign in again.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activate')),
          ],
        ),
      );
      if (confirm != true) return;
    } else {
      String? reason;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Deactivate account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deactivate $userName ($userEmail)? They will not be able to sign in or place orders.'),
                const SizedBox(height: 16),
                const Text('Reason (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Policy violation',
                    border: OutlineInputBorder(),
                  ),
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
      reason = result['reason'] as String?;
      await _updateUserStatus(context, userId, activate, reason);
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
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
