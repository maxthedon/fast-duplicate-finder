import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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

  /// Run scan in background isolate to avoid blocking UI
  Future<void> _runScanInBackground(String rootPath) async {
    try {
      // Run the FFI call in a separate isolate to avoid blocking the UI
      final result = await _runScanInIsolate(rootPath);
      
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
          progressPercentage: 100.0,
          isScanning: false,
          isCompleted: true,
          isCancelled: false,
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
      );
      _progressController?.add(errorProgress);
    }
  }

  /// Run the actual FFI scan in a separate isolate
  Future<Map<String, dynamic>> _runScanInIsolate(String rootPath) async {
    final receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(_scanIsolateEntryPoint, {
        'sendPort': receivePort.sendPort,
        'rootPath': rootPath,
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
    
    try {
      // Initialize bindings in the isolate
      final bindings = DuplicateFinderBindings.instance;
      bindings.initialize();
      
      // Run the actual scan
      final result = bindings.scanDirectory(rootPath);
      
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

  /// Get final results (from Go library) using isolate
  Future<ScanResult> getResults() async {
    if (_currentScanPath == null) {
      return ScanResult.empty;
    }

    try {
      // Get the scan result from the Go library using isolate
      final result = await _runScanInIsolate(_currentScanPath!);
      
      if (result['success'] != true) {
        print('Scan failed: ${result['error']}');
        return ScanResult.empty;
      }

      // Parse the JSON result from Go
      final reportString = result['report'];
      if (reportString == null || reportString is! String) {
        print('No report data found');
        print('Result keys: ${result.keys}');
        print('Report value type: ${reportString.runtimeType}');
        print('Report value: $reportString');
        return ScanResult.empty;
      }

      print('=== DEBUG: Raw JSON Report ===');
      print('Report length: ${reportString.length}');
      print('First 500 chars: ${reportString.substring(0, reportString.length > 500 ? 500 : reportString.length)}');
      
      final report = jsonDecode(reportString) as Map<String, dynamic>;
      print('=== DEBUG: Parsed Report Structure ===');
      print('Report keys: ${report.keys}');
      if (report['summary'] != null) {
        print('Summary: ${report['summary']}');
      }
      if (report['fileDuplicates'] != null) {
        final fileDups = report['fileDuplicates'];
        print('File duplicates structure: ${fileDups.keys}');
        if (fileDups['sets'] != null) {
          print('File sets count: ${(fileDups['sets'] as List).length}');
        }
      }
      if (report['folderDuplicates'] != null) {
        final folderDups = report['folderDuplicates'];
        print('Folder duplicates structure: ${folderDups.keys}');
        if (folderDups['sets'] != null) {
          print('Folder sets count: ${(folderDups['sets'] as List).length}');
        }
      }
      
      // Convert Go duplicate groups to Flutter models
      final duplicateGroups = <DuplicateGroup>[];
      
      // Process file duplicates
      final fileDuplicates = report['fileDuplicates'];
      print('=== DEBUG: Processing File Duplicates ===');
      print('fileDuplicates is null: ${fileDuplicates == null}');
      if (fileDuplicates != null) {
        print('fileDuplicates type: ${fileDuplicates.runtimeType}');
        print('fileDuplicates keys: ${fileDuplicates.keys}');
        final sets = fileDuplicates['sets'];
        print('sets is null: ${sets == null}');
        if (sets != null) {
          print('sets type: ${sets.runtimeType}');
          final setsList = sets as List;
          print('sets length: ${setsList.length}');
          if (setsList.isNotEmpty) {
            print('First set: ${setsList[0]}');
          }
        }
      }
      
      if (fileDuplicates != null && fileDuplicates['sets'] != null) {
        final sets = fileDuplicates['sets'] as List<dynamic>;
        print('Processing ${sets.length} file duplicate sets');
        for (int i = 0; i < sets.length; i++) {
          final set = sets[i] as Map<String, dynamic>;
          print('Processing file set $i: ${set.keys}');
          final paths = (set['paths'] as List<dynamic>)
              .map((path) => path as String)
              .toList();
          
          if (paths.length > 1) {
            final fileName = paths.first.split('/').last;
            final fileSize = set['sizeBytes'] as int;
            print('Adding duplicate group: $fileName (${paths.length} copies, $fileSize bytes)');
            
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
      
      // Process folder duplicates
      final folderDuplicates = report['folderDuplicates'];
      if (folderDuplicates != null && folderDuplicates['sets'] != null) {
        final sets = folderDuplicates['sets'] as List<dynamic>;
        for (int i = 0; i < sets.length; i++) {
          final set = sets[i] as Map<String, dynamic>;
          final paths = (set['paths'] as List<dynamic>)
              .map((path) => path as String)
              .toList();
          
          if (paths.length > 1) {
            final folderName = paths.first.split('/').last;
            
            duplicateGroups.add(DuplicateGroup(
              id: 'folder_$i',
              fileName: folderName,
              filePaths: paths,
              fileSize: 0, // Folders don't have direct size in the current JSON structure
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
