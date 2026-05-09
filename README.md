# FlexiCurl Mobile Client

Flutter mobile client for FlexiCurl.

This guide is written for a new developer who has no Flutter or Dart installed yet.
Dart ships with Flutter, so install Flutter first instead of installing Dart separately.

## 1. Install Required Tools

### Windows

1. Install Git for Windows: https://git-scm.com/download/win
2. Install Flutter from the official guide: https://docs.flutter.dev/install
3. Install Android Studio: https://developer.android.com/studio
4. Open Android Studio and install:
   - Android SDK
   - Android SDK Platform
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android Emulator, if you want to use an emulator
5. Add Flutter to your system `PATH`.
6. Close and reopen PowerShell after changing `PATH`.

Verify setup:

```powershell
flutter --version
flutter doctor
flutter doctor --android-licenses
```

Accept the Android licenses when prompted.

If `flutter doctor` reports Android toolchain issues, fix those first before running the app.

## 2. Clone The Project

```powershell
git clone https://github.com/flexicurl/flexicurl-client-mobile.git
cd flexicurl-client-mobile
```

## 3. Install App Dependencies

```powershell
flutter pub get
```

This project requires a Flutter SDK new enough to provide Dart `^3.10.8`.
If dependency resolution fails because your Dart SDK is too old, upgrade Flutter:

```powershell
flutter upgrade
flutter pub get
```

## 4. Run The App

### Run On Chrome

Useful for quick UI checks:

```powershell
flutter run -d chrome
```

### Run On Android Emulator

Start an emulator from Android Studio Device Manager, then run:

```powershell
flutter devices
flutter run
```

### Run On Physical Android Device

1. Enable Developer Options on the phone.
2. Enable USB debugging.
3. Connect the phone with USB.
4. Approve the debugging prompt on the phone.
5. Run:

```powershell
flutter devices
flutter run
```

## 5. API Configuration

The app has safe defaults:

- Web run defaults to `http://localhost:8000`.
- Android emulator debug run defaults to `http://10.0.2.2:8000`.
- Release builds default to `https://api.flexicurl.fit`.

If you need to point the app to a specific backend, pass API URLs with
`--dart-define`.

Local backend example:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Production API example:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://api.flexicurl.fit/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=https://api.flexicurl.fit/api/v1
```

## 6. Quality Checks

Run these before opening a pull request or building an APK:

```powershell
flutter analyze
flutter test
```

## 7. Build APK

### Debug APK

This does not require release signing files:

```powershell
flutter build apk --debug
```

Output:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

### Release APK For Local Testing

Fresh clones can build a release APK for local testing without the private
release keystore. Without `android/key.properties`, Gradle falls back to debug
signing so the APK is installable but not Play Store production-ready.

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.flexicurl.fit/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=https://api.flexicurl.fit/api/v1
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

### Production-Signed Release APK

Production signing requires private files that must never be committed:

- `android/key.properties`
- `android/app/upload-keystore.jks`

Create `android/key.properties` locally:

```properties
storeFile=app/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

Then build:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.flexicurl.fit/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=https://api.flexicurl.fit/api/v1
```

## 8. Backend Smoke Checks

Before testing a production API build:

```powershell
curl.exe https://api.flexicurl.fit/mobile/api/v1/health
curl.exe https://api.flexicurl.fit/api/v1/health
curl.exe "https://api.flexicurl.fit/api/v1/gyms/discover?lat=25.14668&lng=75.82909&limit=5"
curl.exe -i https://api.flexicurl.fit/api/v1/auth/me
```

Expected:

- Mobile health: `200`
- Web health: `200`
- Gym discovery: `200`, possibly with an empty list
- Auth `/me`: `401` without a token, which is normal

## 9. What Not To Commit

These files are intentionally ignored and should stay local:

- `.env`
- `.env.*`
- `android/key.properties`
- `android/local.properties`
- `android/app/upload-keystore.jks`
- `build/`
- `.dart_tool/`
- IDE caches

## 10. Common Fixes

### `flutter` is not recognized

Flutter is not on your `PATH`. Add the Flutter SDK `bin` folder to `PATH`, then
restart PowerShell.

### Android licenses are missing

```powershell
flutter doctor --android-licenses
```

### No Android devices found

Run:

```powershell
flutter devices
```

Then start an emulator from Android Studio or connect a physical device with USB
debugging enabled.

### App cannot reach local backend from Android emulator

Use `10.0.2.2` instead of `localhost` for Android emulator builds:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/mobile/api/v1
```

### Dependency resolution fails

Upgrade Flutter, then fetch dependencies again:

```powershell
flutter upgrade
flutter pub get
```
