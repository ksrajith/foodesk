// Use v1 API explicitly so deploy/emulator can detect 1st gen backend (avoids load timeout / spec errors).
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { defineString } = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

// Lazy-load axios to avoid deployment timeout during initial load
function getAxios() {
  return require("axios");
}

function maskSecret(value) {
  if (!value || typeof value !== "string") return "(empty)";
  if (value.length <= 4) return "*".repeat(value.length);
  return value.slice(0, 2) + "*".repeat(Math.max(1, value.length - 4)) + value.slice(-2);
}

// Brevo Transactional Email API (https://developers.brevo.com/reference/sendtransacemail)
const BREVO_API_KEY_PARAM = defineString("BREVO_API_KEY", { default: "" });
const BREVO_SENDER_EMAIL_PARAM = defineString("BREVO_SENDER_EMAIL", { default: "" });
const BREVO_SENDER_NAME_PARAM = defineString("BREVO_SENDER_NAME", { default: "FoodDesk" });

function getBrevoConfig() {
  const rawKey = process.env.BREVO_API_KEY || BREVO_API_KEY_PARAM.value() || "";
  const rawEmail = process.env.BREVO_SENDER_EMAIL || BREVO_SENDER_EMAIL_PARAM.value() || "";
  const rawName = process.env.BREVO_SENDER_NAME || BREVO_SENDER_NAME_PARAM.value() || "FoodDesk";
  // Trim: Firebase Console / copy-paste often adds accidental leading/trailing spaces (Brevo returns 401 "Key not found").
  const apiKey = typeof rawKey === "string" ? rawKey.trim() : "";
  const senderEmail = typeof rawEmail === "string" ? rawEmail.trim() : "";
  const senderName = typeof rawName === "string" ? rawName.trim() || "FoodDesk" : "FoodDesk";
  return { apiKey, senderEmail, senderName };
}

function isBrevoEmailConfigured() {
  const { apiKey, senderEmail } = getBrevoConfig();
  return Boolean(apiKey && senderEmail);
}

/**
 * @param {{ to: string, subject: string, text: string, replyTo?: string, senderName?: string }} opts
 * @returns {Promise<{ messageId?: string }>}
 */
async function sendBrevoEmail(opts) {
  const { apiKey, senderEmail, senderName: defaultSenderName } = getBrevoConfig();
  const senderName = opts.senderName || defaultSenderName;
  const axios = getAxios();
  const payload = {
    sender: { email: senderEmail, name: senderName },
    to: [{ email: opts.to }],
    subject: opts.subject,
    textContent: opts.text,
  };
  if (opts.replyTo && typeof opts.replyTo === "string" && opts.replyTo.includes("@")) {
    payload.replyTo = { email: opts.replyTo };
  }
  const res = await axios.post("https://api.brevo.com/v3/smtp/email", payload, {
    headers: {
      "api-key": apiKey,
      "Content-Type": "application/json",
    },
    validateStatus: () => true,
  });
  if (res.status < 200 || res.status >= 300) {
    if (res.status === 401) {
      console.warn(
        "Brevo 401: use the REST API key from Brevo (Dashboard → SMTP & API → API keys), not the SMTP password. " +
          "Re-copy the full key into BREVO_API_KEY. apiKeyLength:",
        apiKey ? apiKey.length : 0
      );
    }
    const err = new Error("Brevo API error: " + res.status + " " + JSON.stringify(res.data));
    err.brevoStatus = res.status;
    err.brevoBody = res.data;
    throw err;
  }
  return { messageId: res.data && res.data.messageId };
}

/** Returns true if the value looks like a valid FCM device token. */
function isValidFcmToken(value) {
  return typeof value === "string" && value.length >= 50 && value.length <= 2000 && value.trim().length > 0;
}

/**
 * When a registration_requests document is updated and status is 'approved' or 'rejected',
 * send an email to the applicant (Brevo sender; reply-to admin when present).
 */
exports.onRegistrationResponded = functions.firestore
  .document("registration_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const beforeStatus = before && before.status;
    const status = after && after.status;

    if (status !== "approved" && status !== "rejected") {
      return null;
    }
    // Only send when the status actually changes to an end-state.
    if (beforeStatus === status) {
      console.log(
        "onRegistrationResponded: status unchanged, skipping email",
        "requestId:",
        context.params.requestId,
        "status:",
        status
      );
      return null;
    }
    console.log(
      "onRegistrationResponded: trigger detected",
      "requestId:",
      context.params.requestId,
      "fromStatus:",
      beforeStatus || "(none)",
      "toStatus:",
      status
    );

    const toEmail = after.email;
    if (!toEmail || typeof toEmail !== "string" || !toEmail.includes("@")) {
      console.warn("onRegistrationResponded: no valid email for request", context.params.requestId);
      return null;
    }

    const adminEmail = after.respondedByEmail || "";
    const adminName = after.respondedByName || "";
    const requestedRole = after.requestedRole || "Customer";
    const approvedRole = after.approvedRole || (status === "approved" ? "Customer" : "");
    const comment = after.adminComment || "";

    const subject =
      status === "approved"
        ? "Your Food Desk Registration Request has Approved"
        : "Your Food Desk Registration Request has Rejected";

    const actionLabel = status === "approved" ? "Approved" : "Rejected";
    const bodyLines = [
      status === "approved"
        ? "Your Food Desk registration request has been approved."
        : "Your Food Desk registration request has been rejected.",
      "",
      "Requested Role: " + (requestedRole || "—"),
      status === "approved"
        ? "Approved Role: " + (approvedRole || "—")
        : "",
      "",
      actionLabel + " by Email: " + (adminEmail || "—"),
      actionLabel + " by Name: " + (adminName || "—"),
      "",
      comment ? "Comment from admin:\n" + comment : "",
    ];
    const text = bodyLines.filter(Boolean).join("\n");

    const { apiKey, senderEmail, senderName } = getBrevoConfig();
    console.log(
      "onRegistrationResponded: Brevo resolved",
      "toEmail:",
      toEmail,
      "senderEmail:",
      senderEmail || "(empty)",
      "senderName:",
      senderName,
      "apiKeyMasked:",
      maskSecret(apiKey)
    );

    if (!isBrevoEmailConfigured()) {
      console.warn(
        "onRegistrationResponded: Brevo not configured. Set BREVO_API_KEY and BREVO_SENDER_EMAIL as Firebase params (or env)."
      );
      return null;
    }

    try {
      const info = await sendBrevoEmail({
        to: toEmail,
        subject,
        text,
        replyTo: adminEmail || undefined,
        senderName: "FoodDesk Admin",
      });
      console.log(
        "onRegistrationResponded: email sent",
        "requestId:",
        context.params.requestId,
        "toEmail:",
        toEmail,
        "status:",
        status,
        "messageId:",
        (info && info.messageId) || "(none)"
      );
    } catch (err) {
      const e = err || {};
      console.error(
        "onRegistrationResponded: email send failed",
        "requestId:",
        context.params.requestId,
        "toEmail:",
        toEmail,
        "status:",
        status,
        "brevoStatus:",
        e.brevoStatus || "(none)",
        "brevoBody:",
        e.brevoBody != null ? JSON.stringify(e.brevoBody) : "(none)",
        "message:",
        e.message || String(err)
      );
      throw err;
    }

    return null;
  });

/**
 * When a user document is updated and accountStatus changes to Deactivated or Active,
 * send an email to the user.
 */
exports.onUserAccountStatusChanged = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const beforeStatus = (before && before.accountStatus) || "";
    const afterStatus = (after && after.accountStatus) || "";

    if (afterStatus !== "Deactivated" && afterStatus !== "Active") return null;
    if (beforeStatus === afterStatus) return null;

    const toEmail = after.email;
    if (!toEmail || typeof toEmail !== "string" || !toEmail.includes("@")) {
      console.warn("onUserAccountStatusChanged: no valid email for user", context.params.userId);
      return null;
    }

    if (!isBrevoEmailConfigured()) {
      console.warn("onUserAccountStatusChanged: Brevo not configured. Skipping email.");
      return null;
    }

    let subject, text;
    if (afterStatus === "Deactivated") {
      subject = "Your FoodDesk account has been deactivated";
      const reason = after.deactivationReason || "";
      text = [
        "Your FoodDesk account has been deactivated.",
        "You will not be able to sign in or place orders until your account is reactivated.",
        "",
        reason ? "Reason: " + reason : "",
      ]
        .filter(Boolean)
        .join("\n");
    } else {
      subject = "Your FoodDesk account has been reactivated";
      text = "Your FoodDesk account has been reactivated. You can sign in and place orders again.";
    }

    try {
      await sendBrevoEmail({ to: toEmail, subject, text });
      console.log("Account status email sent to", toEmail, "status:", afterStatus);
    } catch (err) {
      console.error("Failed to send account status email:", err);
      throw err;
    }
    return null;
  });

exports.onLateOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    // Firestore may store boolean; be defensive for any legacy/string values
    const isLateOrder =
      data &&
      (data.lateOrder === true ||
        data.lateOrder === "true" ||
        data.lateOrder === 1);
    if (!data || !isLateOrder) {
      return null;
    }
    const supplierId = data.supplierId;
    const orderId = context.params.orderId;
    if (!supplierId) {
      console.warn("onLateOrderCreated: missing supplierId on order", orderId);
      return null;
    }

    // Send FCM to supplier: use BOTH notification + data.
    // Data-only messages often do not show in the system tray when the app is backgrounded/killed on Android;
    // customer late-order responses already use notification + channelId for reliable delivery.
    try {
      const userSnap = await admin.firestore().collection("users").doc(supplierId).get();
      const supplierData = userSnap.exists && userSnap.data() ? userSnap.data() : null;
      const fcmToken = supplierData && supplierData.fcmToken;
      if (!fcmToken) {
        console.warn(
          "onLateOrderCreated: no fcmToken for supplier",
          supplierId,
          "- supplier must open the app and allow notifications so the token is saved to users/{uid}"
        );
      } else if (!isValidFcmToken(fcmToken)) {
        console.warn("onLateOrderCreated: invalid fcmToken for supplier", supplierId);
      } else {
        const title = "New late order";
        const body =
          (data.customerName || "Customer") +
          " – " +
          (data.productName || "Meal") +
          " (x" +
          (data.quantity || 1) +
          ")";
        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body },
          data: {
            type: "late_order_pending",
            orderId: String(orderId),
            productId: String(data.productId || ""),
            quantity: String(data.quantity || 1),
            customerName: String(data.customerName || ""),
            productName: String(data.productName || ""),
            mealType: String(data.mealType || ""),
            title,
            body,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "food_desk_orders",
              title,
              body,
            },
          },
        });
        console.log("Late order FCM sent to supplier", supplierId);
      }
    } catch (fcmErr) {
      console.warn("onLateOrderCreated: FCM to supplier failed", fcmErr);
    }

    // Email to supplier (if SMTP configured)
    let supplierEmail = "";
    try {
      const userSnap = await admin.firestore().collection("users").doc(supplierId).get();
      if (userSnap.exists && userSnap.data() && userSnap.data().email) supplierEmail = userSnap.data().email;
    } catch (e) {
      console.warn("onLateOrderCreated: could not get supplier email", e);
    }
    if (supplierEmail && supplierEmail.includes("@")) {
      if (isBrevoEmailConfigured()) {
        const text = [
          "A new late meal reservation requires your approval.",
          "",
          "Customer: " + (data.customerName || "Customer"),
          "Product: " + (data.productName || "Meal"),
          "Quantity: " + (data.quantity || 1),
          data.mealType ? "Meal type: " + data.mealType : "",
          data.customerNotes ? "Notes: " + data.customerNotes : "",
          "",
          "Please open the FoodDesk app and go to Late Orders to approve or reject.",
        ]
          .filter(Boolean)
          .join("\n");
        try {
          await sendBrevoEmail({
            to: supplierEmail,
            subject: "FoodDesk: New late order awaiting your approval",
            text,
          });
          console.log("Late order email sent to supplier", supplierEmail);
        } catch (err) {
          console.error("onLateOrderCreated: email send failed", err);
        }
      }
    }
    return null;
  });

exports.onLateOrderResponded = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after || !after.lateOrder) return null;
    if ((before.status || "") !== "LateOrderPending") return null;
    const afterStatus = after.status || "";
    if (afterStatus !== "Pending" && afterStatus !== "Rejected") return null;
    const toEmail = after.customerEmail;
    const customerId = after.customerId;
    const productName = after.productName || "your order";
    const supplierComment = after.supplierComment || "";

    // Send push notification to customer if we have a valid FCM token
    if (customerId && typeof customerId === "string") {
      try {
        const userSnap = await admin.firestore().collection("users").doc(customerId).get();
        const fcmToken = userSnap.exists && userSnap.data() && userSnap.data().fcmToken;
        if (!fcmToken) {
          console.warn("onLateOrderResponded: no fcmToken for customer", customerId, "- ensure customer opened app and allowed notifications");
        } else if (!isValidFcmToken(fcmToken)) {
          console.warn("onLateOrderResponded: invalid fcmToken for customer", customerId, "- token format/length invalid");
        } else {
          const isApproved = afterStatus === "Pending";
          const title = isApproved
            ? "Late order approved"
            : "Late order not accepted";
          const body = isApproved
            ? productName + " – Your late reservation was approved by the supplier."
            : (productName + (supplierComment ? " – " + supplierComment : " – Your late reservation could not be accepted."));
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            android: {
              priority: "high",
              notification: {
                channelId: "food_desk_orders",
                title,
                body,
              },
            },
          });
          console.log("Late order FCM sent to customer", customerId);
        }
      } catch (fcmErr) {
        console.warn("onLateOrderResponded: FCM send failed", fcmErr);
      }
    }

    // Send email to customer
    if (!toEmail || typeof toEmail !== "string" || !toEmail.includes("@")) {
      console.warn("onLateOrderResponded: no customer email on order", context.params.orderId);
      return null;
    }
    if (!isBrevoEmailConfigured()) {
      console.warn("onLateOrderResponded: Brevo not configured.");
      return null;
    }
    let subject, text;
    if (afterStatus === "Pending") {
      subject = "Your late meal reservation was approved";
      text = [
        "Good news! Your late meal reservation has been approved by the supplier.",
        "",
        "Order: " + productName,
        supplierComment ? "supplier note: " + supplierComment : "",
        "",
        "It will be fulfilled as normal.",
      ]
        .filter(Boolean)
        .join("\n");
    } else {
      subject = "Your late meal reservation was not accepted";
      text = [
        "Your late meal reservation could not be accepted.",
        "",
        "Order: " + productName,
        supplierComment ? "Reason: " + supplierComment : "",
      ]
        .filter(Boolean)
        .join("\n");
    }
    try {
      await sendBrevoEmail({
        to: toEmail,
        subject: "FoodDesk: " + subject,
        text,
      });
      console.log("Late order response notification sent to customer", toEmail);
    } catch (err) {
      console.error("onLateOrderResponded: send failed", err);
      throw err;
    }
    return null;
  });

/**
 * Callable: send a test push notification to the currently authenticated user.
 * Used to validate that FCM is configured and the user's token is valid.
 */
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }
  const uid = context.auth.uid;
  const userSnap = await admin.firestore().collection("users").doc(uid).get();
  const fcmToken = userSnap.exists && userSnap.data() && userSnap.data().fcmToken;
  if (!fcmToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "No FCM token. Open the app, allow notifications, and try again."
    );
  }
  if (!isValidFcmToken(fcmToken)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Stored FCM token is invalid. Try logging out and back in, then allow notifications."
    );
  }
  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: "FoodDesk test",
      body: "If you see this, push notifications are working.",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "food_desk_orders",
        title: "FoodDesk test",
        body: "If you see this, push notifications are working.",
      },
    },
  });
  console.log("Test notification sent to user", uid);
  return { success: true, message: "Test notification sent." };
});

const TEMP_RESET_PASSWORD = "Fooddesk@123";

/**
 * Callable (admin only): reset a user's password to TEMP_RESET_PASSWORD,
 * mark that user to change password on next login, and send notification email.
 */
exports.adminResetUserPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }

  const adminUid = context.auth.uid;
  const adminUserDoc = await admin.firestore().collection("users").doc(adminUid).get();
  const adminData = adminUserDoc.exists ? adminUserDoc.data() : null;
  const adminRole = (adminData && adminData.role ? String(adminData.role) : "").toLowerCase();
  if (adminRole !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Only admin can reset passwords.");
  }

  const targetUserId = data && typeof data.targetUserId === "string" ? data.targetUserId.trim() : "";
  const targetEmail = data && typeof data.targetEmail === "string" ? data.targetEmail.trim() : "";
  if (!targetUserId || !targetEmail || !targetEmail.includes("@")) {
    throw new functions.https.HttpsError("invalid-argument", "targetUserId and valid targetEmail are required.");
  }
  if (targetUserId === adminUid) {
    throw new functions.https.HttpsError("failed-precondition", "You cannot reset your own password.");
  }

  try {
    const userRecord = await admin.auth().getUser(targetUserId);
    const emailOnAuth = (userRecord.email || "").toLowerCase();
    if (emailOnAuth && emailOnAuth !== targetEmail.toLowerCase()) {
      throw new functions.https.HttpsError("failed-precondition", "Selected email does not match the auth account email.");
    }

    await admin.auth().updateUser(targetUserId, { password: TEMP_RESET_PASSWORD });
    await admin.firestore().collection("users").doc(targetUserId).set(
      {
        mustChangePassword: true,
        passwordResetAt: admin.firestore.FieldValue.serverTimestamp(),
        passwordResetBy: adminUid,
        passwordResetByEmail: context.auth.token.email || "",
      },
      { merge: true }
    );
    await admin.firestore().collection("audit_log").add({
      action: "reset_password",
      targetUserId,
      targetEmail,
      byAdminId: adminUid,
      byAdminEmail: context.auth.token.email || "",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (isBrevoEmailConfigured()) {
      const subject = "FoodDesk password reset by admin";
      const text = [
        "Your FoodDesk password has been reset by an administrator.",
        "",
        "Temporary password: " + TEMP_RESET_PASSWORD,
        "",
        "Please sign in with this temporary password, then change your password immediately.",
      ].join("\n");
      await sendBrevoEmail({ to: targetEmail, subject, text });
    } else {
      console.warn("adminResetUserPassword: Brevo not configured, password reset completed without email.");
    }

    return { success: true };
  } catch (err) {
    if (err instanceof functions.https.HttpsError) throw err;
    console.error("adminResetUserPassword failed", err);
    throw new functions.https.HttpsError("internal", "Password reset failed.");
  }
});
