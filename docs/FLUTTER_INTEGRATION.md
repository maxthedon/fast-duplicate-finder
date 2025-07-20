# Flutter Integration Guide for Fast Duplicate Finder

This guide explains how to integrate the Fast Duplicate Finder Go library into a Flutter application using FFI (Foreign Function Interface).

## Prerequisites

- Flutter SDK
- Go 1.19+ with CGO support
- GCC compiler for your target platform
- Built C shared library (`libfastdupe.so`, `libfastdupe.dll`, or `libfastdupe.dylib`)

## Step 1: Build the C Library

Run the build script to create the shared library:

```bash
# For Linux
CGO_ENABLED=1 go build -buildmode=c-shared -o libfastdupe.so pkg/fastdupefinder/c_bindings/c_bindings.go

# For Windows (with MinGW)
GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc go build -buildmode=c-shared -o libfastdupe.dll pkg/fastdupefinder/c_bindings/c_bindings.go

# For macOS
GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -buildmode=c-shared -o libfastdupe.dylib pkg/fastdupefinder/c_bindings/c_bindings.go
```

This generates:
- `libfastdupe.{so|dll|dylib}` - The shared library
- `libfastdupe.h` - C header file with function signatures

## Step 2: Add FFI Dependencies to Flutter

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.0.0
  path: ^1.8.0
```

## Step 3: Create Dart FFI Bindings

Create `lib/duplicate_finder_bindings.dart`:

```dart
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// C function type definitions
typedef InitializeLibraryCNative = ffi.Void Function();
typedef InitializeLibraryCDart = void Function();

typedef RunDuplicateFinderCNative = ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>);
typedef RunDuplicateFinderCDart = ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>);

typedef GetCurrentStatusCNative = ffi.Pointer<ffi.Utf8> Function();
typedef GetCurrentStatusCDart = ffi.Pointer<ffi.Utf8> Function();

typedef GetVersionCNative = ffi.Pointer<ffi.Utf8> Function();
typedef GetVersionCDart = ffi.Pointer<ffi.Utf8> Function();

typedef GetLogsCNative = ffi.Pointer<ffi.Utf8> Function(ffi.Int32);
typedef GetLogsCDart = ffi.Pointer<ffi.Utf8> Function(int);

typedef FreeStringCNative = ffi.Void Function(ffi.Pointer<ffi.Utf8>);
typedef FreeStringCDart = void Function(ffi.Pointer<ffi.Utf8>);

typedef IsRunningCNative = ffi.Int32 Function();
typedef IsRunningCDart = int Function();

class DuplicateFinderBindings {
  static DuplicateFinderBindings? _instance;
  late ffi.DynamicLibrary _dylib;
  
  // Function bindings
  late InitializeLibraryCDart initializeLibrary;
  late RunDuplicateFinderCDart runDuplicateFinder;
  late GetCurrentStatusCDart getCurrentStatus;
  late GetVersionCDart getVersion;
  late GetLogsCDart getLogs;
  late FreeStringCDart freeString;
  late IsRunningCDart isRunning;

  DuplicateFinderBindings._internal() {
    _loadLibrary();
    _bindFunctions();
  }

  static DuplicateFinderBindings get instance {
    _instance ??= DuplicateFinderBindings._internal();
    return _instance!;
  }

  void _loadLibrary() {
    String libraryPath;
    
    if (Platform.isWindows) {
      libraryPath = 'libfastdupe.dll';
    } else if (Platform.isMacOS) {
      libraryPath = 'libfastdupe.dylib';
    } else {
      libraryPath = 'libfastdupe.so';
    }
    
    try {
      _dylib = ffi.DynamicLibrary.open(libraryPath);
    } catch (e) {
      throw Exception('Failed to load library $libraryPath: $e');
    }
  }

  void _bindFunctions() {
    initializeLibrary = _dylib.lookupFunction<InitializeLibraryCNative, InitializeLibraryCDart>('InitializeLibraryC');
    runDuplicateFinder = _dylib.lookupFunction<RunDuplicateFinderCNative, RunDuplicateFinderCDart>('RunDuplicateFinderC');
    getCurrentStatus = _dylib.lookupFunction<GetCurrentStatusCNative, GetCurrentStatusCDart>('GetCurrentStatusC');
    getVersion = _dylib.lookupFunction<GetVersionCNative, GetVersionCDart>('GetVersionC');
    getLogs = _dylib.lookupFunction<GetLogsCNative, GetLogsCDart>('GetLogsC');
    freeString = _dylib.lookupFunction<FreeStringCNative, FreeStringCDart>('FreeStringC');
    isRunning = _dylib.lookupFunction<IsRunningCNative, IsRunningCDart>('IsRunningC');
  }

  String _convertCString(ffi.Pointer<ffi.Utf8> ptr) {
    if (ptr == ffi.nullptr) return '';
    final result = ptr.toDartString();
    freeString(ptr);
    return result;
  }

  // High-level Dart API
  void initialize() {
    initializeLibrary();
  }

  Map<String, dynamic> scanDirectory(String directoryPath) {
    final pathPtr = directoryPath.toNativeUtf8();
    try {
      final resultPtr = runDuplicateFinder(pathPtr);
      final jsonResult = _convertCString(resultPtr);
      return jsonDecode(jsonResult);
    } finally {
      malloc.free(pathPtr);
    }
  }

  Map<String, dynamic> getStatus() {
    final statusPtr = getCurrentStatus();
    final jsonStatus = _convertCString(statusPtr);
    return jsonDecode(jsonStatus);
  }

  Map<String, dynamic> getVersionInfo() {
    final versionPtr = getVersion();
    final jsonVersion = _convertCString(versionPtr);
    return jsonDecode(jsonVersion);
  }

  List<dynamic> getRecentLogs(int count) {
    final logsPtr = getLogs(count);
    final jsonLogs = _convertCString(logsPtr);
    return jsonDecode(jsonLogs);
  }

  bool isScanRunning() {
    return isRunning() != 0;
  }
}
```

## Step 4: Create a Flutter Service

Create `lib/duplicate_finder_service.dart`:

```dart
import 'dart:async';
import 'duplicate_finder_bindings.dart';

class DuplicateFinderService {
  static final DuplicateFinderService _instance = DuplicateFinderService._internal();
  factory DuplicateFinderService() => _instance;
  
  DuplicateFinderService._internal() {
    _bindings = DuplicateFinderBindings.instance;
    _bindings.initialize();
  }

  late DuplicateFinderBindings _bindings;
  StreamController<Map<String, dynamic>>? _statusController;

  Stream<Map<String, dynamic>> get statusStream {
    _statusController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _statusController!.stream;
  }

  Future<Map<String, dynamic>> scanForDuplicates(String directoryPath) async {
    try {
      // Start status monitoring
      _startStatusMonitoring();
      
      // Run the scan (this will block until complete)
      final result = await _runScanInIsolate(directoryPath);
      
      // Stop status monitoring
      _stopStatusMonitoring();
      
      return result;
    } catch (e) {
      _stopStatusMonitoring();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _runScanInIsolate(String directoryPath) async {
    // In a real implementation, you might want to run this in an isolate
    // to prevent blocking the UI thread
    return _bindings.scanDirectory(directoryPath);
  }

  Timer? _statusTimer;
  
  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(Duration(milliseconds: 250), (timer) {
      if (!_bindings.isScanRunning()) {
        timer.cancel();
        return;
      }
      
      final status = _bindings.getStatus();
      _statusController?.add(status);
    });
  }

  void _stopStatusMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Map<String, dynamic> getVersionInfo() {
    return _bindings.getVersionInfo();
  }

  List<dynamic> getRecentLogs(int count) {
    return _bindings.getRecentLogs(count);
  }

  void dispose() {
    _stopStatusMonitoring();
    _statusController?.close();
  }
}
```

## Step 5: Using in Flutter UI

Example usage in a Flutter widget:

```dart
import 'package:flutter/material.dart';
import 'duplicate_finder_service.dart';

class DuplicateFinderScreen extends StatefulWidget {
  @override
  _DuplicateFinderScreenState createState() => _DuplicateFinderScreenState();
}

class _DuplicateFinderScreenState extends State<DuplicateFinderScreen> {
  final DuplicateFinderService _service = DuplicateFinderService();
  Map<String, dynamic>? _results;
  Map<String, dynamic>? _currentStatus;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _service.statusStream.listen((status) {
      setState(() {
        _currentStatus = status;
      });
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _results = null;
    });

    try {
      final results = await _service.scanForDuplicates('/path/to/scan');
      setState(() {
        _results = results;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Duplicate Finder')),
      body: Column(
        children: [
          if (_isScanning && _currentStatus != null)
            LinearProgressIndicator(
              value: (_currentStatus!['progress'] as num) / 100.0,
            ),
          if (_currentStatus != null)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '${_currentStatus!['phase']}: ${_currentStatus!['message']}',
                style: Theme.of(context).textTheme.subtitle1,
              ),
            ),
          ElevatedButton(
            onPressed: _isScanning ? null : _startScan,
            child: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          if (_results != null)
            Expanded(
              child: _buildResults(),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final report = _results!['report'];
    if (report is String) {
      final parsedReport = jsonDecode(report);
      final summary = parsedReport['summary'];
      
      return ListView(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: Theme.of(context).textTheme.headline6),
                  Text('File sets: ${summary['totalAllFileSets']}'),
                  Text('Folder sets: ${summary['totalAllFolderSets']}'),
                  Text('Wasted space: ${_formatBytes(summary['wastedSpaceBytes'])}'),
                ],
              ),
            ),
          ),
          // Add more UI to display duplicate files and folders
        ],
      );
    }
    return Text('No results available');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
```

## Step 6: Platform-Specific Setup

### Android
1. Copy `libfastdupe.so` to `android/app/src/main/jniLibs/arm64-v8a/`
2. Add to `android/app/build.gradle`:
```gradle
android {
    packagingOptions {
        pickFirst '**/libc++_shared.so'
        pickFirst '**/libfastdupe.so'
    }
}
```

### iOS
1. Copy `libfastdupe.a` to `ios/` directory
2. Add to iOS project in Xcode
3. Link against the static library

### Desktop
1. Copy the appropriate library file (`libfastdupe.so`, `libfastdupe.dll`, `libfastdupe.dylib`) to your app bundle

## Memory Management

**Critical**: Always ensure strings returned from the C library are freed:
- The bindings automatically handle memory management
- Never call `freeString()` on the same pointer twice
- The high-level Dart API handles this automatically

## Error Handling

The C library returns JSON responses with success/error information:

```json
{
  "success": true,
  "report": "...",
  "error": null
}
```

Check the `success` field before processing results.

## Performance Tips

1. Use `RunDuplicateFinderMobileC` for mobile devices with optimized settings
2. Monitor progress using the status stream to provide user feedback
3. Consider running scans in isolates for large directories
4. Use the `IsRunningC` function to prevent concurrent scans

## Troubleshooting

### Library Loading Issues
- Ensure the library is in the correct path
- Check architecture compatibility (arm64, x64)
- Verify CGO was enabled during build

### Memory Issues
- Always free returned strings
- Monitor memory usage during large scans
- Use mobile optimizations on resource-constrained devices

### Performance Issues
- Use progress callbacks to avoid UI blocking
- Consider implementing cancellation support
- Test with various directory sizes
