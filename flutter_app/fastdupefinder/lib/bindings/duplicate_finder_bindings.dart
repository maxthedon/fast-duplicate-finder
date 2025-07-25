import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// C function type definitions
typedef InitializeLibraryCNative = ffi.Void Function();
typedef InitializeLibraryCDart = void Function();

typedef RunDuplicateFinderCNative = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);
typedef RunDuplicateFinderCDart = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);

typedef GetCurrentStatusCNative = ffi.Pointer<ffi.Char> Function();
typedef GetCurrentStatusCDart = ffi.Pointer<ffi.Char> Function();

typedef GetVersionCNative = ffi.Pointer<ffi.Char> Function();
typedef GetVersionCDart = ffi.Pointer<ffi.Char> Function();

typedef GetLogsCNative = ffi.Pointer<ffi.Char> Function(ffi.Int32);
typedef GetLogsCDart = ffi.Pointer<ffi.Char> Function(int);

typedef FreeStringCNative = ffi.Void Function(ffi.Pointer<ffi.Char>);
typedef FreeStringCDart = void Function(ffi.Pointer<ffi.Char>);

typedef IsRunningCNative = ffi.Int32 Function();
typedef IsRunningCDart = int Function();

typedef SetStatusCallbackCNative = ffi.Void Function(ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>);
typedef SetStatusCallbackCDart = void Function(ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>);

typedef RemoveStatusCallbackCNative = ffi.Void Function();
typedef RemoveStatusCallbackCDart = void Function();

typedef CancelScanCNative = ffi.Void Function();
typedef CancelScanCDart = void Function();

typedef GetLastReportCNative = ffi.Pointer<ffi.Char> Function();
typedef GetLastReportCDart = ffi.Pointer<ffi.Char> Function();

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
  late SetStatusCallbackCDart setStatusCallback;
  late RemoveStatusCallbackCDart removeStatusCallback;
  late CancelScanCDart cancelScan;
  late GetLastReportCDart getLastReport;

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
    if (Platform.isLinux) {
      // Try different paths in order of preference
      try {
        // First try the bundle's lib directory (for production builds)
        libraryPath = 'lib/libfastdupe.so';
        _dylib = ffi.DynamicLibrary.open(libraryPath);
      } catch (e) {
        try {
          // Try the development lib/native directory
          libraryPath = 'lib/native/libfastdupe.so';
          _dylib = ffi.DynamicLibrary.open(libraryPath);
        } catch (e2) {
          try {
            // Try relative path for development
            libraryPath = './lib/native/libfastdupe.so';
            _dylib = ffi.DynamicLibrary.open(libraryPath);
          } catch (e3) {
            try {
              // Try the build directory
              libraryPath = '../../backend/build/libfastdupe.so';
              _dylib = ffi.DynamicLibrary.open(libraryPath);
            } catch (e4) {
              // Fallback to libfastdupe.so in the same directory
              libraryPath = 'libfastdupe.so';
              _dylib = ffi.DynamicLibrary.open(libraryPath);
            }
          }
        }
      }
    } else if (Platform.isWindows) {
      libraryPath = 'lib/native/libfastdupe.dll';
      _dylib = ffi.DynamicLibrary.open(libraryPath);
    } else if (Platform.isMacOS) {
      libraryPath = 'lib/native/libfastdupe.dylib';
      _dylib = ffi.DynamicLibrary.open(libraryPath);
    } else {
      throw UnsupportedError('Platform not supported');
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
    setStatusCallback = _dylib.lookupFunction<SetStatusCallbackCNative, SetStatusCallbackCDart>('SetStatusCallbackC');
    removeStatusCallback = _dylib.lookupFunction<RemoveStatusCallbackCNative, RemoveStatusCallbackCDart>('RemoveStatusCallbackC');
    cancelScan = _dylib.lookupFunction<CancelScanCNative, CancelScanCDart>('CancelScanC');
    getLastReport = _dylib.lookupFunction<GetLastReportCNative, GetLastReportCDart>('GetLastReportC');
  }

  String _convertCString(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) return '';
    final result = ptr.cast<Utf8>().toDartString();
    freeString(ptr);
    return result;
  }

  // High-level Dart API
  void initialize() {
    initializeLibrary();
  }

  Map<String, dynamic> scanDirectory(String directoryPath) {
    final pathPtr = directoryPath.toNativeUtf8().cast<ffi.Char>();
    try {
      final resultPtr = runDuplicateFinder(pathPtr);
      final jsonResult = _convertCString(resultPtr);
      if (jsonResult.isEmpty) {
        return {'success': false, 'error': 'Empty result from scan'};
      }
      return jsonDecode(jsonResult);
    } catch (e) {
      return {'success': false, 'error': 'Scan failed: $e'};
    } finally {
      malloc.free(pathPtr);
    }
  }

  Map<String, dynamic> getStatus() {
    final statusPtr = getCurrentStatus();
    final jsonStatus = _convertCString(statusPtr);
    if (jsonStatus.isEmpty) {
      return {'phase': 'idle', 'progress': 0.0};
    }
    try {
      return jsonDecode(jsonStatus);
    } catch (e) {
      return {'phase': 'error', 'progress': 0.0, 'error': e.toString()};
    }
  }

  Map<String, dynamic> getVersionInfo() {
    final versionPtr = getVersion();
    final jsonVersion = _convertCString(versionPtr);
    if (jsonVersion.isEmpty) {
      return {'version': 'unknown'};
    }
    try {
      return jsonDecode(jsonVersion);
    } catch (e) {
      return {'version': 'unknown', 'error': e.toString()};
    }
  }

  List<dynamic> getRecentLogs(int count) {
    final logsPtr = getLogs(count);
    final jsonLogs = _convertCString(logsPtr);
    if (jsonLogs.isEmpty) {
      return [];
    }
    try {
      final result = jsonDecode(jsonLogs);
      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }

  bool isScanRunning() {
    return isRunning() != 0;
  }

  void dispose() {
    removeStatusCallback();
  }

  void cancelCurrentScan() {
    cancelScan();
  }

  String getLastScanReport() {
    final reportPtr = getLastReport();
    return _convertCString(reportPtr);
  }
}
