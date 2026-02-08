import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'screens/login_register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_pending_registrations.dart';
import 'screens/admin_approved_registrations_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_product_list.dart';
import 'screens/admin_order_list.dart';
import 'screens/supplier_dashboard.dart';
import 'screens/supplier_product_list.dart';
import 'screens/supplier_add_edit_meal_screen.dart';
import 'screens/supplier_order_before_screen.dart';
import 'screens/supplier_order_list.dart';
import 'screens/supplier_order_summary.dart';
import 'screens/supplier_late_orders_screen.dart';
import 'screens/customer_dashboard.dart';
import 'screens/customer_order_history_screen.dart';
import 'screens/pool_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initError;
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    initError = e.toString();
    debugPrint('Firebase.initializeApp error: $e');
    debugPrint(st.toString());
  }
  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, this.initError}) : super(key: key);
  final String? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodDesk',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
          primary: Colors.teal,
        ),
      ),
      initialRoute: initError != null ? null : '/splash',
      home: initError != null
          ? Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FoodDesk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('Firebase failed to initialize:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(child: SingleChildScrollView(child: Text(initError!, style: const TextStyle(fontSize: 12)))),
                    ],
                  ),
                ),
              ),
            )
          : null,
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginRegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/admin-pending-registrations': (context) => const AdminPendingRegistrations(),
        '/admin-approved-registrations': (context) => const AdminApprovedRegistrationsScreen(),
        '/admin-settings': (context) => const AdminSettingsScreen(),
        '/admin-products': (context) => const AdminProductList(),
        '/admin-orders': (context) => const AdminOrderList(),
        '/supplier-dashboard': (context) => const SupplierDashboard(),
        '/supplier-products': (context) => const SupplierProductList(),
        '/supplier-add-edit-meal': (context) => const SupplierAddEditMealScreen(),
        '/supplier-order-before': (context) => const SupplierOrderBeforeScreen(),
        '/supplier-orders': (context) => const SupplierOrderList(),
        '/supplier-late-orders': (context) => const SupplierLateOrdersScreen(),
        '/supplier-order-summary': (context) => const SupplierOrderSummary(),
        '/customer-home': (context) => const CustomerDashboard(),
        '/customer-order-history': (context) => const CustomerOrderHistoryScreen(),
        '/pool': (context) => const PoolScreen(),
      },
    );
  }
}
