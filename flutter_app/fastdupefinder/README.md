# Fast Duplicate Finder

A new Flutter project.

## Getting Started

# Fast Duplicate Finder

A cross-platform desktop Flutter application for finding and managing duplicate files efficiently across Windows, Linux, and macOS platforms.

## Features

- **Cross-Platform**: Runs on Windows, Linux, and macOS
- **Material 3 UI**: Modern, clean interface optimized for desktop use
- **Progressive Scanning**: 5-phase scanning process with real-time progress
- **Duplicate Management**: Select and delete duplicate files while keeping originals
- **Desktop Optimized**: Mouse and keyboard friendly with proper hover states
- **File Explorer Integration**: Open files in system file manager

## Architecture

- **State Management**: Provider pattern for reactive UI updates
- **Clean Architecture**: Separation of models, services, screens, and providers
- **Mock Backend**: Currently uses mock data for demonstration
- **FFI Ready**: Designed to integrate with Go library via Foreign Function Interface

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── models/                       # Data models
│   ├── scan_progress.dart        # Progress tracking
│   ├── scan_result.dart          # Scan results
│   └── scan_report.dart          # Duplicate groups
├── providers/
│   └── scan_provider.dart        # State management
├── screens/                      # UI screens
│   ├── splash_screen.dart        # Loading screen
│   ├── home_screen.dart          # Main interaction
│   └── results_screen.dart       # Results display
├── services/
│   └── fast_dupe_finder_service.dart # Backend interface
├── utils/
│   └── app_theme.dart            # Material 3 theming
└── widgets/
    └── scan_progress_widget.dart # Progress display
```

## Running the App

1. Ensure Flutter is installed and set up for desktop development
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on Linux:
   ```bash
   flutter run -d linux
   ```
4. Or use VS Code tasks (Ctrl+Shift+P > "Tasks: Run Task" > "Flutter Run (Linux)")

## Usage Flow

1. **Splash Screen**: 3-second loading screen with app branding
2. **Home Screen**: 
   - Select folder using "Browse" button
   - Click "Start Scan" to begin scanning
   - Watch real-time progress through 5 phases
3. **Results Screen**:
   - View duplicate groups with file sizes
   - Select items to delete (keeps one copy)
   - Use "Show" to open in file explorer
   - Bulk delete selected duplicates

## Mock Data

Currently uses mock data to demonstrate the UI:
- Simulates 5-phase scanning process
- Shows example duplicate groups (photos, documents, music)
- Mock file operations (actual deletion not implemented)

## Future Integration

The app is designed to integrate with a Go backend library:
- FFI interface for native performance
- Real file system scanning
- Actual file operations
- Platform-specific optimizations

## Development

- Built with Flutter 3.24.1+ 
- Uses Material 3 design system
- Provider for state management
- Desktop-first responsive design
- Comprehensive error handling

## Dependencies

- `provider`: State management
- `file_picker`: Folder selection dialog
- `path_provider`: File system paths
- `url_launcher`: System integration

## License

This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file in the root of the repository for more details.
