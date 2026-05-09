# flexicurl-client-mobile
Client side for the Mobile Application of Flexicurl

## Release API Configuration

Use production URLs while creating APK:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.flexicurl.fit/mobile/api/v1 `
  --dart-define=WEB_API_BASE_URL=https://api.flexicurl.fit/api/v1 `
  --dart-define=AUTH_BASE_URL=https://api.flexicurl.fit/api/v1/auth
```

API split used by the app:

- Mobile features (workout, nutrition, hydration): `.../mobile/api/v1`
- Gym, memberships, profile, discovery: `.../api/v1`
- Auth: `.../api/v1/auth`

## Quick Smoke Test Before APK

```powershell
curl https://api.flexicurl.fit/mobile/api/v1/health
curl https://api.flexicurl.fit/mobile/api/openapi.json
curl https://api.flexicurl.fit/api/v1/gyms/discover?lat=25.14668^&lng=75.82909^&limit=5
curl https://api.flexicurl.fit/api/v1/auth/me
```

Expected:

- Health/OpenAPI: `200`
- Gyms discover: `200` with JSON array
- Auth `/me`: `401` without token (this is normal)
