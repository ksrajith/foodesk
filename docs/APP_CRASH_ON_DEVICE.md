# App flashes and closes on device

If the app shows a brief flash (splash) then closes on a real device, follow these steps to find the cause.

---

## 1. Get the crash log (recommended)

Connect the phone with USB (with USB debugging enabled), then:

**Option A – Run from PC and watch logs**
```powershell
cd D:\mobileGit\food_desk\food_desk
flutter run --release
```
Launch the app on the device; when it crashes, the error will appear in the terminal.

**Option B – Capture logcat**
1. Connect the device and open the app so it crashes.
2. In a terminal:
   ```powershell
   adb logcat -d | findstr /i "flutter crash exception error fatal"
   ```
   Or save full log:
   ```powershell
   adb logcat -d > logcat.txt
   ```
   Then search `logcat.txt` for `FATAL`, `Exception`, `Error`, or `flutter`.

The first line of the stack trace (or the FATAL EXCEPTION) is usually the cause (e.g. missing class, wrong SDK, Firebase init).

---

## 2. Common causes and fixes

| Cause | What you see in log | Fix |
|-------|----------------------|-----|
| **Firebase init** | `Default FirebaseApp is not initialized` or `GoogleApiAvailability` | Ensure `android/app/google-services.json` exists and matches app package `com.mit.food_desk`. Rebuild: `flutter clean` then `flutter build apk`. |
| **Min SDK** | `minSdkVersion` / `requires min version` | In `android/app/build.gradle.kts`, ensure `minSdk` is 21 or lower if the device is old (Flutter default is often 21). |
| **Missing permission** | `Permission denied` / `SecurityException` | Add the needed permission in `android/app/src/main/AndroidManifest.xml`. |
| **Native library / ABI** | `UnsatisfiedLinkError` or `.so` not found | Build a fat APK: `flutter build apk --target-platform android-arm,android-arm64`. |
| **Release build** | ProGuard/R8 stripping required class | Add keep rules in `android/app/proguard-rules.pro` if you use minify. |

---

## 3. Rebuild and reinstall

After changing config or fixing the cause:

```powershell
flutter clean
flutter pub get
flutter build apk
```

Then install the new APK from `build/app/outputs/flutter-apk/app-release.apk`.

---

## 4. In-app error handling

The app now catches Firebase init errors and FCM setup errors so they don’t crash the process. If the app still closes, the failure is likely in native code or very early startup; use step 1 to get the exact error from logcat or `flutter run --release`.
