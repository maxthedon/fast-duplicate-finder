import 'scan_report.dart';

class ScanResult {
  final List<DuplicateGroup> duplicateGroups;
  final int totalDuplicates;
  final int totalWastedSpace; // in bytes
  final DateTime scanStartedAt;
  final DateTime scanCompletedAt;
  final String scannedPath;

  const ScanResult({
    required this.duplicateGroups,
    required this.totalDuplicates,
    required this.totalWastedSpace,
    required this.scanStartedAt,
    required this.scanCompletedAt,
    required this.scannedPath,
  });

  static ScanResult empty = ScanResult(
    duplicateGroups: const [],
    totalDuplicates: 0,
    totalWastedSpace: 0,
    scanStartedAt: DateTime.now(),
    scanCompletedAt: DateTime.now(),
    scannedPath: '',
  );

  int get duplicateGroupCount => duplicateGroups.length;
  
  Duration get scanDuration => scanCompletedAt.difference(scanStartedAt);
  
  String get formattedScanDuration {
    final duration = scanDuration;
    
    if (duration.inMinutes >= 60) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    } else if (duration.inSeconds >= 60) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    } else if (duration.inSeconds >= 1) {
      return '${duration.inSeconds}s';
    } else {
      return '${duration.inMilliseconds}ms';
    }
  }
  
  String get formattedWastedSpace {
    if (totalWastedSpace == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = totalWastedSpace.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  List<DuplicateGroup> get selectedGroups =>
      duplicateGroups.where((group) => group.isSelected).toList();
      
  int get selectedCount => selectedGroups.length;
  
  int get selectedWastedSpace => selectedGroups.fold<int>(
        0, 
        (sum, group) => sum + (group.fileSize * (group.duplicateCount - 1)),
      );
}
