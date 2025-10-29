Geolocator setup notes

Android
- Add the following permissions to `android/app/src/main/AndroidManifest.xml` inside the `<manifest>` element:

  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

- For Android 10+ background location may also need `ACCESS_BACKGROUND_LOCATION` if you need background tracking.

iOS
- In `ios/Runner/Info.plist`, add keys and user-facing messages:

  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Nous avons besoin de votre position pour proposer l\'adresse.</string>

- If you need always-on location, add NSLocationAlwaysAndWhenInUseUsageDescription.

General
- After editing pubspec.yaml, run `flutter pub get`.
- Then run the app on a real device or emulator with location services enabled.

Troubleshooting
- On Android emulators, set a simulated GPS location in the emulator settings.
- If permission is deniedForever, prompt user to open app settings (Geolocator.openAppSettings()).
