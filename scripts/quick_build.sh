#!/bin/bash
# Quick development build - builds only for current platform
# This is a simplified wrapper around build_and_deploy.sh for development use

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app/fastdupefinder"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

ensure_portal_disabled() {
    local my_app_file="$FLUTTER_DIR/linux/runner/my_application.cc"
    
    if [ ! -f "$my_app_file" ]; then
        print_warning "my_application.cc not found, skipping portal configuration"
        return
    fi
    
    print_step "Ensuring XDG desktop portal is disabled..."
    
    # Check if the portal disable line exists
    if grep -q "g_setenv(\"GTK_USE_PORTAL\", \"0\", TRUE);" "$my_app_file"; then
        print_success "Portal disable configuration already present"
        return
    fi
    
    print_warning "Portal disable configuration missing - will be added by main build script"
}

# Detect current platform
case "$OSTYPE" in
    linux*)     PLATFORM="linux" ;;
    darwin*)    PLATFORM="darwin" ;;
    msys*|win*) PLATFORM="windows" ;;
    *)          echo "Unsupported platform: $OSTYPE"; exit 1 ;;
esac

echo "🚀 Quick build for $PLATFORM platform..."
echo

# Check portal configuration before building
ensure_portal_disabled
echo

# Run the main build script for current platform only
exec "$SCRIPT_DIR/build_and_deploy.sh" --platform "$PLATFORM" "$@"
