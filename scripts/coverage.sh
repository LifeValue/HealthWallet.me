#!/usr/bin/env bash
# Coverage status: runs the tests with coverage and prints the total, each feature area and the
# critical areas with their floors (tool/coverage_floors.json). Files no test touches count as 0%.
#   scripts/coverage.sh                  summary
#   scripts/coverage.sh --files <dir>    per-file lines for one directory (e.g. lib/features/sync/)
#   scripts/coverage.sh --check          also fail if a critical area fell below its floor
#   scripts/coverage.sh --ratchet        raise the floors to today's coverage (commit the file)
set -euo pipefail
cd "$(dirname "$0")/.."

trap 'rm -f test/coverage_all_files_test.dart' EXIT
scripts/write_coverage_helper.sh

fvm flutter test --coverage --reporter=failures-only
fvm dart run tool/coverage_report.dart "$@"
