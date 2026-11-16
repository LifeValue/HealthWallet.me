---
title: 'Publish desktop downloads to our own open-source CDN'
type: 'feature'
created: '2026-11-16'
status: 'done'
route: 'dispatch'
baseline_commit: 'cf2e2a45dd1e13de844f700ee6e83c80c237a29f'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The website needs download buttons for macOS, Windows and Linux that download the installer from our own servers, like Docker Desktop. The pipeline only puts desktop builds on a GitLab Release, and macOS has no direct-download build at all.

**Approach:** A new manual `macos:direct` job builds a notarized DMG. A new manual `cdn:publish` job copies one pipeline's desktop packages into an S3-compatible bucket (RustFS) and writes a `versions.json` that the website reads to build its buttons.

## Boundaries & Constraints

**Always:**
- Decisions taken with the user (2026-11-16):
  - Open-source stack only: RustFS for storage, rclone to upload, an optional nginx cache in front. No hosted CDN and no Redis.
  - No `latest` files or folders. Every file carries its version in its name and folder, and nothing already uploaded is overwritten. The only file that changes is `<channel>/versions.json`, which names the current version.
  - `master` publishes to `stable/`. `develop` and `release/*` publish to `beta/`.
  - The CDN carries the Windows portable zip, the Linux .deb and .tar.gz, and the macOS DMG. No Android APK (the website links to Google Play) and no Windows MSIX (Store-only).
  - Publishing doesn't wait for macOS. `cdn:publish` includes the DMG when `macos:direct` already uploaded it for that release tag, and otherwise publishes without it.
  - `macos:direct` stops with a clear message when the Developer ID Application certificate for team N668J5X92P is missing from the keychain.
- Every deploy job is manual, on `develop`, `release/*` and `master` only, and runs after all checks pass (`*all_checks`, `*on_deploy_branches`).
- Storage settings come from protected CI/CD variables (`CDN_S3_ENDPOINT`, `CDN_S3_REGION` (optional), `CDN_BUCKET`, `CDN_ACCESS_KEY_ID`, `CDN_SECRET_ACCESS_KEY`, `CDN_PUBLIC_URL`). The job lists any missing ones and stops.
- Images and tools are pinned to exact versions (`rclone/rclone:1.75.2`).

**Never:** Change the TestFlight, Play or Shorebird lanes. Edit `.github/workflows/`. Add any CDN server config to the repo beyond documentation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Full publish | Windows, Linux and macOS packages in the registry for tag `v1.3.0` on master | `stable/v1.3.0/` holds 4 files + `SHA256SUMS`; `stable/versions.json` lists all three platforms | N/A |
| No macOS | Only Windows and Linux packages | Published; `versions.json` has no `macos` key | Logs that macOS was skipped |
| Windows or Linux missing | Registry returns 404 | Nothing uploaded | Fails naming the missing file |
| Variables missing | `CDN_*` unset | Nothing uploaded | Fails listing the missing variables |
| Re-run same tag | Files already in the bucket | Same objects re-uploaded with identical content, `versions.json` rewritten | N/A |
| No certificate | `macos:direct` on Mac mini without Developer ID | No build | Fails with how to create and import it |

</frozen-after-approval>

## Code Map

- `.gitlab-ci.yml` -- header comment lists deploys and protected variables; `.macmini` (secrets, codegen, cleanup), `*apple_signing`, `*ios_cocoapods`, `*pod_install`, `macos:testflight` (pattern for the new macOS job), `windows:release` (PowerShell release; keep, only add a macOS line to its release description), `linux:release` (bash release upload, to be replaced by the shared script), `*on_deploy_branches`, `*all_checks`.
- `macos/fastlane/Fastfile` -- `asc_xcargs`, `get_version_name`, `get_asc_api_key`, `fix_framework_symlinks`, lane `beta` (pattern for the new lane). Team ID from `CredentialsManager::AppfileConfig`.
- `macos/Runner/Release.entitlements` -- sandboxed; no hardened runtime in the project (`ENABLE_HARDENED_RUNTIME` absent), so turn it on via xcargs for the direct build only.
- `scripts/package_linux.sh` -- names: `HealthWallet-Linux-v<version>-<amd64|arm64>.{deb,tar.gz}`. `scripts/build_windows.ps1` -- `HealthWallet-Windows-v<version>-portable.zip`.
- Release tag rule (keep identical everywhere): `master` → `v<version>`, else `v<version>-dev.<CI_PIPELINE_IID>`; version from `pubspec.yaml` without build number.
- Shell style: shfmt (2 spaces, `.editorconfig`) + shellcheck run on `scripts/`.
- `_bmad-output/planning-artifacts/architecture.md` -- `## CI/CD` section.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/release_tag.sh` -- print the release tag -- one shared rule for bash jobs.
- [x] `scripts/gitlab_release.sh` -- `<package> <dir>`: upload each file to the generic package registry, create the release (form-encoded, 201/409 OK, else fail with GitLab's body), link the files; release description lists macOS, Windows and Linux. Needs only curl -- runs on the Linux image and the Mac mini.
- [x] `macos/fastlane/Fastfile` -- lane `direct`: certificate check, Flutter build (build number from `CI_PIPELINE_IID`, else 1), archive with hardened runtime, symlink fix, `developer-id` export, DMG with an Applications link at `build/macos/packages/HealthWallet-macOS-v<version>.dmg`, sign it, notarize and staple.
- [x] `test/scripts/release_scripts_test.dart` -- `@TestOn('linux || mac-os')`; run `release_tag.sh` and `gitlab_release.sh` against a local `HttpServer` faking GitLab: tag per branch, uploads, 201 and 409 accepted, other status fails with the body, links posted -- pins the release path Linux now shares.
- [x] `scripts/publish_cdn.sh` -- fetch the packages for the tag from the registry, upload `<channel>/<tag>/<file>` (long immutable cache, `Content-Disposition: attachment`), then `SHA256SUMS`, then `<channel>/versions.json` last (`Cache-Control: no-cache`).
- [x] `test/scripts/publish_cdn_test.dart` -- `@TestOn('linux || mac-os')`; fake registry (`HttpServer`) + fake `rclone` first on `PATH` (copies into a temp "bucket", records headers); one test per I/O-matrix row except the certificate row -- runs in CI's `flutter test`.
- [x] `.gitlab-ci.yml` -- `macos:direct` (extends `.macmini`); `cdn:publish` (rclone image, needs `windows:release` + `linux:release`, `resource_group`, `environment: downloads-<channel>`, channel from rules variables); `linux:release` uses `scripts/gitlab_release.sh`; Windows release text gains macOS; header and setup comments updated.
- [x] `_bmad-output/planning-artifacts/download-cdn.md` -- server requirements (RustFS, bucket, CI key policy, public read, CORS for the website, beta 30-day lifecycle, optional nginx cache, HTTPS domain) and the `versions.json` contract for the website.
- [x] `_bmad-output/planning-artifacts/architecture.md` -- CI/CD bullets for the new jobs, linking `download-cdn.md`.

**Acceptance Criteria:**
- Given a local RustFS 1.0.6 and a fake package registry, when `publish_cdn.sh` runs, then the I/O matrix rows hold, and a download through a local nginx cache returns the file with its versioned name.
- Given the branch, when `shellcheck` and `shfmt -d` run on the new scripts, then they report nothing, and `.gitlab-ci.yml` passes GitLab's CI lint if reachable, else a YAML parse.

## Implementation Notes

- Implemented by five parallel agents (one per file or area) on `cf2e2a45`, then checked together against the diff.
- Additions beyond the task text:
  - `publish_cdn.sh` refuses to replace a published file with different content (compares against the tag's `SHA256SUMS`).
  - It checks that the channel matches the tag: `stable` only takes `v<version>`, `beta` only `-dev.` tags.
  - It falls back from amd64 to arm64 Linux packages.
  - `gitlab_release.sh` and `publish_cdn.sh` run under macOS's bash 3.2.
- `linux:release` no longer installs `jq` (only its removed inline release code used it).
- Matrix coverage:
  - `test/scripts/publish_cdn_test.dart` (11 tests): full, no macOS, Windows missing, Linux missing, variables missing, re-run, plus extra cases.
  - `test/scripts/release_scripts_test.dart` (14 tests).
  - The certificate row was checked by running the lane's certificate check on a Mac without a Developer ID identity; it stopped with the instructions.
  - End to end against `rustfs/rustfs:1.0.6` + `nginx:1.29.3-alpine` + a fake registry (scratchpad harness): full, no macOS, Windows missing and missing variables all behave as in the matrix. The second download was a cache `HIT`; `versions.json` was never cached and carried CORS from the doc's nginx config.
- RustFS 1.0.6 accepted the anonymous read policy, CORS and the 30-day lifecycle rule through the S3 API. The doc no longer relies on `mc`, which MinIO stopped publishing.
- Not verified until the Developer ID certificate exists: everything in the `direct` lane after the certificate check (export, hardened runtime, DMG, notarization).
- Separate change on this branch, at the user's request: `addressable` 2.9.0 → 2.9.2 in `android/` and `macos/Gemfile.lock` (osv-scanner: 12 advisories, now none).

## Spec Change Log

## Review Triage Log

| Finding | Verdict | Evidence | Route |
|---|---|---|---|
| `rclone cat` failure skips the immutability guard (verification-gap, blind, edge) | medium | Real rclone 1.75.2 on RustFS 1.0.6: missing object → exit 0, empty output; wrong key → exit 1. The script treats any failure as "not published", and the test fake exits 3 for missing, unlike the real tool. | patch |
| `SHA256SUMS` immutable-cached but rewritten when the DMG is added (blind, edge) | medium | A re-run after `macos:direct` rewrites it with `max-age=31536000, immutable`; caches keep the old one. | patch |
| curl exit ignored inside `fetch` (edge) | medium | `fetch` runs in `if`/`\|\|` context, so errexit is off; a partial transfer still prints 200 from `-w`. | patch |
| Published file missing from this run is dropped (edge) | low | The loop skips names with no local sum; a one-line fail fixes it. | patch |
| `--ignore-times`, failed upload ordering, invalid channel / master tag to beta untested (verification-gap, blind) | low | The fake drops all flags and never fails. | patch |
| DMG name in the Fastfile and in `publish_cdn.sh` only matched by hand (verification-gap) | medium | A 404 is "publishing without macOS" with exit 0; nothing ties the names. | patch |
| Older pipeline's `cdn:publish` rolls `versions.json` back (verification-gap, blind, edge) | low | Manual by design: it is the rollback path agreed with the user; undocumented. | patch (docs) |
| One CI key can write `stable/` from develop (blind) | low | Protected branches only; environment-scoped variables give each channel its own key with no code change. | patch (docs) |
| Docs: "a re-run uploads the same bytes" (blind) | low | False after a build-job retry (non-reproducible builds). | patch (docs) |
| Link POST not idempotent on job retry (blind, edge) | medium | Pre-existing in `linux:release`; same behaviour kept. | defer |
| Beta `.deb` version equals stable (blind) | medium | Pre-existing in `scripts/package_linux.sh`. | defer |
| Hardened runtime + llamadart at run time (blind) | maybe-false | Needs the first notarized DMG launched with an AI scan. | defer (medium, unverified) |
| PowerShell tag rule duplicated (verification-gap, blind) | medium | Pre-existing duplication; now script vs PowerShell. | defer |
| `printf` JSON unescaped (blind, edge) | low | Values are controlled names, URLs, numbers, hashes. | reject |
| Quoted pubspec version (edge) | false | `pubspec.yaml` is unquoted; the same sed is used across the existing scripts. | reject |
| JOB-TOKEN sent on `-L` redirect (edge) | low | Job-scoped token, expires with the job; redirect target is GitLab's storage. | reject |
| App and DMG signed by different certs (blind) | low | Both are Developer ID of team N668J5X92P; notarization accepts it. | reject |
| Release text always lists macOS (blind) | low | Same pattern as Windows/Linux before; links show what is attached. | reject |
| `publish_cdn.sh` version read without check (blind) | false | `tag=$(scripts/release_tag.sh)` exits first on an empty version under `set -e`. | reject |
| Schema / `min_os` fields (blind) | false | Contract addition, no defect. | reject |
| `macos:direct` without `resource_group` / environment; no env URL (blind) | low | Concurrent notarizations are harmless; cosmetic. | reject |
| DMG from an earlier commit at the same version (edge) | low | A second master build at the same version fails the immutability check first. | reject |
| Partial run then rebuild overwrites (edge) | low | Needs a failed publish, a rebuilt package and a re-run. | reject |

## Design Notes

`versions.json` (the website contract; `macos` omitted when absent):

```json
{ "channel": "stable", "version": "1.3.0", "tag": "v1.3.0", "commit": "<sha>", "published": "2026-11-20T10:15:00Z",
  "macos":   { "name": "HealthWallet-macOS-v1.3.0.dmg", "url": "<CDN_PUBLIC_URL>/stable/v1.3.0/…", "size": 190840832, "sha256": "…" },
  "windows": { … same fields … },
  "linux":   { "deb": { … same fields, "arch": "amd64" }, "tar": { … } } }
```

### Interfaces (shared by every task; keep exact)

- `scripts/release_tag.sh` -- no args; prints the tag. Reads `CI_COMMIT_BRANCH`, `CI_PIPELINE_IID`, `pubspec.yaml` from the repo root (resolved from the script's own path).
- `scripts/gitlab_release.sh <package> <dir>` -- uploads every file in `<dir>` to `$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic/<package>/<tag>/<file>` with `JOB-TOKEN`, creates the release (`tag_name`, `ref=$CI_COMMIT_SHA`, `name`, `description`), links each file (`link_type=package`). bash + curl only (no jq: the Mac mini may lack it).
- Package names: `healthwallet-windows`, `healthwallet-linux`, `healthwallet-macos`.
- Fastlane: `cd macos && bundle exec fastlane direct`, after `.macmini` setup, `*apple_signing`, `*ios_cocoapods`, `*pod_install`; writes exactly one file into `build/macos/packages/` (repo root).
- `scripts/publish_cdn.sh` -- no args; reads `CDN_CHANNEL` (`stable`/`beta`) and the `CDN_*` variables, checks them itself; bash, curl, rclone, `sha256sum` or `shasum -a 256`; no jq (JSON written with printf; every value is a controlled name, URL, number or hash). Configures rclone only through `RCLONE_CONFIG_CDN_*` env (type s3, provider Other, path style, `no_check_bucket`), remote `cdn:`. Work dir `build/cdn/`.
- `cdn:publish` -- image `rclone/rclone:1.75.2` with `entrypoint: [""]`, `apk add --no-cache bash curl`, runs `scripts/publish_cdn.sh`; rules on `master` set `CDN_CHANNEL: stable`, on `develop`/`release/*` `beta`.

## Verification

**Commands:**
- `shellcheck scripts/*.sh && shfmt -d scripts/` -- expected: no output.
- `ruby -c macos/fastlane/Fastfile` -- expected: Syntax OK.
- `fvm flutter test test/scripts/` -- expected: all pass.
- Local end-to-end run of `scripts/publish_cdn.sh` against RustFS + nginx containers (scratchpad harness) -- expected: matrix rows pass.
