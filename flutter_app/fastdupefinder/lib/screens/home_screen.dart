import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/scan_progress_widget.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _selectFolder(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && context.mounted) {
      context.read<ScanProvider>().setSelectedPath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, scanProvider, child) {
        // Navigate to results screen when scan is completed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scanProvider.hasResults && 
              scanProvider.currentProgress.isCompleted && 
              !scanProvider.isScanning &&
              !scanProvider.currentProgress.isGeneratingReport) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ResultsScreen(),
              ),
            );
          }
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fast Duplicate Finder'),
            centerTitle: true,
            elevation: 0,
            actions: [
              // Settings button - only visible when not scanning
              if (!scanProvider.isScanning)
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Advanced Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Header section
                Text(
                  scanProvider.isScanning 
                    ? 'Scanning: ${scanProvider.selectedPath ?? ''}'
                    : 'Find and manage duplicate files efficiently',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                if (!scanProvider.isScanning) ...[
                  // Folder selection section
                  Text(
                    'Select Root Folder:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            scanProvider.selectedPath ?? 'No folder selected',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scanProvider.selectedPath != null
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _selectFolder(context),
                        child: const Text('Browse'),
                      ),
                      if (scanProvider.selectedPath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            scanProvider.setSelectedPath(null);
                          },
                          tooltip: 'Clear selection',
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Start scan button
                  Center(
                    child: ElevatedButton(
                      onPressed: scanProvider.canStartScan
                          ? () {
                              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                              scanProvider.startScan(settingsProvider: settingsProvider);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Start Scan',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ] else ...[
                  // Progress section
                  ScanProgressWidget(
                    progress: scanProvider.currentProgress,
                    onCancel: () => scanProvider.cancelScan(),
                  ),
                ],

                // Add some spacing and footer info
                if (!scanProvider.isScanning) ...[
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      'Select a folder to scan for duplicate files',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ), // End of Column
          ), // End of SingleChildScrollView
        ), // End of Padding (body)
        ); // End of Scaffold
      },
    );
  }
}
