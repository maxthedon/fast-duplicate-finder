#!/bin/bash
# Build script for creating C shared libraries for different platforms
# Now supports automated deployment to Flutter project

set -e

# Determine if we're running from project root or backend directory
if [ -d "pkg" ]; then
    # Running from backend directory - set paths relative to current location
    PROJECT_ROOT="."
    FLUTTER_ROOT="../flutter_app"
    BINDINGS_DIR="./pkg/fastdupefinder/c_bindings"
    OUTPUT_DIR="./build"
elif [ -d "backend/pkg" ]; then
    # Running from project root - set paths to backend subdirectory
    PROJECT_ROOT="./backend"
    FLUTTER_ROOT="./flutter_app"
    BINDINGS_DIR="./backend/pkg/fastdupefinder/c_bindings"
    OUTPUT_DIR="./backend/build"
else
    echo "❌ Error: Cannot find pkg directory. Run from project root or backend directory."
    exit 1
fi

# Flutter platform directories
FLUTTER_ANDROID_DIR="$FLUTTER_ROOT/android/app/src/main/jniLibs"
FLUTTER_IOS_DIR="$FLUTTER_ROOT/ios"
FLUTTER_WINDOWS_DIR="$FLUTTER_ROOT/windows"
FLUTTER_LINUX_DIR="$FLUTTER_ROOT/linux"
FLUTTER_MACOS_DIR="$FLUTTER_ROOT/macos"
FLUTTER_APP_DIR="$FLUTTER_ROOT/fastdupefinder"

# Function to ensure XDG portal is disabled in Flutter Linux app
ensure_portal_disabled() {
    local my_app_file="$FLUTTER_APP_DIR/linux/runner/my_application.cc"
    
    if [ ! -f "$my_app_file" ]; then
        echo "⚠️  my_application.cc not found, skipping portal configuration"
        return
    fi
    
    echo "🔧 Ensuring XDG desktop portal is disabled..."
    
    # Check if the portal disable line exists in startup function
    if grep -q "g_setenv(\"GTK_USE_PORTAL\", \"0\", TRUE);" "$my_app_file"; then
        echo "✅ Portal disable configuration already present"
        return
    fi
    
    # Check if startup function exists
    if ! grep -q "static void my_application_startup(GApplication\* application)" "$my_app_file"; then
        echo "⚠️  my_application_startup function not found, cannot configure portal"
        return
    fi
    
    # Add the portal disable line to startup function
    echo "🔧 Adding portal disable configuration to my_application.cc..."
    
    # Create a backup
    cp "$my_app_file" "$my_app_file.backup.$(date +%s)"
    
    # Use sed to add the line after the startup function opening
    sed -i '/static void my_application_startup(GApplication\* application) {/,/G_APPLICATION_CLASS(my_application_parent_class)->startup(application);/ {
        /G_APPLICATION_CLASS(my_application_parent_class)->startup(application);/i\
  // Set environment variable to disable XDG desktop portal\
  g_setenv("GTK_USE_PORTAL", "0", TRUE);\

    }' "$my_app_file"
    
    if grep -q "g_setenv(\"GTK_USE_PORTAL\", \"0\", TRUE);" "$my_app_file"; then
        echo "✅ Successfully added portal disable configuration"
    else
        echo "❌ Failed to add portal disable configuration"
        # Restore backup if available
        if [ -f "$my_app_file.backup.$(date +%s)" ]; then
            mv "$my_app_file.backup.$(date +%s)" "$my_app_file" 2>/dev/null || true
        fi
    fi
}

# Create output directories
mkdir -p "$OUTPUT_DIR"

echo "🏗️  Building Fast Duplicate Finder C libraries..."
echo "📁 Backend: $PROJECT_ROOT"
echo "📱 Flutter: $FLUTTER_ROOT"

# Ensure portal is disabled for Linux builds
ensure_portal_disabled
echo

# Flag to control Flutter deployment
DEPLOY_TO_FLUTTER=${DEPLOY_TO_FLUTTER:-true}

if [ "$DEPLOY_TO_FLUTTER" = "true" ]; then
    echo "🚀 Automatic Flutter deployment enabled"
    # Create Flutter platform directories
    mkdir -p "$FLUTTER_ANDROID_DIR/arm64-v8a"
    mkdir -p "$FLUTTER_ANDROID_DIR/x86_64"
    mkdir -p "$FLUTTER_IOS_DIR"
    mkdir -p "$FLUTTER_WINDOWS_DIR"
    mkdir -p "$FLUTTER_LINUX_DIR"
    mkdir -p "$FLUTTER_MACOS_DIR"
fi

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local arch=$2
    local extension=$3
    local cc=$4
    local flutter_deploy=${5:-false}
    local flutter_dest_dir=$6
    local output_name="libfastdupe_${platform}_${arch}.${extension}"
    
    echo "🔨 Building for $platform-$arch..."
    
    # Save current directory
    local original_dir=$(pwd)
    
    # Change to backend directory for build
    cd "$PROJECT_ROOT"
    
    if [ -n "$cc" ]; then
        GOOS=$platform GOARCH=$arch CGO_ENABLED=1 CC=$cc \
        go build -buildmode=c-shared \
        -o "$output_name" \
        "./pkg/fastdupefinder/c_bindings/c_bindings.go"
    else
        GOOS=$platform GOARCH=$arch CGO_ENABLED=1 \
        go build -buildmode=c-shared \
        -o "$output_name" \
        "./pkg/fastdupefinder/c_bindings/c_bindings.go"
    fi
    
    # Move the built file to the correct output directory
    if [ -f "$output_name" ]; then
        mkdir -p "$original_dir/$(dirname "$OUTPUT_DIR")"
        mv "$output_name" "$original_dir/$OUTPUT_DIR/"
        mv "${output_name%.so}.h" "$original_dir/$OUTPUT_DIR/" 2>/dev/null || true
        mv "${output_name%.dll}.h" "$original_dir/$OUTPUT_DIR/" 2>/dev/null || true
        mv "${output_name%.dylib}.h" "$original_dir/$OUTPUT_DIR/" 2>/dev/null || true
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_DIR/$output_name" ]; then
        echo "✅ Successfully built $output_name"
        ls -la "$OUTPUT_DIR/$output_name"*
        
        # Deploy to Flutter if requested
        if [ "$DEPLOY_TO_FLUTTER" = "true" ] && [ "$flutter_deploy" = "true" ] && [ -n "$flutter_dest_dir" ]; then
            deploy_to_flutter "$platform" "$arch" "$extension" "$flutter_dest_dir"
        fi
    else
        echo "❌ Failed to build $output_name"
        return 1
    fi
    echo
}

# Function to deploy built libraries to Flutter project
deploy_to_flutter() {
    local platform=$1
    local arch=$2
    local extension=$3
    local dest_dir=$4
    local source_file="$OUTPUT_DIR/libfastdupe_${platform}_${arch}.${extension}"
    local header_file="$OUTPUT_DIR/libfastdupe_${platform}_${arch}.h"
    
    if [ -f "$source_file" ] && [ -d "$dest_dir" ]; then
        echo "📱 Deploying to Flutter: $dest_dir"
        
        # Copy the library file
        cp "$source_file" "$dest_dir/"
        
        # Copy header file if it exists and it's the first deployment
        if [ -f "$header_file" ] && [ ! -f "$FLUTTER_ROOT/libfastdupe.h" ]; then
            cp "$header_file" "$FLUTTER_ROOT/"
            echo "📋 Header file copied to Flutter root"
        fi
        
        # Create a generic name for easier Flutter import
        local generic_name="libfastdupe.${extension}"
        if [ ! -f "$dest_dir/$generic_name" ]; then
            ln -sf "libfastdupe_${platform}_${arch}.${extension}" "$dest_dir/$generic_name"
            echo "🔗 Created generic link: $generic_name"
        fi
        
        echo "✅ Deployed $platform-$arch library to Flutter"
    else
        echo "⚠️  Skipping Flutter deployment (source or destination missing)"
    fi
}

# Build for Linux (current platform)
echo "=== 🐧 Building for Linux Desktop ==="
build_platform "linux" "amd64" "so" "" "true" "$FLUTTER_LINUX_DIR"

# Build for Android ARM64
echo "=== 🤖 Building for Android ARM64 ==="
if [ -n "$ANDROID_NDK_HOME" ] && [ -f "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" ]; then
    build_platform "android" "arm64" "so" "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" "true" "$FLUTTER_ANDROID_DIR/arm64-v8a"
else
    echo "⚠️ Skipping Android ARM64 build (Android NDK not found)"
    echo "💡 Set ANDROID_NDK_HOME to enable Android builds"
fi

# Build for Android x86_64 (emulator)
echo "=== 🤖 Building for Android x86_64 ==="
if [ -n "$ANDROID_NDK_HOME" ] && [ -f "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang" ]; then
    build_platform "android" "amd64" "so" "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang" "true" "$FLUTTER_ANDROID_DIR/x86_64"
else
    echo "⚠️ Skipping Android x86_64 build (Android NDK not found)"
fi

# Build for Windows (requires mingw-w64)
echo "=== 🪟 Building for Windows ==="
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    build_platform "windows" "amd64" "dll" "x86_64-w64-mingw32-gcc" "true" "$FLUTTER_WINDOWS_DIR"
else
    echo "⚠️ Skipping Windows build (mingw-w64 not found)"
    echo "💡 Install mingw-w64-gcc to enable Windows builds"
fi

# Build for macOS (if on macOS or with cross-compilation support)
echo "=== 🍎 Building for macOS ==="
if [[ "$OSTYPE" == "darwin"* ]] || command -v o64-clang >/dev/null 2>&1; then
    build_platform "darwin" "amd64" "dylib" "" "true" "$FLUTTER_MACOS_DIR"
else
    echo "⚠️ Skipping macOS build (not on macOS)"
    echo "💡 Build on macOS or set up cross-compilation for macOS builds"
fi

# Build for iOS (requires Xcode on macOS)
echo "=== 📱 Building for iOS ==="
if [[ "$OSTYPE" == "darwin"* ]] && command -v xcrun >/dev/null 2>&1; then
    # iOS builds require special handling for static libraries
    echo "🍎 Building iOS static library..."
    cd "$PROJECT_ROOT"
    if CGO_ENABLED=1 GOOS=ios GOARCH=arm64 go build -buildmode=c-archive -o "$OUTPUT_DIR/libfastdupe_ios.a" "$BINDINGS_DIR/c_bindings.go" 2>/dev/null; then
        echo "✅ iOS static library built"
        if [ "$DEPLOY_TO_FLUTTER" = "true" ]; then
            cp "$OUTPUT_DIR/libfastdupe_ios.a" "$FLUTTER_IOS_DIR/"
            cp "$OUTPUT_DIR/libfastdupe_ios.h" "$FLUTTER_IOS_DIR/" 2>/dev/null || true
            echo "📱 iOS library deployed to Flutter"
        fi
    else
        echo "❌ iOS build failed"
    fi
    cd - > /dev/null
else
    echo "⚠️ Skipping iOS build (requires macOS with Xcode)"
fi

echo ""
echo "=== 📋 Build Summary ==="
echo "📁 Built libraries in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR/" 2>/dev/null || echo "No build directory found"

if [ "$DEPLOY_TO_FLUTTER" = "true" ]; then
    echo ""
    echo "=== 📱 Flutter Deployment Summary ==="
    echo "🚀 Libraries automatically deployed to Flutter project structure:"
    echo "   📂 Android: $FLUTTER_ANDROID_DIR/"
    echo "   📂 iOS: $FLUTTER_IOS_DIR/"
    echo "   📂 Windows: $FLUTTER_WINDOWS_DIR/"
    echo "   📂 Linux: $FLUTTER_LINUX_DIR/"
    echo "   📂 macOS: $FLUTTER_MACOS_DIR/"
    
    # Show what was actually deployed
    echo ""
    echo "📦 Deployed files:"
    find "$FLUTTER_ROOT" -name "libfastdupe*" -type f 2>/dev/null | sort || echo "No files deployed"
fi

echo ""
echo "=== 🔧 Usage Instructions ==="
echo "1. 🎯 Libraries are ready for Flutter FFI integration"
echo "2. 📋 Use libfastdupe.h for FFI bindings"
echo "3. 🧹 Always call FreeStringC() for returned strings"
echo "4. 🔄 Initialize with InitializeLibraryC() before use"
echo "5. 📱 Flutter project structure is pre-configured"

echo ""
echo "=== 🚀 Next Steps ==="
echo "1. Create Flutter project in: $FLUTTER_ROOT"
echo "2. Add FFI dependencies to pubspec.yaml"
echo "3. Implement Dart bindings using the integration guide"
echo "4. Test with your target directories"

echo ""
echo "💡 Tip: Set DEPLOY_TO_FLUTTER=false to skip automatic deployment"
echo "💡 Tip: Run from project root or backend directory"
