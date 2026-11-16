#!/usr/bin/env bash
# Publishes one pipeline's desktop packages to the download CDN (an S3-compatible bucket, RustFS),
# for the website's download buttons. Run by the CI job cdn:publish after windows:release and
# linux:release; macos:direct is optional, its DMG is included when it is already in the registry.
#
# Fetches the packages for this pipeline's release tag (scripts/release_tag.sh) from the generic
# package registry and uploads, in this order:
#   <channel>/<tag>/<file>        each package, cached for a year, downloaded as an attachment
#   <channel>/<tag>/SHA256SUMS    the packages' checksums (no-cache: a re-run may add the DMG)
#   <channel>/versions.json       what the website reads (no-cache), written last
# Nothing else is ever overwritten: every package carries its version in its name and folder,
# and a tag already published with different files fails the job.
#
# Variables: CDN_CHANNEL (stable or beta), CDN_S3_ENDPOINT, CDN_S3_REGION (optional), CDN_BUCKET,
# CDN_ACCESS_KEY_ID, CDN_SECRET_ACCESS_KEY, CDN_PUBLIC_URL, and GitLab's CI_API_V4_URL,
# CI_PROJECT_ID, CI_JOB_TOKEN, CI_COMMIT_SHA, CI_COMMIT_BRANCH, CI_PIPELINE_IID.
# Needs bash, curl, rclone and sha256sum (or shasum).
set -euo pipefail
cd "$(dirname "$0")/.."

missing=()
for name in CDN_CHANNEL CDN_S3_ENDPOINT CDN_BUCKET CDN_ACCESS_KEY_ID CDN_SECRET_ACCESS_KEY \
  CDN_PUBLIC_URL CI_API_V4_URL CI_PROJECT_ID CI_JOB_TOKEN CI_COMMIT_SHA CI_COMMIT_BRANCH; do
  [ -n "${!name:-}" ] || missing+=("$name")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing CI/CD variables: ${missing[*]}" >&2
  echo "Set the CDN_* variables as protected variables (Settings → CI/CD → Variables) and run the job on a protected branch." >&2
  exit 1
fi

channel=$CDN_CHANNEL
tag=$(scripts/release_tag.sh)
version=$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)
case "$channel:$tag" in
stable:*-dev.*)
  echo "Tag $tag is a pre-release; the stable channel only takes master's v<version> tags." >&2
  exit 1
  ;;
stable:* | beta:*-dev.*) ;;
beta:*)
  echo "Tag $tag is a release; the beta channel only takes v<version>-dev.<pipeline> tags." >&2
  exit 1
  ;;
*)
  echo "CDN_CHANNEL must be stable or beta, not $channel." >&2
  exit 1
  ;;
esac

# rclone is configured only through the environment: remote cdn:, S3 with path-style URLs.
# no_check_bucket: the CI key may only write objects, not create or list buckets.
export RCLONE_CONFIG_CDN_TYPE=s3
export RCLONE_CONFIG_CDN_PROVIDER=Other
export RCLONE_CONFIG_CDN_ENV_AUTH=false
export RCLONE_CONFIG_CDN_ENDPOINT=$CDN_S3_ENDPOINT
export RCLONE_CONFIG_CDN_ACCESS_KEY_ID=$CDN_ACCESS_KEY_ID
export RCLONE_CONFIG_CDN_SECRET_ACCESS_KEY=$CDN_SECRET_ACCESS_KEY
export RCLONE_CONFIG_CDN_FORCE_PATH_STYLE=true
export RCLONE_CONFIG_CDN_NO_CHECK_BUCKET=true
if [ -n "${CDN_S3_REGION:-}" ]; then
  export RCLONE_CONFIG_CDN_REGION=$CDN_S3_REGION
fi

work=build/cdn
rm -rf "$work"
mkdir -p "$work/files"
registry="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"

# fetch <package> <file>: downloads one package file into $work/files. Returns 1 when the registry
# has no such file (404); any other failure stops the job with the registry's answer.
fetch() {
  local status code=0
  status=$(curl -sS -L -o "$work/files/$2" -w '%{http_code}' -H "JOB-TOKEN: $CI_JOB_TOKEN" \
    "$registry/$1/$tag/$2") || code=$?
  # A broken transfer can still report 200: never publish what curl did not fully download.
  if [ "$code" -ne 0 ]; then
    echo "Downloading $1/$tag/$2 from the package registry failed (curl exit $code)." >&2
    exit 1
  fi
  case "$status" in
  200) return 0 ;;
  404)
    rm -f "$work/files/$2"
    return 1
    ;;
  *)
    echo "Downloading $1/$tag/$2 from the package registry failed (HTTP $status):" >&2
    cat "$work/files/$2" >&2 || true
    echo >&2
    exit 1
    ;;
  esac
}

macos=HealthWallet-macOS-v$version.dmg
windows=HealthWallet-Windows-v$version-portable.zip
files=()

if fetch healthwallet-macos "$macos"; then
  files+=("$macos")
else
  echo "No macOS DMG for $tag in the registry (macos:direct has not run); publishing without macOS."
  macos=
fi

fetch healthwallet-windows "$windows" || {
  echo "Missing healthwallet-windows/$tag/$windows in the package registry; run windows:release first." >&2
  exit 1
}
files+=("$windows")

# The Linux packages are built for the runner's architecture: take amd64, else arm64.
linux_arch=
for arch in amd64 arm64; do
  if fetch healthwallet-linux "HealthWallet-Linux-v$version-$arch.deb"; then
    linux_arch=$arch
    break
  fi
done
if [ -z "$linux_arch" ]; then
  echo "Missing healthwallet-linux/$tag/HealthWallet-Linux-v$version-amd64.deb (or -arm64.deb) in the package registry; run linux:release first." >&2
  exit 1
fi
deb=HealthWallet-Linux-v$version-$linux_arch.deb
tar=HealthWallet-Linux-v$version-$linux_arch.tar.gz
fetch healthwallet-linux "$tar" || {
  echo "Missing healthwallet-linux/$tag/$tar in the package registry; run linux:release first." >&2
  exit 1
}
files+=("$deb" "$tar")

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

: >"$work/SHA256SUMS"
for file in "${files[@]}"; do
  printf '%s  %s\n' "$(sha256 "$work/files/$file")" "$file" >>"$work/SHA256SUMS"
done

# sum_of <file>: the file's checksum from SHA256SUMS (no associative arrays: macOS has bash 3.2).
sum_of() {
  awk -v name="$1" '$2 == name { print $1 }' "$work/SHA256SUMS"
}

dest="cdn:$CDN_BUCKET/$channel/$tag"

# A published tag is immutable: re-running the job may add the DMG or upload the same files
# again, never replace a file with different content or drop one. rclone cat prints nothing for
# a missing object (not published yet) and fails only when the bucket can't be read.
published=$(rclone cat "$dest/SHA256SUMS") || {
  echo "Reading $channel/$tag/SHA256SUMS from the bucket failed; check the CDN_* variables and the key's permissions." >&2
  exit 1
}
while read -r hash name; do
  [ -n "$name" ] || continue
  ours=$(sum_of "$name")
  if [ -z "$ours" ]; then
    echo "$channel/$tag/$name is already published but not part of this run; its package is missing from the registry." >&2
    exit 1
  fi
  if [ "$ours" != "$hash" ]; then
    echo "$channel/$tag/$name is already published with different content. Published files never change: bump the version in pubspec.yaml." >&2
    exit 1
  fi
done <<<"$published"

# --ignore-times: upload every file again, so a re-run also rewrites its headers.
for file in "${files[@]}"; do
  rclone copyto --ignore-times \
    --header-upload "Cache-Control: public, max-age=31536000, immutable" \
    --header-upload "Content-Disposition: attachment; filename=\"$file\"" \
    "$work/files/$file" "$dest/$file"
  echo "Uploaded $channel/$tag/$file"
done
rclone copyto --ignore-times \
  --header-upload "Cache-Control: no-cache" \
  --header-upload "Content-Type: text/plain; charset=utf-8" \
  "$work/SHA256SUMS" "$dest/SHA256SUMS"
echo "Uploaded $channel/$tag/SHA256SUMS"

# entry <file> [arch]: the versions.json object for one package.
entry() {
  local size
  size=$(wc -c <"$work/files/$1" | tr -d '[:space:]')
  printf '{ "name": "%s", "url": "%s", "size": %s, "sha256": "%s"' \
    "$1" "${CDN_PUBLIC_URL%/}/$channel/$tag/$1" "$size" "$(sum_of "$1")"
  if [ -n "${2:-}" ]; then
    printf ', "arch": "%s"' "$2"
  fi
  printf ' }'
}

{
  printf '{\n'
  printf '  "channel": "%s",\n' "$channel"
  printf '  "version": "%s",\n' "$version"
  printf '  "tag": "%s",\n' "$tag"
  printf '  "commit": "%s",\n' "$CI_COMMIT_SHA"
  printf '  "published": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ -n "$macos" ]; then
    printf '  "macos": %s,\n' "$(entry "$macos")"
  fi
  printf '  "windows": %s,\n' "$(entry "$windows")"
  printf '  "linux": {\n'
  printf '    "deb": %s,\n' "$(entry "$deb" "$linux_arch")"
  printf '    "tar": %s\n' "$(entry "$tar" "$linux_arch")"
  printf '  }\n'
  printf '}\n'
} >"$work/versions.json"

rclone copyto --ignore-times \
  --header-upload "Cache-Control: no-cache" \
  --header-upload "Content-Type: application/json; charset=utf-8" \
  "$work/versions.json" "cdn:$CDN_BUCKET/$channel/versions.json"
echo "Published $tag to $channel: ${CDN_PUBLIC_URL%/}/$channel/versions.json"
