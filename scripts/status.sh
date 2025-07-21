#!/bin/bash
# Project status and build information display

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_ROOT/VERSION"
NATIVE_LIB_DIR="$PROJECT_ROOT/flutter_app/fastdupefinder/lib/native"
BUILD_INFO="$NATIVE_LIB_DIR/build_info.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN} Fast Duplicate Finder - Project Status ${NC}"
echo -e "${CYAN}========================================${NC}"
echo

# Version Information
if [ -f "$VERSION_FILE" ]; then
    version=$(cat "$VERSION_FILE")
    echo -e "${GREEN}Version:${NC} $version"
else
    echo -e "${YELLOW}Version:${NC} Not found"
fi

# Git Information
if git rev-parse --git-dir >/dev/null 2>&1; then
    git_hash=$(git rev-parse --short HEAD)
    git_branch=$(git branch --show-current)
    git_status=$(git status --porcelain | wc -l)
    
    echo -e "${GREEN}Git Branch:${NC} $git_branch"
    echo -e "${GREEN}Git Hash:${NC} $git_hash"
    if [ "$git_status" -gt 0 ]; then
        echo -e "${YELLOW}Git Status:${NC} $git_status uncommitted changes"
    else
        echo -e "${GREEN}Git Status:${NC} Clean working directory"
    fi
fi

echo

# Build Status
echo -e "${BLUE}Build Status:${NC}"
if [ -d "$NATIVE_LIB_DIR" ]; then
    lib_count=$(find "$NATIVE_LIB_DIR" -name "libfastdupe.*" -not -name "*.h" | wc -l)
    echo -e "  Libraries: $lib_count deployed"
    
    for lib in "$NATIVE_LIB_DIR"/libfastdupe.*; do
        if [ -f "$lib" ] && [[ "$lib" != *.h ]]; then
            filename=$(basename "$lib")
            size=$(du -h "$lib" | cut -f1)
            echo -e "    📦 $filename ($size)"
        fi
    done
    
    if [ -f "$NATIVE_LIB_DIR/libfastdupe.h" ]; then
        echo -e "    📋 libfastdupe.h (header)"
    fi
else
    echo -e "  ${YELLOW}No libraries deployed${NC}"
fi

echo

# Build Info
if [ -f "$BUILD_INFO" ]; then
    echo -e "${BLUE}Last Build:${NC}"
    
    if command -v jq >/dev/null 2>&1; then
        build_time=$(jq -r '.build_time' "$BUILD_INFO")
        build_version=$(jq -r '.version' "$BUILD_INFO")
        build_hash=$(jq -r '.git_hash' "$BUILD_INFO")
        platform_count=$(jq '.platforms | length' "$BUILD_INFO")
        
        echo -e "  Time: $build_time"
        echo -e "  Version: $build_version"
        echo -e "  Git Hash: $build_hash"
        echo -e "  Platforms: $platform_count built"
        
        echo -e "  Platform Details:"
        jq -r '.platforms[] | "    \(.platform)-\(.arch): \(.size) bytes"' "$BUILD_INFO"
    else
        echo -e "  Build info available (install jq for details)"
        echo -e "  File: $BUILD_INFO"
    fi
else
    echo -e "  ${YELLOW}No build info available${NC}"
fi

echo

# Available Scripts
echo -e "${BLUE}Available Scripts:${NC}"
echo -e "  ./scripts/build_and_deploy.sh    ${GREEN}# Full cross-platform build${NC}"
echo -e "  ./scripts/quick_build.sh         ${GREEN}# Quick build for current platform${NC}"
echo -e "  ./scripts/status.sh              ${GREEN}# Show this status (current script)${NC}"

echo

# Usage Examples
echo -e "${BLUE}Common Commands:${NC}"
echo -e "  ${GREEN}# Quick development build${NC}"
echo -e "  ./scripts/quick_build.sh"
echo
echo -e "  ${GREEN}# Full release build with version bump${NC}"
echo -e "  ./scripts/build_and_deploy.sh --version-bump minor --clean"
echo
echo -e "  ${GREEN}# Build specific platform${NC}"
echo -e "  ./scripts/build_and_deploy.sh --platform linux"
echo
echo -e "  ${GREEN}# Clean build without deployment${NC}"
echo -e "  ./scripts/build_and_deploy.sh --clean --no-deploy"

echo

# Flutter Integration Status  
echo -e "${BLUE}Flutter Integration:${NC}"
flutter_dir="$PROJECT_ROOT/flutter_app/fastdupefinder"
if [ -d "$flutter_dir" ]; then
    echo -e "  Flutter App: ${GREEN}Found${NC}"
    
    if [ -f "$flutter_dir/lib/bindings/duplicate_finder_bindings.dart" ]; then
        echo -e "  FFI Bindings: ${GREEN}Available${NC}"
    else
        echo -e "  FFI Bindings: ${YELLOW}Not found${NC}"
    fi
    
    if [ $lib_count -gt 0 ]; then
        echo -e "  Ready to run: ${GREEN}Yes${NC}"
        echo -e "    cd flutter_app/fastdupefinder && flutter run"
    else
        echo -e "  Ready to run: ${YELLOW}No (run build script first)${NC}"
    fi
else
    echo -e "  Flutter App: ${YELLOW}Not found${NC}"
fi

echo
