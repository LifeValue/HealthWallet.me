# GitHub Secrets Inventory

All secrets are configured in **Repository Settings > Secrets and variables > Actions**.

---

## SSH & Environment

### `SSH_PRIVATE_KEY`
**Purpose:** Authenticate with `git.techstackapps.com:2822` to fetch the private `fhir_ips_export` dependency.

**How to generate:**
```bash
ssh-keygen -t ed25519 -C "github-actions-healthwallet" -f healthwallet_deploy_key
# Add healthwallet_deploy_key.pub as a deploy key on the fhir-ips-export repo
```

**Value:** The raw private key content (including `-----BEGIN/END-----` headers). The `webfactory/ssh-agent` action handles it directly.

---

### `ENV_FILE_CONTENT`
**Purpose:** Provide environment variables for `envied` code generation at build time.

**How to generate:** Copy the entire contents of your local `.env` file.

**Value:** The full `.env` file content, e.g.:
```
API_KEY=your_api_key_here
BASE_URL=https://api.example.com
```

---

## Android Secrets

### `ANDROID_KEYSTORE_BASE64`
**Purpose:** Upload keystore for signing Android release builds.

**How to generate:**
```bash
base64 -i android/app/upload-keystore.jks
```

**Value:** Base64-encoded keystore file content.

---

### `ANDROID_KEY_ALIAS`
**Purpose:** Key alias within the keystore.

**Value:** Typically `upload` (must match what was used during `keytool -genkey`).

---

### `ANDROID_KEY_PASSWORD`
**Purpose:** Password for the key within the keystore.

**Value:** The password set during keystore generation.

---

### `ANDROID_STORE_PASSWORD`
**Purpose:** Password for the keystore file itself.

**Value:** The store password set during keystore generation.

---

### `PLAY_STORE_SERVICE_ACCOUNT_BASE64`
**Purpose:** Google Play API access for Fastlane `supply` uploads.

**How to generate:**
1. Create a service account in Google Cloud Console
2. Download the JSON key
3. Link the project in Google Play Console > API access
4. Grant the service account **Release manager** permissions
```bash
base64 -i service-account.json
```

**Value:** Base64-encoded JSON service account key.

---

## iOS Secrets

### `ASC_KEY_ID`
**Purpose:** App Store Connect API Key identifier.

**How to find:** App Store Connect > Users and Access > Integrations > App Store Connect API — shown next to the key name.

**Value:** A 10-character alphanumeric string (e.g., `ABC1234DEF`).

---

### `ASC_ISSUER_ID`
**Purpose:** App Store Connect API Issuer identifier.

**How to find:** Same page as the API key — shown at the top of the keys list.

**Value:** A UUID string (e.g., `12345678-abcd-1234-abcd-123456789012`).

---

### `ASC_KEY_CONTENT`
**Purpose:** App Store Connect API private key for authentication.

**How to generate:**
```bash
base64 -i AuthKey_XXXXXXXXXX.p8
```

**Value:** Base64-encoded `.p8` file content. **Note:** You can only download the `.p8` file once from ASC.

---

### `MATCH_GIT_URL`
**Purpose:** HTTPS URL to the private git repo where Match stores certificates and profiles.

**Value:** `https://github.com/YourOrg/ios-certificates.git` (or wherever your Match repo lives).

---

### `MATCH_PASSWORD`
**Purpose:** Encryption password for Match certificate storage.

**How to generate:** This is the password you chose (or was auto-generated) when running `fastlane match init` for the first time.

**Value:** The encryption passphrase string.

---

### `MATCH_GIT_PAT`
**Purpose:** GitHub Personal Access Token to clone the Match certificates repo on CI.

**How to generate:**
1. Go to GitHub > Settings > Developer settings > Personal access tokens > Fine-grained tokens
2. Create a token with **Repository access** to the certificates repo
3. Grant **Contents: Read** permission

**Value:** The token string (e.g., `github_pat_...`).

---

## Summary Table

| # | Secret | Used By |
|---|--------|---------|
| 1 | `SSH_PRIVATE_KEY` | All workflows |
| 2 | `ENV_FILE_CONTENT` | All workflows |
| 3 | `ANDROID_KEYSTORE_BASE64` | Android deploy |
| 4 | `ANDROID_KEY_ALIAS` | Android deploy |
| 5 | `ANDROID_KEY_PASSWORD` | Android deploy |
| 6 | `ANDROID_STORE_PASSWORD` | Android deploy |
| 7 | `PLAY_STORE_SERVICE_ACCOUNT_BASE64` | Android deploy |
| 8 | `ASC_KEY_ID` | iOS deploy |
| 9 | `ASC_ISSUER_ID` | iOS deploy |
| 10 | `ASC_KEY_CONTENT` | iOS deploy |
| 11 | `MATCH_GIT_URL` | iOS deploy |
| 12 | `MATCH_PASSWORD` | iOS deploy |
| 13 | `MATCH_GIT_PAT` | iOS deploy |
