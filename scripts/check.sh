#!/usr/bin/env bash
# Code quality checks: dart format, Prettier, flutter analyze and flutter test.
#
#   scripts/check.sh           check the whole project
#   scripts/check.sh --fix     format everything first, then check
#   scripts/check.sh --staged  check only staged files and skip tests (used by the pre-commit hook)
#
# Prettier is pinned in package.json; run `npm install` once to get it.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-all}"

# Tracked Dart sources, minus files a generator rewrites (gen-l10n, flutter_gen, drift schemas).
dart_files() {
  git ls-files "$@" -- '*.dart' \
    ':!:lib/core/l10n/arb/app_localizations*.dart' \
    ':!:*.gen.dart' \
    ':!:test/drift/my_database/generated/*'
}

if [[ "$mode" == "--staged" ]]; then
  staged=$(git diff --cached --name-only --diff-filter=ACMR)
  [[ -z "$staged" ]] && exit 0

  if echo "$staged" | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'; then
    echo "Refusing to commit the secret files above (see AGENTS.md)." >&2
    exit 1
  fi

  dart=$(comm -12 <(dart_files | sort) <(echo "$staged" | sort))
  if [[ -n "$dart" ]]; then
    echo "==> dart format (staged)"
    # shellcheck disable=SC2086
    fvm dart format --output=none --set-exit-if-changed $dart
  fi

  echo "==> prettier (staged)"
  # shellcheck disable=SC2086
  npx --no-install prettier --check --ignore-unknown --no-error-on-unmatched-pattern --log-level warn $staged

  echo "==> flutter analyze"
  fvm flutter analyze --no-pub
  exit 0
fi

if [[ "$mode" == "--fix" ]]; then
  dart_files | xargs fvm dart format
  npx --no-install prettier --write --log-level warn .
fi

echo "==> dart format"
dart_files | xargs fvm dart format --output=none --set-exit-if-changed
echo "==> prettier"
npx --no-install prettier --check --log-level warn .
echo "==> flutter analyze"
fvm flutter analyze
echo "==> flutter test"
fvm flutter test
