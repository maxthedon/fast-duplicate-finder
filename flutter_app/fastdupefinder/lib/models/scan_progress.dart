class ScanProgress {
  final int currentPhase;
  final int totalPhases;
  final String phaseDescription;
  final int processedFiles;
  final double progressPercentage;
  final bool isScanning;
  final bool isCompleted;
  final bool isCancelled;

  const ScanProgress({
    required this.currentPhase,
    required this.totalPhases,
    required this.phaseDescription,
    required this.processedFiles,
    required this.progressPercentage,
    required this.isScanning,
    required this.isCompleted,
    required this.isCancelled,
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
    );
  }

  String get phaseText => 'Phase $currentPhase of $totalPhases';
  
  int get progressPercent => (progressPercentage * 100).round();
}
