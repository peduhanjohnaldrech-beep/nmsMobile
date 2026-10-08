# NMS Mobile — Nutrition Monitoring System (Android)

A Flutter Android application for field health workers of the City Health Office Nutrition Department. It allows BHW, BNS, Midwife, and Encoder staff to register beneficiaries, record assessments, and submit data to the central server.

## Overview

The mobile app connects to the NMS backend API at `https://kabnms.duckdns.org/api`. Field staff log in with their web-system credentials. A local SQLite database enables offline use and syncs with the server when a connection is available.

---

## Features

- **Login** — Bearer token authentication via NMS API; session persisted securely on-device
- **Beneficiary Management** — Register, view, and edit child beneficiaries; BHW/BNS/Midwife are scoped to their assigned barangay
- **Assessment Recording** — Record weight, height, and MUAC; automatic OPT period detection (January for Jan–Jun, July for Jul–Dec)
- **OPT Batch Weighing** — Enter weights for multiple children at once and submit all records in a single API call
- **Submit to Admin** — BNS can submit pending beneficiary records to the midwife/admin for validation
- **Validation Queue** — Midwife and other authorized roles can review and validate pending assessment submissions from field workers
- **Reports** — View OPT, DSP, MNS, and summary reports filtered by barangay
- **Offline Support** — Local SQLite database via `sqflite`; records created offline sync on next connection
- **Auto-sync** — Syncs with the server on app open and on explicit refresh

---

## Assessment Validation Workflow

1. BHW or BNS enters weight/height data via **OPT Batch Weighing** or individual assessment form
2. Records are saved to the server with `validation_status = pending`
3. Midwife (or Nutritionist/Admin) reviews entries in the **Validation Queue**
4. Once validated, nutritional status is computed and reflected in beneficiary profiles

> Beneficiary registration and assessment validation are separate workflows. A beneficiary record must be validated before assessments for that child are processed.

---

## User Roles on Mobile

| Role | Access |
|------|--------|
| **BHW** | Own barangay only; register beneficiaries, record assessments, OPT batch weighing |
| **BNS** | Same as BHW; can submit pending records to admin |
| **Midwife** | Own barangay; record assessments; validate submissions in Validation Queue |
| **Encoder** | Add/edit beneficiaries and record assessments |
| **Nutritionist** | Full data access; validates all field submissions |
| **Admin** | Full access |

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.32.2 |
| Language | Dart 3.8.1 |
| State Management | Provider (ChangeNotifier) |
| HTTP Client | `http` package |
| Secure Storage | `flutter_secure_storage` |
| Local Database | `sqflite` (SQLite) |
| Target Platform | Android (ARM64) |
| Minimum Android | Android 5.0 (API 21) |

---

## Project Structure

```
nms_mobile/
├── lib/
│   ├── main.dart                    # App entry point, theme, routes
│   ├── models/                      # Data models (BeneficiaryModel, etc.)
│   ├── services/
│   │   ├── api_service.dart         # All API calls
│   │   ├── auth_provider.dart       # Auth state (Provider)
│   │   ├── local_db_service.dart    # SQLite operations
│   │   └── sync_service.dart        # Sync logic
│   ├── screens/
│   │   ├── login/
│   │   ├── dashboard/
│   │   ├── beneficiaries/           # List, detail, create, submit to admin
│   │   ├── assessments/             # Single form, OPT batch weighing
│   │   ├── reports/                 # OPT, DSP, MNS, summary reports
│   │   └── validation/              # Validation queue screen
│   └── widgets/                     # Shared UI components (StatusBadge, etc.)
├── android/                         # Android-specific configuration
├── pubspec.yaml                     # Dependencies
└── build/
    └── app/outputs/flutter-apk/    # Built APKs
```

---

## Build

### Requirements

- Flutter SDK 3.32.2 or higher
- Android SDK (API 21+)
- Android device or emulator

### Build Release APK

```bash
cd C:\xampp\htdocs\nms_mobile
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Install on Device

Transfer the APK to the Android device and install it directly. Enable **"Install from unknown sources"** (or "Install unknown apps") in device settings if prompted.

---

## API

All requests target `https://kabnms.duckdns.org/api`. Authentication uses a Bearer token stored via `flutter_secure_storage`.

**Key endpoints:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/api/auth/login` | Login |
| `GET` | `/api/beneficiaries` | List beneficiaries |
| `POST` | `/api/beneficiaries` | Create beneficiary |
| `POST` | `/api/assessments` | Record single assessment |
| `POST` | `/api/assessments/batch` | Submit OPT batch weighing |
| `GET` | `/api/sync` | Pull latest server data |
| `POST` | `/api/sync/push` | Push locally created records |
| `GET` | `/api/validation/queue` | Validation queue (midwife/admin) |
| `POST` | `/api/validation/validate` | Validate pending submissions |

### Changing the API URL

The base URL is defined in `lib/services/api_service.dart`:

```dart
static const String _baseUrl = 'https://kabnms.duckdns.org/api';
```

Update this value and rebuild the APK to target a different server (e.g., local development).

---

*NMS Mobile — September 2026*
