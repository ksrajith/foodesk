const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

/**
 * When a registration_requests document is updated and status is 'approved' or 'rejected',
 * send an email to the applicant. From = admin email, Subject and body as per requirement.
 */
exports.onRegistrationResponded = functions.firestore
  .document("registration_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const status = after && after.status;

    if (status !== "approved" && status !== "rejected") {
      return null;
    }

    const toEmail = after.email;
    if (!toEmail || typeof toEmail !== "string" || !toEmail.includes("@")) {
      console.warn("onRegistrationResponded: no valid email for request", context.params.requestId);
      return null;
    }

    const adminEmail = after.respondedByEmail || "";
    const role = after.approvedRole || (status === "approved" ? "Customer" : "");
    const comment = after.adminComment || "";

    const subject =
      status === "approved"
        ? "Your Food Desk Registration Request has Approved"
        : "Your Food Desk Registration Request has Rejected";

    const bodyLines = [
      status === "approved"
        ? "Your Food Desk registration request has been approved."
        : "Your Food Desk registration request has been rejected.",
      "",
      "Role: " + (role || "—"),
      "",
      comment ? "Comment from admin:\n" + comment : "",
    ];
    const text = bodyLines.filter(Boolean).join("\n");

    // Use SMTP from Firebase config (firebase functions:config:set smtp.user=... smtp.pass=...) or env
    const config = functions.config();
    const smtpUser = process.env.SMTP_USER || process.env.GMAIL_USER || (config.smtp && config.smtp.user);
    const smtpPass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || (config.smtp && config.smtp.pass);
    const smtpHost = process.env.SMTP_HOST || (config.smtp && config.smtp.host) || "smtp.gmail.com";
    const smtpPort = parseInt(process.env.SMTP_PORT || (config.smtp && config.smtp.port) || "587", 10);
    const fromEmail = adminEmail || smtpUser || "noreply@fooddesk.com";

    if (!smtpUser || !smtpPass) {
      console.warn(
        "onRegistrationResponded: SMTP not configured. Set SMTP_USER and SMTP_PASS (or GMAIL_USER and GMAIL_APP_PASSWORD) in Firebase config or env."
      );
      return null;
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: { user: smtpUser, pass: smtpPass },
    });

    const mailOptions = {
      from: `"FoodDesk Admin" <${fromEmail}>`,
      to: toEmail,
      replyTo: adminEmail || undefined,
      subject,
      text,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log("Registration email sent to", toEmail, "status:", status);
    } catch (err) {
      console.error("Failed to send registration email:", err);
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

    const config = functions.config();
    const smtpUser = process.env.SMTP_USER || process.env.GMAIL_USER || (config.smtp && config.smtp.user);
    const smtpPass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || (config.smtp && config.smtp.pass);
    const smtpHost = process.env.SMTP_HOST || (config.smtp && config.smtp.host) || "smtp.gmail.com";
    const smtpPort = parseInt(process.env.SMTP_PORT || (config.smtp && config.smtp.port) || "587", 10);

    if (!smtpUser || !smtpPass) {
      console.warn("onUserAccountStatusChanged: SMTP not configured. Skipping email.");
      return null;
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: { user: smtpUser, pass: smtpPass },
    });

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
      await transporter.sendMail({
        from: `"FoodDesk" <${smtpUser}>`,
        to: toEmail,
        subject,
        text,
      });
      console.log("Account status email sent to", toEmail, "status:", afterStatus);
    } catch (err) {
      console.error("Failed to send account status email:", err);
      throw err;
    }
    return null;
  });

function getSmtpTransporter() {
  const config = functions.config();
  const smtpUser = process.env.SMTP_USER || process.env.GMAIL_USER || (config.smtp && config.smtp.user);
  const smtpPass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || (config.smtp && config.smtp.pass);
  const smtpHost = process.env.SMTP_HOST || (config.smtp && config.smtp.host) || "smtp.gmail.com";
  const smtpPort = parseInt(process.env.SMTP_PORT || (config.smtp && config.smtp.port) || "587", 10);
  if (!smtpUser || !smtpPass) return null;
  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });
}

exports.onLateOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || !data.lateOrder) return null;
    const vendorId = data.vendorId;
    if (!vendorId) return null;
    let vendorEmail = "";
    try {
      const userSnap = await admin.firestore().collection("users").doc(vendorId).get();
      if (userSnap.exists && userSnap.data() && userSnap.data().email) vendorEmail = userSnap.data().email;
    } catch (e) {
      console.warn("onLateOrderCreated: could not get vendor email", e);
    }
    if (!vendorEmail || !vendorEmail.includes("@")) return null;
    const transporter = getSmtpTransporter();
    if (!transporter) {
      console.warn("onLateOrderCreated: SMTP not configured.");
      return null;
    }
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
      await transporter.sendMail({
        from: process.env.SMTP_USER || (functions.config().smtp && functions.config().smtp.user) || "noreply@fooddesk.com",
        to: vendorEmail,
        subject: "FoodDesk: New late order awaiting your approval",
        text,
      });
      console.log("Late order notification sent to vendor", vendorEmail);
    } catch (err) {
      console.error("onLateOrderCreated: send failed", err);
      throw err;
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
    if (!toEmail || typeof toEmail !== "string" || !toEmail.includes("@")) {
      console.warn("onLateOrderResponded: no customer email on order", context.params.orderId);
      return null;
    }
    const transporter = getSmtpTransporter();
    if (!transporter) {
      console.warn("onLateOrderResponded: SMTP not configured.");
      return null;
    }
    const productName = after.productName || "your order";
    const vendorComment = after.vendorComment || "";
    let subject, text;
    if (afterStatus === "Pending") {
      subject = "Your late meal reservation was approved";
      text = [
        "Good news! Your late meal reservation has been approved by the vendor.",
        "",
        "Order: " + productName,
        vendorComment ? "Vendor note: " + vendorComment : "",
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
        vendorComment ? "Reason: " + vendorComment : "",
      ]
        .filter(Boolean)
        .join("\n");
    }
    try {
      await transporter.sendMail({
        from: process.env.SMTP_USER || (functions.config().smtp && functions.config().smtp.user) || "noreply@fooddesk.com",
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
