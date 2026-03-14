import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/fcm_utils.dart';
// AppData removed. User profile stored in Firestore; no app-level cache.

/// Password policy: 8–12 characters; at least one uppercase, one lowercase, one digit.
const int _passwordMinLength = 8;
const int _passwordMaxLength = 12;

String? _validatePasswordPolicy(String? value) {
  if (value == null || value.isEmpty) return null; // Let required check handle empty
  if (value.length < _passwordMinLength) {
    return 'Password must be at least $_passwordMinLength characters';
  }
  if (value.length > _passwordMaxLength) {
    return 'Password must be at most $_passwordMaxLength characters';
  }
  final hasUppercase = value.contains(RegExp(r'[A-Z]'));
  final hasLowercase = value.contains(RegExp(r'[a-z]'));
  final hasDigit = value.contains(RegExp(r'[0-9]'));
  final count = (hasUppercase ? 1 : 0) + (hasLowercase ? 1 : 0) + (hasDigit ? 1 : 0);
  if (count < 3) {
    return 'Use uppercase, lowercase and numbers';
  }
  return null;
}

void _showPasswordPolicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.teal.shade600),
          const SizedBox(width: 8),
          const Text('Password policy'),
        ],
      ),
      content: const Text(
        '• Length: 8–12 characters\n'
        '• Use at least three of:\n'
        '  · Uppercase letters (A–Z)\n'
        '  · Lowercase letters (a–z)\n'
        '  · Numbers (0–9)',
        style: TextStyle(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({Key? key}) : super(key: key);

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  
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

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (isLogin) {
      await _handleLogin();
    } else {
      await _handleRegister();
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = creds.user!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final requestDoc = await FirebaseFirestore.instance.collection('registration_requests').doc(uid).get();

      Map<String, dynamic> profile;
      if (doc.exists) {
        profile = doc.data()!;
        final status = (profile['accountStatus'] as String?)?.toLowerCase();
        if (status == 'deactivated') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deactivated. Contact an administrator.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        // No users doc: check registration request status (approval workflow)
        if (requestDoc.exists) {
          final req = requestDoc.data()!;
          final status = req['status'] as String? ?? 'pending';
          if (status == 'pending') {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your registration is pending admin approval. You will be notified when reviewed.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (status == 'rejected') {
            if (!mounted) return;
            final comment = req['adminComment'] as String? ?? '';
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Registration Rejected'),
                content: Text(
                  comment.isEmpty
                      ? 'Your registration request was rejected by an administrator.'
                      : 'Your registration request was rejected.\n\nAdmin comment: $comment',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
          if (status == 'approved') {
            final approvedRole = req['approvedRole'] as String? ?? 'Customer';
            final adminComment = req['adminComment'] as String? ?? '';
            profile = {
              'id': uid,
              'name': req['name'] ?? creds.user!.displayName ?? email.split('@').first,
              'email': req['email'] ?? email,
              'role': approvedRole,
              'accountStatus': 'Active',
              'approvedAt': FieldValue.serverTimestamp(),
            };
            await FirebaseFirestore.instance.collection('users').doc(uid).set(profile);
            if (!mounted) return;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Registration Approved'),
                content: Text(
                  adminComment.isEmpty
                      ? 'Your registration has been approved. Your role: $approvedRole.'
                      : 'Your registration has been approved. Your role: $approvedRole.\n\nAdmin comment: $adminComment',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            profile = {
              'id': uid,
              'name': creds.user!.displayName ?? email.split('@').first,
              'email': email,
              'role': 'Customer',
              'accountStatus': 'Active',
            };
            await FirebaseFirestore.instance.collection('users').doc(uid).set(profile);
          }
        } else {
          profile = {
            'id': uid,
            'name': creds.user!.displayName ?? email.split('@').first,
            'email': email,
            'role': 'Customer',
            'accountStatus': 'Active',
          };
          await FirebaseFirestore.instance.collection('users').doc(uid).set(profile);
        }
      }

      if (!mounted) return;
      await refreshFcmTokenAndSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome ${profile['name']}!'),
          backgroundColor: Colors.green,
        ),
      );

      final role = ((profile['role'] ?? 'Customer') as String).trim().toLowerCase();
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      } else if (role == 'vendor' || role == 'supplier') {
        Navigator.pushReplacementNamed(context, '/supplier-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/customer-home');
      }
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'user-not-found'
          ? 'No user found for that email'
          : e.code == 'wrong-password'
              ? 'Wrong password provided'
              : e.message ?? 'Login failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    try {
      final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await creds.user!.updateDisplayName(name);

      // Create pending registration request — admins will be notified via Firestore (admin screen lists pending)
      await FirebaseFirestore.instance.collection('registration_requests').doc(creds.user!.uid).set({
        'uid': creds.user!.uid,
        'email': email,
        'name': name,
        'requestedRole': selectedRole,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted. An admin will review your request. You will be notified when approved or rejected.'),
          backgroundColor: Colors.green,
        ),
      );

      if (!mounted) return;
      setState(() {
        isLogin = true;
        _formKey.currentState?.reset();
      });
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'email-already-in-use'
          ? 'Email already exists'
          : e.code == 'weak-password'
              ? 'Password is too weak'
              : e.message ?? 'Registration failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration error. Please try again.'),
          backgroundColor: Colors.red,
        ),
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
                              Text('FOOD DESK', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(isLogin ? 'Welcome Back!' : 'Create Account', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
                                    onPressed: () => _showPasswordPolicyDialog(context),
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
                            final policyError = _validatePasswordPolicy(value);
                            if (policyError != null) return policyError;
                            return null;
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
                                      role == 'Customer' ? Icons.shopping_cart : role == 'Supplier' ? Icons.store : Icons.admin_panel_settings,
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isLogin ? "Don't have an account? " : "Already have an account? ", style: TextStyle(color: Colors.grey.shade700)),
                            TextButton(
                              onPressed: _toggleMode,
                              child: Text(isLogin ? 'Register' : 'Login', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade600)),
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