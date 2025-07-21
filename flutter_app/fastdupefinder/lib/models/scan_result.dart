import 'scan_report.dart';

class ScanResult {
  final List<DuplicateGroup> duplicateGroups;
  final int totalDuplicates;
  final int totalWastedSpace; // in bytes
  final DateTime scanCompletedAt;
  final String scannedPath;

  const ScanResult({
    required this.duplicateGroups,
    required this.totalDuplicates,
    required this.totalWastedSpace,
    required this.scanCompletedAt,
    required this.scannedPath,
  });

  static ScanResult empty = ScanResult(
    duplicateGroups: const [],
    totalDuplicates: 0,
    totalWastedSpace: 0,
    scanCompletedAt: DateTime.now(),
    scannedPath: '',
  );

  int get duplicateGroupCount => duplicateGroups.length;
  
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
