#!/usr/bin/env bash
# Adds a pipeline's desktop packages to the GitLab Release of its tag (scripts/release_tag.sh):
#   scripts/gitlab_release.sh <package> <dir>
# Uploads every file in <dir> to the generic package registry as <package>/<tag>/<file>, creates
# the release for the tag on the commit that was built unless another platform's job already
# did, and links the files to it. <package> is healthwallet-windows, healthwallet-linux or
# healthwallet-macos.
# Needs only bash and curl, so it runs on the Linux image and on the Mac mini. Reads the GitLab CI
# variables CI_API_V4_URL, CI_PROJECT_ID, CI_JOB_TOKEN, CI_COMMIT_SHA and CI_COMMIT_BRANCH, plus
# CI_PIPELINE_IID through release_tag.sh.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <package> <dir>" >&2
  exit 2
fi
package=$1
dir=$2

missing=()
for name in CI_API_V4_URL CI_PROJECT_ID CI_JOB_TOKEN CI_COMMIT_SHA CI_COMMIT_BRANCH; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing CI variables: ${missing[*]}" >&2
  exit 1
fi

files=()
for file in "$dir"/*; do
  if [ -f "$file" ]; then
    files+=("$file")
  fi
done
if [ "${#files[@]}" -eq 0 ]; then
  echo "No files to release in $dir" >&2
  exit 1
fi

tag=$("$(dirname "$0")/release_tag.sh")
package_url="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic/$package/$tag"
releases="$CI_API_V4_URL/projects/$CI_PROJECT_ID/releases"

# Each request leaves GitLab's response in $response, to show it when the request fails.
response=$(mktemp)
trap 'rm -f "$response"' EXIT
# Prints the HTTP status of a request to GitLab with the job token and the given curl arguments.
send() {
  curl -sS -o "$response" -w '%{http_code}' -H "JOB-TOKEN: $CI_JOB_TOKEN" "$@"
}
# Stops with what was being done, the HTTP status and GitLab's response.
fail() {
  echo "$1 failed (HTTP $2):" >&2
  cat "$response" >&2
  echo >&2
  exit 1
}

for file in "${files[@]}"; do
  name=$(basename "$file")
  echo "Uploading $name to $package/$tag"
  status=$(send --upload-file "$file" "$package_url/$name")
  case "$status" in
  2??) ;;
  *) fail "Uploading $name" "$status" ;;
  esac
done

description="## HealthWallet $tag

Branch: \`$CI_COMMIT_BRANCH\`, commit: \`$CI_COMMIT_SHA\`

- **macOS (.dmg):** open it and drag HealthWallet to Applications (macOS 14 or newer)
- **Windows installer (.msix):** double-click to install (Windows 10+)
- **Windows portable (.zip):** extract and run \`health_wallet.exe\`
- **Linux (.deb):** \`sudo apt install ./HealthWallet-Linux-*.deb\` (Ubuntu 24.04, Debian 13 or newer)
- **Linux portable (.tar.gz):** extract and run \`HealthWallet/health_wallet\`"

# 409 means another platform's job created the release already; anything else fails the job with
# GitLab's reason.
status=$(send --data-urlencode "tag_name=$tag" --data-urlencode "ref=$CI_COMMIT_SHA" \
  --data-urlencode "name=$tag" --data-urlencode "description=$description" "$releases")
case "$status" in
201) echo "Created release $tag" ;;
409) echo "Release $tag exists already" ;;
*) fail "Creating release $tag" "$status" ;;
esac

for file in "${files[@]}"; do
  name=$(basename "$file")
  echo "Linking $name to release $tag"
  status=$(send --data-urlencode "name=$name" --data-urlencode "url=$package_url/$name" \
    --data "link_type=package" "$releases/$tag/assets/links")
  case "$status" in
  2??) ;;
  *) fail "Linking $name" "$status" ;;
  esac
done
