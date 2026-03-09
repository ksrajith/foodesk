# Firebase notification config – late order approve/reject

This checklist confirms that **push notifications to the customer** when a **vendor approves or rejects a late meal order** are correctly configured in the codebase.

---

## 1. Flutter app (client)

| Item | Status | Location |
|------|--------|----------|
| firebase_messaging dependency | Done | `pubspec.yaml`: `firebase_messaging: ^16.1.0` |
| Save FCM token to Firestore | Done | `lib/utils/fcm_utils.dart`: `refreshFcmTokenAndSave()` writes `users/{uid}.fcmToken` |
| Token saved after login | Done | `lib/screens/login_register_screen.dart`: calls `refreshFcmTokenAndSave()` after successful login |
| Token saved on customer dashboard | Done | `lib/screens/customer_dashboard.dart`: `initState` calls it + retry after 3s |
| Token refresh listener | Done | `lib/main.dart`: `listenTokenRefreshAndSave()`; `fcm_utils.dart`: `onTokenRefresh.listen` |
| Background message handler | Done | `lib/main.dart`: `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)` |
| Android: POST_NOTIFICATIONS | Done | `android/app/src/main/AndroidManifest.xml` |
| Android: default notification channel id | Done | `AndroidManifest.xml` meta-data + `res/values/strings.xml`: `food_desk_orders` |
| Android: create channel at runtime | Done | `MainActivity.kt`: creates channel `food_desk_orders` (Order updates) |
| Firebase config (Android) | Done | `android/app/google-services.json` present |

---

## 2. Late order creation (order doc has customerId)

| Item | Status | Location |
|------|--------|----------|
| customerId on late order | Done | `lib/screens/place_meal_screen.dart`: order payload includes `customerId` and `customerEmail` |

---

## 3. Cloud Function (send FCM when vendor responds)

| Item | Status | Location |
|------|--------|----------|
| Trigger on order update | Done | `functions/index.js`: `onLateOrderResponded` on `orders/{orderId}` `onUpdate` |
| Only when late order status changes | Done | Checks `before.status === 'LateOrderPending'` and `after.status` in `['Pending','Rejected']` |
| Read customerId from order | Done | `after.customerId` |
| Read fcmToken from users doc | Done | `users.doc(customerId).get()` → `fcmToken` |
| Send FCM to customer | Done | `admin.messaging().send()` with title/body and `android.notification.channelId: 'food_desk_orders'` |
| Logging when no token | Done | `console.warn` when no fcmToken for customer |

---

## 4. Firestore security

| Item | Status |
|------|--------|
| User can write own `users/{uid}` (for fcmToken) | Done | `firestore.rules`: `request.auth.uid == userId` |

---

## 5. What you must do (deployment / runtime)

1. **Deploy Cloud Functions**  
   - From project root: `cd functions`, `npm install`, `firebase deploy --only functions`  
   - Ensures `onLateOrderResponded` runs in your Firebase project.

2. **Customer device**  
   - Customer must **open the app**, **log in**, and **allow notifications** when prompted.  
   - This saves `fcmToken` to `users/{customerId}`.  
   - Optionally leave app in background or close it before vendor approves/rejects.

3. **Verify token in Firestore**  
   - Firebase Console → Firestore → `users` → select the customer’s document.  
   - Confirm field `fcmToken` (and optionally `fcmTokenUpdatedAt`) exists after they’ve logged in and allowed notifications.

4. **Check Function logs**  
   - Firebase Console → Functions → Logs.  
   - After vendor approves/rejects a late order, look for:  
     - `"Late order FCM sent to customer"` (success), or  
     - `"no fcmToken for customer"` / `"FCM send failed"` (need to fix token or permissions).

---

## Summary

All **Firebase-related notification configs in code** for “notify customer when vendor approves or rejects late meal order” are in place: FCM token is saved to Firestore, Cloud Function sends FCM using that token and the correct Android channel, and Android has the required permission and channel. Ensure **Cloud Functions are deployed** and the **customer has logged in and allowed notifications** so their device has a stored `fcmToken`.
