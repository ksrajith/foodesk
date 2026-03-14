import 'dart:io' show exit, Platform;
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Adds the 7 food products from app_data.dart into Firestore (products collection).
// You must sign in as a Supplier so Firestore rules allow the write.
//
// Run on Android (emulator or device):
//   flutter run -d emulator-5554 -t lib/scripts/seed_products_from_app_data.dart --dart-define=SEED_EMAIL=yoursupplier@email.com --dart-define=SEED_PASSWORD=yourpassword
//
// Replace with a real Supplier account that exists in your Firebase Auth + users collection.

const seedEmail = String.fromEnvironment('SEED_EMAIL');
const seedPassword = String.fromEnvironment('SEED_PASSWORD');

const fbApiKey = String.fromEnvironment('FB_API_KEY');
const fbAuthDomain = String.fromEnvironment('FB_AUTH_DOMAIN');
const fbProjectId = String.fromEnvironment('FB_PROJECT_ID');
const fbStorageBucket = String.fromEnvironment('FB_STORAGE_BUCKET');
const fbMessagingSenderId = String.fromEnvironment('FB_MESSAGING_SENDER_ID');
const fbAppId = String.fromEnvironment('FB_APP_ID');
const fbMeasurementId = String.fromEnvironment('FB_MEASUREMENT_ID');

Future<void> _initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (isMobile) {
    await Firebase.initializeApp();
    return;
  }
  final missing = <String>[];
  if (fbApiKey.isEmpty) missing.add('FB_API_KEY');
  if (fbAuthDomain.isEmpty) missing.add('FB_AUTH_DOMAIN');
  if (fbProjectId.isEmpty) missing.add('FB_PROJECT_ID');
  if (fbStorageBucket.isEmpty) missing.add('FB_STORAGE_BUCKET');
  if (fbMessagingSenderId.isEmpty) missing.add('FB_MESSAGING_SENDER_ID');
  if (fbAppId.isEmpty) missing.add('FB_APP_ID');
  if (missing.isNotEmpty) {
    print('[SEED_PRODUCTS] Missing Firebase config. Run on Android/iOS or pass --dart-define.');
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

// Products from app_data.dart (lines 35–104)
final List<Map<String, dynamic>> _productsFromAppData = [
  {
    'id': '1',
    'name': 'Fried rice set menu chicken',
    'description': 'Delicious fried rice with tender chicken pieces, vegetables, and special sauce',
    'price': 450.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 20,
    'image': '',
  },
  {
    'id': '2',
    'name': 'Fried rice set menu fish',
    'description': 'Savory fried rice with fresh fish, mixed vegetables, and aromatic spices',
    'price': 500.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 18,
    'image': '',
  },
  {
    'id': '3',
    'name': 'Fried rice set menu vegetable',
    'description': 'Healthy fried rice packed with fresh seasonal vegetables and herbs',
    'price': 400.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 25,
    'image': '',
  },
  {
    'id': '4',
    'name': 'Rice and curry chicken',
    'description': 'Traditional rice and curry with succulent chicken curry and side dishes',
    'price': 550.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 22,
    'image': '',
  },
  {
    'id': '5',
    'name': 'Rice and curry fish',
    'description': 'Authentic rice and curry with flavorful fish curry and accompaniments',
    'price': 600.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 15,
    'image': '',
  },
  {
    'id': '6',
    'name': 'Rice and curry vegetable',
    'description': 'Wholesome rice and curry with mixed vegetable curries and condiments',
    'price': 450.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 30,
    'image': '',
  },
  {
    'id': '7',
    'name': 'Rice and curry egg',
    'description': 'Classic rice and curry with perfectly cooked egg curry and side dishes',
    'price': 400.00,
    'vendorId': '2',
    'vendorName': 'John Vendor',
    'stock': 28,
    'image': '',
  },
];

Future<void> main() async {
  await _initFirebase();

  if (seedEmail.isEmpty || seedPassword.isEmpty) {
    print('[SEED_PRODUCTS] Set SEED_EMAIL and SEED_PASSWORD (Supplier account).');
    print('Example: flutter run -d emulator-5554 -t lib/scripts/seed_products_from_app_data.dart --dart-define=SEED_EMAIL=supplier@example.com --dart-define=SEED_PASSWORD=yourpassword');
    exit(1);
  }

  print('[SEED_PRODUCTS] Signing in as: $seedEmail');
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: seedEmail,
      password: seedPassword,
    );
  } catch (e) {
    print('[SEED_PRODUCTS] Sign-in failed: $e');
    exit(1);
  }

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final vendorName = FirebaseAuth.instance.currentUser!.email ?? 'Supplier';
  final prodCol = FirebaseFirestore.instance.collection('products');

  for (final p in _productsFromAppData) {
    final docId = p['id'] as String;
    final prodMap = {
      'name': p['name'],
      'description': p['description'],
      'price': p['price'],
      'vendorId': uid,
      'vendorName': vendorName,
      'stock': p['stock'],
      'image': p['image'],
    };
    await prodCol.doc(docId).set(prodMap, SetOptions(merge: true));
    print('[SEED_PRODUCTS] Added/updated: products/$docId (${p['name']})');
  }

  print('[SEED_PRODUCTS] Done. ${_productsFromAppData.length} products written to Firestore.');
  exit(0);
}
