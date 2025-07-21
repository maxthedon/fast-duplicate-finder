import 'dart:async';
import '../models/scan_progress.dart';
import '../models/scan_result.dart';
import '../models/scan_report.dart';

class FastDupeFinderService {
  static final FastDupeFinderService _instance = FastDupeFinderService._internal();
  factory FastDupeFinderService() => _instance;
  FastDupeFinderService._internal();

  StreamController<ScanProgress>? _progressController;
  Timer? _mockProgressTimer;
  bool _isScanning = false;
  String? _currentScanPath;

  /// Start scan with progress callback
  Future<void> startScan(String rootPath, Function(ScanProgress) onProgress) async {
    if (_isScanning) return;

    _isScanning = true;
    _currentScanPath = rootPath;
    _progressController = StreamController<ScanProgress>.broadcast();
    
    _progressController!.stream.listen(onProgress);

    // Mock scanning progress for demo purposes
    await _simulateScan();
  }

  /// Simulate scanning process with 5 phases
  Future<void> _simulateScan() async {
    final phases = [
      'Directory traversal',
      'File size grouping', 
      'Hash calculation',
      'Duplicate detection',
      'Report generation'
    ];

    for (int phase = 1; phase <= 5; phase++) {
      if (!_isScanning) break; // Check if cancelled

      final phaseDescription = phases[phase - 1];
      
      // Simulate progress within each phase
      for (int step = 0; step <= 100; step += 2) {
        if (!_isScanning) break;

        final progress = ScanProgress(
          currentPhase: phase,
          totalPhases: 5,
          phaseDescription: phaseDescription,
          processedFiles: (step * phase * 100).clamp(0, 50000),
          progressPercentage: ((phase - 1) * 20 + (step * 0.2)) / 100,
          isScanning: true,
          isCompleted: false,
          isCancelled: false,
        );

        _progressController?.add(progress);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Complete the scan
    if (_isScanning) {
      final finalProgress = ScanProgress(
        currentPhase: 5,
        totalPhases: 5,
        phaseDescription: 'Scan completed',
        processedFiles: 47523,
        progressPercentage: 1.0,
        isScanning: false,
        isCompleted: true,
        isCancelled: false,
      );

      _progressController?.add(finalProgress);
    }

    _isScanning = false;
  }

  /// Cancel running scan
  Future<void> cancelScan() async {
    _isScanning = false;
    _mockProgressTimer?.cancel();
    
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

  /// Get final results (mock data for demo)
  Future<ScanResult> getResults() async {
    if (_currentScanPath == null) {
      return ScanResult.empty;
    }

    // Generate mock duplicate groups
    final duplicateGroups = [
      DuplicateGroup(
        id: '1',
        fileName: 'vacation_photos',
        filePaths: [
          '$_currentScanPath/Pictures/vacation_photos',
          '$_currentScanPath/Backup/vacation_photos',
          '$_currentScanPath/Desktop/vacation_photos_copy',
        ],
        fileSize: 471859200, // 450 MB
        duplicateCount: 3,
        type: FileType.folder,
      ),
      DuplicateGroup(
        id: '2', 
        fileName: 'document.pdf',
        filePaths: [
          '$_currentScanPath/Documents/document.pdf',
          '$_currentScanPath/Downloads/document.pdf',
        ],
        fileSize: 15728640, // 15 MB
        duplicateCount: 2,
        type: FileType.file,
      ),
      DuplicateGroup(
        id: '3',
        fileName: 'music_collection',
        filePaths: [
          '$_currentScanPath/Music/music_collection',
          '$_currentScanPath/External/music_collection',
          '$_currentScanPath/Backup/old/music_collection',
          '$_currentScanPath/Archive/music_collection',
        ],
        fileSize: 2147483648, // 2 GB
        duplicateCount: 4,
        type: FileType.folder,
      ),
    ];

    final totalWastedSpace = duplicateGroups.fold<int>(
      0,
      (sum, group) => sum + (group.fileSize * (group.duplicateCount - 1)),
    );

    return ScanResult(
      duplicateGroups: duplicateGroups,
      totalDuplicates: duplicateGroups.length,
      totalWastedSpace: totalWastedSpace,
      scanCompletedAt: DateTime.now(),
      scannedPath: _currentScanPath!,
    );
  }

  /// Delete files/folders (mock implementation)
  Future<bool> deleteItems(List<String> paths) async {
    // Mock delay for deletion
    await Future.delayed(const Duration(seconds: 1));
    
    // In real implementation, this would delete the actual files
    // For now, just return success
    return true;
  }

  /// Open file in system explorer
  Future<void> showInExplorer(String path) async {
    // Mock implementation - in real app this would open the system file explorer
    // This would use platform channels or url_launcher
    print('Opening in explorer: $path');
  }

  void dispose() {
    _progressController?.close();
    _mockProgressTimer?.cancel();
  }
}
