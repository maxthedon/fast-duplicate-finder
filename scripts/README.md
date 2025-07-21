# Build and Deploy Documentation

This directory contains scripts for building and deploying the Fast Duplicate Finder Go libraries to the Flutter application.

## Main Script: `build_and_deploy.sh`

A comprehensive script that builds Go shared libraries for multiple platforms and deploys them to the Flutter app.

### Features

- **Cross-platform builds**: Linux, Windows, macOS support
- **Automatic deployment**: Copies libraries to Flutter `lib/native/` directory
- **Version management**: Automatic version bumping and tracking
- **Build validation**: Checks dependencies and build tools
- **Clean builds**: Option to clean previous artifacts
- **Selective building**: Build specific platforms only
- **Build metadata**: Creates build info with timestamps and checksums

### Usage

```bash
# Basic usage - build all platforms and deploy
./scripts/build_and_deploy.sh

# Clean build all platforms
./scripts/build_and_deploy.sh --clean

# Bump version and build
./scripts/build_and_deploy.sh --version-bump minor

# Build specific platform only
./scripts/build_and_deploy.sh --platform linux

# Build without deploying to Flutter
./scripts/build_and_deploy.sh --no-deploy

# Show help
./scripts/build_and_deploy.sh --help
```

### Version Bumping

The script supports semantic versioning with three bump types:

- `--version-bump patch` - Increments patch version (1.0.0 → 1.0.1)
- `--version-bump minor` - Increments minor version (1.0.1 → 1.1.0)  
- `--version-bump major` - Increments major version (1.1.0 → 2.0.0)

Versions are stored in:
- `/VERSION` file (primary)
- `flutter_app/fastdupefinder/pubspec.yaml` (automatically updated)

### Prerequisites

#### Required
- Go 1.19+ with CGO enabled (`CGO_ENABLED=1`)
- GCC or compatible C compiler for native platform

#### For Cross-compilation
- **Windows**: MinGW-w64 (`sudo apt-get install gcc-mingw-w64-x86-64`)
- **macOS**: Run on macOS system or set up osxcross

### Build Output

The script creates these artifacts:

#### Build Directory (`backend/build/`)
- Platform-specific libraries: `libfastdupe_linux_amd64.so`, `libfastdupe_windows_amd64.dll`, etc.
- Generic libraries: `libfastdupe.so`, `libfastdupe.dll`, `libfastdupe.dylib`
- Header files: `libfastdupe.h`

#### Flutter Deployment (`flutter_app/fastdupefinder/lib/native/`)
- `libfastdupe.so` - Linux library
- `libfastdupe.dll` - Windows library  
- `libfastdupe.dylib` - macOS library
- `libfastdupe.h` - C header file
- `build_info.json` - Build metadata

### Integration with Flutter

The deployed libraries are automatically detected by the Flutter app through the FFI bindings in:
- `lib/bindings/duplicate_finder_bindings.dart`

The binding code searches for libraries in this order:
1. `lib/native/libfastdupe.{so|dll|dylib}` (deployed by this script)
2. `./lib/native/libfastdupe.{so|dll|dylib}` (alternative path)
3. `../../backend/build/libfastdupe.{so|dll|dylib}` (development path)

### Build Information

Each build creates a `build_info.json` file with metadata:

```json
{
  "version": "1.0.0",
  "build_time": "2025-07-21 12:34:56 UTC",
  "git_hash": "abc1234",
  "platforms": [
    {"platform": "linux", "arch": "amd64", "size": 12345},
    {"platform": "windows", "arch": "amd64", "size": 13579}
  ]
}
```

### Troubleshooting

#### Common Issues

1. **CGO not enabled**
   ```bash
   export CGO_ENABLED=1
   ```

2. **Cross-compilation tools missing**
   - Install MinGW-w64 for Windows builds
   - Use macOS system for macOS builds

3. **Permission denied**
   ```bash
   chmod +x scripts/build_and_deploy.sh
   ```

4. **Go build failures**
   - Ensure you're running from project root
   - Check that backend/pkg/fastdupefinder/c_bindings/ exists

#### Debug Build Issues

```bash
# Verbose build with details
./scripts/build_and_deploy.sh --clean --platform linux

# Check Go environment
cd backend && go env

# Test manual build
cd backend && CGO_ENABLED=1 go build -buildmode=c-shared -o libfastdupe.so ./pkg/fastdupefinder/c_bindings/c_bindings.go
```

### CI/CD Integration

For automated builds, you can use:

```bash
# In CI/CD pipeline
./scripts/build_and_deploy.sh --version-bump patch --clean
```

The script returns appropriate exit codes:
- `0` - Success
- `1` - Build failure or missing dependencies

### Development Workflow

1. Make changes to Go source code in `backend/`
2. Run build script: `./scripts/build_and_deploy.sh`
3. Test in Flutter: `cd flutter_app/fastdupefinder && flutter run`
4. For releases: `./scripts/build_and_deploy.sh --version-bump minor --clean`

This replaces the need for automatic file watching and provides more control over the build and deployment process.
