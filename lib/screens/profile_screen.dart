import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_constants.dart';
import '../utils/date_time_utils.dart';
import '../utils/password_policy.dart';
import '../utils/screen_helpers.dart';

/// Profile for any signed-in role: view account/registration info; update name and password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _nameInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (!_wantsPasswordChange) return null;
    if (value == null || value.isEmpty) return 'Please enter a new password';
    return validateRegistrationPassword(value);
  }

  bool get _wantsPasswordChange {
    final current = _currentPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    return current.isNotEmpty || newPw.isNotEmpty || confirm.isNotEmpty;
  }

  Future<void> _saveProfile({
    required String uid,
    required String? currentName,
    required String email,
  }) async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    final nameChanged = newName != (currentName ?? '').trim();

    if (!nameChanged && !_wantsPasswordChange) {
      showAppSnackBar(context, message: 'No changes to save.');
      return;
    }

    if (_wantsPasswordChange) {
      if (email.isEmpty || !email.contains('@')) {
        showAppSnackBar(context, message: 'Cannot change password: no email on this account.', backgroundColor: Colors.red);
        return;
      }
      if (_currentPasswordController.text.isEmpty) {
        showAppSnackBar(context, message: 'Enter your current password to change it.', backgroundColor: Colors.orange);
        return;
      }
      if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
        showAppSnackBar(context, message: 'Enter and confirm your new password.', backgroundColor: Colors.orange);
        return;
      }
      final policyError = validateRegistrationPassword(_newPasswordController.text);
      if (policyError != null) {
        showAppSnackBar(context, message: policyError, backgroundColor: Colors.orange);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_wantsPasswordChange) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? email,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);
        await FirebaseFirestore.instance.collection(AppConstants.collectionUsers).doc(uid).set({
          'mustChangePassword': false,
          'passwordResetAt': null,
          'passwordResetBy': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }

      if (nameChanged) {
        await user.updateDisplayName(newName);
        await FirebaseFirestore.instance.collection(AppConstants.collectionUsers).doc(uid).set({
          'name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      showAppSnackBar(context, message: 'Profile updated successfully.', backgroundColor: Colors.green);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'wrong-password'
          ? 'Current password is incorrect.'
          : e.code == 'requires-recent-login'
              ? 'Please sign out, sign in again, then retry.'
              : (e.message ?? 'Failed to update profile');
      showAppSnackBar(context, message: msg, backgroundColor: Colors.red);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: 'Failed: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.teal.shade600, foregroundColor: Colors.white),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final uid = authUser.uid;
    final authEmail = authUser.email ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(AppConstants.collectionUsers).doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data?.data();
          final name = userData?['name'] as String? ?? authUser.displayName ?? '';
          if (!_nameInitialized) {
            _nameController.text = name;
            _nameInitialized = true;
          }

          final role = (userData?['role'] as String?) ?? 'Customer';
          final accountStatus = _formatAccountStatus(userData?['accountStatus'] as String?);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(AppConstants.collectionRegistrationRequests).doc(uid).snapshots(),
            builder: (context, regSnap) {
              final regData = regSnap.data?.exists == true ? regSnap.data!.data() : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionCard(
                        title: 'Registration details',
                        icon: Icons.assignment_outlined,
                        children: _registrationRows(regData),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: 'Edit profile',
                        icon: Icons.edit_outlined,
                        children: [
                          _readonlyFormField(
                            label: 'Email address',
                            value: authEmail,
                            icon: Icons.email,
                            helperText: 'Cannot be changed',
                          ),
                          const SizedBox(height: 16),
                          _readonlyFormField(
                            label: 'User role',
                            value: role,
                            icon: Icons.badge_outlined,
                            helperText: 'Assigned by administrator',
                            valueColor: Colors.teal.shade800,
                          ),
                          const SizedBox(height: 16),
                          _readonlyFormField(
                            label: 'Account status',
                            value: accountStatus,
                            icon: Icons.info_outline,
                            helperText: 'Cannot be changed',
                            valueColor: _statusColor(accountStatus),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: _validateName,
                          ),
                          const SizedBox(height: 20),
                          Text('Change password', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          const SizedBox(height: 4),
                          Text(
                            'Leave blank to keep your current password.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrent,
                            decoration: _passwordDecoration(
                              label: 'Current password',
                              obscure: _obscureCurrent,
                              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            decoration: _passwordDecoration(
                              label: 'New password',
                              obscure: _obscureNew,
                              onToggle: () => setState(() => _obscureNew = !_obscureNew),
                              helperText: '8–12 characters; use uppercase, lowercase and numbers',
                              onPolicyInfo: () => showPasswordPolicyDialog(context),
                            ),
                            validator: _validateNewPassword,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: _passwordDecoration(
                              label: 'Confirm new password',
                              obscure: _obscureConfirm,
                              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (value) {
                              if (!_wantsPasswordChange) return null;
                              if (value == null || value.isEmpty) return 'Please confirm your new password';
                              if (value != _newPasswordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => _saveProfile(uid: uid, currentName: name, email: authEmail),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatAccountStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Active';
    final lower = raw.toLowerCase();
    if (lower == 'deactivated') return 'Deactivated';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  static Color? _statusColor(String status) {
    if (status.toLowerCase() == 'deactivated') return Colors.red.shade700;
    return Colors.green.shade700;
  }

  static String _formatRegistrationStatus(String? status) {
    final s = (status ?? 'unknown').toLowerCase();
    switch (s) {
      case 'pending':
        return 'Pending approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status ?? '—';
    }
  }

  List<Widget> _registrationRows(Map<String, dynamic>? reg) {
    if (reg == null) {
      return [
        Text(
          'No registration request found for this account.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ];
    }

    final status = _formatRegistrationStatus(reg['status'] as String?);
    final requestedRole = reg['requestedRole'] as String? ?? '—';
    final approvedRole = reg['approvedRole'] as String?;
    final adminComment = reg['adminComment'] as String? ?? '';
    final createdAt = DateTimeUtils.formatAny(reg['createdAt']);
    final respondedAt = DateTimeUtils.formatAny(reg['respondedAt']);
    final respondedBy = reg['respondedByEmail'] as String? ?? reg['respondedByName'] as String? ?? '—';

    return [
      _readOnlyRow('Registration status', status, valueColor: _registrationStatusColor(reg['status'] as String?)),
      _readOnlyRow('Requested role', requestedRole),
      if (approvedRole != null && approvedRole.isNotEmpty) _readOnlyRow('Approved role', approvedRole),
      _readOnlyRow('Submitted', createdAt),
      if ((reg['status'] as String? ?? '').toLowerCase() != 'pending') ...[
        _readOnlyRow('Reviewed', respondedAt),
        _readOnlyRow('Reviewed by', respondedBy),
      ],
      if (adminComment.isNotEmpty) _readOnlyRow('Admin comment', adminComment),
    ];
  }

  static Color? _registrationStatusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange.shade800;
      default:
        return null;
    }
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _readonlyFormField({
    required String label,
    required String value,
    required IconData icon,
    String? helperText,
    Color? valueColor,
  }) {
    return TextFormField(
      readOnly: true,
      enableInteractiveSelection: true,
      initialValue: value,
      style: TextStyle(
        color: valueColor ?? Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade200,
        helperText: helperText,
        helperMaxLines: 1,
      ),
    );
  }

  Widget _readOnlyRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? helperText,
    VoidCallback? onPolicyInfo,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      helperText: helperText,
      helperMaxLines: 2,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPolicyInfo != null)
            IconButton(
              icon: Icon(Icons.info_outline, size: 22, color: Colors.teal.shade600),
              onPressed: onPolicyInfo,
              tooltip: 'Password policy',
            ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
