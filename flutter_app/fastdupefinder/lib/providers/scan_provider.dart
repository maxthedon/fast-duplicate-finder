import 'package:flutter/foundation.dart';
import '../models/scan_progress.dart';
import '../models/scan_result.dart';
import '../models/scan_report.dart';
import '../services/fast_dupe_finder_service.dart';

class ScanProvider extends ChangeNotifier {
  final FastDupeFinderService _service = FastDupeFinderService();

  String? _selectedPath;
  ScanProgress _currentProgress = ScanProgress.initial;
  ScanResult? _scanResult;
  bool _isScanning = false;

  // Getters
  String? get selectedPath => _selectedPath;
  ScanProgress get currentProgress => _currentProgress;
  ScanResult? get scanResult => _scanResult;
  bool get isScanning => _isScanning;
  bool get canStartScan => _selectedPath != null && !_isScanning;
  bool get hasResults => _scanResult != null;

  // Methods
  void setSelectedPath(String? path) {
    _selectedPath = path;
    notifyListeners();
  }

  Future<void> startScan() async {
    if (!canStartScan) return;

    _isScanning = true;
    _currentProgress = ScanProgress.initial.copyWith(isScanning: true);
    _scanResult = null;
    notifyListeners();

    try {
      await _service.startScan(_selectedPath!, (progress) {
        _currentProgress = progress;
        _isScanning = progress.isScanning || progress.isGeneratingReport;
        notifyListeners();

        // When scan is fully completed (not generating report anymore), get results
        if (progress.isCompleted && !progress.isGeneratingReport && !progress.isCancelled) {
          _getResults();
        }
      });
    } catch (e) {
      _isScanning = false;
      _currentProgress = ScanProgress.initial.copyWith(
        isCancelled: true,
        phaseDescription: 'Scan failed: ${e.toString()}',
      );
      notifyListeners();
    }
  }

  Future<void> _getResults() async {
    try {
      // Get the final results from the service
      _scanResult = await _service.getResults();
      notifyListeners();
    } catch (e) {
      print('Error getting scan results: $e');
      // Results might not be available yet, but that's handled by the service
    }
  }

  Future<void> cancelScan() async {
    if (!_isScanning) return;

    await _service.cancelScan();
    _isScanning = false;
    _currentProgress = ScanProgress.initial.copyWith(isCancelled: true);
    notifyListeners();
  }

  void reset() {
    _selectedPath = null;
    _currentProgress = ScanProgress.initial;
    _scanResult = null;
    _isScanning = false;
    notifyListeners();
  }

  void toggleGroupSelection(String groupId) {
    if (_scanResult == null) return;

    final updatedGroups = _scanResult!.duplicateGroups.map((group) {
      if (group.id == groupId) {
        return group.copyWith(isSelected: !group.isSelected);
      }
      return group;
    }).toList();

    _scanResult = ScanResult(
      duplicateGroups: updatedGroups,
      totalDuplicates: _scanResult!.totalDuplicates,
      totalWastedSpace: _scanResult!.totalWastedSpace,
      scanCompletedAt: _scanResult!.scanCompletedAt,
      scannedPath: _scanResult!.scannedPath,
    );
    notifyListeners();
  }

  void selectAllGroups() {
    if (_scanResult == null) return;

    final updatedGroups = _scanResult!.duplicateGroups
        .map((group) => group.copyWith(isSelected: true))
        .toList();

    _scanResult = ScanResult(
      duplicateGroups: updatedGroups,
      totalDuplicates: _scanResult!.totalDuplicates,
      totalWastedSpace: _scanResult!.totalWastedSpace,
      scanCompletedAt: _scanResult!.scanCompletedAt,
      scannedPath: _scanResult!.scannedPath,
    );
    notifyListeners();
  }

  void deselectAllGroups() {
    if (_scanResult == null) return;

    final updatedGroups = _scanResult!.duplicateGroups
        .map((group) => group.copyWith(isSelected: false))
        .toList();

    _scanResult = ScanResult(
      duplicateGroups: updatedGroups,
      totalDuplicates: _scanResult!.totalDuplicates,
      totalWastedSpace: _scanResult!.totalWastedSpace,
      scanCompletedAt: _scanResult!.scanCompletedAt,
      scannedPath: _scanResult!.scannedPath,
    );
    notifyListeners();
  }

  Future<void> deleteSelectedItems() async {
    if (_scanResult == null) return;

    final selectedGroups = _scanResult!.selectedGroups;
    if (selectedGroups.isEmpty) return;

    // Collect all file paths to delete
    final pathsToDelete = <String>[];
    for (final group in selectedGroups) {
      // Skip the first file in each group (keep one copy)
      pathsToDelete.addAll(group.filePaths.skip(1));
    }

    try {
      final success = await _service.deleteItems(pathsToDelete);
      if (success) {
        // Remove deleted groups from results
        final remainingGroups = _scanResult!.duplicateGroups
            .where((group) => !group.isSelected)
            .toList();

        _scanResult = ScanResult(
          duplicateGroups: remainingGroups,
          totalDuplicates: remainingGroups.length,
          totalWastedSpace: remainingGroups.fold<int>(
            0,
            (sum, group) => sum + (group.fileSize * (group.duplicateCount - 1)),
          ),
          scanCompletedAt: _scanResult!.scanCompletedAt,
          scannedPath: _scanResult!.scannedPath,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting items: $e');
    }
  }

  Future<void> showInExplorer(String path) async {
    await _service.showInExplorer(path);
  }

  Future<bool> deleteIndividualPaths(List<String> pathsToDelete) async {
    try {
      final success = await _service.deleteItems(pathsToDelete);
      if (success && _scanResult != null) {
        // Update the scan result by removing the deleted paths from all groups
        final updatedGroups = <DuplicateGroup>[];
        
        for (final group in _scanResult!.duplicateGroups) {
          final remainingPaths = group.filePaths.where((path) => !pathsToDelete.contains(path)).toList();
          
          // If this group has less than 2 paths remaining, it's no longer a duplicate
          if (remainingPaths.length >= 2) {
            // Update the group with remaining paths
            updatedGroups.add(group.copyWith(
              filePaths: remainingPaths,
              duplicateCount: remainingPaths.length,
            ));
          }
        }

        _scanResult = ScanResult(
          duplicateGroups: updatedGroups,
          totalDuplicates: updatedGroups.length,
          totalWastedSpace: updatedGroups.fold<int>(
            0,
            (sum, group) => sum + (group.fileSize * (group.duplicateCount - 1)),
          ),
          scanCompletedAt: _scanResult!.scanCompletedAt,
          scannedPath: _scanResult!.scannedPath,
        );
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error deleting individual paths: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
