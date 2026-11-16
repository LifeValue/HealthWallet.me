#!/usr/bin/env bash
# Packages a Linux release build as a .deb and a portable tarball, in build/linux/packages/.
# Build first, on Ubuntu 24.04 or newer (llamadart's libraries need glibc 2.38):
#   fvm flutter build linux --release --target lib/main_desktop.dart
#   scripts/package_linux.sh
# The CI job linux:snap runs the same steps, then packs the bundle as a snap (snap/snapcraft.yaml).
set -euo pipefail
cd "$(dirname "$0")/.."

app_id=com.techstackapps.healthwallet # APPLICATION_ID in linux/CMakeLists.txt
package=healthwallet
version=$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)
arch=$(dpkg --print-architecture) # amd64 or arm64
case "$arch" in
amd64) flutter_arch=x64 ;;
arm64) flutter_arch=arm64 ;;
*)
  echo "Unsupported architecture: $arch" >&2
  exit 1
  ;;
esac

bundle=build/linux/$flutter_arch/release/bundle
if [ ! -x "$bundle/health_wallet" ]; then
  echo "No release build in $bundle; run fvm flutter build linux --release --target lib/main_desktop.dart" >&2
  exit 1
fi

out=build/linux/packages
rm -rf "$out"
mkdir -p "$out"

# Portable: unpack anywhere and run HealthWallet/health_wallet. The system libraries the .deb
# depends on must be installed.
tarball=HealthWallet-Linux-v$version-$arch.tar.gz
staging=$out/tarball/HealthWallet
mkdir -p "$staging"
cp -a "$bundle/." "$staging/"
tar -C "$out/tarball" -czf "$out/$tarball" HealthWallet
rm -rf "$out/tarball"

# .deb: the bundle in /opt, a launcher and an icon. Ubuntu 24.04 and Debian 13 or newer.
deb=HealthWallet-Linux-v$version-$arch.deb
root=$out/deb
mkdir -p "$root/DEBIAN" "$root/opt/$package" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle/." "$root/opt/$package/"
ln -s "/opt/$package/health_wallet" "$root/usr/bin/$package"
cp linux/runner/resources/app_icon.png "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

cat >"$root/usr/share/applications/$app_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=HealthWallet.me
GenericName=Health Records
Comment=Patient-controlled health records, synced with your phone
Exec=/opt/$package/health_wallet
Icon=$app_id
Terminal=false
Categories=Office;MedicalSoftware;
StartupWMClass=$app_id
EOF

installed_size=$(du -sk "$root" | cut -f1)
# Flutter draws through EGL and GLES; libsecret keeps the pairing keys in the desktop's
# keyring (GNOME Keyring or KWallet); Avahi announces the desktop to the phone; Tesseract is the
# OCR engine (the runner links it), with English always and the app's other languages when
# installed; Vulkan lets llama.cpp use the GPU.
cat >"$root/DEBIAN/control" <<EOF
Package: $package
Version: $version
Architecture: $arch
Maintainer: Life Value <ciagent@lifevalue.com>
Installed-Size: $installed_size
Section: misc
Priority: optional
Homepage: https://healthwallet.me
Depends: libc6 (>= 2.39), libstdc++6 (>= 13.2), libgtk-3-0t64 | libgtk-3-0, libegl1, libgles2, libsecret-1-0, libayatana-appindicator3-1, libtesseract5, tesseract-ocr-eng
Recommends: avahi-daemon, libvulkan1, tesseract-ocr-deu, tesseract-ocr-spa, tesseract-ocr-ron
Description: Patient-controlled health records
 HealthWallet.me keeps your health records on your own devices. The desktop
 app pairs with the HealthWallet.me phone app over your local network, syncs
 your records with it and reads scanned documents with on-device AI.
EOF

dpkg-deb --root-owner-group --build "$root" "$out/$deb" >/dev/null
rm -rf "$root"

echo "$out/$deb"
echo "$out/$tarball"
