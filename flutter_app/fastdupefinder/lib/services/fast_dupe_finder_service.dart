import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_progress.dart';
import '../models/scan_result.dart';
import '../models/scan_report.dart';
import '../bindings/duplicate_finder_bindings.dart';
import '../utils/logger.dart';

class FastDupeFinderService {
  static final FastDupeFinderService _instance = FastDupeFinderService._internal();
  factory FastDupeFinderService() => _instance;
  
  late DuplicateFinderBindings _bindings;
  StreamController<ScanProgress>? _progressController;
  Timer? _statusTimer;
  bool _isScanning = false;
  String? _currentScanPath;

  FastDupeFinderService._internal() {
    _bindings = DuplicateFinderBindings.instance;
    _bindings.initialize();
  }

  /// Start scan with progress callback
  Future<void> startScan(String rootPath, Function(ScanProgress) onProgress, {int? cpuCores}) async {
    if (_isScanning) return;

    _isScanning = true;
    _currentScanPath = rootPath;
    _progressController = StreamController<ScanProgress>.broadcast();
    
    _progressController!.stream.listen(onProgress);

    // Start status monitoring for real-time progress
    _startStatusMonitoring();

    try {
      // Run the actual scan using FFI in a separate isolate to avoid blocking UI
      await _runScanInBackground(rootPath, cpuCores: cpuCores);
    } catch (e) {
      // Handle unexpected errors
      final errorProgress = ScanProgress(
        currentPhase: 0,
        totalPhases: 5,
        phaseDescription: 'Scan error: $e',
        processedFiles: 0,
        progressPercentage: 0.0,
        isScanning: false,
        isCompleted: false,
        isCancelled: false,
        isGeneratingReport: false,
        duplicatesFound: 0,
        currentItem: 0,
        totalItems: 0,
      );
      _progressController?.add(errorProgress);
    } finally {
      _isScanning = false;
      _stopStatusMonitoring();
    }
  }

  /// Run scan in background isolate to avoid blocking UI
  Future<void> _runScanInBackground(String rootPath, {int? cpuCores}) async {
    try {
      // Run the FFI call in a separate isolate to avoid blocking the UI
      final result = await _runScanInIsolate(rootPath, cpuCores: cpuCores);
      
      // Wait for completion by monitoring status
      while (_isScanning && _bindings.isScanRunning()) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (!_isScanning) return; // Cancelled
      
      if (result['success'] == true) {
        final finalProgress = ScanProgress(
          currentPhase: 5,
          totalPhases: 5,
          phaseDescription: 'Scan completed',
          processedFiles: result['processed_files'] ?? 0,
          progressPercentage: 1.0,
          isScanning: false,
          isCompleted: true,
          isCancelled: false,
          isGeneratingReport: false,
          duplicatesFound: result['duplicates_found'] ?? 0,
          currentItem: 0,
          totalItems: 0,
        );
        _progressController?.add(finalProgress);
      } else {
        final errorProgress = ScanProgress(
          currentPhase: 0,
          totalPhases: 5,
          phaseDescription: 'Scan failed: ${result['error'] ?? 'Unknown error'}',
          processedFiles: 0,
          progressPercentage: 0.0,
          isScanning: false,
          isCompleted: false,
          isCancelled: false,
          isGeneratingReport: false,
          duplicatesFound: 0,
          currentItem: 0,
          totalItems: 0,
        );
        _progressController?.add(errorProgress);
      }
    } catch (e) {
      final errorProgress = ScanProgress(
        currentPhase: 0,
        totalPhases: 5,
        phaseDescription: 'Scan failed: $e',
        processedFiles: 0,
        progressPercentage: 0.0,
        isScanning: false,
        isCompleted: false,
        isCancelled: false,
        isGeneratingReport: false,
        duplicatesFound: 0,
        currentItem: 0,
        totalItems: 0,
      );
      _progressController?.add(errorProgress);
    }
  }

  /// Run the actual FFI scan in a separate isolate
  Future<Map<String, dynamic>> _runScanInIsolate(String rootPath, {int? cpuCores}) async {
    final receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(_scanIsolateEntryPoint, {
        'sendPort': receivePort.sendPort,
        'rootPath': rootPath,
        'cpuCores': cpuCores,
      });
      
      final result = await receivePort.first as Map<String, dynamic>;
      return result;
    } catch (e) {
      return {'success': false, 'error': 'Isolate error: $e'};
    } finally {
      receivePort.close();
    }
  }

  /// Isolate entry point for running the scan
  static void _scanIsolateEntryPoint(Map<String, dynamic> params) {
    final sendPort = params['sendPort'] as SendPort;
    final rootPath = params['rootPath'] as String;
    final cpuCores = params['cpuCores'] as int?;
    
    try {
      // Initialize bindings in the isolate
      final bindings = DuplicateFinderBindings.instance;
      bindings.initialize();
      
      // Run the actual scan with CPU configuration
      final result = cpuCores != null && cpuCores > 0
          ? bindings.scanDirectoryWithConfig(rootPath, cpuCores)
          : bindings.scanDirectory(rootPath);
      
      // Send result back to main isolate
      sendPort.send(result);
    } catch (e) {
      sendPort.send({
        'success': false,
        'error': 'FFI error: $e',
      });
    }
  }

  /// Start monitoring the status from the Go library
  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isScanning) {
        timer.cancel();
        return;
      }

      try {
        final status = _bindings.getStatus();
        final progress = _convertStatusToProgress(status);
        _progressController?.add(progress);
        
        // If we're generating report and report is available, we can finish
        if (progress.isGeneratingReport) {
          // Check if report is available
          try {
            final reportString = _bindings.getLastScanReport();
            if (reportString.isNotEmpty && !reportString.contains('"error"')) {
              // Report is ready, send final completion status
              final finalProgress = progress.copyWith(
                isGeneratingReport: false,
                isScanning: false,
                isCompleted: true,
                phaseDescription: 'Scan completed successfully',
              );
              _progressController?.add(finalProgress);
              timer.cancel();
              _isScanning = false;
            }
          } catch (e) {
            // Report not ready yet, continue monitoring
          }
        }
      } catch (e) {
        // Ignore status errors during monitoring
      }
    });
  }

  /// Stop status monitoring
  void _stopStatusMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  /// Convert Go status to Flutter ScanProgress
  ScanProgress _convertStatusToProgress(Map<String, dynamic> status) {
    final phase = status['phase'] ?? 'idle';
    var progress = (status['progress'] ?? 0.0).toDouble();
    final filesFound = status['files_found'] ?? 0;
    final dupesFound = status['dupes_found'] ?? 0;
    final currentItem = status['current_item'] ?? 0;
    final totalItems = status['total_items'] ?? 0;
    final message = status['message'] ?? '';
    
    // Clamp progress to avoid wild jumps
    if (progress > 100.0) {
      progress = 100.0;
    } else if (progress < 0.0) {
      progress = 0.0;
    }
    
    // Map Go phase names to Flutter phase descriptions and numbers
    String phaseDescription;
    int currentPhase;
    bool isGeneratingReport = false;
    
    switch (phase) {
      case 'phase1':
        phaseDescription = 'Scanning files';
        currentPhase = 1;
        break;
      case 'phase2':
        phaseDescription = 'Computing partial hashes';
        currentPhase = 2;
        break;
      case 'phase3':
        phaseDescription = 'Computing full hashes';
        currentPhase = 3;
        break;
      case 'phase4':
        phaseDescription = 'Analyzing folders';
        currentPhase = 4;
        break;
      case 'phase5':
        phaseDescription = 'Filtering results';
        currentPhase = 5;
        break;
      case 'completed':
        // When phase is completed, transition to report generation state
        phaseDescription = 'Generating Report';
        currentPhase = 5;
        isGeneratingReport = true;
        progress = 100.0; // Keep progress at 100% during report generation
        break;
      default:
        phaseDescription = message.isNotEmpty ? message : phase;
        currentPhase = 1;
    }

    return ScanProgress(
      currentPhase: currentPhase,
      totalPhases: 5,
      phaseDescription: phaseDescription,
      processedFiles: filesFound,
      progressPercentage: progress / 100.0, // Convert percentage to 0-1 range
      isScanning: (phase != 'completed' && phase != 'idle') || isGeneratingReport,
      isCompleted: phase == 'completed',
      isCancelled: false,
      isGeneratingReport: isGeneratingReport,
      duplicatesFound: dupesFound,
      currentItem: currentItem,
      totalItems: totalItems,
    );
  }

  /// Cancel running scan
  Future<void> cancelScan() async {
    _isScanning = false;
    _stopStatusMonitoring();
    
    // Cancel the scan in the Go library
    try {
      _bindings.cancelCurrentScan();
    } catch (e) {
      Logger.log('Error cancelling scan: $e');
    }
    
    if (_progressController != null) {
      final cancelledProgress = ScanProgress(
        currentPhase: 0,
        totalPhases: 5,
        phaseDescription: 'Scan cancelled',
        processedFiles: 0,
        progressPercentage: 0.0,
        isScanning: false,
        isCompleted: false,
        isCancelled: true,
        duplicatesFound: 0,
        currentItem: 0,
        totalItems: 0,
      );
      
      _progressController?.add(cancelledProgress);
      await _progressController?.close();
      _progressController = null;
    }
  }

  /// Get final results (from Go library) - no need to run scan again
  Future<ScanResult> getResults({DateTime? scanStartTime}) async {
    if (_currentScanPath == null) {
      return ScanResult.empty;
    }

    try {
      // Get the cached report from the Go library 
      final reportString = _bindings.getLastScanReport();
      
      if (reportString.isEmpty || reportString.contains('"error"')) {
        Logger.log('No cached results available: $reportString');
        return ScanResult.empty;
      }

      return _parseReportFromJson(reportString, scanStartTime);
    } catch (e) {
      Logger.log('Error getting results: $e');
      return ScanResult.empty;
    }
  }

  /// Parse the report JSON string into a ScanResult
  ScanResult _parseReportFromJson(String reportString, [DateTime? scanStartTime]) {
    try {
      final report = jsonDecode(reportString) as Map<String, dynamic>;
      
      // Convert Go duplicate groups to Flutter models
      final duplicateGroups = <DuplicateGroup>[];
      
      // Process file duplicates - now direct array instead of object with sets
      final fileDuplicates = report['fileDuplicates'];
      if (fileDuplicates != null && fileDuplicates is List<dynamic>) {
        for (int i = 0; i < fileDuplicates.length; i++) {
          final set = fileDuplicates[i] as Map<String, dynamic>;
          final paths = (set['paths'] as List<dynamic>)
              .map((path) => path as String)
              .toList();
          
          if (paths.length > 1) {
            final fileName = paths.first.split('/').last;
            final fileSize = set['sizeBytes'] as int;
            
            duplicateGroups.add(DuplicateGroup(
              id: 'file_$i',
              fileName: fileName,
              filePaths: paths,
              fileSize: fileSize,
              duplicateCount: paths.length,
              type: FileType.file,
              isSelected: false,
            ));
          }
        }
      }
      
      // Process folder duplicates - now direct array instead of object with sets
      final folderDuplicates = report['folderDuplicates'];
      if (folderDuplicates != null && folderDuplicates is List<dynamic>) {
        for (int i = 0; i < folderDuplicates.length; i++) {
          final set = folderDuplicates[i] as Map<String, dynamic>;
          final paths = (set['paths'] as List<dynamic>)
              .map((path) => path as String)
              .toList();
          
          if (paths.length > 1) {
            final folderName = paths.first.split('/').last;
            final folderSize = set['sizeBytes'] as int? ?? 0;
            
            duplicateGroups.add(DuplicateGroup(
              id: 'folder_$i',
              fileName: folderName,
              filePaths: paths,
              fileSize: folderSize,
              duplicateCount: paths.length,
              type: FileType.folder,
              isSelected: false,
            ));
          }
        }
      }

      // Get total wasted space from summary
      final summary = report['summary'];
      final totalWastedSpace = summary != null ? (summary['wastedSpaceBytes'] as int? ?? 0) : 0;

      return ScanResult(
        duplicateGroups: duplicateGroups,
        totalDuplicates: duplicateGroups.length,
        totalWastedSpace: totalWastedSpace,
        scanStartedAt: scanStartTime ?? DateTime.now().subtract(const Duration(seconds: 1)), // Default fallback
        scanCompletedAt: DateTime.now(),
        scannedPath: _currentScanPath!,
      );
    } catch (e) {
      Logger.log('Error parsing report JSON: $e');
      return ScanResult.empty;
    }
  }

  /// Delete files/folders 
  Future<bool> deleteItems(List<String> paths) async {
    try {
      for (String path in paths) {
        final fileEntity = File(path);
        final dirEntity = Directory(path);
        
        if (await fileEntity.exists()) {
          await fileEntity.delete();
        } else if (await dirEntity.exists()) {
          await dirEntity.delete(recursive: true);
        }
      }
      
      return true;
    } catch (e) {
      Logger.log('Error deleting items: $e');
      return false;
    }
  }

  /// Open file/folder in system explorer with proper highlighting
  Future<void> showInExplorer(String path) async {
    try {
      if (Platform.isWindows) {
        // Windows: Use explorer with /select to highlight the item
        await Process.run('explorer', ['/select,', path]);
      } else if (Platform.isMacOS) {
        // macOS: Use open with -R to reveal in Finder
        await Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        // Linux: Try multiple file managers in order of preference
        await _showInLinuxExplorer(path);
      } else {
        // Fallback: Use url_launcher to open parent directory
        final parentDir = File(path).parent;
        final uri = parentDir.uri;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Cannot open file explorer on this platform');
        }
      }
    } catch (e) {
      Logger.log('Error opening in explorer: $e');
      // Fallback: Try to open parent directory with url_launcher
      try {
        final parentDir = File(path).parent;
        final uri = parentDir.uri;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (fallbackError) {
        Logger.log('Fallback also failed: $fallbackError');
      }
    }
  }

  /// Linux-specific implementation with multiple file manager support
  Future<void> _showInLinuxExplorer(String path) async {
    // List of file managers to try, in order of preference
    final fileManagers = [
      // GNOME Files (Nautilus) - supports --select for highlighting
      {'command': 'nautilus', 'args': ['--select', path]},
      // KDE Dolphin - supports --select for highlighting
      {'command': 'dolphin', 'args': ['--select', path]},
      // Nemo (Cinnamon) - supports selection
      {'command': 'nemo', 'args': [path]},
      // Caja (MATE) - supports selection when opening file directly
      {'command': 'caja', 'args': [path]},
      // XFCE Thunar - opens and selects when given file path
      {'command': 'thunar', 'args': [path]},
      // PCManFM (LXDE/LXQt) - basic support
      {'command': 'pcmanfm', 'args': [File(path).parent.path]},
    ];

    // Try each file manager
    for (final fm in fileManagers) {
      try {
        final result = await Process.run(
          fm['command'] as String, 
          fm['args'] as List<String>,
        );
        if (result.exitCode == 0) {
          return; // Success, we're done
        }
      } catch (e) {
        // This file manager is not available, try the next one
        continue;
      }
    }

    // Try dbus-based approach for better file managers
    if (await _tryDbusFileSelection(path)) {
      return;
    }

    // Try the file:// URL approach with default app
    if (await _tryFileUrlApproach(path)) {
      return;
    }

    // Final fallback: use xdg-open with parent directory (no highlighting)
    try {
      await Process.run('xdg-open', [File(path).parent.path]);
      Logger.log('Warning: File opened in folder but not highlighted. Consider installing nautilus, dolphin, or nemo for better file selection.');
    } catch (e) {
      // Even xdg-open failed, use url_launcher
      final parentDir = File(path).parent;
      final uri = parentDir.uri;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        Logger.log('Warning: File opened in folder but not highlighted.');
      } else {
        throw Exception('No suitable file manager found');
      }
    }
  }

  /// Try D-Bus based file manager communication (advanced approach)
  Future<bool> _tryDbusFileSelection(String path) async {
    try {
      // Try to use D-Bus to communicate with file managers that support it
      final result = await Process.run('dbus-send', [
        '--session',
        '--dest=org.freedesktop.FileManager1',
        '--type=method_call',
        '/org/freedesktop/FileManager1',
        'org.freedesktop.FileManager1.ShowItems',
        'array:string:"file://$path"',
        'string:""'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Try opening with file:// URL approach
  Future<bool> _tryFileUrlApproach(String path) async {
    try {
      final fileUri = Uri.file(path);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri);
        return true;
      }
    } catch (e) {
      // Ignore
    }
    return false;
  }

  void dispose() {
    _progressController?.close();
    _stopStatusMonitoring();
    _bindings.dispose();
  }
}
