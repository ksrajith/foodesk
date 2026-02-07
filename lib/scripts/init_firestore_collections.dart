import 'dart:io' show exit, Platform;
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Creates the 4 Firestore collections (users, registration_requests, products, orders)
// by writing one placeholder document to each. Run once after creating your Firestore
// database instance. Safe to run again (uses set with merge / overwrite).
//
// Run on Android/iOS (uses google-services.json / GoogleService-Info.plist):
//   flutter run -d <device-id> -t lib/scripts/init_firestore_collections.dart
//
// Run on web/desktop: pass Firebase config via --dart-define (see seed_firestore.dart).
//
// Note: If your Firestore rules require auth, use test mode in the Console for this run,
// or deploy rules after init. New projects often start in test mode and allow these writes.

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
    print('[INIT][ERROR] Missing Firebase config: ${missing.join(', ')}');
    print('[INIT] Run on Android/iOS, or pass --dart-define for web/desktop.');
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
  final firestore = FirebaseFirestore.instance;

  print('[INIT] Creating Firestore collections (users, registration_requests, products, orders)...');

  // 1. users – placeholder so collection exists. Delete doc _init after first real user registers.
  await firestore.collection('users').doc('_init').set({
    'name': 'Delete me',
    'role': 'System',
    'email': '',
    'id': '_init',
  }, SetOptions(merge: true));
  print('[INIT] Created collection: users (doc _init)');

  // 2. registration_requests – placeholder. Delete doc _init after first registration if desired.
  await firestore.collection('registration_requests').doc('_init').set({
    '_placeholder': true,
  }, SetOptions(merge: true));
  print('[INIT] Created collection: registration_requests (doc _init)');

  // 3. products – one sample product so collection exists.
  await firestore.collection('products').doc('1').set({
    'name': 'Sample meal',
    'description': 'Edit or delete this product',
    'price': 100.0,
    'vendorId': '',
    'vendorName': '',
    'stock': 0,
    'image': '',
  }, SetOptions(merge: true));
  print('[INIT] Created collection: products (doc 1)');

  // 4. orders – one placeholder order (fixed ID so rules can allow it).
  await firestore.collection('orders').doc('_init').set({
    'customerId': '',
    'customerName': '',
    'productId': '1',
    'productName': 'Sample meal',
    'vendorId': '',
    'vendorName': '',
    'quantity': 1,
    'totalPrice': 100.0,
    'status': 'Pending',
    'orderDate': DateTime.now().toIso8601String(),
    'deliveryDate': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    'mealType': 'Lunch',
  });
  print('[INIT] Created collection: orders (doc _init)');

  print('[INIT] Done. You can delete users/_init and registration_requests/_init after the first real user registers.');
}
