import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/login_profile_service.dart';
import '../utils/fcm_utils.dart';
import '../utils/password_policy.dart';
import '../utils/screen_helpers.dart';

/// Login and registration screen.
/// - Login: Firebase Auth → load/create Firestore profile → optional password change → home by role.
/// - Register: create Auth user → pending `registration_requests` doc for admin approval.
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({Key? key}) : super(key: key);

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _loginProfileService = LoginProfileService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String selectedRole = 'Customer';
  final List<String> roles = ['Customer', 'Supplier', 'Admin'];
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Switches between Login and Register form layouts.
  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
      selectedRole = 'Customer';
    });
  }

  /// Login button / Register button — validates form then runs the matching flow.
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (isLogin) {
      await _handleLogin();
    } else {
      await _handleRegister();
    }
  }

  /// 1) Sign in with email/password.
  /// 2) Resolve Firestore profile (see [LoginProfileService]).
  /// 3) Optional forced password change, FCM token, navigate by role.
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = creds.user!;
      final uid = user.uid;

      final result = await _loginProfileService.resolveAfterSignIn(
        uid: uid,
        email: email,
        displayName: user.displayName,
      );

      if (!mounted) return;
      if (!await _handleLoginProfileResult(result)) return;

      final profile = result.profile!;
      await _completeLoginSuccess(profile);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: loginAuthErrorMessage(e), backgroundColor: Colors.red);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Login error. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Shows messages/dialogs when profile resolution blocks login. Returns false to stop.
  Future<bool> _handleLoginProfileResult(LoginProfileResult result) async {
    switch (result.blockReason) {
      case LoginBlockReason.deactivated:
        showAppSnackBar(
          context,
          message: 'Your account has been deactivated. Contact an administrator.',
          backgroundColor: Colors.red,
        );
        return false;
      case LoginBlockReason.registrationPending:
        showAppSnackBar(
          context,
          message: 'Your registration is pending admin approval. You will be notified when reviewed.',
          backgroundColor: Colors.orange,
        );
        return false;
      case LoginBlockReason.registrationRejected:
        await _showRegistrationRejectedDialog(result.rejectedAdminComment);
        return false;
      case null:
        break;
    }

    if (result.showApprovedDialog) {
      await _showRegistrationApprovedDialog(
        role: result.approvedRole!,
        adminComment: result.approvedAdminComment,
      );
      if (!mounted) return false;
    }

    return result.canContinue;
  }

  Future<void> _showRegistrationRejectedDialog(String? comment) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration Rejected'),
        content: Text(
          (comment == null || comment.isEmpty)
              ? 'Your registration request was rejected by an administrator.'
              : 'Your registration request was rejected.\n\nAdmin comment: $comment',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showRegistrationApprovedDialog({
    required String role,
    String? adminComment,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration Approved'),
        content: Text(
          (adminComment == null || adminComment.isEmpty)
              ? 'Your registration has been approved. Your role: $role.'
              : 'Your registration has been approved. Your role: $role.\n\nAdmin comment: $adminComment',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  /// After a valid profile: password change (if required), FCM, welcome, home route.
  Future<void> _completeLoginSuccess(Map<String, dynamic> profile) async {
    if (profile['mustChangePassword'] == true) {
      await Navigator.pushNamed(context, '/change-password', arguments: true);
      if (!mounted) return;
    }

    await refreshFcmTokenAndSave();

    if (!mounted) return;
    showAppSnackBar(
      context,
      message: 'Welcome ${profile['name']}!',
      backgroundColor: Colors.green,
    );
    navigateToHomeForProfile(context, profile);
  }

  /// Creates Firebase Auth user + pending registration request for admin review.
  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    try {
      final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = creds.user!.uid;

      await creds.user!.updateDisplayName(name);

      await FirebaseFirestore.instance.collection('registration_requests').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'requestedRole': selectedRole,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Registration submitted. An admin will review your request. You will be notified when approved or rejected.',
        backgroundColor: Colors.green,
      );

      setState(() {
        isLogin = true;
        _formKey.currentState?.reset();
        selectedRole = 'Customer';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: registerAuthErrorMessage(e), backgroundColor: Colors.red);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Registration error. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade400,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade400, Colors.green.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/app_logo.png',
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant, size: 80, color: Colors.teal.shade600),
                              const SizedBox(height: 8),
                              Text(
                                'FOOD DESK',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isLogin ? 'Welcome Back!' : 'Create Account',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 32),
                        if (!isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (!isLogin && (value == null || value.isEmpty)) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isLogin)
                                  IconButton(
                                    icon: Icon(Icons.info_outline, size: 22, color: Colors.teal.shade600),
                                    onPressed: () => showPasswordPolicyDialog(context),
                                    tooltip: 'Password policy',
                                  ),
                                IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ],
                            ),
                            helperText: !isLogin
                                ? '8–12 characters; use uppercase, lowercase and numbers'
                                : null,
                            helperMaxLines: 2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (isLogin) return null;
                            return validateRegistrationPassword(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Colors.teal.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        if (isLogin) const SizedBox(height: 8),
                        if (!isLogin) ...[
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Select Role',
                              prefixIcon: const Icon(Icons.work),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Row(
                                  children: [
                                    Icon(
                                      role == 'Customer'
                                          ? Icons.shopping_cart
                                          : role == 'Supplier'
                                              ? Icons.store
                                              : Icons.admin_panel_settings,
                                      size: 20,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(role),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() => selectedRole = newValue!);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (isLogin) const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: Text(
                              isLogin ? 'Login' : 'Register',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLogin ? "Don't have an account? " : "Already have an account? ",
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            TextButton(
                              onPressed: _toggleMode,
                              child: Text(
                                isLogin ? 'Register' : 'Login',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
