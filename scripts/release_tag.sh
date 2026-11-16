#!/usr/bin/env bash
# Prints the release tag of this pipeline: v<version> on master, v<version>-dev.<pipeline iid>
# on every other branch, with the version from pubspec.yaml without its build number.
# windows:release in .gitlab-ci.yml applies the same rule in PowerShell; keep the two identical.
# Reads CI_COMMIT_BRANCH and CI_PIPELINE_IID.
set -euo pipefail

pubspec="$(cd "$(dirname "$0")/.." && pwd)/pubspec.yaml"
version=$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' "$pubspec")
if [ -z "$version" ]; then
  echo "No version found in $pubspec" >&2
  exit 1
fi

if [ "${CI_COMMIT_BRANCH:-}" = master ]; then
  echo "v$version"
elif [ -n "${CI_PIPELINE_IID:-}" ]; then
  echo "v$version-dev.$CI_PIPELINE_IID"
else
  echo "CI_PIPELINE_IID is not set; it is needed for the tag of a branch other than master" >&2
  exit 1
fi
