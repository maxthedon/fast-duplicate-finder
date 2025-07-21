#!/bin/bash
# Quick development build - builds only for current platform
# This is a simplified wrapper around build_and_deploy.sh for development use

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect current platform
case "$OSTYPE" in
    linux*)     PLATFORM="linux" ;;
    darwin*)    PLATFORM="darwin" ;;
    msys*|win*) PLATFORM="windows" ;;
    *)          echo "Unsupported platform: $OSTYPE"; exit 1 ;;
esac

echo "🚀 Quick build for $PLATFORM platform..."
echo

# Run the main build script for current platform only
exec "$SCRIPT_DIR/build_and_deploy.sh" --platform "$PLATFORM" "$@"
