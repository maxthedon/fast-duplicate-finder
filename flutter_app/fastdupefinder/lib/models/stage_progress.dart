import '../models/scan_progress.dart';

enum StageType {
  started,
  discovering,
  findingSuspects,
  filteringSuspects,
  findingFolders,
  filteringFolders,
  done,
}

class StageInfo {
  final StageType type;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isActive;
  final int? count;
  final String? detail;
  final DateTime? completedAt;

  const StageInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isActive,
    this.count,
    this.detail,
    this.completedAt,
  });

  StageInfo copyWith({
    StageType? type,
    String? title,
    String? description,
    bool? isCompleted,
    bool? isActive,
    int? count,
    String? detail,
    DateTime? completedAt,
  }) {
    return StageInfo(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
      count: count ?? this.count,
      detail: detail ?? this.detail,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get displayCount {
    if (count == null) return '';
    return _formatNumber(count!);
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class StageProgress {
  final List<StageInfo> stages;
  final StageType currentStage;
  final bool isCompleted;
  final bool isCancelled;

  const StageProgress({
    required this.stages,
    required this.currentStage,
    required this.isCompleted,
    required this.isCancelled,
  });

  static StageProgress fromScanProgress(ScanProgress scanProgress) {
    final stages = <StageInfo>[];
    StageType currentStageType = StageType.started;

    // Initialize all stages with user-friendly names and percentage-based approach
    final stageDefinitions = [
      (StageType.started, 'Started', 'Initializing duplicate file scan'),
      (StageType.discovering, 'Discovering', 'Finding all files in directory'),
      (
        StageType.findingSuspects,
        'Finding Suspects',
        'Grouping files by size to find potential duplicates',
      ),
      (
        StageType.filteringSuspects,
        'Filtering Suspects',
        'Computing file hashes to confirm duplicates',
      ),
      (
        StageType.findingFolders,
        'Finding Folders',
        'Analyzing folders for duplicate content',
      ),
      (
        StageType.filteringFolders,
        'Filtering Folders',
        'Filtering nested duplicate folders',
      ),
      (StageType.done, 'Done', 'Scan completed successfully'),
    ];

    // Determine current stage based on scan progress
    if (scanProgress.isCompleted) {
      currentStageType = StageType.done;
    } else if (scanProgress.isCancelled) {
      currentStageType = StageType.started; // Reset to first stage if cancelled
    } else {
      // Map Go phases to stages with new simplified approach
      switch (scanProgress.currentPhase) {
        case 1:
          // Phase 1: File discovery (0-20%)
          currentStageType = scanProgress.processedFiles > 0
              ? StageType.discovering
              : StageType.started;
          break;
        case 2:
          // Phase 2: Group by size and partial hash (20-40%)
          currentStageType = StageType.findingSuspects;
          break;
        case 3:
          // Phase 3: Compute full hashes (40-60%)
          currentStageType = StageType.filteringSuspects;
          break;
        case 4:
          // Phase 4: Find duplicate folders (60-80%)
          currentStageType = StageType.findingFolders;
          break;
        case 5:
          // Phase 5: Filter results (80-100%)
          currentStageType = StageType.filteringFolders;
          break;
        default:
          currentStageType = StageType.started;
      }
    }

    // Build stages with completion status
    for (int i = 0; i < stageDefinitions.length; i++) {
      final (type, title, description) = stageDefinitions[i];
      final stageIndex = StageType.values.indexOf(type);
      final currentStageIndex = StageType.values.indexOf(currentStageType);

      bool isCompleted =
          stageIndex < currentStageIndex ||
          (scanProgress.isCompleted && type == StageType.done);
      bool isActive = type == currentStageType && scanProgress.isScanning;

      int? count;
      String? detail;

      // Set count and detail based on stage and scan progress
      // Using percentage-based approach instead of complex counting
      switch (type) {
        case StageType.started:
          isCompleted =
              scanProgress.currentPhase > 0 || scanProgress.isCompleted;
          if (isActive) {
            detail = 'Initializing scan...';
          }
          break;

        case StageType.discovering:
          isCompleted =
              scanProgress.currentPhase > 1 || scanProgress.isCompleted;

          if (isActive || isCompleted) {
            if (isActive) {
              // Don't show percentage for discovering - show "Active" instead
              count = null; // This will make the widget show "Active"
              detail = 'Discovering files in directory...';
            } else if (isCompleted) {
              // When completed, don't show file count - keep count null to show "Done"
              count = null;
              detail = 'File discovery completed';
            }
          }
          break;

        case StageType.findingSuspects:
          // Phase 2: 20-40% -> 0-100% of this stage
          if (scanProgress.currentPhase >= 2) {
            isCompleted =
                scanProgress.currentPhase > 2 || scanProgress.isCompleted;

            if (isActive || isCompleted) {
              if (isActive) {
                final phaseProgress =
                    ((scanProgress.progressPercentage - 0.2) * 5).clamp(
                      0.0,
                      1.0,
                    ) *
                    100.0;
                count = phaseProgress.round().clamp(
                  1,
                  100,
                ); // Ensure we always have at least 1% when active
                detail = 'Grouping files by size...';
              } else if (isCompleted) {
                count = 100;
                detail = 'Size-based grouping completed';
              }
            }
          }
          break;

        case StageType.filteringSuspects:
          // Phase 3: 40-60% -> 0-100% of this stage
          if (scanProgress.currentPhase >= 3) {
            isCompleted =
                scanProgress.currentPhase > 3 || scanProgress.isCompleted;

            if (isActive || isCompleted) {
              if (isActive) {
                final phaseProgress =
                    ((scanProgress.progressPercentage - 0.4) * 5).clamp(
                      0.0,
                      1.0,
                    ) *
                    100.0;
                count = phaseProgress.round().clamp(
                  1,
                  100,
                ); // Ensure we always have at least 1% when active
                detail = 'Computing file hashes...';
              } else if (isCompleted) {
                count = 100;
                detail = 'Hash computation completed';
              }
            }
          }
          break;

        case StageType.findingFolders:
          // Phase 4: 60-80% -> 0-100% of this stage
          if (scanProgress.currentPhase >= 4) {
            isCompleted =
                scanProgress.currentPhase > 4 || scanProgress.isCompleted;

            if (isActive || isCompleted) {
              if (isActive) {
                final phaseProgress =
                    ((scanProgress.progressPercentage - 0.6) * 5).clamp(
                      0.0,
                      1.0,
                    ) *
                    100.0;
                count = phaseProgress.round().clamp(
                  1,
                  100,
                ); // Ensure we always have at least 1% when active
                detail = 'Analyzing folders for duplicates...';
              } else if (isCompleted) {
                count = 100;
                detail = 'Folder analysis completed';
              }
            }
          }
          break;

        case StageType.filteringFolders:
          // Phase 5: 80-100% -> 0-100% of this stage
          if (scanProgress.currentPhase >= 5) {
            isCompleted = scanProgress.isCompleted;

            if (isActive || isCompleted) {
              if (isActive) {
                final phaseProgress =
                    ((scanProgress.progressPercentage - 0.8) * 5).clamp(
                      0.0,
                      1.0,
                    ) *
                    100.0;
                count = phaseProgress.round().clamp(
                  1,
                  100,
                ); // Ensure we always have at least 1% when active
                detail = 'Filtering duplicate folders...';
              } else if (isCompleted) {
                count = 100;
                detail = 'Folder filtering completed';
              }
            }
          }
          break;

        case StageType.done:
          isCompleted = scanProgress.isCompleted;
          isActive = false;
          if (isCompleted) {
            // Show duplicate count instead of percentage
            count = scanProgress.duplicatesFound > 0
                ? scanProgress.duplicatesFound
                : null;
            detail = count != null
                ? '${_formatNumber(count)} Duplicates Found'
                : 'Scan completed';
          }
          break;
      }

      stages.add(
        StageInfo(
          type: type,
          title: title,
          description: description,
          isCompleted: isCompleted,
          isActive: isActive,
          count: count,
          detail: detail,
          completedAt: isCompleted ? DateTime.now() : null,
        ),
      );
    }

    return StageProgress(
      stages: stages,
      currentStage: currentStageType,
      isCompleted: scanProgress.isCompleted,
      isCancelled: scanProgress.isCancelled,
    );
  }

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  StageInfo? get currentStageInfo {
    try {
      return stages.firstWhere((stage) => stage.type == currentStage);
    } catch (e) {
      return null;
    }
  }

  List<StageInfo> get completedStages {
    return stages.where((stage) => stage.isCompleted).toList();
  }

  List<StageInfo> get remainingStages {
    return stages
        .where((stage) => !stage.isCompleted && !stage.isActive)
        .toList();
  }
}
