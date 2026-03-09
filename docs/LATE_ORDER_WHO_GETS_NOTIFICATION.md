# Who gets the late-order approve/reject notification?

- **Customer (Phone B)** – Gets a **push notification** when the vendor approves or rejects their late order. This is the only device that should receive it from `onLateOrderResponded`.
- **Vendor (Phone A)** – Does **not** get any notification from this flow. The function only sends to the customer.

So in your test: only **Phone B** should show the "Late order approved" (or rejected) notification. Phone A will not.

---

## Which function runs when?

| Action | Function that runs | Who gets notification |
|--------|--------------------|------------------------|
| Customer places late order | **onLateOrderCreated** | Vendor (email only, if SMTP configured) |
| Vendor approves or rejects | **onLateOrderResponded** | **Customer only** (push + email if SMTP set) |

The **invocation count** that increased after 1 minute could be from **onLateOrderCreated** (when the order was created) or from cold start of the function. Check the **Logs** for **onLateOrderResponded** at the **exact time** you tapped Approve on Phone A.

---

## After adding detailed logs

Redeploy functions, then run the test again (place late order on B, approve on A). In Firebase Console → Functions → Logs, open **onLateOrderResponded** and you should see one of:

- `onLateOrderResponded invoked ... before.status: LateOrderPending after.status: Pending ...` → then either "Late order FCM sent to customer" or "no fcmToken for customer" or "FCM send failed".
- `onLateOrderResponded skip: ...` → explains why the function did not send (e.g. wrong status, not late order).

That will show why the customer did not receive the notification.
