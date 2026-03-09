import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String _channelId = 'food_desk_orders';
const String _channelName = 'Order updates';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

/// Initialize local notifications so FCM messages in foreground can be shown in the status bar.
Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: android);
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (_) {},
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
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message if needed
}
