# Move This App to Your Personal Firebase Project

The app is currently configured for the **demo** Firebase project (`ecommers-demo-rajith`). To use **your personal** Firebase project, follow these steps.

---

## 1. Create or select your Firebase project

1. Open [Firebase Console](https://console.firebase.google.com).
2. Sign in with your **personal** Google account.
3. Either:
   - **Create project** → choose a name (e.g. `food_desk`) → enable Google Analytics if you want.
   - Or **select** an existing personal project.

---

## 2. Add both Android and iOS apps (same Firebase project)

Firebase does **not** have a “Flutter” app type. For Android + iOS support you add **two apps** to the same project:

- **Add app** → **Android** (get `google-services.json`)
- **Add app** → **iOS** (get `GoogleService-Info.plist`)

Use the same Firebase project for both; Auth and Firestore are shared.

---

### 2a. Android app

1. In your project: **Project settings** (gear) → **Your apps** → **Add app** → choose **Android** (not Flutter).
2. **Android package name** (must match the app exactly):
   ```text
   com.mit.food_desk
   ```
3. Register → **download `google-services.json`**.
4. **Replace** the file in this repo:
   - Put the downloaded file at: **`android/app/google-services.json`** (overwrite the existing one).

---

### 2b. iOS app

1. **Project settings** → **Your apps** → **Add app** → choose **iOS** (not Flutter).
2. **iOS bundle ID** (must match the app exactly):
   ```text
   com.mit.foodDesk
   ```
3. Register → **download `GoogleService-Info.plist`**.
4. Add the file to the app:
   - In Xcode: open **Runner** → drag **GoogleService-Info.plist** into the **Runner** group (check “Copy items if needed” and Runner target).
   - Or place the file at: **`ios/Runner/GoogleService-Info.plist`** and add it to the Runner target in Xcode.

---

## 3. Enable Auth and Firestore in your project

1. **Authentication**  
   Firebase Console → **Build** → **Authentication** → **Get started** → enable **Email/Password** (and any other providers you use).

2. **Firestore**  
   **Build** → **Firestore Database** → **Create database** → choose location → start in **test mode** or **production** and then deploy rules (see below).

---

## 4. Deploy Firestore rules to your project

This repo has `firestore.rules` and a `firebase.json` that points to it.

1. Install Firebase CLI if needed:  
   `npm install -g firebase-tools`
2. Log in:  
   `firebase login`
3. From the **project root** (`food_desk`), link your personal project:  
   `firebase use --add`  
   Select your personal project and give it an alias (e.g. `default`).
4. Deploy only rules:  
   `firebase deploy --only firestore:rules`

Your personal Firestore will now use the rules from `firestore.rules`. You can edit that file and run the same deploy command again to update.

---

## 5. (Optional) Seed data in your personal project

To seed products/users in your **personal** Firestore:

1. Ensure **Authentication** has at least one user (e.g. create a user with the email/password you will use for seeding).
2. From project root, run the seed script **on Android or iOS** (so it uses the native config, i.e. your new `google-services.json`):

   ```bash
   flutter run -d <device-id> -t lib/scripts/seed_firestore.dart --dart-define=SEED_EMAIL=your@email.com --dart-define=SEED_PASSWORD=yourpassword
   ```

   Or on web/desktop, pass your personal project’s Firebase options via `--dart-define` (see `lib/scripts/seed_firestore.dart` for `FB_API_KEY`, `FB_PROJECT_ID`, etc.).

---

## Summary: what you must do

| Step | Action |
|------|--------|
| 1 | Create or select your personal Firebase project. |
| 2 | Add Android app with package `com.mit.food_desk`, download `google-services.json`, and **replace** `android/app/google-services.json`. |
| 3 | Add iOS app with bundle ID `com.mit.foodDesk` and add `GoogleService-Info.plist` to `ios/Runner/`. |
| 4 | Enable Email/Password auth and create Firestore. |
| 4 | Run `firebase use --add`, then `firebase deploy --only firestore:rules`. |

After step 2 (and 3 if you use iOS), the app will use your personal Firebase. No code changes are required; the app reads the project from the config files.
