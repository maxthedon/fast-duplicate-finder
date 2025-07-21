class ScanProgress {
  final int currentPhase;
  final int totalPhases;
  final String phaseDescription;
  final int processedFiles;
  final double progressPercentage;
  final bool isScanning;
  final bool isCompleted;
  final bool isCancelled;
  final bool isGeneratingReport;
  final int duplicatesFound;
  final int currentItem;
  final int totalItems;

  const ScanProgress({
    required this.currentPhase,
    required this.totalPhases,
    required this.phaseDescription,
    required this.processedFiles,
    required this.progressPercentage,
    required this.isScanning,
    required this.isCompleted,
    required this.isCancelled,
    this.isGeneratingReport = false,
    this.duplicatesFound = 0,
    this.currentItem = 0,
    this.totalItems = 0,
  });

  static const ScanProgress initial = ScanProgress(
    currentPhase: 0,
    totalPhases: 5,
    phaseDescription: '',
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

  ScanProgress copyWith({
    int? currentPhase,
    int? totalPhases,
    String? phaseDescription,
    int? processedFiles,
    double? progressPercentage,
    bool? isScanning,
    bool? isCompleted,
    bool? isCancelled,
    bool? isGeneratingReport,
    int? duplicatesFound,
    int? currentItem,
    int? totalItems,
  }) {
    return ScanProgress(
      currentPhase: currentPhase ?? this.currentPhase,
      totalPhases: totalPhases ?? this.totalPhases,
      phaseDescription: phaseDescription ?? this.phaseDescription,
      processedFiles: processedFiles ?? this.processedFiles,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      isScanning: isScanning ?? this.isScanning,
      isCompleted: isCompleted ?? this.isCompleted,
      isCancelled: isCancelled ?? this.isCancelled,
      isGeneratingReport: isGeneratingReport ?? this.isGeneratingReport,
      duplicatesFound: duplicatesFound ?? this.duplicatesFound,
      currentItem: currentItem ?? this.currentItem,
      totalItems: totalItems ?? this.totalItems,
    );
  }

  String get phaseText {
    if (isGeneratingReport) {
      return 'Phase 5 of $totalPhases';
    }
    return 'Phase $currentPhase of $totalPhases';
  }
  
  int get progressPercent => (progressPercentage * 100).round();

  /// Get appropriate file count display based on current phase
  String get fileCountDisplay {
    if (isGeneratingReport) {
      return duplicatesFound > 0 ? '${_formatNumber(duplicatesFound)} duplicates found' : 'Finalizing results...';
    }
    
    switch (currentPhase) {
      case 1:
        return processedFiles > 0 ? 'Found ${_formatNumber(processedFiles)} files' : 'Calculating...';
      case 2:
      case 3:
        if (totalItems > 0 && currentItem > 0) {
          return '$currentItem of $totalItems (Suspects)';
        }
        return processedFiles > 0 ? '${_formatNumber(processedFiles)} suspects' : 'Calculating...';
      case 4:
        if (totalItems > 0 && currentItem > 0) {
          return '$currentItem of $totalItems (Folders)';
        }
        return duplicatesFound > 0 ? '${_formatNumber(duplicatesFound)} duplicates found' : 'Analyzing folders...';
      case 5:
        if (totalItems > 0) {
          return 'Processing ${_formatNumber(totalItems)} duplicates';
        }
        return duplicatesFound > 0 ? '${_formatNumber(duplicatesFound)} duplicates found' : 'Filtering results...';
      default:
        return processedFiles > 0 ? 'Processed: ${_formatNumber(processedFiles)} files' : 'Calculating...';
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }
}
