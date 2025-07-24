import 'package:flutter/material.dart';
import '../models/scan_progress.dart';
import '../models/stage_progress.dart';
import 'stage_progress_widget.dart';

class ScanProgressWidget extends StatelessWidget {
  final ScanProgress progress;
  final VoidCallback? onCancel;

  const ScanProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final stageProgress = StageProgress.fromScanProgress(progress);
    
    return Column(
      children: [
        // Timeline stages view
        StageProgressWidget(
          stageProgress: stageProgress,
          onCancel: onCancel,
        ),
        const SizedBox(height: 16),
        
        // Traditional progress card for detailed info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress.phaseText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Remove cancel button from here since it's in the stage widget
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  progress.isGeneratingReport 
                    ? 'Generating Report'
                    : progress.phaseDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  progress.fileCountDisplay,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress.progressPercentage,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${progress.progressPercent}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
