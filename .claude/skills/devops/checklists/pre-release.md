# Pre-Release Checklist

Complete these checks before triggering a production release.

---

## Code Quality

- [ ] All CI checks pass on the release branch
- [ ] `flutter analyze --no-fatal-infos` reports no errors or warnings
- [ ] `flutter test` passes with no failures
- [ ] Code generation is up to date (`dart run build_runner build --delete-conflicting-outputs`)
- [ ] No unresolved merge conflicts

## Version & Build Number

- [ ] `pubspec.yaml` version bumped appropriately (semver)
- [ ] Build number incremented (must be higher than last uploaded build)
- [ ] Version matches across platforms:
  - `pubspec.yaml` → `version: X.Y.Z+N`
  - Android reads from Flutter automatically
  - iOS reads from Flutter automatically

## Android-Specific

- [ ] Release AAB builds successfully locally: `flutter build appbundle --release`
- [ ] Signing config is correct in `android/key.properties`
- [ ] ProGuard rules are up to date if new native dependencies were added
- [ ] No new permissions that require Play Store policy declarations

## iOS-Specific

- [ ] Release IPA builds successfully locally: `flutter build ipa --release`
- [ ] Match certificates are valid and not expired
- [ ] Share Extension is included in the archive
- [ ] No new entitlements that require App Store review explanation
- [ ] `Podfile.lock` is committed and up to date

## Release Notes

- [ ] Changelog prepared for this version
- [ ] Release notes written for:
  - Google Play (internal/production track)
  - TestFlight (what to test)
  - App Store (if promoting from TestFlight)

## Deployment

- [ ] Trigger Android deploy: `workflow_dispatch` on `android-deploy.yml`
  - Internal track for testing → Production track for release
- [ ] Trigger iOS deploy: `workflow_dispatch` on `ios-deploy.yml`
  - Beta lane uploads to TestFlight
  - Production promotion done manually in App Store Connect

## Post-Deployment

- [ ] Verify build appears in Google Play internal track / production
- [ ] Verify build appears in TestFlight
- [ ] Tag the release: `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] Merge release branch back to `develop` (if using GitFlow release branch)
- [ ] Monitor crash reports after rollout
