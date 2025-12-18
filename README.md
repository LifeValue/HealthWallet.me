
<div align="center">

<img src="assets/readme/icon_and_healthwallet.svg" alt="HealthWallet.me Logo" width="600">

<div style="display: flex; align-items: center; justify-content: center; gap: 40px; margin: 20px 0; flex-wrap: wrap;">
  <div style="flex: 1; min-width: 280px; max-width: 500px; text-align: left;">
    <h3 style="font-size: clamp(1.5rem, 4vw, 2.5rem); margin-bottom: 16px; text-align: left;">One app. All your medical records, safe and ready.</h3>
    <p style="font-size: clamp(1rem, 2.5vw, 1.2rem); line-height: 1.6; margin-bottom: 20px; text-align: left;"><strong>No more forms. No more repeating yourself.</strong> With HealthWallet.me, your health info is always safe and easy to share.</p>
    <div align="center" style="margin-top: 20px;">
      <a href="https://apps.apple.com/app/healthwallet-me/id6748325588">
        <img src="assets/readme/apple_store.svg" alt="Download for iOS" width="200">
      </a>
      <a href="https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet">
        <img src="assets/readme/playstore.svg" alt="Download for Android" width="200">
      </a>
    </div>
  </div>
  <div style="flex: 1; min-width: 280px; text-align: center; display: flex; justify-content: center; align-items: center;">
    <img src="assets/readme/app.gif" alt="HealthWallet.me App Preview" style="border-radius: 50px; max-width: 100%; width: clamp(250px, 50vw, 400px); height: auto;">
  </div>
</div>
</div>

<p align="center">
  <a href="changelog.md">
    <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-blue" height="24">
  </a>
  <a href="https://github.com/techstackapps">
    <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" height="24"/>
  </a>
  <a href="https://www.youtube.com/@TechStackAppsCo">
    <img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" height="24"/>
  </a>
  <a href="https://www.facebook.com/techstackapps/">
    <img src="https://img.shields.io/badge/Facebook-1877F2?style=for-the-badge&logo=facebook&logoColor=white" height="24"/>
  </a>
  <a href="https://www.linkedin.com/company/techstackapps/">
    <img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" height="24"/>
  </a>
  <a href="https://x.com/techstackapps">
    <img src="https://img.shields.io/twitter/follow/techstackapps" alt="Follow @techstackapps" height="24"/>
  </a>
</p>

## 📋 About

**HealthWallet.me** is a **patient-controlled**, **community-driven** health record platform that consolidates your medical data from multiple providers into one accessible app.

### Key Benefits
- **Patient-Centered** • **Privacy-First** • **FHIR Compliant** • **Offline Capable**

## ✨ Features

- 🔐 **Login** - Biometric authentication
- 🏥 **Health Records Management** - Comprehensive view of medical history
- 📊 **Dashboard** - Centralized health information overview
- 🌐 **Offline Support** - Access critical data without internet
- 🌍 **Global Access** - Works worldwide with International Patient Summary


## 🚀 Getting Started

### 📱 Download the Mobile App
Get HealthWallet.me from your app store:
- **[iOS App Store](https://apps.apple.com/app/healthwallet-me/id6748325588)** 
- **[Google Play Store](https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet)**

### 🏠 Self-Hosted Backend ([FastenHealth](https://github.com/fastenhealth/fasten-onprem))
The backend server aggregates medical records from healthcare providers and syncs them with your mobile app.

**Prerequisites:**
- Docker installed on your computer ([Install Docker](https://docs.docker.com/get-docker/))

**Quick Setup:**

1. **Download and run Fasten application**
   ```bash
   curl https://raw.githubusercontent.com/fastenhealth/fasten-onprem/refs/heads/main/docker-compose-prod.yml -o docker-compose.yml && \
   curl https://raw.githubusercontent.com/fastenhealth/fasten-onprem/refs/heads/main/set_env.sh -o set_env.sh && \
   chmod +x ./set_env.sh && \
   ./set_env.sh && \
   docker compose up -d
   ```

   **Commands Breakdown**
   - Downloads necessary files (**docker-compose.yml** and **set_env.sh**)
   - The environment script automatically assigns your local IP so **Fasten** can be available on **your local network**
   - Starts the Fasten application (**docker-compose up -d**)

2. **Access Fasten:**
   Open your browser and go to `http://localhost:9090`

3. **Create your account:**
   - Click "Sign Up" on the login page
   - Choose a username and password (e.g., `testuser` / `testuser`)

### 🔄 Connecting Everything Together
1. **Generate access token** in your FastenHealth dashboard
2. **Scan** the generated **QR code**
3. **Sync your health records** automatically

<div align="center">
  <img src="assets/readme/generate_qr_code.gif" alt="Access Token Setup Demo" style="border-radius: 8px; max-width: 100%; width: clamp(300px, 60vw, 600px); height: auto;">
</div>

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio or VS Code with Flutter extensions

### Quick Start
1. **Install FVM (Flutter Version Management)**
   ```bash
   dart pub global activate fvm
   fvm install
   fvm use
   ```

2. **Install development dependencies**
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run tests**
   ```bash
   flutter test
   ```

## 🏗️ Architecture

### Tech Stack
- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **State Management**: BLoC (flutter_bloc)
- **Dependency Injection**: GetIt + Injectable
- **Navigation**: Auto Route
- **Local Storage**: Drift (SQLite)
- **Network**: Dio
- **Code Generation**: Freezed, JSON Serializable
- **Localization**: Flutter Intl

<details>
  <summary><strong>Project Structure</strong></summary>

```
lib/
├── app/                    # App configuration and initialization
├── core/                   # Core utilities, constants, and shared code
│   ├── constants/         # App constants and configurations
│   ├── errors/            # Error handling and custom exceptions
│   ├── network/           # Network configuration and interceptors
│   ├── storage/           # Local storage implementations
│   └── utils/             # Utility functions and helpers
├── features/              # Feature modules
│   ├── auth/              # Authentication feature
│   ├── dashboard/         # Main dashboard
│   ├── health_records/    # Health records management
│   ├── sync/              # Data synchronization
│   └── profile/           # User profile management
└── gen/                   # Generated code (assets, routes, etc.)
```
</details>

<details>
  <summary><strong>GIT Branches</strong></summary>

| Branch      | Purpose                 | CI/CD Action                 |
| ----------- | ----------------------- | ---------------------------- |
| `master`    | Production              | Deploy to production         |
| `dev/*`     | Development             | For development purposes     |
| `feature/*` | New features            | Run tests only               |
| `fix/*`     | Bug fixes               | Run tests only               |
| `release/*` | Release stabilization   | Full test + optional staging |
| `hotfix/*`  | Urgent production fixes | Run tests                    |

</details>

## 🎯 Roadmap

### Completed Features ✅
- Basic health record management
- Authentication and security
- Cross-platform support
- Document scanning & OCR
- File import & in-app viewing

### In Progress 🚧
- QR code sharing (SMART Health Cards)
- Proximity-based communication (Airdrop)
- Desktop app backup system(CRDT) and FHIR processing

### Future Plans 📋
- Responsive UI
- Wearable & health provider integration
- AI health insights
- AI Note taking prescription
- Family management


## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](CONTRIBUTING.md) for:
- Code style and standards
- Pull request process
- Development setup

**Quick Start:**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 👥 Authors

- **Alex Szilagyi** - Initial Development - [@alexszilagyi](https://github.com/alexszilagyi)
- **Jason Kulatunga** - Co-Author - [@AnalogJ](https://github.com/AnalogJ)

# Licenses

[![GitHub license](https://img.shields.io/github/license/fastenhealth/fasten-onprem?style=flat-square)](https://github.com/TechStackApps/HealthWallet.me/blob/master/LICENSE.md)

## 🙏 Acknowledgments 
- **FHIR Community** - For the healthcare interoperability standards
- **Open Source Contributors** - For the libraries and tools that make this possible
- **Healthcare Providers** - For feedback and requirements

## ⭐ Rate Our App

If you find **HealthWallet.me** helpful, please consider rating us in the app stores:

<div align="center">

[![Rate on iOS App Store](https://img.shields.io/badge/Rate_on_iOS_App_Store-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/healthwallet-me/id6748325588)
[![Rate on Google Play Store](https://img.shields.io/badge/Rate_on_Google_Play_Store-3DDC84?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.techstackapps.healthwallet)

</div>

Your ratings help us improve and reach more people who need better health record management!

## 🤝🏼 Sponsorship

**HealthWallet.me** is an open-source project dedicated to improving healthcare accessibility and patient data management.

### Corporate Sponsorship

We'd like to thank the following Corporate Sponsors:

<div align="center" style="margin: 20px 0;">

<a href="https://lifevalue.com/" target="_blank">
<img src="assets/readme/lifevalue.svg" alt="LifeValue" width="120" style="margin: 0 20px;">
</a>
<a href="https://www.fastenhealth.com/" target="_blank">
<img src="assets/readme/fasten.svg" alt="Fasten" width="120" style="margin: 0 20px;">
</a>

</div>


Interested in **corporate sponsorship** or **partnership opportunities**? We offer:

- 🏢 **Enterprise features** and custom integrations
- 📊 **White-label solutions** for healthcare organizations
- 🤝 **Strategic partnerships** in the healthcare technology space
- 📈 **Priority support** and dedicated resources

[**Contact us**](https://lifevalue.com/company/contact)

---

**Thank you for supporting open-source healthcare innovation!** 🙏


