import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String _channelId = 'food_desk_orders';
const String _channelName = 'Order updates';

/// Payload key for late-order notification (JSON string with orderId, productId, quantity).
const String _lateOrderPayloadKey = 'late_order_payload';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

/// Callback when user taps Approve/Reject/Cancel on a late-order notification. Called from main isolate.
void _onLateOrderNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || actionId == 'cancel') return;
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final orderId = map['orderId'] as String?;
    final productId = map['productId'] as String?;
    final quantity = (map['quantity'] is int) ? map['quantity'] as int : int.tryParse(map['quantity']?.toString() ?? '0') ?? 0;
    if (orderId == null || orderId.isEmpty) return;
    if (actionId == 'approve') {
      _executeApproveOrder(orderId, productId, quantity);
    } else if (actionId == 'reject') {
      _executeRejectOrder(orderId);
    }
  } catch (_) {}
}

Future<void> _executeApproveOrder(String orderId, String? productId, int quantity) async {
  try {
    if (productId == null || productId.isEmpty) return;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final orderSnap = await txn.get(FirebaseFirestore.instance.collection('orders').doc(orderId));
      final mealType = orderSnap.exists && orderSnap.data() != null
          ? orderSnap.data()!['mealType'] as String? ?? ''
          : '';
      final prodRef = FirebaseFirestore.instance.collection('products').doc(productId);
      final snap = await txn.get(prodRef);
      if (!snap.exists) throw Exception('Product not found');
      final prodData = snap.data()!;
      final stockByMealType = prodData['stockByMealType'];
      if (stockByMealType is Map && mealType.isNotEmpty) {
        final map = Map<String, int>.from(
          (stockByMealType as Map).map((k, v) => MapEntry(k.toString(), (v is int) ? v : (v is num ? (v as num).toInt() : 0))),
        );
        final current = map[mealType] ?? 0;
        if (current < quantity) throw Exception('Insufficient stock');
        map[mealType] = current - quantity;
        final newStock = map.values.fold<int>(0, (a, b) => a + b);
        txn.update(prodRef, {'stockByMealType': map, 'stock': newStock});
      } else {
        final stock = (prodData['stock'] is int) ? prodData['stock'] as int : (prodData['stock'] as num).toInt();
        if (stock < quantity) throw Exception('Insufficient stock');
        txn.update(prodRef, {'stock': stock - quantity});
      }
      txn.update(FirebaseFirestore.instance.collection('orders').doc(orderId), {
        'status': 'Pending',
        'vendorRespondedAt': FieldValue.serverTimestamp(),
        'vendorComment': null,
      });
    });
  } catch (_) {}
}

Future<void> _executeRejectOrder(String orderId) async {
  try {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'Rejected',
      'vendorRespondedAt': FieldValue.serverTimestamp(),
      'vendorComment': null,
    });
  } catch (_) {}
}

/// Initialize local notifications so FCM messages in foreground can be shown in the status bar.
/// Handles late-order notification action taps (Approve/Reject/Cancel).
Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: android);
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null && response.payload!.contains('orderId')) {
        _onLateOrderNotificationResponse(response);
      }
    },
  );
  if (Platform.isAndroid) {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Late order approval and other order notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }
}

/// Show a notification in the status bar (like other apps). Call when FCM message is received in foreground.
Future<void> showForegroundNotification({required String title, required String body}) async {
  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Late order approval and other order notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);
  await _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    details,
  );
}

/// Android notification actions for late-order: Approve, Reject, Cancel.
const List<AndroidNotificationAction> _lateOrderActions = [
  AndroidNotificationAction('approve', 'Approve', showsUserInterface: false, cancelNotification: true),
  AndroidNotificationAction('reject', 'Reject', showsUserInterface: false, cancelNotification: true),
  AndroidNotificationAction('cancel', 'Cancel', showsUserInterface: false, cancelNotification: true),
];

/// Shows a local notification for a new late order with Approve, Reject, Cancel buttons.
/// [payloadJson] must be a JSON string with orderId, productId, quantity for the action handler.
Future<void> showLateOrderNotification({
  required String title,
  required String body,
  required String payloadJson,
}) async {
  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Late order approval and other order notifications',
    importance: Importance.high,
    priority: Priority.high,
    actions: _lateOrderActions,
  );
  const details = NotificationDetails(android: androidDetails);
  const id = 9000; // fixed id for late-order so we don't stack many
  await _localNotifications.show(id, title, body, details, payload: payloadJson);
}

/// Returns true if the FCM data message is a late-order-pending for the vendor.
bool isLateOrderPendingMessage(Map<String, dynamic>? data) {
  return data != null && data['type'] == 'late_order_pending';
}

/// Builds the payload JSON and shows the late-order notification. Call from FCM onMessage or background handler.
void showLateOrderNotificationFromData(Map<String, dynamic> data) {
  final title = data['title'] as String? ?? 'New late order';
  final body = data['body'] as String? ?? 'A customer placed a late order.';
  final orderId = data['orderId'] as String? ?? '';
  final productId = data['productId'] as String? ?? '';
  final quantity = data['quantity'] as String? ?? '1';
  final payloadJson = jsonEncode({
    'orderId': orderId,
    'productId': productId,
    'quantity': int.tryParse(quantity) ?? 1,
  });
  showLateOrderNotification(title: title, body: body, payloadJson: payloadJson);
}

/// Saves the current FCM token to Firestore for the logged-in user so Cloud Functions can send push notifications.
/// Call after login and when app opens with an existing session (e.g. from dashboard initState).
Future<void> refreshFcmTokenAndSave() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return;

  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isIOS &&
        settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }
    String? token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 2));
      token = await messaging.getToken();
    }
    if (token == null || token.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 5));
      token = await messaging.getToken();
    }
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  } catch (_) {
    // Ignore; token will be refreshed on next open
  }
}

/// Call once after Firebase init to listen for token refresh and save to Firestore.
void listenTokenRefreshAndSave() {
  FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || newToken.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': newToken, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  });
}

/// Call from main() to set up background message handler (must be top-level).
/// When a late-order data message is received in background, show a local notification with actions.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data.isEmpty) return;
  if (data['type'] != 'late_order_pending') return;
  try {
    await Firebase.initializeApp();
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(InitializationSettings(android: android));
    if (Platform.isAndroid) {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Late order approval and other order notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
    final title = data['title'] as String? ?? 'New late order';
    final body = data['body'] as String? ?? 'A customer placed a late order.';
    final orderId = data['orderId'] as String? ?? '';
    final productId = data['productId'] as String? ?? '';
    final quantity = data['quantity'] as String? ?? '1';
    final payloadJson = jsonEncode({
      'orderId': orderId,
      'productId': productId,
      'quantity': int.tryParse(quantity) ?? 1,
    });
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Late order approval and other order notifications',
      importance: Importance.high,
      priority: Priority.high,
      actions: _lateOrderActions,
    );
    await plugin.show(9000, title, body, const NotificationDetails(android: androidDetails), payload: payloadJson);
  } catch (_) {}
}
