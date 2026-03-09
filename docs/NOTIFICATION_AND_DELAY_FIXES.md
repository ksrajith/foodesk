# Customer not getting notification + ~1 minute delay

## 1. FCM is being sent successfully

Your logs show:
```
Late order FCM sent to customer CRxBdaRkDqW3TVVbSEaEf2LXeWx2 | validation: token OK
Function execution took 607 ms, finished with status: 'ok'
```

So the Cloud Function **is** sending the push. If the customer’s phone doesn’t show it, the message is going to a **different device** or the **device is blocking** it.

---

## 2. Why the customer phone might not show the notification

### Most likely: token in Firestore is from another device

We store **one FCM token per user**. Whoever last opened the app as that customer **overwrites** the token.

- If that customer (e.g. `CRxBdaRkDqW3TVVbSEaEf2LXeWx2`) was ever logged in on an **emulator** or **another phone**, the token in Firestore is for that device.
- When the vendor approves, FCM sends to that stored token → notification appears on the **emulator or the other device**, not on the current customer phone.

**Fix so the customer phone gets it:**

1. On **Phone B** (the one that should get the notification), open the FoodDesk app and log in as the **customer**.
2. Go to the **Customer dashboard** and stay there for **5–10 seconds** (or tap **Test notification** and confirm you get the test).
3. That saves **Phone B’s** FCM token to Firestore and overwrites any old token.
4. Now, from the vendor app, **approve the late order** again (or create a new late order and approve it).
5. The notification should appear on **Phone B**.

Do **not** log in as that same customer on the emulator (or another device) if you want the notification on Phone B; otherwise the token will switch back to the other device.

### Other checks if it still doesn’t show

- **Settings → Apps → FoodDesk → Notifications:** ON, and the “Order updates” (or default) channel enabled.
- **Do Not Disturb / Focus:** off during the test.
- **Battery / background:** allow FoodDesk to run in background (no “battery optimization” that kills it).

---

## 3. Why there’s a ~1 minute delay

The **~1 minute** before `onLateOrderResponded` runs is almost certainly **cold start** of the Cloud Function:

- When a function hasn’t been used for a while, Firebase shuts down its container.
- The **first** request after that has to start the container again; that startup can take **30–60+ seconds**.
- Your logs show that once the function starts, it runs quickly: **607 ms**.

So:

- **First** approval after a quiet period: long delay (cold start), then fast execution.
- **Next** approvals within a few minutes: usually much faster (container already warm).

There’s no way to remove cold start entirely on the free/default setup. Options:

- **Accept** that the first notification after idle may be delayed.
- **Keep the function warm** (e.g. a scheduled function that runs every few minutes and calls something trivial). This uses more invocations and can have a small cost.

---

## Summary

| Issue | Cause | What to do |
|-------|--------|------------|
| Customer doesn’t get notification | Token in Firestore is for another device (e.g. emulator) or device blocks it | On **customer phone**, open app, go to dashboard, wait 5–10 s or tap Test notification; then test approve again. Check app notification settings. |
| ~1 minute delay | Function cold start | Expected for first run after idle. Later runs are faster. Optional: add a keep-warm scheduled function. |

After refreshing the token on the customer phone and testing again, the notification should appear on that phone.
