#!/usr/bin/env bash
set -euo pipefail

LLAMADART_VERSION="${LLAMADART_VERSION:-0.6.6}"
LLAMA_CPP_TAG="${LLAMA_CPP_TAG:-b8216}"
BUNDLE_NAME="android-arm64"
ARCHIVE_NAME="llamadart-native-${BUNDLE_NAME}-${LLAMA_CPP_TAG}.tar.gz"
DOWNLOAD_URL="https://github.com/leehack/llamadart-native/releases/download/${LLAMA_CPP_TAG}/${ARCHIVE_NAME}"

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG_DIR="$(find "$PUB_CACHE" -maxdepth 3 -type d -name "llamadart-${LLAMADART_VERSION}" 2>/dev/null | head -1)"
if [ -z "$PKG_DIR" ]; then
  echo "llamadart-${LLAMADART_VERSION} not found in pub cache, skipping."
  exit 0
fi

CACHE_DIR="$PKG_DIR/.dart_tool/llamadart/native_bundles/${LLAMA_CPP_TAG}/${BUNDLE_NAME}/extracted"

if [ ! -d "$CACHE_DIR" ]; then
  echo "Native bundle cache not found — downloading original bundle..."
  mkdir -p "$CACHE_DIR"
  curl -sL "$DOWNLOAD_URL" | tar xz -C "$CACHE_DIR"
  echo "Downloaded and extracted to $CACHE_DIR"
fi

NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_SDK_ROOT:-$ANDROID_HOME}/ndk/$(ls "${ANDROID_SDK_ROOT:-$ANDROID_HOME}/ndk/" 2>/dev/null | sort -V | tail -1)}"
OBJDUMP="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
if [ ! -f "$OBJDUMP" ]; then
  OBJDUMP="$NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objdump"
fi
if [ ! -f "$OBJDUMP" ]; then
  OBJDUMP="llvm-objdump"
fi

already_aligned=true
for so in "$CACHE_DIR"/*.so; do
  [ -f "$so" ] || continue
  align=$("$OBJDUMP" -p "$so" 2>/dev/null | grep "LOAD" | awk '{print $NF}' | sort -u | head -1)
  case "$align" in
    2\*\*14|2\*\*15|2\*\*16) ;;
    *) already_aligned=false; break ;;
  esac
done

if [ "$already_aligned" = true ]; then
  echo "All .so files already 16KB-aligned, nothing to do."
  exit 0
fi

echo "Rebuilding llamadart native libraries with 16KB page alignment..."

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

git clone --recursive --depth 1 --branch "$LLAMA_CPP_TAG" \
  https://github.com/leehack/llamadart-native.git "$BUILD_DIR/src" 2>&1

TOOLCHAIN="$NDK_HOME/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN" ]; then
  echo "ERROR: Android NDK toolchain not found at $TOOLCHAIN"
  exit 1
fi

NPROC="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"

cmake -B "$BUILD_DIR/build" -S "$BUILD_DIR/src" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DBUILD_SHARED_LIBS=ON \
  -DGGML_BACKEND_DL=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DGGML_LLAMAFILE=OFF \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DGGML_CPU_KLEIDIAI=ON \
  -DGGML_VULKAN=OFF \
  -DGGML_OPENCL=OFF \
  -DCMAKE_SHARED_LINKER_FLAGS="-s -Wl,-z,max-page-size=16384" \
  2>&1

cmake --build "$BUILD_DIR/build" --config Release -j"$NPROC" 2>&1

replaced=0
for so in $(find "$BUILD_DIR/build" -name "*.so" -type f); do
  name=$(basename "$so")
  target="$CACHE_DIR/$name"
  if [ -f "$target" ]; then
    cp "$so" "$target"
    replaced=$((replaced + 1))
  fi
done

for leftover in "$CACHE_DIR"/libggml-vulkan.so "$CACHE_DIR"/libggml-opencl.so; do
  if [ -f "$leftover" ]; then
    rm "$leftover"
    echo "Removed unaligned optional backend: $(basename "$leftover")"
  fi
done

echo "Replaced $replaced .so files with 16KB-aligned versions."
echo "16KB alignment fix complete."
