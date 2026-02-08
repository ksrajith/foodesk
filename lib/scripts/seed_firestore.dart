import 'dart:io' show exit, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// AppData removed: inline demo products below for seeding

// Seed Firestore with demo data (products, optional orders) without adding UI screens.
// Run with:
// flutter run -d emulator-5554 -t lib/scripts/seed_firestore.dart 
//--dart-define=SEED_EMAIL=supplier@demo.com 
//--dart-define=SEED_PASSWORD=demo123 
//--dart-define=SEED_ORDERS=false
//
// Notes:
// - Provide credentials for a Supplier per security rules.
// - The script creates/updates users/{uid} with role 'Supplier', then writes products with vendorId = uid.
// - Set SEED_ORDERS=true to also create a sample order for the signed-in user (acts as customer).

const seedEmail = String.fromEnvironment('SEED_EMAIL');
const seedPassword = String.fromEnvironment('SEED_PASSWORD');
const seedOrdersFlag = String.fromEnvironment('SEED_ORDERS'); // 'true' or 'false'

// Optional Firebase options for web/desktop runs
const fbApiKey = String.fromEnvironment('FB_API_KEY');
const fbAuthDomain = String.fromEnvironment('FB_AUTH_DOMAIN');
const fbProjectId = String.fromEnvironment('FB_PROJECT_ID');
const fbStorageBucket = String.fromEnvironment('FB_STORAGE_BUCKET');
const fbMessagingSenderId = String.fromEnvironment('FB_MESSAGING_SENDER_ID');
const fbAppId = String.fromEnvironment('FB_APP_ID');
const fbMeasurementId = String.fromEnvironment('FB_MEASUREMENT_ID');

Future<void> _initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On web or desktop (macOS/Windows/Linux), Firebase requires explicit options.
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (isMobile) {
    await Firebase.initializeApp();
    return;
  }

  // Validate required web/desktop options
  final missing = <String>[];
  if (fbApiKey.isEmpty) missing.add('FB_API_KEY');
  if (fbAuthDomain.isEmpty) missing.add('FB_AUTH_DOMAIN');
  if (fbProjectId.isEmpty) missing.add('FB_PROJECT_ID');
  if (fbStorageBucket.isEmpty) missing.add('FB_STORAGE_BUCKET');
  if (fbMessagingSenderId.isEmpty) missing.add('FB_MESSAGING_SENDER_ID');
  if (fbAppId.isEmpty) missing.add('FB_APP_ID');

  if (missing.isNotEmpty) {
    // ignore: avoid_print
    print('[SEED][ERROR] Missing Firebase web/desktop config: ${missing.join(', ')}');
    // ignore: avoid_print
    print('[SEED] Provide via --dart-define, or run on Android/iOS where native config exists.');
    exit(1);
  }

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: fbApiKey,
      authDomain: fbAuthDomain,
      projectId: fbProjectId,
      storageBucket: fbStorageBucket,
      messagingSenderId: fbMessagingSenderId,
      appId: fbAppId,
      measurementId: fbMeasurementId.isEmpty ? null : fbMeasurementId,
    ),
  );
}

Future<void> main() async {
  await _initFirebase();

  // Sign in
  if (seedEmail.isEmpty || seedPassword.isEmpty) {
    // ignore: avoid_print
    print('[SEED] Missing SEED_EMAIL/SEED_PASSWORD. Aborting.');
    // Exit with error code
    exit(1);
  }

  // ignore: avoid_print
  print('[SEED] Signing in as: ' + seedEmail);
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: seedEmail,
    password: seedPassword,
  );
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Ensure users/{uid} has a Supplier role so rules allow supplier-managed products
  final currentEmail = FirebaseAuth.instance.currentUser!.email;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'name': currentEmail ?? 'Supplier',
    'role': 'Supplier',
    'email': currentEmail,
    'id': uid,
  }, SetOptions(merge: true));
  // ignore: avoid_print
  print('[SEED] Ensured users/$uid has role=Supplier');

  // Seed products
  // Inline demo product list (previously stored in AppData.products)
  final products = [
    {
      'id': '1',
      'name': 'Fried rice set menu chicken',
      'description': 'Delicious fried rice with tender chicken pieces, vegetables, and special sauce',
      'price': 450.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 20,
      'image': 'assets/ProductImages/Fried rice set menu chiken.png',
    },
    {
      'id': '2',
      'name': 'Fried rice set menu fish',
      'description': 'Savory fried rice with fresh fish, mixed vegetables, and aromatic spices',
      'price': 500.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 18,
      'image': 'assets/ProductImages/Fried rice set menu fish.png',
    },
    {
      'id': '3',
      'name': 'Fried rice set menu vegetable',
      'description': 'Healthy fried rice packed with fresh seasonal vegetables and herbs',
      'price': 400.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 25,
      'image': 'assets/ProductImages/Fried rice set menu vegitable.png',
    },
    {
      'id': '4',
      'name': 'Rice and curry chicken',
      'description': 'Traditional rice and curry with succulent chicken curry and side dishes',
      'price': 550.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 22,
      'image': 'assets/ProductImages/Rice and curry chicken.png',
    },
    {
      'id': '5',
      'name': 'Rice and curry fish',
      'description': 'Authentic rice and curry with flavorful fish curry and accompaniments',
      'price': 600.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 15,
      'image': 'assets/ProductImages/Rice and curry fish.png',
    },
    {
      'id': '6',
      'name': 'Rice and curry vegetable',
      'description': 'Wholesome rice and curry with mixed vegetable curries and condiments',
      'price': 450.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 30,
      'image': 'assets/ProductImages/Rice and curry vegitable.png',
    },
    {
      'id': '7',
      'name': 'Rice and curry egg',
      'description': 'Classic rice and curry with perfectly cooked egg curry and side dishes',
      'price': 400.00,
      'vendorId': '2',
      'vendorName': 'John Vendor',
      'stock': 28,
      'image': 'assets/ProductImages/Rice and curry egg.png',
    },
  ];
  final prodCol = FirebaseFirestore.instance.collection('products');

  for (final p in products) {
    final docId = p['id']?.toString() ?? FirebaseFirestore.instance.collection('products').doc().id;
    final prodMap = {
      'name': p['name'],
      'description': p['description'],
      'price': p['price'],
      // Write vendorId as the signed-in vendor's UID to satisfy security rules
      'vendorId': uid,
      // Use the supplier's email (or keep demo name if present)
      'vendorName': p['vendorName'] ?? (currentEmail ?? 'Supplier'),
      'stock': p['stock'],
      'image': p['image'],
    };

    await prodCol.doc(docId).set(prodMap, SetOptions(merge: true));
    // ignore: avoid_print
    print('[SEED] Upserted product doc: products/$docId (${p['name']})');
  }

  // Optionally seed a sample order for the current user
  final seedOrders = seedOrdersFlag.toLowerCase() == 'true';
  if (seedOrders && products.isNotEmpty) {
    final firstProduct = products.first;
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final totalPrice = (firstProduct['price'] as num).toDouble();

    final deliveryDate = DateTime.now().add(const Duration(days: 1));
    await orderRef.set({
      'customerId': uid,
      'customerName': FirebaseAuth.instance.currentUser!.email ?? 'Seeder',
      'productId': firstProduct['id']?.toString() ?? '',
      'productName': firstProduct['name'] ?? '',
      'vendorId': firstProduct['vendorId'] ?? '',
      'vendorName': firstProduct['vendorName'] ?? '',
      'quantity': 1,
      'totalPrice': totalPrice,
      'status': 'Pending',
      'orderDate': DateTime.now().toIso8601String(),
      'deliveryDate': deliveryDate.toIso8601String(),
      'mealType': 'Lunch',
    });
    // ignore: avoid_print
    print('[SEED] Created sample order: orders/${orderRef.id}');
  } else {
    // ignore: avoid_print
    print('[SEED] Skipping orders seed (SEED_ORDERS=false).');
  }

  // Done
  // ignore: avoid_print
  print('[SEED] Completed seeding Firestore. You can stop the app now.');
}
