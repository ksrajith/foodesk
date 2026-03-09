# Deploy Firebase Functions

## Run the deploy (do not paste output into the terminal)

In PowerShell, **type or run this command** (do not paste the previous deploy output into the terminal, or PowerShell will try to run each line as a command):

```powershell
npm run deploy:functions
```

Or:

```powershell
npx firebase deploy --only functions
```

Make sure Node is on PATH first (e.g. `$env:Path = "D:\node_donot_del;$env:Path"`).

---

## If you see "failed to create function"

This usually means one of the following.

### 1. Billing not enabled (most common)

**Cloud Functions require the Blaze (pay-as-you-go) plan.**

1. Open [Firebase Console](https://console.firebase.google.com/) → select project **food-desk**.
2. Go to **Project settings** (gear) → **Usage and billing**.
3. Click **Modify plan** or **Upgrade to Blaze**.
4. Link a billing account (Blaze has a free tier; you only pay beyond free quotas).

Then run `npm run deploy:functions` again.

### 2. APIs still enabling

If the CLI said it was enabling `cloudfunctions.googleapis.com`, `cloudbuild.googleapis.com`, or `artifactregistry.googleapis.com`, wait 2–3 minutes and run the deploy again.

### 3. See the full error

Scroll up in the same terminal where you ran the deploy to see the full error (e.g. "Billing account not configured", "Permission denied"). Fix that specific issue and redeploy.
