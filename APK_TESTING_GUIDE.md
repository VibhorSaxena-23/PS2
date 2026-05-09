# FlexiCurl APK Testing Guide

This guide is for creating and testing a working Android APK from the Flutter
mobile client against the deployed FlexiCurl API gateway.

## Project Map

- Backend gateway: `flexicurl-server`
- Mobile client: `flexicurl-client-mobile`
- Production API host: `https://api.flexicurl.fit`

The backend exposes two API surfaces:

- Mobile API: `https://api.flexicurl.fit/mobile/api/v1`
- Web API: `https://api.flexicurl.fit/api/v1`
- Auth API: `https://api.flexicurl.fit/api/v1/auth`

The mobile app uses the mobile API for workouts, nutrition, hydration,
metrics, progress, and plans. It uses the web API for auth, gyms,
memberships, subscriptions, attendance, and profile.

## Backend Smoke Checks

Run these before building a release APK:

```powershell
curl.exe https://api.flexicurl.fit/mobile/api/v1/health
curl.exe https://api.flexicurl.fit/api/v1/health
curl.exe "https://api.flexicurl.fit/api/v1/gyms/discover?lat=25.14668&lng=75.82909&limit=5"
curl.exe -i https://api.flexicurl.fit/api/v1/auth/me
```

Expected results:

- Mobile health returns `200` and `{"status":"ok"}`.
- Web health returns `200`.
- Gym discovery returns `200` with a JSON list. An empty list is valid if no gyms match the coordinates.
- Auth `/me` returns `401` without a token. This is expected and confirms the protected route is active.

## Verification Before APK

From `flexicurl-server`:

```powershell
.venv\Scripts\python.exe -m pytest -q
```

From `flexicurl-client-mobile`:

```powershell
flutter analyze
flutter test
```

## Build Release APK

From `flexicurl-client-mobile`:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.flexicurl.fit/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=https://api.flexicurl.fit/api/v1 `
  --dart-define=AUTH_BASE_URL=https://api.flexicurl.fit/api/v1/auth
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## Install On Android Device

Enable USB debugging, connect the device, then run:

```powershell
flutter devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

If `adb` is not on PATH, use Android Studio's Device Manager or locate it in
the Android SDK `platform-tools` folder.

## Manual QA Checklist

1. Launch app and confirm splash/onboarding opens.
2. Register or log in with a test account.
3. Complete OTP flow if required.
4. Complete health onboarding and save nutrition targets.
5. Open dashboard and confirm no blocking API error appears.
6. Search foods, log a meal, and confirm daily nutrition summary updates.
7. Add hydration entry, edit it, and delete it.
8. Open workout area, select or create a plan, and start a session.
9. Open gym discovery and confirm the screen handles empty results cleanly.
10. Open profile and confirm authenticated data loads.
11. Kill and reopen the app to confirm token/session behavior.

## Notes For Test Builds

- The APK is signed through `android/key.properties` and `android/app/upload-keystore.jks`.
- Do not commit keystore secrets or expose the contents of `key.properties`.
- `android:usesCleartextTraffic="true"` is enabled, which is useful for local backend testing. For a Play Store production build, prefer HTTPS-only unless local HTTP is still required.
- Backend tests may show Pydantic and Python 3.14 deprecation warnings. They are not current APK blockers, but should be scheduled before production hardening.
