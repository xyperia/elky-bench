#!/usr/bin/env bash
set -e

# ==============================================================================
# ElkyBench - Linux Build Script (ARM64 & x86_64)
# ==============================================================================

echo "=========================================================="
echo "  ElkyBench - Linux Release Builder"
echo "=========================================================="

HOST_ARCH="$(uname -m)"
TARGET_ARCH="${1:-$HOST_ARCH}"

echo "[*] Host architecture: $HOST_ARCH"
echo "[*] Target architecture: $TARGET_ARCH"

if [ "$TARGET_ARCH" = "x86_64" ] || [ "$TARGET_ARCH" = "amd64" ] || [ "$TARGET_ARCH" = "x86" ]; then
    ARCH_DIR="x64"
elif [ "$TARGET_ARCH" = "aarch64" ] || [ "$TARGET_ARCH" = "arm64" ] || [ "$TARGET_ARCH" = "arm" ]; then
    ARCH_DIR="arm64"
else
    ARCH_DIR="$TARGET_ARCH"
fi

echo "[*] Resolving dependencies..."
flutter pub get

echo "[*] Enabling Linux desktop support..."
flutter config --enable-linux-desktop >/dev/null 2>&1 || true

echo "[*] Building Linux release bundle..."
flutter build linux --release

BUNDLE_PATH="build/linux/$ARCH_DIR/release/bundle"

if [ -d "$BUNDLE_PATH" ]; then
    echo "=========================================================="
    echo "  BUILD SUCCESSFUL!"
    echo "  Bundle directory: $BUNDLE_PATH"
    echo "  Executable: $BUNDLE_PATH/elky_bench"
    echo "=========================================================="
else
    # Fallback search if path varies by Flutter version
    FOUND_BUNDLE=$(find build/linux -type f -name "elky_bench" 2>/dev/null | head -n 1 || true)
    if [ -n "$FOUND_BUNDLE" ]; then
        echo "=========================================================="
        echo "  BUILD SUCCESSFUL!"
        echo "  Executable: $FOUND_BUNDLE"
        echo "=========================================================="
    else
        echo "[-] Check build/linux/ for build artifacts."
    fi
fi
