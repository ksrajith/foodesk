import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPendingRegistrations extends StatelessWidget {
  const AdminPendingRegistrations({Key? key}) : super(key: key);

  static const List<String> _roles = ['Customer', 'Supplier', 'Admin'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Registrations'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('registration_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No pending registration requests',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final email = data['email'] as String? ?? '—';
              final name = data['name'] as String? ?? '—';
              final requestedRole = data['requestedRole'] as String? ?? 'Customer';
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.person_add, color: Colors.teal.shade700),
                  ),
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$name · requested: $requestedRole'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showApprovalDialog(context, doc.reference.id, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Call this from admin dashboard (or elsewhere) to show approve/reject dialog for a pending request.
  static void showApprovalDialog(BuildContext scaffoldContext, String requestId, Map<String, dynamic> data) {
    final email = data['email'] as String? ?? '';
    final name = data['name'] as String? ?? '';
    String selectedRole = (data['requestedRole'] as String?) ?? 'Customer';
    final commentController = TextEditingController();

    showDialog(
      context: scaffoldContext,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) {
          return AlertDialog(
            title: const Text('Registration approval'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registration email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  const Text('User role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedRole = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Comment (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a comment for the user...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => _respondStatic(ctx, scaffoldContext, requestId, data, false, selectedRole, commentController.text),
                child: Text('Reject', style: TextStyle(color: Colors.red.shade700)),
              ),
              ElevatedButton(
                onPressed: () => _respondStatic(ctx, scaffoldContext, requestId, data, true, selectedRole, commentController.text),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
                child: const Text('Approve'),
              ),
            ],
          );
        },
      ),
    ).then((_) => commentController.dispose());
  }

  static Future<void> _respondStatic(
    BuildContext dialogContext,
    BuildContext screenContext,
    String requestId,
    Map<String, dynamic> data,
    bool approve,
    String role,
    String comment,
  ) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final adminName = FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'approvedRole': approve ? role : null,
        'adminComment': comment.isEmpty ? null : comment,
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': adminUid,
        'respondedByName': adminName,
        'respondedByEmail': adminEmail,
      });
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      if (!screenContext.mounted) return;
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Registration approved. User role: $role.' : 'Registration rejected.'),
          backgroundColor: approve ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showApprovalDialog(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) {
    showApprovalDialog(context, requestId, data);
  }

  /// [dialogContext] is the dialog's context (used only to pop). [screenContext] is the
  /// scaffold context for showing SnackBar so we never use a disposed dialog context.
  Future<void> _respond(
    BuildContext dialogContext,
    BuildContext screenContext,
    String requestId,
    Map<String, dynamic> data,
    bool approve,
    String role,
    String comment,
  ) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final adminName = FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    try {
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'approvedRole': approve ? role : null,
        'adminComment': comment.isEmpty ? null : comment,
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': adminUid,
        'respondedByName': adminName,
        'respondedByEmail': adminEmail,
      });

      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);

      if (!screenContext.mounted) return;
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Registration approved. User role: $role.' : 'Registration rejected.'),
          backgroundColor: approve ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
