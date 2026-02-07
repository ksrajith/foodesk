import 'package:flutter/material.dart';

/// Shows app logo on white background while the app loads. Then navigates to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/app_logo.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.restaurant,
            size: 120,
            color: Colors.teal.shade600,
          ),
        ),
      ),
    );
  }
}
