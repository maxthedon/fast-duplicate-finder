import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/scan_progress.dart';
import '../models/scan_result.dart';
import '../models/scan_report.dart';
import '../bindings/duplicate_finder_bindings.dart';

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
  Future<void> startScan(String rootPath, Function(ScanProgress) onProgress) async {
    if (_isScanning) return;

    _isScanning = true;
    _currentScanPath = rootPath;
    _progressController = StreamController<ScanProgress>.broadcast();
    
    _progressController!.stream.listen(onProgress);

    // Start status monitoring for real-time progress
    _startStatusMonitoring();

    try {
      // Run the actual scan using FFI in a separate isolate to avoid blocking UI
      await _runScanInBackground(rootPath);
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
      );
      _progressController?.add(errorProgress);
    } finally {
      _isScanning = false;
      _stopStatusMonitoring();
    }
  }

  /// Run scan in background and monitor completion
  Future<void> _runScanInBackground(String rootPath) async {
    // Start the scan - this will run in the background
    try {
      final result = _bindings.scanDirectory(rootPath);
      
      // Wait for completion by monitoring status
      while (_isScanning && _bindings.isScanRunning()) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      
      if (!_isScanning) return; // Cancelled
      
      if (result['success'] == true) {
        // Scan completed successfully
        final finalProgress = ScanProgress(
          currentPhase: 5,
          totalPhases: 5,
          phaseDescription: 'Scan completed',
          processedFiles: result['total_files'] ?? 0,
          progressPercentage: 1.0,
          isScanning: false,
          isCompleted: true,
          isCancelled: false,
        );
        _progressController?.add(finalProgress);
      } else {
        // Scan failed
        final errorProgress = ScanProgress(
          currentPhase: 0,
          totalPhases: 5,
          phaseDescription: 'Scan failed: ${result['error'] ?? 'Unknown error'}',
          processedFiles: 0,
          progressPercentage: 0.0,
          isScanning: false,
          isCompleted: false,
          isCancelled: false,
        );
        _progressController?.add(errorProgress);
      }
    } catch (e) {
      final errorProgress = ScanProgress(
        currentPhase: 0,
        totalPhases: 5,
        phaseDescription: 'Scan error: $e',
        processedFiles: 0,
        progressPercentage: 0.0,
        isScanning: false,
        isCompleted: false,
        isCancelled: false,
      );
      _progressController?.add(errorProgress);
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
    final progress = (status['progress'] ?? 0.0).toDouble();
    final processedFiles = status['processed_files'] ?? 0;
    
    // Map Go phase names to Flutter phase descriptions
    String phaseDescription;
    int currentPhase;
    
    switch (phase) {
      case 'directory_traversal':
        phaseDescription = 'Directory traversal';
        currentPhase = 1;
        break;
      case 'file_grouping':
        phaseDescription = 'File size grouping';
        currentPhase = 2;
        break;
      case 'hash_calculation':
        phaseDescription = 'Hash calculation';
        currentPhase = 3;
        break;
      case 'duplicate_detection':
        phaseDescription = 'Duplicate detection';
        currentPhase = 4;
        break;
      case 'report_generation':
        phaseDescription = 'Report generation';
        currentPhase = 5;
        break;
      case 'completed':
        phaseDescription = 'Scan completed';
        currentPhase = 5;
        break;
      default:
        phaseDescription = phase;
        currentPhase = 1;
    }

    return ScanProgress(
      currentPhase: currentPhase,
      totalPhases: 5,
      phaseDescription: phaseDescription,
      processedFiles: processedFiles,
      progressPercentage: progress,
      isScanning: phase != 'completed' && phase != 'idle',
      isCompleted: phase == 'completed',
      isCancelled: false,
    );
  }

  /// Cancel running scan
  Future<void> cancelScan() async {
    _isScanning = false;
    _stopStatusMonitoring();
    
    // Try to cancel the scan in the Go library if it's running
    try {
      // Note: The current Go library doesn't have a cancel function
      // This would need to be implemented in the Go C bindings if needed
      // For now, we just stop our monitoring and mark as cancelled
    } catch (e) {
      print('Error cancelling scan: $e');
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
      );
      
      _progressController?.add(cancelledProgress);
      await _progressController?.close();
      _progressController = null;
    }
  }

  /// Get final results (from Go library)
  Future<ScanResult> getResults() async {
    if (_currentScanPath == null) {
      return ScanResult.empty;
    }

    try {
      // Get the scan result from the Go library
      final result = _bindings.scanDirectory(_currentScanPath!);
      
      if (result['success'] != true) {
        return ScanResult.empty;
      }

      // Parse the JSON result from Go
      final reportString = result['report'];
      if (reportString == null || reportString is! String) {
        return ScanResult.empty;
      }

      final report = jsonDecode(reportString) as Map<String, dynamic>;
      
      // Convert Go duplicate groups to Flutter models
      final duplicateGroups = <DuplicateGroup>[];
      
      // Process file duplicates
      final fileDuplicates = report['fileDuplicates'];
      if (fileDuplicates != null && fileDuplicates['sets'] != null) {
        final fileSets = List<Map<String, dynamic>>.from(fileDuplicates['sets']);
        
        for (int i = 0; i < fileSets.length; i++) {
          final fileSet = fileSets[i];
          final paths = List<String>.from(fileSet['paths'] ?? []);
          final sizeBytes = fileSet['sizeBytes'] ?? 0;
          
          if (paths.length > 1) {
            final duplicateGroup = DuplicateGroup(
              id: 'file_${i + 1}',
              fileName: paths.first.split('/').last,
              filePaths: paths,
              fileSize: sizeBytes is int ? sizeBytes : (sizeBytes as num).toInt(),
              duplicateCount: paths.length,
              type: FileType.file,
            );
            duplicateGroups.add(duplicateGroup);
          }
        }
      }
      
      // Process folder duplicates
      final folderDuplicates = report['folderDuplicates'];
      if (folderDuplicates != null && folderDuplicates['sets'] != null) {
        final folderSets = List<Map<String, dynamic>>.from(folderDuplicates['sets']);
        
        for (int i = 0; i < folderSets.length; i++) {
          final folderSet = folderSets[i];
          final paths = List<String>.from(folderSet['paths'] ?? []);
          
          if (paths.length > 1) {
            final duplicateGroup = DuplicateGroup(
              id: 'folder_${i + 1}',
              fileName: paths.first.split('/').last,
              filePaths: paths,
              fileSize: 0, // Folders don't have a direct size in the report
              duplicateCount: paths.length,
              type: FileType.folder,
            );
            duplicateGroups.add(duplicateGroup);
          }
        }
      }

      // Get total wasted space from summary
      final summary = report['summary'];
      final totalWastedSpace = summary != null ? (summary['wastedSpaceBytes'] ?? 0) : 0;

      return ScanResult(
        duplicateGroups: duplicateGroups,
        totalDuplicates: duplicateGroups.length,
        totalWastedSpace: totalWastedSpace is int ? totalWastedSpace : (totalWastedSpace as num).toInt(),
        scanCompletedAt: DateTime.now(),
        scannedPath: _currentScanPath!,
      );
    } catch (e) {
      print('Error getting results: $e');
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
      print('Error deleting items: $e');
      return false;
    }
  }

  /// Open file in system explorer
  Future<void> showInExplorer(String path) async {
    try {
      String command;
      List<String> arguments;
      
      if (Platform.isLinux) {
        command = 'xdg-open';
        arguments = [File(path).parent.path];
      } else if (Platform.isWindows) {
        command = 'explorer';
        arguments = ['/select,', path];
      } else if (Platform.isMacOS) {
        command = 'open';
        arguments = ['-R', path];
      } else {
        print('Platform not supported for showing in explorer');
        return;
      }
      
      await Process.run(command, arguments);
    } catch (e) {
      print('Error opening in explorer: $e');
    }
  }

  void dispose() {
    _progressController?.close();
    _stopStatusMonitoring();
    _bindings.dispose();
  }
}
