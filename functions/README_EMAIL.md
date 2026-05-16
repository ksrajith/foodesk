# Sending transactional emails from Cloud Functions

Emails (registration decisions, account status, late orders, admin password reset) are sent via the **Brevo Transactional Email REST API** (`POST https://api.brevo.com/v3/smtp/email`).

## Configure Brevo (required for emails to send)

Use a **Brevo API key** (Dashboard → **SMTP & API** → **API keys**), not the SMTP password, in the `api-key` sense. The sender address must be a **verified sender** (or domain) in Brevo.

This project uses Firebase **params** (`defineString`).

Set params in Firebase Console:

1. Open Firebase Console → Build → Functions → select a function that sends mail (or deploy once so params appear).
2. Under runtime variables / params, set:
   - `BREVO_API_KEY` = your Brevo v3 API key
   - `BREVO_SENDER_EMAIL` = verified sender email (e.g. `mymobileapp@outlook.com`)
   - `BREVO_SENDER_NAME` = optional display name (default in code: `FoodDesk`)
3. Deploy.

For **local emulator / testing**, you can set the same names in `process.env` (`BREVO_API_KEY`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`).

If Brevo is not configured, triggers skip sending and log a warning (approve/reject and other app logic still proceed where applicable).

## Deploy

From the project root:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Email content

- **From:** `BREVO_SENDER_EMAIL` / `BREVO_SENDER_NAME` (registration emails use display name `FoodDesk Admin`).
- **Reply-To:** Registration responses set reply-to to the admin email when present.
- **Body:** Plain text via Brevo `textContent`.
