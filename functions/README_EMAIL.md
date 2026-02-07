# Sending registration emails from Cloud Functions

When an admin approves or rejects a registration, the Cloud Function `onRegistrationResponded` sends an email to the applicant.

## Configure SMTP (required for emails to send)

Set environment variables for the function. Using **Gmail** as an example:

1. Use a Gmail account and create an [App Password](https://support.google.com/accounts/answer/185833) (2FA must be enabled).
2. Set config (run from project root):

   ```bash
   firebase functions:config:set smtp.user="your-admin@gmail.com" smtp.pass="your-app-password"
   ```

   Or set in Firebase Console → Functions → your project → Environment variables:
   - `SMTP_USER` = your Gmail address
   - `SMTP_PASS` = the app password

3. Optional: `SMTP_HOST` (default `smtp.gmail.com`), `SMTP_PORT` (default `587`).

If SMTP is not set, the function skips sending and logs a warning (approve/reject still works in the app).

## Deploy

From the project root:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Email content

- **From:** Admin email (who approved/rejected), when available.
- **Subject:**  
  - Approved: "Your Food Desk Registration Request has Approved"  
  - Rejected: "Your Food Desk Registration Request has Rejected"
- **Body:** Role assigned by admin and admin comments.
