# Family Zone

Bilingual (Arabic / English) fashion storefront for the whole family — Flutter app with Firebase backend, WhatsApp checkout, and staff catalog management.

## Features

- Product catalog with search, filters, and pagination
- Cart and checkout via WhatsApp
- Favorites for signed-in customers
- Staff panel: add/edit products, image upload, visibility & approval workflow
- Admin / employee / client roles with Firestore & Storage security rules
- Web, Android, and desktop targets

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (SDK ^3.9)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Node.js 20 (for Cloud Functions)
- A Firebase project (`family-zone-2026` or your own)

## Setup

```bash
# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions && npm install && cd ..

# Log in and select your Firebase project
firebase login
firebase use family-zone-2026
```

If you use a new Firebase project, regenerate platform config:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

## Deploy backend

Deploy rules, indexes, functions, and web hosting:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions,hosting
```

After deploying functions, contact form submissions go through the rate-limited `submitContactMessage` callable (5 messages per hour per user/IP).

### First admin user

1. Sign up in the app with email or Google.
2. In Firebase Console → Firestore, open `users/{uid}` and set `role` to `admin`.
3. Sign out and sign back in so Storage custom claims refresh (or wait for `syncUserRoleToClaims`).

## Run locally

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android
```

## Build for production

```bash
# Web (output: build/web)
flutter build web

# Android App Bundle
flutter build appbundle --release
```

### Android release signing

1. Create a keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` → `android/key.properties` and fill in paths/passwords.
3. Build: `flutter build appbundle --release`

### Google Play package ID

The app currently uses `com.example.family_zone`. **Google Play rejects `com.example.*` packages.** Before publishing:

1. Choose a final ID (e.g. `lb.familyzone.app`).
2. Update `applicationId` in `android/app/build.gradle.kts` and move `MainActivity.kt` to the matching package path.
3. Add the new Android app in Firebase Console and run `flutterfire configure`.
4. Update iOS bundle ID in Xcode / `AppInfo.xcconfig` if needed.

## Privacy policy

- In-app: sidebar → **Privacy Policy**
- Web: host `web/privacy.html` (e.g. `https://your-domain/privacy.html`) and link it in the Play Store listing

## Project structure

```
lib/
  pages/          # Dashboard, staff panel, auth, privacy
  services/       # Catalog, cart, orders, favorites, contact
  widgets/        # UI components
  models/         # Data models
  l10n/           # EN / AR strings
functions/        # Role sync + contact rate limiting
firestore.rules   # Security rules
storage.rules     # Image upload rules
```

## Firebase budget

Set a billing alert in [Firebase Console → Usage and billing](https://console.firebase.google.com/) to avoid unexpected costs during traffic spikes.

## License

Private — Family Zone © 2026
