import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shared UI and navigation helpers used across screens.

/// Shows a short message at the bottom of the screen.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  Color? backgroundColor,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: backgroundColor),
  );
}

/// Signs out of Firebase Auth and returns to the login screen.
Future<void> signOutAndGoToLogin(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, '/');
}

/// Maps [role] from Firestore to the home route for that role.
String homeRouteForRole(String? role) {
  switch ((role ?? 'Customer').trim().toLowerCase()) {
    case 'admin':
      return '/admin-dashboard';
    case 'supplier':
      return '/supplier-dashboard';
    default:
      return '/customer-home';
  }
}

/// Navigates to Admin, Supplier, or Customer home based on [profile] role.
void navigateToHomeForProfile(BuildContext context, Map<String, dynamic> profile) {
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, homeRouteForRole(profile['role'] as String?));
}

/// User-friendly message for Firebase Auth errors on login.
String loginAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found for that email';
    case 'wrong-password':
      return 'Wrong password provided';
    default:
      return e.message ?? 'Login failed';
  }
}

/// User-friendly message for Firebase Auth errors on register.
String registerAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Email already exists';
    case 'weak-password':
      return 'Password is too weak';
    default:
      return e.message ?? 'Registration failed';
  }
}

/// User-friendly message for password-reset email errors.
String passwordResetAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No account found with this email.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    default:
      return e.message?.isNotEmpty == true ? e.message! : 'Could not send reset email. Try again.';
  }
}
