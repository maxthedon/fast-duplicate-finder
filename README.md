# Fast Dupe Finder

Fast Dupe Finder is a cross-platform desktop application for finding and managing duplicate files. It's built with a Go backend for high-performance file scanning and a Flutter frontend for a modern and responsive user interface.

## Features

- **High-Performance Backend**: Utilizes Go for efficient, multi-threaded file processing and hashing.
- **Cross-Platform UI**: A single Flutter codebase for Windows, Linux, and macOS.
- **5-Phase Scanning**: A detailed scanning process provides progress and transparency.
- **Duplicate Management**: Easily select and delete duplicate files.
- **Open Source**: Licensed under the GPLv3.

## Project Structure

This monorepo contains the following main components:

- `backend/`: The Go library that performs the file scanning.
- `flutter_app/`: The Flutter desktop application.
- `scripts/`: Build and deployment scripts to link the backend and frontend.

## Getting Started

### Prerequisites

- Go (1.19+ recommended)
- Flutter SDK (3.32.7+ recommended)
- A C compiler (like GCC) for building the Go shared library.

### Building and Running

1.  **Build the Go Library:**
    The Go backend needs to be compiled into a shared library (`.so`, `.dll`, or `.dylib`) that the Flutter app can use. A helper script is provided for this. From the project root:
    ```bash
    ./scripts/build_and_deploy.sh
    ```
    This script compiles the Go code and places the resulting library and header files into the `flutter_app/fastdupefinder/lib/native/` directory. For more details, see `scripts/README.md`.

2.  **Run the Flutter App:**
    Navigate to the Flutter project directory and run the app:
    ```bash
    cd flutter_app/fastdupefinder
    flutter pub get
    flutter run
    ```

## License

This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file for more details.
