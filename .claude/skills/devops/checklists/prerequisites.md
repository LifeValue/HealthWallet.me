# Prerequisites Checklist

Complete these steps before the CI/CD pipeline can run successfully.

---

## 1. Self-Hosted Runner (Mac Mini) — iOS Builds

The iOS deploy workflow runs on a self-hosted macOS runner (Mac Mini).

### Runner setup:
1. Download and configure the GitHub Actions runner:
   ```bash
   mkdir actions-runner && cd actions-runner
   # Download latest runner package from GitHub
   ./config.sh --url https://github.com/LifeValue/HealthWallet.me --token <REGISTRATION_TOKEN>
   ```
2. Install as a launchd service:
   ```bash
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```
3. Configure runner environment (`actions-runner/.env`):
   ```
   PATH=/Users/ciagent/.rbenv/shims:/Users/ciagent/.rbenv/bin:/opt/homebrew/bin:...
   RBENV_ROOT=/Users/ciagent/.rbenv
   GEM_HOME=/Users/ciagent/.gem
   LANG=en_US.UTF-8
   ```

### Required tools on the Mac Mini:
- **FVM** with Flutter 3.32.4 pinned (`.fvmrc` in project root)
- **Ruby** 3.0+ via rbenv
- **CocoaPods** 1.16.2+
- **Xcode** with iOS SDK
- **Bundler** for Fastlane gem management

---

## 2. Android Upload Keystore

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

## 3. First Manual Google Play Upload

**Important:** Fastlane `supply` cannot upload to Google Play until at least one APK/AAB has been uploaded manually.

1. Build a release AAB: `fvm flutter build appbundle --release`
2. Go to [Google Play Console](https://play.google.com/console)
3. Create the app if it doesn't exist
4. Navigate to **Release > Testing > Internal testing**
5. Create a new release and upload the AAB manually
6. Complete the release

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
- `ASC_KEY_CONTENT` — the **raw** `.p8` file content (NOT base64):
  ```bash
  cat AuthKey_XXXXXXXXXX.p8 | pbcopy
  ```

For local dev, place the `.p8` file at `ios/fastlane/private_keys/AuthKey_XXXXXXXXXX.p8` and set `ASC_KEY_PATH` in `ios/fastlane/.env`.

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
- `MATCH_GIT_URL` — SSH URL to the certificates repo: `git@github.com:ciagent-techstackapps/ios-certs.git`
- `MATCH_PASSWORD` — the encryption password chosen during `match init`
- Authentication handled by `SSH_PRIVATE_KEY` via `webfactory/ssh-agent` (no separate PAT needed)

### Changing the Match password:
```ruby
# Run from ios/ directory via: bundle exec ruby script.rb
require "match"
old_pass = "<old_password>"
new_pass = "<new_password>"
files = Dir.glob("/path/to/certs-repo/**/*.{p12,cer,mobileprovision}")
files.each do |f|
  data = File.binread(f)
  enc = Match::Encryption::MatchDataEncryption.new
  decrypted = enc.decrypt(base64encoded_encrypted: data, password: old_pass)
  encrypted = enc.encrypt(data: decrypted, password: new_pass)
  File.binwrite(f, encrypted)
end
```
Then commit and push the certs repo, and update the `MATCH_PASSWORD` GitHub Secret + local `.env`.

---

## 6. SSH Key for Private Dependency

The `fhir_ips_export` package is fetched via SSH from `git.techstackapps.com:2822`.

1. Generate an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-healthwallet" -f healthwallet_deploy_key
   ```
2. Add the **public** key as a deploy key on the `fhir-ips-export` repo
3. Store the raw **private** key content as the `SSH_PRIVATE_KEY` GitHub Secret

The same SSH key must also have access to the `ios-certs` GitHub repo for Match to clone certificates.

---

## 7. Environment File (.env)

The app uses `envied` for compile-time environment variables. The `.env` file content must be available at build time.

1. Copy your local `.env` file content
2. Store the entire content as `ENV_FILE_CONTENT` GitHub Secret

**Note:** This is only used by the CI workflow (`ci.yml`). The iOS deploy workflow on the Mac Mini does not use this secret.

---

## 8. GitHub Secrets Summary

All secrets must be configured in **Repository Settings > Secrets and variables > Actions**.

| Secret Name | Description | Format |
|-------------|-------------|--------|
| `SSH_PRIVATE_KEY` | SSH private key for git.techstackapps.com + github.com | Raw key |
| `ENV_FILE_CONTENT` | Contents of the `.env` file for envied | Raw text |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore | Base64 |
| `ANDROID_KEY_ALIAS` | Keystore key alias (e.g., `upload`) | Plain text |
| `ANDROID_KEY_PASSWORD` | Keystore key password | Plain text |
| `ANDROID_STORE_PASSWORD` | Keystore store password | Plain text |
| `PLAY_STORE_SERVICE_ACCOUNT_BASE64` | Base64-encoded Google Play service account JSON | Base64 |
| `ASC_KEY_ID` | App Store Connect API Key ID | Plain text |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID | Plain text |
| `ASC_KEY_CONTENT` | Raw ASC API key (.p8 content) | Raw text |
| `MATCH_GIT_URL` | SSH URL to Match certificates repo | SSH URL |
| `MATCH_PASSWORD` | Match encryption password | Plain text |

**Total: 12 secrets**

See `references/secrets-inventory.md` for detailed generation instructions for each secret.
