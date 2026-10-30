#!/usr/bin/env bash
# Regenerates every icon and launch screen from the masters in branding/:
#   branding/app_icon_square.png              iOS and Android icons (full bleed)
#   branding/app_icon_rounded.png             macOS and Windows icons, launch screens
#   branding/android_adaptive_foreground.png  Android adaptive icon foreground
# Replace a master, run this script from anywhere, review and commit the result.
# Needs ImageMagick (`brew install imagemagick`) and FVM.
set -euo pipefail
cd "$(dirname "$0")/.."

# The launch screen layout, in logical pixels. AppLaunchScreen
# (lib/core/widgets/app_launch_screen.dart) draws the same layout in Flutter,
# so nothing moves when it replaces the native launch screen.
icon_pt=120       # AppLaunchScreen.iconSize
gap_pt=24         # Insets.medium
text_pt=24        # AppTextStyle.titleLarge fontSize
line_pt=28.8      # fontSize * height (1.2)
tracking_pt=-0.24 # letterSpacing
name='HealthWallet.me'
font=assets/font/matter-font/Matter-Medium.ttf # titleLarge is w500
light_text='#1E1E1E'                           # AppColors.textPrimary
dark_text='#FFFFFF'                            # AppColors.textPrimaryDark

scale=4 # flutter_native_splash reads its images as 4x
px() { awk -v v="$1" -v s="$scale" 'BEGIN { printf "%d", v * s + 0.5 }'; }

out=build/branding
mkdir -p "$out"
rounded=branding/app_icon_rounded.png

icon=$(px "$icon_pt")
width=$(px 240)
# The icon sits at the image's centre (the native launch screen centres the
# image); the name goes below it, and the image is symmetric around the icon.
text_top=$(px "$(awk -v i="$icon_pt" -v g="$gap_pt" 'BEGIN { print i / 2 + g }')")
line=$(px "$line_pt")
half=$((text_top + line))
height=$((half * 2))

splash_with_name() { # <text colour> <output>
  magick -size "${width}x${height}" xc:none \
    \( "$rounded" -resize "${icon}x${icon}" \) -gravity center -composite \
    \( -size "${width}x${line}" xc:none -font "$font" \
    -pointsize "$(px "$text_pt")" -kerning "$(awk -v t="$tracking_pt" -v s="$scale" 'BEGIN { print t * s }')" \
    -fill "$1" -gravity center -annotate +0+0 "$name" \) \
    -gravity center -geometry "+0+$((text_top + line / 2))" -composite \
    -depth 8 -strip "PNG32:$2"
}

echo "==> launch screen images ($out)"
splash_with_name "$light_text" "$out/splash_light.png"
splash_with_name "$dark_text" "$out/splash_dark.png"
# Android 12+ shows only an icon, cropped to a circle of 2/3 of a 288 dp
# canvas; the 120 dp icon stays inside it.
magick -size "$(px 288)x$(px 288)" xc:none \
  \( "$rounded" -resize "${icon}x${icon}" \) -gravity center -composite \
  -depth 8 -strip "PNG32:$out/splash_android12.png"

echo "==> in-app launch icon (assets/images/app_launch_icon.png)"
magick "$rounded" -resize 512x512 -depth 8 -strip PNG32:assets/images/app_launch_icon.png

echo "==> app icons (flutter_launcher_icons.yaml)"
fvm dart run flutter_launcher_icons -f flutter_launcher_icons.yaml

# flutter_launcher_icons rewrites every ASSETCATALOG_* line of the Xcode
# project with the icon name, including one that must stay YES.
sed -i '' 's/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;/' \
  ios/Runner.xcodeproj/project.pbxproj

echo "==> Windows icon (windows/runner/resources/app_icon.ico)"
magick "$rounded" -define icon:auto-resize=256,128,64,48,32,24,16 \
  windows/runner/resources/app_icon.ico

# iOS keeps a snapshot of the launch screen, and after an app update it can
# keep showing the old one while the image keeps the same name. The iOS launch
# image is therefore named after its pixels (LaunchImage-<hash>), so a new
# image gets a new name and updated apps show it without a reinstall or a
# restart of the phone. flutter_native_splash only knows "LaunchImage", so the
# plain name goes back before it runs and the content name after.
assets=ios/Runner/Assets.xcassets
storyboard=ios/Runner/Base.lproj/LaunchScreen.storyboard
for dir in "$assets"/LaunchImage-*.imageset; do
  if [ -d "$dir" ]; then mv "$dir" "$assets/LaunchImage.imageset"; fi
done
sed -i '' -E 's/"LaunchImage-[0-9a-f]{8}"/"LaunchImage"/g' "$storyboard"

echo "==> native launch screens (branding/splash.yaml)"
fvm dart run flutter_native_splash:create --path=branding/splash.yaml

echo "==> iOS launch image named after its content"
launch_image="LaunchImage-$(cat "$assets"/LaunchImage.imageset/*.png | shasum | cut -c1-8)"
mv "$assets/LaunchImage.imageset" "$assets/$launch_image.imageset"
sed -i '' "s/\"LaunchImage\"/\"$launch_image\"/g" "$storyboard"

# The generators rewrite some files they don't change (indentation only).
echo "==> dropping whitespace-only rewrites"
git diff --name-only -- android ios macos windows | while read -r file; do
  if git diff --quiet -w -- "$file"; then git checkout -- "$file"; fi
done

echo "Done. Review the changes with git status and git diff."
