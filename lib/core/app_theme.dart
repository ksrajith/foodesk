import 'package:flutter/material.dart';

/// Centralized app theme for FoodDesk.
class AppTheme {
  AppTheme._();

  static const MaterialColor primaryTeal = Colors.teal;

  static ThemeData get light => ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        primarySwatch: primaryTeal,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          brightness: Brightness.light,
          primary: primaryTeal,
        ),
      );

  static ThemeMode get themeMode => ThemeMode.light;
}
