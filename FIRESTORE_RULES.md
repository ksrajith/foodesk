# Firestore security rules

The file **`firestore.rules`** in this folder defines rules for the `registration_requests` collection used by the registration approval flow.

## What the rules do

- **Admins** (users with `users/{uid}.role == 'Admin'`):
  - Can **read** all documents in `registration_requests` (e.g. list pending requests).
  - Can **update** and **delete** any document (approve/reject).

- **Any signed-in user**:
  - Can **read** only their own document: `registration_requests/{requestId}` when `requestId == request.auth.uid` (used at login to show pending/approved/rejected).
  - Can **create** only their own document: `registration_requests/{uid}` when registering (doc id is the user’s uid).

So: admins can read/write all `registration_requests`; users can read and create only the doc whose id is their own uid.

## Applying these rules

You can use either the Firebase Console or the Firebase CLI.

### Option 1: Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com) → your project → **Firestore Database** → **Rules**.
2. Add or merge the contents of `firestore.rules` into your existing rules (keep any rules you already have for `users`, `products`, `orders`, etc.).
3. Click **Publish**.

### Option 2: Firebase CLI

If your project uses the Firebase CLI:

1. Ensure you have a `firebase.json` that configures Firestore (e.g. `"firestore": { "rules": "firestore.rules" }`).
2. From the project root (where `firebase.json` lives), run:
   ```bash
   firebase deploy --only firestore:rules
   ```

**Note:** The repo’s `firestore.rules` only defines rules for `registration_requests`. If you manage `users`, `products`, `orders`, etc. in the same file, merge this block into your full rules so you don’t overwrite them.
