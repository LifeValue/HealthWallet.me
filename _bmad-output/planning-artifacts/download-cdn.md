# Download CDN

The website's download buttons for macOS, Windows and Linux point at files on our own server: an S3-compatible bucket in RustFS, served over HTTPS, with an optional nginx cache in front. The CI job `cdn:publish` fills the bucket (`scripts/publish_cdn.sh`); nothing else writes to it. This page is for two people:

- [Setting up the server](#setting-up-the-server): what the bucket and the host need, and the values to hand back for CI.
- [Building the website buttons](#versionsjson-for-the-website): the `versions.json` file the website reads.

Hostnames, bucket names and keys below are placeholders: `downloads.example.org` is the public download host, `s3.example.org` the S3 API that CI uploads to, `https://www.example.org` the website, `<bucket>` the bucket.

## What the bucket holds

```text
<bucket>/
  stable/versions.json                                   what the website reads; rewritten on every publish
  stable/v1.3.0/HealthWallet-macOS-v1.3.0.dmg            only when macos:direct ran for this version
  stable/v1.3.0/HealthWallet-Windows-v1.3.0-portable.zip
  stable/v1.3.0/HealthWallet-Linux-v1.3.0-amd64.deb
  stable/v1.3.0/HealthWallet-Linux-v1.3.0-amd64.tar.gz
  stable/v1.3.0/SHA256SUMS
  beta/versions.json
  beta/v1.3.0-dev.412/...                                same files, for a develop or release/* pipeline
```

- `master` publishes to `stable/`, `develop` and `release/*` to `beta/`.
- There is no `latest` file or folder. Every package has its version in its name and folder and never changes once uploaded. Two files do change: `<channel>/<tag>/SHA256SUMS`, rewritten when a re-run adds the DMG, and `<channel>/versions.json`, which names the current version. `versions.json` is uploaded last, so it never points at a file that isn't there yet.
- A re-run of `cdn:publish` on the same pipeline uploads the same bytes again. That holds only while the build jobs aren't retried: builds aren't reproducible, so a retried `windows:store`, `linux:snap` or `macos:direct` puts a different file in the registry, and `cdn:publish` then fails with "bump the version" instead of replacing a published file.
- No Android APK (the website links to Google Play) and no Windows MSIX (Microsoft Store only).
- Headers set on upload, stored with each object and returned on every download:

  | Object                       | `Cache-Control`                       | Other                                                |
  | ---------------------------- | ------------------------------------- | ---------------------------------------------------- |
  | `<channel>/<tag>/<file>`     | `public, max-age=31536000, immutable` | `Content-Disposition: attachment; filename="<file>"` |
  | `<channel>/<tag>/SHA256SUMS` | `no-cache`                            | `Content-Type: text/plain; charset=utf-8`            |
  | `<channel>/versions.json`    | `no-cache`                            | `Content-Type: application/json; charset=utf-8`      |

### Roll back

To put an earlier version back on the download buttons, run `cdn:publish` by hand on the pipeline that built that version (same channel: a `master` pipeline for `stable/`). It uploads the same files again and rewrites `versions.json` to that version. Nothing is deleted, so the newer version's files stay in the bucket.

## Setting up the server

Work through the list in order; the last step is what CI needs from you.

Checked on a local `rustfs/rustfs:1.0.6` (2026-11-16) through its S3 API:

- creating the bucket, the anonymous read policy (step 4), CORS (step 5) and the `beta/` expiry rule (step 6) all work;
- the headers that `cdn:publish` sets are stored and returned;
- downloads through the nginx cache in step 8 work and are served from the cache the second time.

The CI user and policy (step 3) are created in the console and haven't been checked yet.

### 1. Run RustFS 1.0.6

- Image `rustfs/rustfs:1.0.6`, pinned to that exact tag (never `latest`), on a persistent volume. Upgrade on purpose, not by pulling.
- Keep the root credentials (`RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY`) in a Kubernetes Secret. They are for you, never for CI.
- The S3 API listens on port 9000. Keep the admin console (port 9001) off the public internet.
- Space: every published version adds four packages (a few hundred MB together). `stable/` is never cleaned up; `beta/` is capped by the 30-day rule in step 6.
- The default region is `us-east-1`. If you set another one, hand it back as `CDN_S3_REGION`.

### 2. Create the bucket

Create one bucket, `<bucket>`, private by default. No versioning or object lock: re-running a publish rewrites `SHA256SUMS`, `versions.json` and the same packages with identical content, and that must be allowed.

### 3. Create the CI access keys

CI gets two users, each with its own key: `healthwallet-ci-stable` may upload only under `stable/`, `healthwallet-ci-beta` only under `beta/`. GitLab hands the stable key only to `master` pipelines and the beta key only to `develop` and `release/*` (step 10), so a develop job can never write to `stable/`. Neither key can delete anything, change bucket settings or touch other buckets. Each may read its own folder, which everyone can read anyway: the job reads an already published `SHA256SUMS` to make sure a version is never replaced with different files, and rclone checks each upload. `s3:ListBucket` lets a missing file come back as "not found" instead of "access denied".

`s3:PutObject` also lets a key overwrite a file that is already there; S3 policies can't allow "add" without "replace". What keeps published files unchanged is the check in `scripts/publish_cdn.sh`, which stops before uploading when a file of that version is already published with other content.

`ci-stable-policy.json` (for `ci-beta-policy.json`, the same with `beta/*` in place of `stable/*`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UploadReleases",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": ["arn:aws:s3:::<bucket>/stable/*"]
    },
    {
      "Sid": "FindExisting",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": ["arn:aws:s3:::<bucket>"]
    }
  ]
}
```

Create the policy and the user in the RustFS console (port 9001, signed in with the root credentials): add the two policies, `healthwallet-ci-stable` and `healthwallet-ci-beta`, then the two users, each with a new access key, and attach each user's policy to it. Don't plan on the MinIO client (`mc`) for this: MinIO no longer publishes its images, and its admin commands are untested against RustFS.

Generate each key pair randomly (for example `openssl rand -hex 20` and `openssl rand -base64 30`) and don't reuse them anywhere else.

### 4. Allow anonymous downloads

Anyone may download from `stable/` and `beta/`, `versions.json` included. Nobody anonymous may list the bucket or upload.

`public-read.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicDownloads",
      "Effect": "Allow",
      "Principal": { "AWS": ["*"] },
      "Action": ["s3:GetObject"],
      "Resource": [
        "arn:aws:s3:::<bucket>/stable/*",
        "arn:aws:s3:::<bucket>/beta/*"
      ]
    }
  ]
}
```

```bash
aws --endpoint-url https://s3.example.org s3api put-bucket-policy \
  --bucket <bucket> --policy file://public-read.json
```

(`aws` with the root credentials, or any S3 client.)

### 5. Allow the website to read `versions.json` (CORS)

The website fetches `versions.json` from its own pages, so the response needs an `Access-Control-Allow-Origin` header for the website's origin. The downloads themselves are plain links and need no CORS.

`cors.json` (list every origin the site is served from: with and without `www`, and any preview or staging origin):

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["https://www.example.org", "https://example.org"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag", "Content-Length"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```

```bash
aws --endpoint-url https://s3.example.org s3api put-bucket-cors \
  --bucket <bucket> --cors-configuration file://cors.json
```

If the check in step 9 shows no `Access-Control-Allow-Origin`, set the header in the proxy in front instead (the nginx example below does).

### 6. Expire beta builds after 30 days

Beta builds are for testers and pile up quickly. Delete everything under `beta/` 30 days after it was uploaded; `stable/` is kept forever.

`lifecycle.json`:

```json
{
  "Rules": [
    {
      "ID": "expire-beta",
      "Status": "Enabled",
      "Filter": { "Prefix": "beta/" },
      "Expiration": { "Days": 30 }
    }
  ]
}
```

```bash
aws --endpoint-url https://s3.example.org s3api put-bucket-lifecycle-configuration \
  --bucket <bucket> --lifecycle-configuration file://lifecycle.json
```

This also removes `beta/versions.json` when no beta has been published for 30 days; the website treats that as "no beta" (see below).

### 7. Serve it over HTTPS

Two hosts, both through the cluster's current Gateway API controller or Ingress controller. Don't install the community ingress-nginx for this: it is retired and gets no more fixes.

- **`downloads.example.org`, public, read only.** `GET` and `HEAD` only, mapped onto the bucket so that `https://downloads.example.org/stable/versions.json` returns `<bucket>/stable/versions.json`. Without the cache it points at RustFS; with it, at nginx (step 8), which then does the mapping.
- **`s3.example.org`, the S3 API for CI.** All methods, no path rewrite, reachable from GitLab's Linux runners (restrict it to them if you can). Allow request bodies of at least 256 MB and long enough timeouts: rclone uploads files under 200 MB in one request.

TLS certificates on the Gateway listener (cert-manager or however the cluster issues them), plus DNS records for both names. An `HTTPRoute` for the public host without the cache (method matching and `URLRewrite` are extended features; if your controller lacks them, put the nginx from step 8 in front):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: downloads
  namespace: <namespace>
spec:
  parentRefs:
    - name: <gateway>
      namespace: <gateway-namespace>
  hostnames: ["downloads.example.org"]
  rules:
    - matches:
        - { method: GET, path: { type: PathPrefix, value: / } }
        - { method: HEAD, path: { type: PathPrefix, value: / } }
      filters:
        - type: URLRewrite
          urlRewrite:
            path: { type: ReplacePrefixMatch, replacePrefixMatch: /<bucket> }
      backendRefs:
        - { name: rustfs, port: 9000 }
```

### 8. Optional: nginx cache

Worth it when downloads put real load on RustFS. nginx keeps each package after its first download and serves it from disk; `versions.json` is never cached (its `no-cache` header stops nginx from storing it), so a new release shows at once.

```nginx
proxy_cache_path /var/cache/nginx/downloads levels=1:2 keys_zone=downloads:10m
                 max_size=50g inactive=30d use_temp_path=off;

server {
    listen 8080;

    location / {
        limit_except GET { deny all; }            # GET also allows HEAD

        proxy_pass http://rustfs:9000/<bucket>/;  # the trailing / maps /stable/... onto the bucket
        proxy_cache downloads;
        proxy_cache_key $uri;                     # one copy per file; query strings are ignored
        proxy_cache_valid 200 30d;
        proxy_cache_lock on;                      # one fetch from RustFS per file, however many wait
        proxy_cache_use_stale error timeout updating;
        proxy_ignore_headers Set-Cookie;

        # CORS here, not from RustFS: a cached response must carry it for every visitor.
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Access-Control-Allow-Origin "https://www.example.org" always;
        add_header Vary Origin always;
        add_header X-Cache-Status $upstream_cache_status always;
    }
}
```

With several website origins, replace the fixed `Access-Control-Allow-Origin` with a `map $http_origin` that returns the origin when it is one of yours and an empty string otherwise.

### 9. Check it

After the first `cdn:publish` (or after uploading a test file to `beta/test/hello.txt` with the beta key):

```bash
# Anonymous download works and keeps its headers
curl -sI https://downloads.example.org/stable/versions.json     # 200, Cache-Control: no-cache
curl -sI https://downloads.example.org/stable/v1.3.0/SHA256SUMS # 200, Cache-Control: no-cache

# CORS for the website
curl -sI -H 'Origin: https://www.example.org' https://downloads.example.org/stable/versions.json \
  | grep -i access-control-allow-origin                         # https://www.example.org

# Nothing else is open
curl -sI https://downloads.example.org/                         # 403 or 404, no bucket listing
curl -s -o /dev/null -w '%{http_code}\n' -X PUT --data x \
  https://downloads.example.org/stable/x                        # 403 or 405

# The beta key can't delete, and can't write to stable/
export AWS_ACCESS_KEY_ID=<beta-access-key> AWS_SECRET_ACCESS_KEY=<beta-secret-key>
aws --endpoint-url https://s3.example.org s3 rm s3://<bucket>/beta/test/hello.txt   # AccessDenied
echo x | aws --endpoint-url https://s3.example.org s3 cp - s3://<bucket>/stable/x   # AccessDenied
```

### 10. Hand back these values

Set them in GitLab (Settings → CI/CD → Variables), all **Protected**, so only `develop`, `release/*` and `master` see them. The two key variables are each added twice, once per key, with the variable's **Environment scope** set to `downloads-stable` or `downloads-beta`: `cdn:publish` runs in the environment `downloads-stable` on `master` and `downloads-beta` on `develop` and `release/*`, so each pipeline gets only its channel's key. The other variables keep the scope `*` (all environments).

| Variable                | Value                                                                                                                                                       | Flags                        |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `CDN_S3_ENDPOINT`       | The S3 API URL from step 7, e.g. `https://s3.example.org`                                                                                                   | Protected                    |
| `CDN_S3_REGION`         | Only if RustFS runs with a region other than `us-east-1`; otherwise leave it unset                                                                          | Protected                    |
| `CDN_BUCKET`            | `<bucket>`                                                                                                                                                  | Protected                    |
| `CDN_ACCESS_KEY_ID`     | Scope `downloads-stable`: the stable key from step 3                                                                                                        | Protected, masked            |
| `CDN_SECRET_ACCESS_KEY` | Scope `downloads-stable`: its secret                                                                                                                        | Protected, masked and hidden |
| `CDN_ACCESS_KEY_ID`     | Scope `downloads-beta`: the beta key from step 3                                                                                                            | Protected, masked            |
| `CDN_SECRET_ACCESS_KEY` | Scope `downloads-beta`: its secret                                                                                                                          | Protected, masked and hidden |
| `CDN_PUBLIC_URL`        | The public address of the bucket's contents, no trailing `/`: `https://downloads.example.org`. `<CDN_PUBLIC_URL>/stable/versions.json` must return the file | Protected                    |

`CDN_PUBLIC_URL` goes into every URL in `versions.json`. If the public host does not map onto the bucket (no rewrite, no nginx), it is `https://downloads.example.org/<bucket>`.

## `versions.json` for the website

### Where

- Stable: `https://downloads.example.org/stable/versions.json` (what the public download buttons use)
- Beta: `https://downloads.example.org/beta/versions.json` (only if the site offers beta builds to testers)

### Fields

| Field       | Type   | Meaning                                                                                        |
| ----------- | ------ | ---------------------------------------------------------------------------------------------- |
| `channel`   | string | `stable` or `beta`                                                                             |
| `version`   | string | App version, e.g. `1.3.0`: what to show next to the buttons                                    |
| `tag`       | string | Release tag: `v1.3.0` on stable, `v1.3.0-dev.412` on beta. Also the folder the files are in    |
| `commit`    | string | Full git commit the build came from                                                            |
| `published` | string | When this file was written, UTC, ISO 8601 (`2026-11-20T10:15:00Z`)                             |
| `macos`     | object | The DMG. **Left out** when there is no macOS build for this version                            |
| `windows`   | object | The portable zip                                                                               |
| `linux`     | object | `deb` (Ubuntu 24.04, Debian 13 or newer) and `tar` (a portable `.tar.gz` for the same systems) |

Every file object has:

| Field    | Type   | Meaning                                                                   |
| -------- | ------ | ------------------------------------------------------------------------- |
| `name`   | string | File name, which is also what the browser saves it as                     |
| `url`    | string | Full download URL                                                         |
| `size`   | number | Bytes                                                                     |
| `sha256` | string | SHA-256 of the file, lowercase hex                                        |
| `arch`   | string | Linux only: `amd64` or `arm64`. Both Linux files are always the same arch |

The checksums of all files are also published as `SHA256SUMS` next to them: replace the file name at the end of any `url` with `SHA256SUMS`.

### Example

```json
{
  "channel": "stable",
  "version": "1.3.0",
  "tag": "v1.3.0",
  "commit": "0123456789abcdef0123456789abcdef01234567",
  "published": "2026-11-20T10:15:00Z",
  "macos": {
    "name": "HealthWallet-macOS-v1.3.0.dmg",
    "url": "https://downloads.example.org/stable/v1.3.0/HealthWallet-macOS-v1.3.0.dmg",
    "size": 190840832,
    "sha256": "<64 hex characters>"
  },
  "windows": {
    "name": "HealthWallet-Windows-v1.3.0-portable.zip",
    "url": "https://downloads.example.org/stable/v1.3.0/HealthWallet-Windows-v1.3.0-portable.zip",
    "size": 98566144,
    "sha256": "<64 hex characters>"
  },
  "linux": {
    "deb": {
      "name": "HealthWallet-Linux-v1.3.0-amd64.deb",
      "url": "https://downloads.example.org/stable/v1.3.0/HealthWallet-Linux-v1.3.0-amd64.deb",
      "size": 61865984,
      "sha256": "<64 hex characters>",
      "arch": "amd64"
    },
    "tar": {
      "name": "HealthWallet-Linux-v1.3.0-amd64.tar.gz",
      "url": "https://downloads.example.org/stable/v1.3.0/HealthWallet-Linux-v1.3.0-amd64.tar.gz",
      "size": 64487424,
      "sha256": "<64 hex characters>",
      "arch": "amd64"
    }
  }
}
```

### Building the buttons

1. Fetch `stable/versions.json` in the browser when the page loads. Use the `url` values as they are; never build a download URL from the version, since the names and folders are the publisher's to choose.
2. Guess the visitor's system (`navigator.userAgentData.platform` where available, else `navigator.userAgent`): macOS, Windows, Linux, or something else (a phone: link to the App Store and Google Play instead).
3. Show one main button for that system and smaller links for the other two, each with the version and the size (`size` in MB).
   - macOS: `macos.url`.
   - Windows: `windows.url` (a zip: unpack and run). The Microsoft Store listing is the other Windows option.
   - Linux: `linux.deb.url` as the main button, `linux.tar.url` as the alternative, labelled with `arch`.
4. **No `macos` key**: there is no DMG for this version yet. Hide the macOS download, or send macOS visitors to the Mac App Store instead. Don't fall back to an older DMG.
5. Ignore fields you don't know; more may be added. Treat any missing platform as "not available", the same way as `macos`.
6. If the fetch fails (network, or a 404), show the page without download buttons and a short "downloads are unavailable right now" note. For the beta channel a 404 is normal: no beta was published in the last 30 days, so hide the beta section.
7. Optionally show `sha256` (or link `SHA256SUMS`) for people who check their download.

### Caching

- `versions.json` is sent with `Cache-Control: no-cache`: browsers and caches ask the server each time and get a cheap `304 Not Modified` while it is unchanged, so a new release shows up at once. Don't cache it in the site's own service worker or CDN for more than a minute, and don't bake it into the site at build time unless the site is rebuilt on every release.
- The packages are sent with `Cache-Control: public, max-age=31536000, immutable`: a URL always serves the same bytes, so anything may cache them for a year. A new release always comes with new URLs.
- Packages are sent with `Content-Disposition: attachment`, so a plain `<a href>` downloads them; no `download` attribute is needed.
- Link the URLs without query strings; the cache keys on the path only.
- The CDN allows cross-origin reads only from the website's origins. A new origin (preview site, new domain) has to be added to the server's CORS settings first.
