#!/bin/bash
# Fast Duplicate Finder - Cross-Platform Build and Deploy Script
# Builds Go shared libraries for Linux, Windows, and macOS and deploys them to Flutter

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app/fastdupefinder"
BUILD_DIR="$BACKEND_DIR/build"
NATIVE_LIB_DIR="$FLUTTER_DIR/lib/native"

# Build configuration
GO_PACKAGE="./pkg/fastdupefinder/c_bindings/c_bindings.go"
LIBRARY_NAME="libfastdupe"

# Platform configurations: platform:arch:extension:cc_env
PLATFORMS=(
    "linux:amd64:so:"
    "windows:amd64:dll:x86_64-w64-mingw32-gcc"
    "darwin:amd64:dylib:"
)

# Version management
VERSION_FILE="$PROJECT_ROOT/VERSION"
PUBSPEC_FILE="$FLUTTER_DIR/pubspec.yaml"

# Functions
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_dependencies() {
    print_step "Checking build dependencies..."
    
    # Check Go
    if ! command -v go >/dev/null 2>&1; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    # Check CGO
    if [ "$(go env CGO_ENABLED)" != "1" ]; then
        print_error "CGO is not enabled. Set CGO_ENABLED=1"
        exit 1
    fi
    
    print_success "Go $(go version | cut -d' ' -f3) with CGO enabled"
    
    # Check cross-compilation tools
    local has_mingw=false
    local has_osxcross=false
    
    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        has_mingw=true
        print_success "MinGW-w64 found for Windows cross-compilation"
    else
        print_warning "MinGW-w64 not found - Windows builds will be skipped"
        print_warning "Install with: sudo apt-get install gcc-mingw-w64-x86-64"
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]] || command -v o64-clang >/dev/null 2>&1; then
        has_osxcross=true
        print_success "macOS compilation tools available"
    else
        print_warning "macOS cross-compilation tools not found - macOS builds will be skipped"
        print_warning "Run this script on macOS or set up osxcross for cross-compilation"
    fi
    
    echo
}

get_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    elif [ -f "$PUBSPEC_FILE" ]; then
        grep "^version:" "$PUBSPEC_FILE" | cut -d' ' -f2 | cut -d'+' -f1
    else
        echo "1.0.0"
    fi
}

bump_version() {
    local current_version=$(get_version)
    local version_parts=(${current_version//./ })
    local major=${version_parts[0]}
    local minor=${version_parts[1]}
    local patch=${version_parts[2]}
    
    case $1 in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch|*)
            patch=$((patch + 1))
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    echo "$new_version" > "$VERSION_FILE"
    
    # Update pubspec.yaml if it exists
    if [ -f "$PUBSPEC_FILE" ]; then
        sed -i "s/^version:.*/version: $new_version+1/" "$PUBSPEC_FILE"
    fi
    
    print_success "Version bumped: $current_version → $new_version"
    echo "$new_version"
}

setup_directories() {
    print_step "Setting up build directories..."
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Create Flutter native library directory
    mkdir -p "$NATIVE_LIB_DIR"
    
    print_success "Directories created"
}

build_platform() {
    local platform=$1
    local arch=$2
    local extension=$3
    local cc=$4
    local output_file="$BUILD_DIR/${LIBRARY_NAME}.${extension}"
    local platform_file="$BUILD_DIR/${LIBRARY_NAME}_${platform}_${arch}.${extension}"
    
    print_step "Building for $platform-$arch..."
    
    # Change to backend directory
    cd "$BACKEND_DIR"
    
    # Set build environment
    export GOOS=$platform
    export GOARCH=$arch
    export CGO_ENABLED=1
    
    if [ -n "$cc" ]; then
        export CC=$cc
    else
        unset CC
    fi
    
    # Build the shared library
    if go build -buildmode=c-shared -o "$output_file" "$GO_PACKAGE"; then
        # Create platform-specific copy
        cp "$output_file" "$platform_file"
        cp "${output_file%.*}.h" "${platform_file%.*}.h" 2>/dev/null || true
        
        print_success "Built $platform-$arch library ($(du -h "$output_file" | cut -f1))"
        
        # Show build info
        if [ "$platform" = "linux" ] && command -v file >/dev/null 2>&1; then
            file "$output_file" | cut -d':' -f2-
        fi
        
        return 0
    else
        print_error "Failed to build for $platform-$arch"
        return 1
    fi
}

deploy_to_flutter() {
    print_step "Deploying libraries to Flutter project..."
    
    local deployed=0
    
    # Deploy each platform's library
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -ra CONFIG <<< "$platform_config"
        local platform=${CONFIG[0]}
        local arch=${CONFIG[1]}
        local extension=${CONFIG[2]}
        local cc=${CONFIG[3]}
        
        local build_file="$BUILD_DIR/${LIBRARY_NAME}.${extension}"
        local deploy_file="$NATIVE_LIB_DIR/${LIBRARY_NAME}.${extension}"
        
        if [ -f "$build_file" ]; then
            cp "$build_file" "$deploy_file"
            print_success "Deployed $platform library → lib/native/"
            deployed=$((deployed + 1))
        fi
    done
    
    # Deploy header file
    local header_file="$BUILD_DIR/${LIBRARY_NAME}.h"
    if [ -f "$header_file" ]; then
        cp "$header_file" "$NATIVE_LIB_DIR/"
        print_success "Deployed header file → lib/native/"
    fi
    
    if [ $deployed -gt 0 ]; then
        print_success "Successfully deployed $deployed platform libraries"
        
        # Show what was deployed
        echo
        print_step "Deployed files:"
        ls -la "$NATIVE_LIB_DIR"/ | grep "libfastdupe"
    else
        print_warning "No libraries were deployed"
    fi
}

create_build_info() {
    local version=$1
    local build_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    cat > "$NATIVE_LIB_DIR/build_info.json" << EOF
{
  "version": "$version",
  "build_time": "$build_time",
  "git_hash": "$git_hash",
  "platforms": [
$(for platform_config in "${PLATFORMS[@]}"; do
    IFS=':' read -ra CONFIG <<< "$platform_config"
    local platform=${CONFIG[0]}
    local arch=${CONFIG[1]}
    local extension=${CONFIG[2]}
    local build_file="$BUILD_DIR/${LIBRARY_NAME}.${extension}"
    if [ -f "$build_file" ]; then
        local size=$(stat -f%z "$build_file" 2>/dev/null || stat -c%s "$build_file" 2>/dev/null || echo "0")
        echo "    {\"platform\": \"$platform\", \"arch\": \"$arch\", \"size\": $size},"
    fi
done | sed '$ s/,$//')
  ]
}
EOF
    
    print_success "Created build info file"
}

clean_build() {
    print_step "Cleaning previous build artifacts..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"/*
    fi
    
    if [ -d "$NATIVE_LIB_DIR" ]; then
        rm -f "$NATIVE_LIB_DIR"/libfastdupe.*
        rm -f "$NATIVE_LIB_DIR"/build_info.json
    fi
    
    print_success "Build directory cleaned"
}

show_usage() {
    echo "Fast Duplicate Finder - Build and Deploy Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --clean           Clean build artifacts before building"
    echo "  --version-bump    Bump version (patch, minor, major)"
    echo "  --no-deploy       Build only, don't deploy to Flutter"
    echo "  --platform        Build specific platform (linux,windows,darwin)"
    echo "  --help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0                          # Build all platforms and deploy"
    echo "  $0 --clean                  # Clean and build all platforms"
    echo "  $0 --version-bump minor     # Bump minor version and build"
    echo "  $0 --platform linux         # Build only Linux version"
    echo "  $0 --no-deploy              # Build without deploying to Flutter"
}

# Main script
main() {
    local clean_build_flag=false
    local deploy_flag=true
    local version_bump=""
    local target_platform=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_build_flag=true
                shift
                ;;
            --version-bump)
                version_bump="$2"
                shift 2
                ;;
            --no-deploy)
                deploy_flag=false
                shift
                ;;
            --platform)
                target_platform="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Print header
    print_header "Fast Duplicate Finder - Build & Deploy"
    
    echo -e "${PURPLE}Project: $PROJECT_ROOT${NC}"
    echo -e "${PURPLE}Backend: $BACKEND_DIR${NC}"
    echo -e "${PURPLE}Flutter: $FLUTTER_DIR${NC}"
    echo
    
    # Check dependencies
    check_dependencies
    
    # Clean if requested
    if [ "$clean_build_flag" = true ]; then
        clean_build
        echo
    fi
    
    # Bump version if requested
    local version=$(get_version)
    if [ -n "$version_bump" ]; then
        version=$(bump_version "$version_bump")
        echo
    fi
    
    print_step "Building version: $version"
    echo
    
    # Setup directories
    setup_directories
    echo
    
    # Build platforms
    print_header "Building Libraries"
    
    local build_count=0
    local success_count=0
    
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -ra CONFIG <<< "$platform_config"
        local platform=${CONFIG[0]}
        local arch=${CONFIG[1]}
        local extension=${CONFIG[2]}
        local cc=${CONFIG[3]}
        
        # Skip if specific platform requested and this isn't it
        if [ -n "$target_platform" ] && [ "$platform" != "$target_platform" ]; then
            continue
        fi
        
        # Check if cross-compilation tools are available
        if [ "$platform" = "windows" ] && [ -n "$cc" ] && ! command -v "$cc" >/dev/null 2>&1; then
            print_warning "Skipping $platform-$arch (cross-compiler not found: $cc)"
            continue
        fi
        
        if [ "$platform" = "darwin" ] && [[ "$OSTYPE" != "darwin"* ]] && ! command -v o64-clang >/dev/null 2>&1; then
            print_warning "Skipping $platform-$arch (macOS cross-compilation not available)"
            continue
        fi
        
        build_count=$((build_count + 1))
        
        if build_platform "$platform" "$arch" "$extension" "$cc"; then
            success_count=$((success_count + 1))
        fi
        echo
    done
    
    # Report build results
    print_header "Build Results"
    
    if [ $success_count -eq $build_count ] && [ $build_count -gt 0 ]; then
        print_success "All $build_count platform(s) built successfully!"
    elif [ $success_count -gt 0 ]; then
        print_warning "$success_count of $build_count platform(s) built successfully"
    else
        print_error "No platforms were built successfully"
        exit 1
    fi
    
    # Deploy to Flutter
    if [ "$deploy_flag" = true ] && [ $success_count -gt 0 ]; then
        echo
        print_header "Deploying to Flutter"
        deploy_to_flutter
        create_build_info "$version"
    fi
    
    # Final summary
    echo
    print_header "Summary"
    echo -e "${GREEN}Version:     $version${NC}"
    echo -e "${GREEN}Built:       $success_count/$build_count platforms${NC}"
    echo -e "${GREEN}Deployed:    $([ "$deploy_flag" = true ] && echo "Yes" || echo "No")${NC}"
    echo -e "${GREEN}Location:    $NATIVE_LIB_DIR${NC}"
    
    if [ "$deploy_flag" = true ] && [ $success_count -gt 0 ]; then
        echo
        print_success "Libraries are ready for Flutter integration!"
        echo -e "${CYAN}💡 Run your Flutter app with: cd $FLUTTER_DIR && flutter run${NC}"
    fi
}

# Run main function with all arguments
main "$@"
