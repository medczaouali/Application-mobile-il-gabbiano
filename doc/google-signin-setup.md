# Google Sign-In without Firebase (Android)

This app uses the `google_sign_in` plugin and stores users in SQLite. To make Google Sign-In work on Android, you must authorize your app package name with your signing certificate SHA‑1 in Google Cloud. No Firebase required.

Follow these steps on Windows (PowerShell).

---

## 1) Confirm your Android package name

Current package name (applicationId): `com.example.ilgabbiano`

You must use this exact value when creating the Android OAuth client in Google Cloud. If you plan to change it (e.g., `com.yourcompany.ilgabbiano`), change it first in `android/app/build.gradle.kts`, then use that new package everywhere below.

---

## 2) Get your SHA‑1 fingerprint

### Debug SHA‑1
Run in Windows PowerShell:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

Copy the `SHA1` value from the output (format like `AA:BB:CC:...`).

### Release SHA‑1 (optional, for release APK/AAB)
Use your release keystore if you will sign a release build:

```powershell
keytool -list -v -alias YOUR_ALIAS -keystore "C:\path\to\your\release-keystore.jks"
```

> You can add multiple SHA‑1 fingerprints (debug + release) to the same OAuth client.

---

## 3) Create the Android OAuth client in Google Cloud

1. Open https://console.cloud.google.com/apis/credentials
2. If asked, first configure the OAuth consent screen (External → basic fields → Save).
3. Click “Create credentials” → “OAuth client ID”.
4. Application type: Android
5. Package name: `com.example.ilgabbiano`
6. SHA‑1 certificate fingerprint: paste your SHA‑1 from step 2
7. Create and save

No file needs to be added to the project for pure `google_sign_in`.

---

## 4) Rebuild and test

- Close the app on the device/emulator.
- Run the app again and tap “Sign in with Google”.
- Test on a device/emulator with Google Play services and a Google account.

---

## Troubleshooting

- Error 10 (DEVELOPER_ERROR):
  - The package name and/or SHA‑1 do not match the configured OAuth client.
  - Re-check that the package name is `com.example.ilgabbiano` and the SHA‑1 is correct for the keystore used (debug or release).
- Using a different package name:
  - If you change the package in `android/app/build.gradle.kts`, you must create a new Android OAuth client for that package.
- Emulator without Play services:
  - Use an emulator image with the Google Play Store icon, or use a physical device.
- Network errors:
  - Ensure internet access and a logged-in Google account on the device.

---

## iOS (only if you target iOS later)

- Create an iOS OAuth client for your bundle ID in Google Cloud.
- Add the reversed client ID as a URL scheme in `Info.plist` (per `google_sign_in` docs).

---

Once the package name and SHA‑1 are correctly registered, Google Sign-In will work. Our app then creates or finds the user in SQLite and saves the session normally.