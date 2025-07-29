# Fast Duplicate Finder

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support%20Development-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/maxthedon)
[![Release](https://img.shields.io/github/v/release/maxthedon/fast-dupe-finder?style=for-the-badge&logo=github)](https://github.com/maxthedon/fast-dupe-finder/releases/latest)
[![Build Status](https://img.shields.io/github/actions/workflow/status/maxthedon/fast-dupe-finder/release.yml?style=for-the-badge&logo=github-actions)](https://github.com/maxthedon/fast-dupe-finder/actions/workflows/release.yml)

**Quickly find and remove duplicate files to reclaim disk space!** 

Fast Duplicate Finder is a powerful, easy-to-use application that helps you identify and safely remove duplicate files and folders from your computer. Whether you have thousands of photos, documents, or other files, this tool will help you clean up your storage efficiently.

## 📥 Download

**Get the latest version for your platform:**

### 🖥️ **Recommended for Most Users: Desktop Applications (GUI)**

**GUI** means "Graphical User Interface" - these are **desktop apps with a visual interface**. Easy and quick to use with familiar buttons and menus.

- **🐧 Linux x64**: [Download fast-duplicate-finder-linux-x64-gui.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [Quick Start Guide](#step-2-run-the-application)
- **🪟 Windows x64**: [Download fast-duplicate-finder-windows-x64-gui.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [Quick Start Guide](#step-2-run-the-application)
- **🍎 macOS x64 (Intel)**: [Download fast-duplicate-finder-macos-x64-gui.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [Quick Start Guide](#step-2-run-the-application)
- **🍎 macOS ARM64 (Apple Silicon)**: [Download fast-duplicate-finder-macos-arm64-gui.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [Quick Start Guide](#step-2-run-the-application)

### ⚡ **For Advanced Users: Command Line Tools (CLI)**

**CLI** means "Command Line Interface" - these are **text-based tools**. You type commands in a terminal window.

- **🐧 Linux CLI**: [Download fast-duplicate-finder-linux-x64-cli.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [CLI Usage Guide](#-command-line-usage)
- **🪟 Windows CLI**: [Download fast-duplicate-finder-windows-x64-cli.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [CLI Usage Guide](#-command-line-usage)
- **🍎 macOS CLI x64**: [Download fast-duplicate-finder-macos-x64-cli.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [CLI Usage Guide](#-command-line-usage)
- **🍎 macOS CLI ARM64**: [Download fast-duplicate-finder-macos-arm64-cli.zip](https://github.com/maxthedon/fast-dupe-finder/releases/latest) → [CLI Usage Guide](#-command-line-usage)

> 🤔 **Not sure which one to choose?** 
> - **Most people prefer the GUI version** - visual interface with buttons and menus
> - **Choose CLI if** you prefer command-line tools or need automation

## 🚀 Quick Start Guide

> 💡 **New to this?** The **GUI (desktop app) version** is quick and easy to use!

### Step 1: Extract the ZIP File
1. **Download** the appropriate ZIP file for your platform from the [Download section](#-download) above
2. **Extract**: Right-click the downloaded ZIP file and select "Extract All" (Windows) or double-click (macOS/Linux)
3. **Choose location**: Extract to somewhere easy to find (e.g., Desktop, Applications folder, etc.)

### Step 2: Run the Application

#### 🖥️ **GUI (Desktop) Versions - Visual Interface:**
Works like any desktop program with buttons and menus.

- **🐧 Linux**: Open the extracted folder → Double-click `fastdupefinder` → The app opens
- **🪟 Windows**: Open the extracted folder → Double-click `fastdupefinder.exe` (or use `Run-Fast-Duplicate-Finder.bat`) → The app opens  
- **🍎 macOS**: Open the extracted folder → Double-click `fastdupefinder.app` → The app opens

#### ⚡ **CLI (Command Line) Versions - Terminal Interface:**
For users who prefer command-line tools.

- **🐧 Linux**: Open terminal in the extracted folder → Type `./fast-duplicate-finder` → Results show in terminal
- **🪟 Windows**: Open Command Prompt in the extracted folder → Type `fast-duplicate-finder.exe` → Results show in command window
- **🍎 macOS**: Open Terminal in the extracted folder → Type `./fast-duplicate-finder` → Results show in terminal

## � Quick Start Guide

### Step 1: Extract the ZIP File
1. Download the appropriate ZIP file for your platform from the links above
2. Right-click the downloaded ZIP file and select "Extract All" (Windows) or double-click (macOS/Linux)
3. Choose a location to extract the files (e.g., Desktop, Applications folder, etc.)

### Step 2: Run the Application

#### 🖥️ GUI (Desktop) Versions:
- **🐧 Linux**: Open the extracted folder and double-click `fastdupefinder` (or run `./fastdupefinder` in terminal)
- **🪟 Windows**: Open the extracted folder and double-click `fastdupefinder.exe` (or use the included `Run-Fast-Duplicate-Finder.bat`)
- **🍎 macOS**: Open the extracted folder and double-click `fastdupefinder.app`

#### ⚡ CLI (Command Line) Versions:
- **🐧 Linux**: Open terminal in the extracted folder and run `./fast-duplicate-finder`
- **🪟 Windows**: Open Command Prompt in the extracted folder and run `fast-duplicate-finder.exe`
- **🍎 macOS**: Open Terminal in the extracted folder and run `./fast-duplicate-finder`

### 💡 **Important Notes**:
- **Linux**: If you get a "Permission denied" error, make the file executable: `chmod +x fastdupefinder` or `chmod +x fast-duplicate-finder`
- **macOS**: You may see a security warning the first time. Right-click the app and select "Open", then click "Open" in the dialog
- **Windows**: All files are portable and require no installation. Windows may show a security warning - click "More info" then "Run anyway"
- **All platforms**: Each package includes a README.txt file with platform-specific instructions

## 🚀 What Does This Program Do?

Fast Duplicate Finder solves a common problem: **duplicate files wasting your storage space**. Over time, your computer accumulates duplicate files from:
- Repeated downloads
- Photo imports from cameras and phones  
- Document copies and backups
- Email attachments
- Syncing between devices

**This tool finds files that are truly identical** (not just similar names) and lets you safely remove the duplicates, freeing up valuable disk space.

## 🔍 How It Works - The Smart Way

Fast Duplicate Finder uses a **5-phase intelligent scanning process** that's both lightning-fast and highly accurate:

### Phase 1: File Discovery 🔎
Scans your selected folders and discovers all files, building a complete inventory of what's on your system.

### Phase 2: Size Grouping 📏
Groups files by size - if two files have different sizes, they can't be duplicates. This eliminates most files immediately, making the process much faster.

### Phase 3: Content Analysis 🧮
For files of the same size, calculates cryptographic hashes (digital fingerprints) to identify files with identical content. This is 100% accurate - no false positives.

### Phase 4: Folder Intelligence 📁
Analyzes entire folders to find folders that contain identical sets of files - helping you identify duplicate photo albums, backup folders, etc.

### Phase 5: Smart Results 🎯
Presents results in an organized way, showing you exactly which files are duplicates and how much space you can save.

**Why This Approach Works:**
- ✅ **Fast**: Most files are eliminated in Phase 2 (size comparison)
- ✅ **Accurate**: Cryptographic hashes ensure 100% accuracy
- ✅ **Safe**: You always choose what to delete - nothing is removed automatically
- ✅ **Smart**: Folder analysis finds patterns you might miss

## � Command Line Usage

Perfect for power users, automation, and scripting. The command line version runs the same smart algorithm as the desktop app.

### Basic Commands
```bash
# Scan a folder and see what duplicates exist
./fast-duplicate-finder /home/user/Documents

# Show live progress while scanning (great for large folders)  
./fast-duplicate-finder --progress /path/to/your/photos

# Get results in JSON format (perfect for scripts and automation)
./fast-duplicate-finder --json /path/to/scan > duplicates.json

# Quiet mode - only show the final results
./fast-duplicate-finder --quiet /path/to/scan
```

### Practical Examples
```bash
# Scan your entire home directory
./fast-duplicate-finder --progress ~/

# Find duplicates in your photos and save results to a file
./fast-duplicate-finder --json ~/Pictures > photo_duplicates.json

# Quick scan of Downloads folder
./fast-duplicate-finder ~/Downloads

# Scan external drive mounted at /media/backup
./fast-duplicate-finder /media/backup

# Windows users (after extracting CLI zip)
fast-duplicate-finder.exe --progress C:\Users\YourName\Documents
```

### Understanding the Output
The CLI shows:
- **File paths** of all duplicates found
- **File sizes** and how much space each duplicate group wastes
- **Total space** that can be recovered
- **Duplicate groups** organized by identical content



## 🎨 Desktop App Advanced Features

The desktop application provides a beautiful, intuitive interface that makes duplicate management easy for everyone.

### Core Features
- **📊 Visual Progress**: Watch the scan progress through all 5 phases with detailed statistics
- **🗂️ Smart Organization**: Results organized by duplicate groups, showing you exactly what's consuming space
- **🎯 Preview & Compare**: See file details, sizes, and paths before making decisions
- **✅ Batch Selection**: Select multiple files at once with smart selection tools
- **🛡️ Safe Deletion**: Move files to trash/recycle bin instead of permanent deletion

### Advanced Capabilities

#### ⚙️ Settings & Customization
- **CPU Usage Control**: Adjust how much processing power the scan uses
- **Memory Management**: Configure memory usage for optimal performance on your system
- **File Filtering**: Include or exclude specific file types, sizes, or locations
- **Scan Depth**: Control how deep into folder structures the scanner goes

#### 📁 Intelligent Folder Analysis
- **Duplicate Folders**: Find entire folders containing identical file sets
- **Partial Duplicates**: Identify folders with significant overlap
- **Nested Analysis**: Understand how duplicates are distributed across your folder structure
- **Size Visualization**: See at a glance which duplicate groups waste the most space

#### 🔄 Smart Selection Tools
- **Auto-Select by Rules**: Automatically select files based on criteria (oldest, newest, specific paths)
- **Keep Original Logic**: Smart algorithms suggest which copies to keep vs. delete
- **Path-Based Selection**: Select all duplicates from specific folders (like keeping files in "Important" over "Downloads")
- **Size-Based Rules**: Keep the largest file, or the one in the preferred location

#### 📈 Detailed Reporting
- **Space Recovery Estimates**: See exactly how much disk space you'll recover
- **File Type Breakdown**: Understand what types of files are duplicated most
- **Location Analysis**: Identify which folders contain the most duplicates
- **Historical Tracking**: Keep track of your cleanup progress over time

### Why Choose the Desktop App?
- **User-Friendly**: No command line knowledge needed
- **Visual**: See your files, don't just read paths
- **Safe**: Built-in safety features prevent accidental deletion
- **Efficient**: Bulk operations make cleaning up thousands of files quick and easy


## 🔧 Advanced: Build and Run From Source

Want to customize the application, contribute to development, or build it yourself? Here's everything you need to know.

### Prerequisites
- **Go 1.21+** with CGO enabled (run `go env CGO_ENABLED` - should return `1`)
- **Flutter 3.24+** with desktop development support
- **C Compiler**: 
  - Linux/macOS: GCC or Clang
  - Windows: MinGW-w64 for cross-compilation
  - Install with: `sudo apt install gcc build-essential` (Linux) or Xcode command line tools (macOS)

### Quick Development Setup
```bash
# 1. Clone the repository
git clone https://github.com/maxthedon/fast-dupe-finder.git
cd fast-dupe-finder

# 2. Quick build for your current platform (development mode)
./scripts/quick_build.sh

# 3. Run the Flutter desktop app
cd flutter_app/fastdupefinder
flutter pub get
flutter run -d linux    # or -d windows, -d macos
```

### Full Cross-Platform Build (Release Mode)

This builds optimized versions for all supported platforms:

```bash
# Build for all supported platforms with optimizations
./scripts/build_and_deploy.sh --clean

# Build with automatic version increment
./scripts/build_and_deploy.sh --version-bump minor --clean

# Build for specific platform only
./scripts/build_and_deploy.sh --platform linux --clean
./scripts/build_and_deploy.sh --platform windows --clean  
./scripts/build_and_deploy.sh --platform darwin --clean

# Build for specific architecture
./scripts/build_and_deploy.sh --arch amd64 --clean
./scripts/build_and_deploy.sh --arch arm64 --clean

# Build libraries only (no Flutter deployment)
./scripts/build_and_deploy.sh --no-deploy --clean
```

### Build Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `--clean` | Clean previous build artifacts before building | `./scripts/build_and_deploy.sh --clean` |
| `--version-bump` | Auto-increment version (patch/minor/major) | `--version-bump minor` |
| `--platform` | Build for specific platform (linux/windows/darwin) | `--platform linux` |
| `--arch` | Build for specific architecture (amd64/arm64) | `--arch arm64` |
| `--no-deploy` | Build C libraries without deploying to Flutter | `--no-deploy` |

### Platform-Specific Release Building

The release process builds the following packages:

#### Linux x64
- **GUI**: `fast-duplicate-finder-linux-x64-gui.zip` - Flutter application bundle in ZIP format
- **CLI**: `fast-duplicate-finder-linux-x64-cli.zip` - Command line executable in ZIP format
- Built on: Ubuntu 22.04 with GCC

#### Windows x64  
- **GUI**: `fast-duplicate-finder-windows-x64-gui.zip` - Flutter application bundle with launcher batch file
- **CLI**: `fast-duplicate-finder-windows-x64-cli.zip` - Executable (.exe) in ZIP format
- Built on: Windows latest with native tools

#### macOS x64 & ARM64
- **GUI**: `fast-duplicate-finder-macos-{arch}-gui.zip` - macOS app bundle (.app) in ZIP format
- **CLI**: `fast-duplicate-finder-macos-{arch}-cli.zip` - Command line executable in ZIP format
- Built on: macOS 13 (x64) and macOS 14 (ARM64)

### Development Workflow

1. **Make Backend Changes**: Edit Go code in `backend/`
2. **Quick Test**: Run `./scripts/quick_build.sh` to rebuild shared libraries
3. **Test Flutter App**: `cd flutter_app/fastdupefinder && flutter run`
4. **Full Build**: Run `./scripts/build_and_deploy.sh --clean` before releases

### File Structure
```
fast-dupe-finder/
├── backend/                 # Go backend with core logic
│   ├── main.go             # CLI application entry point  
│   ├── pkg/fastdupefinder/ # Core duplicate finding algorithm
│   └── build/              # Compiled shared libraries
├── flutter_app/            # Flutter frontend
│   └── fastdupefinder/     # Main Flutter project  
├── scripts/                # Build and deployment scripts
│   ├── build_and_deploy.sh # Cross-platform build script
│   └── quick_build.sh      # Development build script
└── .github/workflows/      # GitHub Actions for releases
    └── release.yml         # Automated release builds
```

### Troubleshooting Build Issues

**CGO not enabled**: `export CGO_ENABLED=1`
**Missing GCC**: Install with `sudo apt install build-essential gcc`
**Flutter not found**: Add Flutter to your PATH
**Permission denied**: Make scripts executable with `chmod +x scripts/*.sh`

### Contributing
1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test with `./scripts/quick_build.sh`
4. Run full build test: `./scripts/build_and_deploy.sh --clean`
5. Submit a pull request

## 📜 License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

**What this means:**
- ✅ You can use this software for any purpose
- ✅ You can study and modify the source code
- ✅ You can distribute copies of the software
- ✅ You can distribute modified versions
- ⚠️ If you distribute the software, you must provide source code
- ⚠️ Modified versions must also be licensed under GPL v3.0

---

**Made with ❤️ by [maxthedon](https://github.com/maxthedon)**
