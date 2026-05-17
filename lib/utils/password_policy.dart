import 'package:flutter/material.dart';

/// Registration password rules: 8–12 chars; uppercase, lowercase, and digit required.
const int passwordMinLength = 8;
const int passwordMaxLength = 12;

/// Returns an error message if [value] breaks policy; null if valid or empty.
String? validateRegistrationPassword(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.length < passwordMinLength) {
    return 'Password must be at least $passwordMinLength characters';
  }
  if (value.length > passwordMaxLength) {
    return 'Password must be at most $passwordMaxLength characters';
  }
  final hasUppercase = value.contains(RegExp(r'[A-Z]'));
  final hasLowercase = value.contains(RegExp(r'[a-z]'));
  final hasDigit = value.contains(RegExp(r'[0-9]'));
  final count = (hasUppercase ? 1 : 0) + (hasLowercase ? 1 : 0) + (hasDigit ? 1 : 0);
  if (count < 3) return 'Use uppercase, lowercase and numbers';
  return null;
}

/// Dialog explaining registration password rules.
void showPasswordPolicyDialog(BuildContext context) {
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}
