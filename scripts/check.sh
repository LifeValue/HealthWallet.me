#!/usr/bin/env bash
# Code quality checks for the current branch: the formatters (via pre-commit) on the files
# changed since it left develop, then flutter analyze and flutter test.
# Formatters fix files in place; when one changes something the script fails so you can
# review and commit the change. Set CHECK_BASE to compare against another branch.
set -euo pipefail
cd "$(dirname "$0")/.."

base=$(git merge-base "${CHECK_BASE:-origin/develop}" HEAD)

echo "==> formatters (pre-commit) on files changed since $(git rev-parse --short "$base")"
pre-commit run --from-ref "$base" --to-ref HEAD
echo "==> flutter analyze"
fvm flutter analyze
echo "==> flutter test"
fvm flutter test
