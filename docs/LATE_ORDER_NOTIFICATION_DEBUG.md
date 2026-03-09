# Why didn’t I get the late-order reject/approve notification?

Follow these steps to find out why the customer didn’t receive the push.

---

## Step 1: Check Cloud Function logs (most important)

1. Open **[Firebase Console](https://console.firebase.google.com/)** → project **food-desk**.
2. Go to **Build** → **Functions** → **Logs** (or **Usage** tab and open logs).
3. Filter or scroll to the time when you **rejected** the order on the emulator.
4. Look for logs from **onLateOrderResponded**:

| Log message | Meaning |
|-------------|--------|
| `Late order FCM sent to customer <uid> \| validation: token OK` | Notification was sent. If the phone didn’t show it, the issue is on the device (see Step 4). |
| `onLateOrderResponded: no fcmToken for customer <uid>` | The customer’s Firestore document has no FCM token. Do Step 2 and Step 3. |
| `onLateOrderResponded: invalid fcmToken for customer <uid>` | Token in Firestore is invalid. Customer should log out, log in again, allow notifications, and stay on dashboard a few seconds. |
| `onLateOrderResponded: FCM send failed` | FCM rejected the token (e.g. expired). Customer should reopen app so token is refreshed. |
| **No log at all** for that time | Function did not run. Check that the order was updated (status → Rejected) and that **onLateOrderResponded** is deployed (Step 5). |

Write down what you see (exact message and any `customerId`/uid). That drives the next steps.

---

## Step 2: Check the order document in Firestore

1. In Firebase Console go to **Build** → **Firestore Database**.
2. Open the **orders** collection and find the order you rejected (e.g. by date or product name).
3. Check:
   - **customerId** – must be a non-empty string (the customer’s Firebase Auth UID).
   - **lateOrder** – should be `true`.
   - **status** – should be `Rejected` after you rejected it.
   - **customerEmail** – should be the customer’s email.

If **customerId** is missing or empty, the app that created the order is old or buggy; the customer needs the latest app and should place the order again from the **phone**.

---

## Step 3: Check the customer’s user document (FCM token)

1. In Firestore open the **users** collection.
2. Find the document whose **document ID** is exactly the **customerId** from the order (Step 2).
3. Check whether the document has a field **fcmToken** (long string).

- **No fcmToken (or document missing)**  
  The customer’s app has not saved a token. On the **same device** where they placed the order they must:
  - Be logged in as that customer.
  - Open the app and **allow notifications** when prompted.
  - Stay on the Customer dashboard for at least a few seconds (or tap “Test notification”).
  Then reject another late order and check logs again.

- **fcmToken present**  
  If the logs still said “no fcmToken”, then the **customerId** on the order does not match this document ID (wrong uid). Use the latest app so orders use the auth UID (see Step 2).

---

## Step 4: If logs say “FCM sent” but the phone shows nothing

- **Device settings:** Notifications for **FoodDesk** must be allowed (Settings → Apps → FoodDesk → Notifications).
- **Channel:** The app uses channel `food_desk_orders`. If the user previously disabled this channel, re-enable it or reinstall the app.
- **Background:** Try with the app in background or closed; FCM should still show the notification.
- **Same Google account:** The device should be using the same Google account that’s in the Firebase project (for FCM). If the device is not signed into any Google account, notifications may not work.

---

## Step 5: Confirm the right functions are deployed

1. Firebase Console → **Build** → **Functions**.
2. You should see at least:
   - **onLateOrderResponded** (Firestore trigger: `orders/{orderId}` on update).
   - **onRegistrationResponded** (optional for this flow).
   - **sendTestNotification** (callable, for testing).

If **onLateOrderResponded** is missing, deploy again from the project root:

```powershell
$env:Path = "D:\node_donot_del;$env:Path"
cd D:\mobileGit\food_desk\food_desk
npm run deploy:functions
```

---

## Quick checklist (customer on phone)

- [ ] Customer placed the late order **from the phone** (same device that should get the notification).
- [ ] Customer is logged in on the **phone** with the account that placed the order.
- [ ] After login, customer **allowed notifications** when the app asked.
- [ ] Customer opened the **Customer dashboard** and stayed a few seconds (or tapped “Test notification” and got the test).
- [ ] Phone has the **latest** FoodDesk APK (so `customerId` = auth UID and token is saved correctly).
- [ ] Phone **notification permission** for FoodDesk is On (Settings → Apps → FoodDesk → Notifications).

If all of the above are true and the logs still say “no fcmToken for customer”, the **customerId** on the order in Firestore does not match the **users** document ID for that customer. Re-place the order with the latest app and check again.
