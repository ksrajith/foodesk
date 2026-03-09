# Firebase notification validation

How to validate that push notifications (FCM) work for the late-order approve/reject flow.

**If customers don't receive notifications:** (1) Redeploy Cloud Functions so the relaxed token validation is active. (2) Ensure the **customer** has the latest app, has opened it, **allowed notifications** when prompted, and stayed on the dashboard a few seconds (so the token is saved). (3) Orders must use the customer's Firebase Auth UID as `customerId` (latest app does this).

---

## 1. In-app test (recommended)

1. **Deploy the latest Cloud Functions** (includes `sendTestNotification`):
   ```powershell
   cd D:\mobileGit\food_desk\food_desk
   & "D:\node_donot_del\npx.cmd" firebase deploy --only functions
   ```

2. **Run the app** as a **customer** (login with a customer account).

3. **Allow notifications** when the app prompts (so `fcmToken` is saved to Firestore).

4. On the **Customer dashboard**, tap the **bell icon** (Test notification) in the app bar.

5. You should get:
   - A SnackBar: “Test notification sent. Check your device.”
   - A push notification: **“FoodDesk test – If you see this, push notifications are working.”**

If you see an error SnackBar instead:
- **“No FCM token…”** → Open the app, accept the notification permission, wait a few seconds, then tap the bell again.
- **“Stored FCM token is invalid…”** → Log out, log back in, allow notifications, then try again.

---

## 2. Firestore: check token is saved

1. Firebase Console → **Firestore** → **users**.
2. Open the document for the **customer** user (same UID they use in the app).
3. Confirm there is a field **`fcmToken`** (long string) and optionally **`fcmTokenUpdatedAt`**.

If `fcmToken` is missing, the customer must open the app, log in, and **allow notifications** so the app can save the token.

---

## 3. Function logs: late-order flow

When a vendor **approves or rejects** a late order:

1. Firebase Console → **Functions** → **Logs**.
2. Look for one of:
   - **“Late order FCM sent to customer &lt;customerId&gt; | validation: token OK”** → Push was sent.
   - **“no fcmToken for customer &lt;customerId&gt;…”** → Customer has no token; they should open the app and allow notifications.
   - **“invalid fcmToken for customer…”** → Token in Firestore is invalid; customer can log out and back in and allow notifications again.
   - **“FCM send failed”** → Check the error details (e.g. invalid/expired token, project config).

---

## 4. Validation checklist

| Step | What to do | Pass? |
|------|------------|--------|
| 1 | Deploy functions (`firebase deploy --only functions`) | ☐ |
| 2 | Customer opens app, logs in, allows notifications | ☐ |
| 3 | Firestore `users/<customerUid>` has `fcmToken` | ☐ |
| 4 | Tap “Test notification” (bell) on Customer dashboard → receive test push | ☐ |
| 5 | Vendor approves or rejects a late order → customer gets push (and Function log shows “FCM sent…”) | ☐ |

---

## 5. Token validation (backend)

The Cloud Function checks FCM tokens before sending:

- **Missing token** → Log: “no fcmToken for customer”.
- **Invalid format** (wrong length or characters) → Log: “invalid fcmToken for customer”.
- **Valid** → Sends the notification and logs “Late order FCM sent to customer … | validation: token OK”.

This reduces unnecessary FCM calls and makes logs clearer when debugging.
