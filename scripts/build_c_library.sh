#!/bin/bash
# Build script for creating C shared libraries for different platforms

set -e

PROJECT_ROOT=$(dirname "$0")/..
BINDINGS_DIR="$PROJECT_ROOT/pkg/fastdupefinder/c_bindings"
OUTPUT_DIR="$PROJECT_ROOT/build"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Building Fast Duplicate Finder C libraries..."

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local arch=$2
    local extension=$3
    local cc=$4
    local output_name="libfastdupe_${platform}_${arch}.${extension}"
    
    echo "Building for $platform-$arch..."
    
    if [ -n "$cc" ]; then
        GOOS=$platform GOARCH=$arch CGO_ENABLED=1 CC=$cc \
        go build -buildmode=c-shared \
        -o "$OUTPUT_DIR/$output_name" \
        "$BINDINGS_DIR/c_bindings.go"
    else
        GOOS=$platform GOARCH=$arch CGO_ENABLED=1 \
        go build -buildmode=c-shared \
        -o "$OUTPUT_DIR/$output_name" \
        "$BINDINGS_DIR/c_bindings.go"
    fi
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built $output_name"
        ls -la "$OUTPUT_DIR/$output_name"*
    else
        echo "✗ Failed to build $output_name"
    fi
    echo
}

# Build for Linux (current platform)
echo "=== Building for Linux ==="
build_platform "linux" "amd64" "so" ""

# Build for Windows (requires mingw-w64)
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "=== Building for Windows ==="
    build_platform "windows" "amd64" "dll" "x86_64-w64-mingw32-gcc"
else
    echo "⚠ Skipping Windows build (mingw-w64 not found)"
fi

# Build for macOS (if on macOS or with cross-compilation support)
if [[ "$OSTYPE" == "darwin"* ]] || command -v o64-clang >/dev/null 2>&1; then
    echo "=== Building for macOS ==="
    build_platform "darwin" "amd64" "dylib" ""
else
    echo "⚠ Skipping macOS build (not on macOS)"
fi

# Build for Android ARM64 (requires Android NDK)
if [ -n "$ANDROID_NDK_HOME" ] && [ -f "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" ]; then
    echo "=== Building for Android ARM64 ==="
    build_platform "android" "arm64" "so" "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"
else
    echo "⚠ Skipping Android build (Android NDK not found)"
fi

echo "=== Build Summary ==="
echo "Built libraries in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR/"

echo ""
echo "=== Usage Instructions ==="
echo "1. Copy the appropriate library file to your Flutter project"
echo "2. Use the generated .h file for FFI bindings"
echo "3. Call FreeStringC() for any string returned by the library"
echo "4. Initialize with InitializeLibraryC() before use"
