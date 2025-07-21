# Fast Duplicate Finder - Flutter App Design Document

## Overview
A desktop Flutter application for finding and managing duplicate files across Windows, Linux, and macOS platforms. The app provides a clean, efficient Material 3 interface optimized for mouse and keyboard interaction in landscape orientation.

## Target Platforms
- **Primary**: Windows, Linux, macOS
- **Orientation**: Landscape (fixed)
- **Input**: Mouse and keyboard optimized
- **UI Framework**: Material 3

## Application Architecture

### State Management
- **Provider Pattern**: Using `ChangeNotifier` for state management
- **Main Provider**: `ScanProvider` - manages scan state, progress, and results
- **Services**: `FastDupeFinderService` - interfaces with the Go library

### Navigation Structure
```
SplashScreen (2-3 seconds)
    ↓
HomeScreen (Main Screen)
    ↓ (after scan completion)
ResultsScreen (Report Screen)
```

## Screen Specifications

### 1. Splash Screen (`splash_screen.dart`)
**Purpose**: App initialization and branding
**Duration**: 2-3 seconds
**Components**:
- App logo/icon (centered)
- App name "Fast Duplicate Finder"
- Loading indicator (circular progress)
- Version info (bottom)

**Layout**:
```
┌─────────────────────────────────────┐
│                                     │
│            [APP LOGO]               │
│       Fast Duplicate Finder        │
│                                     │
│         [Loading Spinner]           │
│                                     │
│                                v1.0 │
└─────────────────────────────────────┘
```

### 2. Home Screen (`home_screen.dart`)
**Purpose**: Root folder selection and scan initiation

#### Initial State Components:
- **Header**: App title and subtitle
- **Folder Selector**: 
  - Text field showing selected path
  - "Browse" button to open folder picker
  - Clear button (X) when folder is selected
- **Scan Button**: Primary action button (disabled until folder selected)

#### Scanning State Components:
- **Progress Section** (replaces scan button):
  - Phase indicator: "Phase X of 5"
  - File count: "Processed: X files"
  - Horizontal progress bar (0-100%)
  - Cancel button (X) on the right
- **Status Text**: Current operation description

**Layout - Initial State**:
```
┌─────────────────────────────────────────────────────────┐
│  Fast Duplicate Finder                                  │
│  Find and manage duplicate files efficiently            │
│                                                         │
│  Select Root Folder:                                    │
│  ┌─────────────────────────────────┐ [Browse] [X]      │
│  │ /path/to/selected/folder        │                    │
│  └─────────────────────────────────┘                    │
│                                                         │
│                   [Start Scan]                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Layout - Scanning State**:
```
┌─────────────────────────────────────────────────────────┐
│  Fast Duplicate Finder                                  │
│  Scanning: /path/to/selected/folder                     │
│                                                         │
│  Phase 3 of 5 - Building file index                    │
│  Processed: 15,247 files                               │
│                                                         │
│  ████████████████████░░░░░░░░░░  60%              [X]   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3. Results Screen (`results_screen.dart`)
**Purpose**: Display scan results and manage duplicates

#### Components:
- **Header**: 
  - Scan summary (total duplicates, space wasted)
  - "New Scan" button
- **Results List**:
  - Grouped by duplicate sets
  - Each group shows folder/file icon, name, path
  - Space usage bar with size text
  - Action buttons: Delete, Show in Explorer
- **Footer**: 
  - Total selected items
  - Bulk actions

**Layout**:
```
┌─────────────────────────────────────────────────────────┐
│  Scan Results - 45 duplicate groups found              │
│  Total wasted space: 2.3 GB              [New Scan]    │
│                                                         │
│  ┌─ Duplicate Group 1 ────────────────────────────┐    │
│  │ 📁 vacation_photos (3 copies)                  │    │
│  │ /home/user/Pictures/vacation_photos             │    │
│  │ ████████████████████████████ 450 MB            │    │
│  │                            [Delete] [Show] [☑]  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─ Duplicate Group 2 ────────────────────────────┐    │
│  │ 📄 document.pdf (2 copies)                     │    │
│  │ /home/user/Documents/document.pdf               │    │
│  │ ██████████ 15 MB                               │    │
│  │                            [Delete] [Show] [☑]  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  Selected: 2 items                    [Delete All]     │
└─────────────────────────────────────────────────────────┘
```

## Data Models

### 1. `ScanProgress` (`models/scan_progress.dart`)
```dart
class ScanProgress {
  final int currentPhase;      // 1-5
  final int totalPhases;       // Always 5
  final String phaseDescription;
  final int processedFiles;
  final double progressPercentage; // 0.0 - 1.0
  final bool isScanning;
  final bool isCompleted;
  final bool isCancelled;
}
```

### 2. `ScanResult` (`models/scan_result.dart`)
```dart
class ScanResult {
  final List<DuplicateGroup> duplicateGroups;
  final int totalDuplicates;
  final int totalWastedSpace; // in bytes
  final DateTime scanCompletedAt;
  final String scannedPath;
}
```

### 3. `ScanReport` (`models/scan_report.dart`)
```dart
class DuplicateGroup {
  final String id;
  final String fileName;
  final List<String> filePaths;
  final int fileSize; // in bytes
  final int duplicateCount;
  final FileType type; // file or folder
  final bool isSelected;
}

enum FileType { file, folder }
```

## Service Layer

### `FastDupeFinderService` (`services/fast_dupe_finder_service.dart`)
**Purpose**: Interface with Go library via FFI

#### Methods:
```dart
class FastDupeFinderService {
  // Start scan with progress callback
  Future<void> startScan(String rootPath, Function(ScanProgress) onProgress);
  
  // Cancel running scan
  Future<void> cancelScan();
  
  // Get final results
  Future<ScanResult> getResults();
  
  // Delete files/folders
  Future<bool> deleteItems(List<String> paths);
  
  // Open file in system explorer
  Future<void> showInExplorer(String path);
}
```

## Provider Layer

### `ScanProvider` (`providers/scan_provider.dart`)
**Purpose**: Centralized state management

#### Properties:
```dart
class ScanProvider extends ChangeNotifier {
  String? _selectedPath;
  ScanProgress? _currentProgress;
  ScanResult? _scanResult;
  bool _isScanning = false;
  
  // Getters
  String? get selectedPath;
  ScanProgress? get currentProgress;
  ScanResult? get scanResult;
  bool get isScanning;
  bool get canStartScan;
  
  // Methods
  void setSelectedPath(String path);
  Future<void> startScan();
  Future<void> cancelScan();
  void reset();
}
```

## UI Theme Specifications

### Material 3 Theme (`utils/app_theme.dart`)
```dart
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    // Desktop optimizations
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: MaterialStateProperty.all(true),
    ),
  );
  
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );
}
```

### Desktop Optimizations
- **Scrollbars**: Always visible for mouse users
- **Hover States**: Proper hover feedback on buttons/items
- **Context Menus**: Right-click support where appropriate
- **Keyboard Navigation**: Tab order and shortcuts

## Performance Considerations

### Efficiency Guidelines
1. **Lazy Loading**: Load results progressively for large datasets
2. **Virtual Scrolling**: Use `ListView.builder` for long lists
3. **Debounced Updates**: Limit progress update frequency (max 10/second)
4. **Memory Management**: Dispose of large objects promptly
5. **Native Integration**: Minimal FFI call overhead

### Responsive Design
- **Min Width**: 800px
- **Min Height**: 600px
- **Preferred**: 1200x800px
- **Scaling**: Support system font scaling

## File Structure
```
lib/
├── main.dart                     # App entry point
├── models/
│   ├── scan_progress.dart        # Progress tracking model
│   ├── scan_result.dart          # Results data model
│   └── scan_report.dart          # Report structure model
├── providers/
│   └── scan_provider.dart        # State management
├── screens/
│   ├── splash_screen.dart        # Initial loading screen
│   ├── home_screen.dart          # Main interaction screen
│   └── results_screen.dart       # Results display screen
├── services/
│   └── fast_dupe_finder_service.dart # Go library interface
├── utils/
│   └── app_theme.dart            # Material 3 theme config
└── widgets/
    └── scan_progress_widget.dart # Reusable progress component
```

## Integration with Go Backend

### FFI Interface
- **Library**: `libfastdupe.so` (Linux), `libfastdupe.dll` (Windows), `libfastdupe.dylib` (macOS)
- **Communication**: Progress callbacks via function pointers
- **Error Handling**: Structured error codes and messages
- **Memory Management**: Proper cleanup of native resources

### Phase Mapping
1. **Phase 1**: Directory traversal
2. **Phase 2**: File size grouping
3. **Phase 3**: Hash calculation
4. **Phase 4**: Duplicate detection
5. **Phase 5**: Report generation

## User Experience Flow

### Happy Path
1. **Launch** → Splash screen (2-3s) → Home screen
2. **Select Folder** → Browse button → Folder picker → Path displayed
3. **Start Scan** → Progress bar with phases → Real-time updates
4. **View Results** → Results screen → Duplicate groups listed
5. **Take Action** → Select items → Delete/Show → Confirmation dialogs

### Error Handling
- **Invalid Path**: Clear error message, reset to folder selection
- **Permission Denied**: Specific error with suggested solutions
- **Scan Interrupted**: Option to resume or start fresh
- **No Duplicates**: Positive feedback with scan summary

## Accessibility
- **Screen Reader**: Proper semantic labels and descriptions
- **Keyboard Navigation**: Full functionality without mouse
- **High Contrast**: Support system accessibility settings
- **Text Scaling**: Respect system font size preferences

## Development Phases

### Phase 1: Core Structure
- Basic navigation between screens
- State management setup
- Mock data integration

### Phase 2: Backend Integration
- FFI service implementation
- Real progress tracking
- Error handling

### Phase 3: UI Polish
- Material 3 theming
- Animations and transitions
- Desktop optimizations

### Phase 4: Platform Specific
- Native file dialogs
- System integration features
- Platform-specific testing

This design document provides a comprehensive foundation for implementing the Fast Duplicate Finder Flutter application with clean architecture, efficient performance, and excellent user experience across desktop platforms.
