# Mobile App — AlertDam

Flutter mobile app (iOS + Android) for critical incident alerting with native DND bypass and iOS Critical Alerts.

## Requirements

- Flutter 3.22+
- Dart 3.4+
- For iOS: Xcode 16+, Apple Developer account with Critical Alerts entitlement
- For Android: Android Studio, Firebase project

## Directory Structure

```
mobile/
├── lib/
│   ├── main.dart                   # App entry point (Firebase + FCM init)
│   ├── screens/
│   │   ├── home_screen.dart        # Incident dashboard
│   │   ├── incident_screen.dart    # Incident detail + actions
│   │   ├── schedule_screen.dart    # On-call schedule viewer
│   │   └── settings_screen.dart   # User settings
│   ├── services/
│   │   ├── api_service.dart        # HTTP client (Dio)
│   │   ├── notification_service.dart  # FCM + APNs + local notifications
│   │   └── auth_service.dart       # Token management
│   └── models/
│       ├── incident.dart
│       └── schedule.dart
├── android/                        # Android platform files
├── ios/                            # iOS platform files
├── assets/
│   ├── images/
│   └── icons/
└── pubspec.yaml
```

## Setup

### 1. Firebase Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (downloads google-services.json and GoogleService-Info.plist)
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

### 2. iOS — Critical Alerts Entitlement

Add to `ios/Runner/Runner.entitlements`:
```xml
<key>com.apple.developer.usernotifications.critical-alerts</key>
<true/>
```

> Note: Critical Alerts require explicit approval from Apple. See [Apple Developer docs](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns).

### 3. Run

```bash
flutter pub get
flutter run                  # Run on connected device/simulator
flutter run --release        # Test release build
```

## Features

| Feature | iOS | Android |
|---|---|---|
| FCM push notifications | ✅ APNs | ✅ FCM |
| Bypass Silent/DND | ✅ Critical Alerts | ✅ Full-volume channel |
| Background wake | ✅ | ✅ |
| Action buttons (Ack/Resolve) | ✅ | ✅ |
| SIP/WebRTC voice | 🚧 Planned | 🚧 Planned |
