# Rename project folder to food_desk

The following renames are done or need to be done manually.

## Done

- **Android package folder** renamed from `e_commerce_demo_app` to **`food_desk`**:
  - Path: `android/app/src/main/kotlin/com/mit/food_desk/`
  - `build.gradle.kts`: `namespace` and `applicationId` set to `com.mit.food_desk`
  - `MainActivity.kt` package set to `com.mit.food_desk`

## Firebase (required after Android package rename)

The app now uses the package **`com.mit.food_desk`**. Your current `google-services.json` is for `com.example.e_commerce_demo_app`.

1. Open [Firebase Console](https://console.firebase.google.com) → your project.
2. Go to **Project settings** (gear) → **Your apps**.
3. **Add app** → Android (if needed).
4. Register an Android app with package name: **`com.mit.food_desk`**.
5. Download the new **google-services.json** and replace:
   - `android/app/google-services.json`

Then rebuild the app.

## Rename the project root folder (when IDE is closed)

The root folder could not be renamed automatically because it is in use.

1. Close Cursor/IDE and any terminals using this project.
2. In File Explorer, go to `d:\mobileGit\e_commerce_demo_app-main\`.
3. Rename the folder **`e_commerce_demo_app-main`** to **`food_desk`**.
4. (Optional) Rename the parent **`e_commerce_demo_app-main`** to **`food_desk`** if you want a single top-level `food_desk` folder.
5. Reopen the project in Cursor from the new path (e.g. `d:\mobileGit\e_commerce_demo_app-main\food_desk` or `d:\mobileGit\food_desk`).

After reopening, run `flutter pub get` and build as usual.

## Opening in Cursor after folder rename

If the project **won’t open in Cursor** after you renamed the folder:

- **Cause:** Cursor remembers the **old path** (e.g. `e_commerce_demo_app-main`). “Recent” and workspace state still point there, so that path no longer exists.
- **Fix:** Do **not** open from “Recent”. Use **File → Open Folder…** and choose the **new** folder path:
  - `D:\mobileGit\food_desk\food_desk`
- If you had a workspace file or shortcut that used the old path, update it to the new path or remove it and open the folder as above.
- Optional: run `flutter clean` in the project, then `flutter pub get`, to clear build cache that still references the old path.
