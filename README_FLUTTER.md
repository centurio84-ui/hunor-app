# HUNOR Flutter

A HUNOR internal mobile client built with Flutter so the same application code can target Android and iOS.

## Architecture

- Flutter / Dart mobile client
- Supabase Auth + PostgreSQL backend
- Android push: Firebase Cloud Messaging (FCM)
- iOS push: Apple Push Notification service (APNs)
- Shared HUNOR backend and RLS policies

## Windows development

Install Flutter and Android Studio using the official Flutter Android setup guide.

From the repository root:

    flutter create --platforms=android,ios .
    flutter pub get

Run with the HUNOR Supabase project configuration:

    flutter run --dart-define=SUPABASE_URL=https://embicteneumubwlqgfik.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY

Never put a Supabase secret/service-role key in the mobile app.

## Current migration stage

The Flutter client now contains the shared application shell, Supabase authentication, member list, events and alert response flows.

Next:

1. Firebase/FCM device-token registration for Android.
2. Change `device_tokens.platform` to support both `android` and `ios`.
3. Update push delivery so the same HUNOR alert reaches Android via FCM and iPhone via APNs.
4. Port the full admin UI.
5. Test on a physical Android device.
6. Add iOS configuration and TestFlight later.

The existing SwiftUI implementation is retained in `HUNORApp/` while the Flutter client is validated. Once the Flutter version is stable, the native iOS client can be retired.

Official Flutter Android setup:
https://docs.flutter.dev/platform-integration/android/setup

Official Supabase Flutter quickstart:
https://supabase.com/docs/guides/getting-started/quickstarts/flutter
