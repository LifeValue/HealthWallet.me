<div align="center">

<img src="assets/readme/icon_and_healthwallet.svg" alt="HealthWallet.me Logo" width="500">

### Your medical records. On your phone. Under your control.

**Open-source, offline-first health record manager with on-device AI.**
Connects to **52,000+ US healthcare providers** via FHIR R4.
Scans paper documents with a local LLM — **your data never leaves your device.**

[![iOS App Store](https://img.shields.io/badge/App_Store-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/healthwallet-me/id6748325588)
[![Google Play](https://img.shields.io/badge/Google_Play-3DDC84?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet)

<br>

[![CI](https://github.com/LifeValue/HealthWallet.me/actions/workflows/ci.yml/badge.svg)](https://github.com/LifeValue/HealthWallet.me/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE.md)
[![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)](https://flutter.dev)
[![FHIR R4](https://img.shields.io/badge/FHIR-R4-E44D26)](https://hl7.org/fhir/R4/)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey)]()

<br>

<img src="assets/readme/app.gif" alt="HealthWallet.me App Preview" width="300" style="border-radius: 24px;">

</div>

---

## Why HealthWallet?

Every time you visit a new doctor, you fill out the same forms. Your records are scattered across hospital portals, paper files, and USB drives. **You deserve better.**

HealthWallet aggregates your complete medical history from thousands of healthcare providers into a single, encrypted, offline-capable app. When you need to share records — with a new specialist, at an ER, or while traveling — everything is right there on your phone.

**What makes it different:**

- **On-device AI** — Scan paper documents and the built-in LLM (Qwen / MedGemma via llama.cpp) extracts structured FHIR resources locally. No cloud. No uploads. No data leaks.
- **52,000+ providers** — Connect to US healthcare systems through FHIR R4 APIs via a self-hosted [FastenHealth](https://github.com/fastenhealth/fasten-onprem) backend.
- **Truly offline** — Full access to all your records without internet. Sync when you're ready.
- **Proximity sharing** — Share records face-to-face via AirDrop-style transfer. No intermediary server.
- **International Patient Summary (IPS)** — Export a globally recognized health summary for travel or emergencies.
- **Emergency wallet card** — Add your critical health info to Apple Wallet or Google Wallet.

---

## Features

| | Feature | Description |
|---|---|---|
| **AI Scan** | On-device document intelligence | Photograph or import medical documents; the local LLM extracts patient info, encounters, medications, allergies, and lab results into structured FHIR records |
| **Aggregate** | 52K+ provider connectivity | Sync records from hospitals, clinics, and labs through FHIR R4 APIs |
| **Organize** | Unified health timeline | Browse all records — conditions, medications, immunizations, lab results, clinical notes — in one place |
| **Share** | Proximity-based sharing | Transfer records device-to-device without an internet connection |
| **Export** | IPS & Wallet passes | Generate an International Patient Summary PDF or add emergency info to Apple/Google Wallet |
| **Secure** | Biometric + offline-first | Face ID / fingerprint lock, local SQLite storage, no mandatory cloud dependency |

---

## Quick Start

### Install the App

<div align="center">

[![Download on the App Store](assets/readme/apple_store.svg)](https://apps.apple.com/app/healthwallet-me/id6748325588)
[![Get it on Google Play](assets/readme/playstore.svg)](https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet)

</div>

### Set Up Your Self-Hosted Backend

The backend ([FastenHealth](https://github.com/fastenhealth/fasten-onprem)) aggregates medical records from healthcare providers and syncs them to your phone.

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/)

```bash
curl https://raw.githubusercontent.com/fastenhealth/fasten-onprem/refs/heads/main/docker-compose-prod.yml -o docker-compose.yml && \
curl https://raw.githubusercontent.com/fastenhealth/fasten-onprem/refs/heads/main/set_env.sh -o set_env.sh && \
chmod +x ./set_env.sh && \
./set_env.sh && \
docker compose up -d
```

Then open `http://localhost:9090`, create an account, and you're ready.

### Connect the App to Your Backend

1. Generate an access token in your FastenHealth dashboard
2. Scan the QR code with HealthWallet
3. Your records sync automatically

<div align="center">
  <img src="assets/readme/generate_qr_code.gif" alt="QR Code Sync Demo" width="500" style="border-radius: 8px;">
</div>

---

## On-Device AI — How It Works

HealthWallet runs a quantized LLM directly on your phone using [llama.cpp](https://github.com/ggerganov/llama.cpp). No API calls, no cloud processing — the model runs locally with Metal acceleration on iOS and CPU inference on Android.

### Available Models

| Model | Size | Best For |
|-------|------|----------|
| **Standard** ([Qwen3-VL-2B](https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF)) | ~1.1 GB | Fast, lightweight, works on most devices |
| **Advanced** ([MedGemma-4B](https://huggingface.co/SandLogicTechnologies/MedGemma-4B-IT-GGUF)) | ~2.5 GB | Higher accuracy for complex medical documents |

**Deep Scan** (optional vision projector) lets the AI read directly from photos instead of OCR text. One-time download: ~445 MB (Standard) or ~851 MB (Advanced).

<details>
<summary><strong>Device Requirements</strong></summary>

| Device | RAM | Capability |
|--------|-----|------------|
| **iPhone Pro/Pro Max** | 6 GB+ | Full scanning (both models) |
| **iPhone 13/14/15** | 4-6 GB | Standard model only |
| **Android** | 12 GB+ | Full scanning (both models) |
| **Android** | 10-11 GB | Standard model only |

</details>

---

## Architecture

Built with **Clean Architecture** and feature-based modules in **Flutter/Dart**.

| Layer | Technology |
|-------|-----------|
| **State Management** | BLoC (flutter_bloc) |
| **Dependency Injection** | GetIt + Injectable |
| **Navigation** | AutoRoute (type-safe) |
| **Local Database** | Drift (SQLite) |
| **Networking** | Dio |
| **Code Generation** | Freezed, JSON Serializable |
| **Healthcare Standard** | FHIR R4 |
| **On-Device AI** | llama.cpp via llamadart |
| **Localization** | Flutter Intl (EN, ES, DE) |

<details>
<summary><strong>Project Structure</strong></summary>

```
lib/
├── app/                    # App configuration and initialization
├── core/                   # Shared infrastructure
│   ├── config/            # App configuration and constants
│   ├── data/              # Local database (Drift/SQLite)
│   ├── di/                # Dependency injection setup
│   ├── l10n/              # Localization
│   ├── navigation/        # Router and route definitions
│   ├── services/          # Shared services
│   ├── theme/             # Colors, text styles, spacing
│   ├── utils/             # Utility functions
│   └── widgets/           # Reusable UI components
├── features/
│   ├── dashboard/         # Main tab navigation
│   ├── home/              # Health overview with reorderable grid
│   ├── records/           # Health records management + IPS export
│   ├── scan/              # AI document scanning (llama.cpp)
│   ├── sync/              # QR-based backend sync
│   ├── share_records/     # Proximity sharing (AirDrop-style)
│   ├── wallet_pass/       # Apple/Google Wallet emergency card
│   ├── user/              # Profile & patient management
│   ├── onboarding/        # First-launch flow
│   └── notifications/     # In-app notifications
└── gen/                   # Generated code
```

</details>

<details>
<summary><strong>Branch Strategy</strong></summary>

| Branch | Purpose | CI/CD |
|--------|---------|-------|
| `master` | Production | Deploy to App Store + Play Store |
| `develop` | Staging | Deploy to internal tracks |
| `feature/*` | New features | Analyze + test |
| `fix/*` | Bug fixes | Analyze + test |
| `release/*` | Release stabilization | Full test suite |
| `hotfix/*` | Urgent fixes | Analyze + test |

</details>

---

## Development Setup

**Prerequisites:** Flutter 3.38+ (managed via [FVM](https://fvm.app/))

```bash
dart pub global activate fvm
fvm install && fvm use
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

---

## Roadmap

**Shipped:** Health record aggregation, biometric auth, cross-platform (iOS + Android), file import with in-app viewing, AI document scanning with on-device LLM

**In Progress:** Apple/Google Wallet IPS card, proximity sharing (AirDrop), desktop companion app with backup sync

**Planned:** Responsive UI, wearable integration, AI health insights, prescription note-taking, family management, SMART Health Cards (QR sharing)

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Fork → Branch → Code → PR
git checkout -b feature/your-feature
# Make changes
git push origin feature/your-feature
# Open a pull request
```

---

## Sponsors

<div align="center">

<a href="https://lifevalue.com/"><img src="assets/readme/lifevalue.svg" alt="LifeValue" width="120"></a>
&nbsp;&nbsp;&nbsp;&nbsp;
<a href="https://www.fastenhealth.com/"><img src="assets/readme/fasten.svg" alt="FastenHealth" width="120"></a>

</div>

Interested in sponsorship or partnerships? [Contact us](https://lifevalue.com/company/contact)

---

## Authors

- **Alex Szilagyi** — [@alexszilagyi](https://github.com/alexszilagyi)
- **Jason Kulatunga** — [@AnalogJ](https://github.com/AnalogJ)

## License

[GPL-3.0](LICENSE.md) — Copyright 2025 SC TECH STACK APPS SRL

---

<div align="center">

**If HealthWallet helps you, give it a star** — it helps others find it too.

[![Rate on iOS](https://img.shields.io/badge/Rate_on_App_Store-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/healthwallet-me/id6748325588)
[![Rate on Google Play](https://img.shields.io/badge/Rate_on_Google_Play-3DDC84?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet)

</div>
