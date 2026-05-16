import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPendingRegistrations extends StatelessWidget {
  const AdminPendingRegistrations({Key? key}) : super(key: key);

  static const List<String> _roles = ['Customer', 'Supplier', 'Admin'];

  static String _normalizeRole(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    if (r == 'admin') return 'Admin';
    if (r == 'supplier') return 'Supplier';
    if (r == 'customer' || r == 'user') return 'Customer';
    // Default/fallback so we never write an invalid role.
    return 'Customer';
  }

  /// Role the applicant asked for at signup (from request doc). Used on reject so email always has a value.
  static String requestedRoleFromRequestData(Map<String, dynamic> data) {
    return _normalizeRole(data['requestedRole'] as String?);
  }

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
    String selectedRole = _normalizeRole(data['requestedRole'] as String?);
    final commentController = TextEditingController();

    showDialog(
      context: scaffoldContext,
      builder: (ctx) => _ApprovalDialogContent(
        scaffoldContext: scaffoldContext,
        requestId: requestId,
        data: data,
        email: email,
        name: name,
      ),
    );
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
    final normalizedRole = _normalizeRole(role);
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final adminName = FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      // Ensure any open dropdown/menu overlay is closed.
      FocusManager.instance.primaryFocus?.unfocus();
      final update = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        'approvedRole': approve ? normalizedRole : null,
        'adminComment': comment.isEmpty ? null : comment,
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': adminUid,
        'respondedByName': adminName,
        'respondedByEmail': adminEmail,
      };
      // On reject, persist requestedRole from signup (not the admin dropdown) so Cloud Function email matches.
      if (!approve) {
        update['requestedRole'] = requestedRoleFromRequestData(data);
      }
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).update(update);
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext, rootNavigator: true).pop();
      // Defer SnackBar to next frame to avoid _dependents.isEmpty assertion when
      // the stream updates and the list dialog rebuilds (e.g. after approving an Admin request).
      final message = approve ? 'Registration approved. User role: $normalizedRole.' : 'Registration rejected.';
      final color = approve ? Colors.green : Colors.orange;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (screenContext.mounted && ScaffoldMessenger.maybeOf(screenContext) != null) {
          ScaffoldMessenger.of(screenContext).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: color),
          );
        }
      });
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (screenContext.mounted && ScaffoldMessenger.maybeOf(screenContext) != null) {
          ScaffoldMessenger.of(screenContext).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      });
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
      final update = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        'approvedRole': approve ? role : null,
        'adminComment': comment.isEmpty ? null : comment,
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': adminUid,
        'respondedByName': adminName,
        'respondedByEmail': adminEmail,
      };
      if (!approve) {
        update['requestedRole'] = requestedRoleFromRequestData(data);
      }
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).update(update);

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

class _ApprovalDialogContent extends StatefulWidget {
  const _ApprovalDialogContent({
    required this.scaffoldContext,
    required this.requestId,
    required this.data,
    required this.email,
    required this.name,
  });

  final BuildContext scaffoldContext;
  final String requestId;
  final Map<String, dynamic> data;
  final String email;
  final String name;

  @override
  State<_ApprovalDialogContent> createState() => _ApprovalDialogContentState();
}

class _ApprovalDialogContentState extends State<_ApprovalDialogContent> {
  late final TextEditingController _commentController;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _selectedRole = AdminPendingRegistrations._normalizeRole(widget.data['requestedRole'] as String?);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registration approval'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registration email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(widget.email, style: const TextStyle(fontSize: 16)),
            if (widget.name.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(widget.name, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 16),
            const Text('User role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: AdminPendingRegistrations._roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedRole = AdminPendingRegistrations._normalizeRole(v));
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Comment (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => AdminPendingRegistrations._respondStatic(
            context,
            widget.scaffoldContext,
            widget.requestId,
            widget.data,
            false,
            AdminPendingRegistrations._normalizeRole(_selectedRole),
            _commentController.text,
          ),
          child: Text('Reject', style: TextStyle(color: Colors.red.shade700)),
        ),
        ElevatedButton(
          onPressed: () => AdminPendingRegistrations._respondStatic(
            context,
            widget.scaffoldContext,
            widget.requestId,
            widget.data,
            true,
            AdminPendingRegistrations._normalizeRole(_selectedRole),
            _commentController.text,
          ),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
