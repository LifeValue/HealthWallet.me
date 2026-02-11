# Prerequisites Checklist

Complete these steps before the CI/CD pipeline can run successfully.

---

## 1. Android Upload Keystore

Generate a keystore for signing release builds:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Place the keystore at `android/app/upload-keystore.jks` (gitignored).

Create `android/key.properties`:
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=app/upload-keystore.jks
```

For CI, base64-encode the keystore:
```bash
base64 -i android/app/upload-keystore.jks | pbcopy
```
Store as `ANDROID_KEYSTORE_BASE64` GitHub Secret.

---

## 2. First Manual Google Play Upload

**Important:** Fastlane `supply` cannot upload to Google Play until at least one APK/AAB has been uploaded manually.

1. Build a release AAB: `flutter build appbundle --release`
2. Go to [Google Play Console](https://play.google.com/console)
3. Create the app if it doesn't exist
4. Navigate to **Release > Testing > Internal testing**
5. Create a new release and upload the AAB manually
6. Complete the release

---

## 3. Google Play Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create a project linked to your Play Console
3. Navigate to **IAM & Admin > Service Accounts**
4. Create a service account with a descriptive name (e.g., `fastlane-deploy`)
5. Create a JSON key and download it
6. Go to [Google Play Console](https://play.google.com/console) > **Settings > API access**
7. Link the Google Cloud project
8. Grant the service account **Release manager** permissions for the app

For local use: save as `android/fastlane/service-account.json` (gitignored).
For CI: base64-encode and store as `PLAY_STORE_SERVICE_ACCOUNT_BASE64`:
```bash
base64 -i android/fastlane/service-account.json | pbcopy
```

---

## 4. App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com) > **Users and Access > Integrations > App Store Connect API**
2. Click **Generate API Key**
3. Name: `Fastlane CI` (or similar)
4. Access: **App Manager** role
5. Download the `.p8` file (you can only download it once!)
6. Note the **Key ID** and **Issuer ID**

Store these as GitHub Secrets:
- `ASC_KEY_ID` — the Key ID
- `ASC_ISSUER_ID` — the Issuer ID
- `ASC_KEY_CONTENT` — base64-encoded `.p8` file content:
  ```bash
  base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
  ```

---

## 5. Fastlane Match Setup

Match stores iOS certificates and provisioning profiles in a private git repo.

### Initial setup (one-time):

```bash
cd ios
bundle exec fastlane match init
```

Choose **git** storage and provide the certificates repo URL.

### Generate certificates:

```bash
# App Store certificates for both bundle IDs
bundle exec fastlane match appstore \
  --app_identifier "com.techstackapps.healthwallet,com.techstackapps.healthwallet.Share-Extension"
```

This creates and stores certificates + profiles in the Match repo.

### For CI:
- `MATCH_GIT_URL` — HTTPS URL to the certificates repo
- `MATCH_PASSWORD` — the encryption password chosen during `match init`
- `MATCH_GIT_PAT` — a GitHub Personal Access Token with `repo` scope for the certificates repo

---

## 6. SSH Key for Private Dependency

The `fhir_ips_export` package is fetched via SSH from `git.techstackapps.com:2822`.

1. Generate an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-healthwallet" -f healthwallet_deploy_key
   ```
2. Add the **public** key as a deploy key on the `fhir-ips-export` repo
3. Base64-encode the **private** key and store as `SSH_PRIVATE_KEY` GitHub Secret:
   ```bash
   base64 -i healthwallet_deploy_key | pbcopy
   ```

   Or store the raw private key content directly (the workflow uses `webfactory/ssh-agent`).

---

## 7. Environment File (.env)

The app uses `envied` for compile-time environment variables. The `.env` file content must be available at build time.

1. Copy your local `.env` file content
2. Store the entire content as `ENV_FILE_CONTENT` GitHub Secret

---

## 8. GitHub Secrets Inventory

All secrets must be configured in **Repository Settings > Secrets and variables > Actions**.

| Secret Name | Description |
|-------------|-------------|
| `SSH_PRIVATE_KEY` | SSH private key for `git.techstackapps.com:2822` |
| `ENV_FILE_CONTENT` | Contents of the `.env` file for envied |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore |
| `ANDROID_KEY_ALIAS` | Keystore key alias (e.g., `upload`) |
| `ANDROID_KEY_PASSWORD` | Keystore key password |
| `ANDROID_STORE_PASSWORD` | Keystore store password |
| `PLAY_STORE_SERVICE_ACCOUNT_BASE64` | Base64-encoded Google Play service account JSON |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_CONTENT` | Base64-encoded ASC API key (.p8) |
| `MATCH_GIT_URL` | HTTPS URL to Match certificates repo |
| `MATCH_PASSWORD` | Match encryption password |
| `MATCH_GIT_PAT` | GitHub PAT with repo access to certificates repo |

**Total: 13 secrets**

See `references/secrets-inventory.md` for detailed generation instructions for each secret.
