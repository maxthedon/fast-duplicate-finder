import 'package:flutter/material.dart';
import '../models/scan_progress.dart';

class ScanProgressWidget extends StatelessWidget {
  final ScanProgress progress;
  final VoidCallback? onCancel;

  const ScanProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  Future<void> _showCancelConfirmation(BuildContext context) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Abort'),
          content: const Text(
            'Are you sure you want to abort the scan? '
            'This will halt the current operation and you\'ll lose the progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Abort'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && onCancel != null) {
      onCancel!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _showCancelConfirmation(context),
                    tooltip: 'Cancel scan',
                  ),
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
    );
  }
}
