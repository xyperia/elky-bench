#!/usr/bin/env bash
set -e

# ==============================================================================
# ElkyBench - macOS Build Script (ARM64 & x86_64 / Universal)
# ==============================================================================

echo "=========================================================="
echo "  ElkyBench - macOS Release Builder"
echo "=========================================================="

TARGET_ARCH="${1:-auto}"
HOST_ARCH="$(uname -m)"

echo "[*] Host architecture: $HOST_ARCH"

if [ "$TARGET_ARCH" = "auto" ]; then
    echo "[*] Auto-detecting build target: Universal (ARM64 + x86_64)..."
    BUILD_MODE="universal"
elif [ "$TARGET_ARCH" = "arm" ] || [ "$TARGET_ARCH" = "arm64" ]; then
    echo "[*] Target architecture selected: Apple Silicon (ARM64)"
    BUILD_MODE="arm64"
elif [ "$TARGET_ARCH" = "x86" ] || [ "$TARGET_ARCH" = "x86_64" ] || [ "$TARGET_ARCH" = "intel" ]; then
    echo "[*] Target architecture selected: Intel (x86_64)"
    BUILD_MODE="x86_64"
elif [ "$TARGET_ARCH" = "universal" ]; then
    echo "[*] Target architecture selected: Universal Binary"
    BUILD_MODE="universal"
else
    echo "[-] Unknown architecture '$TARGET_ARCH'. Usage: ./osx_build.sh [arm64|x86_64|universal]"
    exit 1
fi

echo "[*] Resolving dependencies..."
flutter pub get

echo "[*] Building macOS release application..."

if [ "$BUILD_MODE" = "arm64" ]; then
    FLUTTER_XCODE_ARCHS="arm64" flutter build macos --release
elif [ "$BUILD_MODE" = "x86_64" ]; then
    FLUTTER_XCODE_ARCHS="x86_64" flutter build macos --release
else
    # Universal Binary contains both arm64 and x86_64 slices
    flutter build macos --release
fi

APP_PATH=$(find build/macos/Build/Products/Release -maxdepth 1 -name "*.app" | head -n 1)

if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    if [ -f "macos/Runner/AppIcon.icns" ]; then
        cp -f macos/Runner/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
    fi
    touch "$APP_PATH"
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH" 2>/dev/null || true

    echo "=========================================================="
    echo "  BUILD SUCCESSFUL!"
    echo "  Application bundle: $APP_PATH"
    echo "=========================================================="
    BINARY=$(find "$APP_PATH/Contents/MacOS" -type f -perm +111 2>/dev/null | head -n 1)
    if [ -n "$BINARY" ] && [ -f "$BINARY" ]; then
        echo "[*] Binary slices:"
        lipo -info "$BINARY" 2>/dev/null || file "$BINARY"
    fi
else
    echo "[-] Warning: App bundle not found at expected location: $APP_PATH"
fi
