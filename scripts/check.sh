#!/usr/bin/env bash
# Code quality checks: every formatter (via pre-commit), flutter analyze and flutter test.
# Formatters fix files in place; when one changes something the script fails so you can
# review and commit the change. Setup: README.md, "Code quality".
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> formatters (pre-commit)"
pre-commit run --all-files
echo "==> flutter analyze"
fvm flutter analyze
echo "==> flutter test"
fvm flutter test
