# GitHub Secrets Inventory

All secrets are configured in **Repository Settings > Secrets and variables > Actions**.

---

## SSH & Environment

### `SSH_PRIVATE_KEY`
**Purpose:** Authenticate with `git.techstackapps.com:2822` (private `fhir_ips_export` dependency) and `github.com` (Match certs repo).

**How to generate:**
```bash
ssh-keygen -t ed25519 -C "github-actions-healthwallet" -f healthwallet_deploy_key
# Add healthwallet_deploy_key.pub as a deploy key on the fhir-ips-export repo
# Also add to the ciagent-techstackapps GitHub account for Match certs access
```

**Value:** The raw private key content (including `-----BEGIN/END-----` headers). The `webfactory/ssh-agent` action handles it directly.

---

### `ENV_FILE_CONTENT`
**Purpose:** Provide environment variables for `envied` code generation at build time (CI workflow only).

**How to generate:** Copy the entire contents of your local `.env` file.

**Value:** The full `.env` file content.

**Note:** This is only used by the CI workflow (`ci.yml`). The iOS deploy workflow does not need it since FVM and tools are pre-installed on the Mac Mini.

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

**Value:** A 10-character alphanumeric string (e.g., `BUU37V3MZ6`).

---

### `ASC_ISSUER_ID`
**Purpose:** App Store Connect API Issuer identifier.

**How to find:** Same page as the API key — shown at the top of the keys list.

**Value:** A UUID string (e.g., `2284b5ac-4c6d-4a7c-9f1f-53c61680e1e8`).

---

### `ASC_KEY_CONTENT`
**Purpose:** App Store Connect API private key for authentication.

**How to generate:**
```bash
cat AuthKey_XXXXXXXXXX.p8
```

**Value:** The **raw** `.p8` file content (NOT base64-encoded). It should look like:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEH...
-----END PRIVATE KEY-----
```

**Note:** The workflow writes this to a file at build time. You can only download the `.p8` file once from ASC.

---

### `MATCH_GIT_URL`
**Purpose:** SSH URL to the private git repo where Match stores certificates and profiles.

**Value:** `git@github.com:ciagent-techstackapps/ios-certs.git`

**Note:** Uses SSH authentication via the same `SSH_PRIVATE_KEY` loaded by `webfactory/ssh-agent`. No separate token needed.

---

### `MATCH_PASSWORD`
**Purpose:** Encryption password for Match certificate storage.

**How to generate:** This is the password used to encrypt/decrypt certificates in the Match repo. To change it, use the re-encryption script (decrypt all files with old password, re-encrypt with new password, push to certs repo).

**Value:** The encryption passphrase string.

---

## Summary Table

| # | Secret | Used By | Format |
|---|--------|---------|--------|
| 1 | `SSH_PRIVATE_KEY` | All workflows | Raw private key |
| 2 | `ENV_FILE_CONTENT` | CI workflow | Raw .env content |
| 3 | `ANDROID_KEYSTORE_BASE64` | Android deploy | Base64 |
| 4 | `ANDROID_KEY_ALIAS` | Android deploy | Plain text |
| 5 | `ANDROID_KEY_PASSWORD` | Android deploy | Plain text |
| 6 | `ANDROID_STORE_PASSWORD` | Android deploy | Plain text |
| 7 | `PLAY_STORE_SERVICE_ACCOUNT_BASE64` | Android deploy | Base64 |
| 8 | `ASC_KEY_ID` | iOS deploy | Plain text |
| 9 | `ASC_ISSUER_ID` | iOS deploy | Plain text |
| 10 | `ASC_KEY_CONTENT` | iOS deploy | Raw .p8 content |
| 11 | `MATCH_GIT_URL` | iOS deploy | SSH URL |
| 12 | `MATCH_PASSWORD` | iOS deploy | Plain text |

**Total: 12 secrets** (previously 13 — `MATCH_GIT_PAT` removed since SSH handles auth)
