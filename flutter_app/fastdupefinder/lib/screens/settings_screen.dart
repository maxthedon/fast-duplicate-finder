import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final int _maxCpuCores = Platform.numberOfProcessors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showResetDialog(context),
            icon: const Icon(Icons.restore),
            label: const Text('Reset'),
          ),
          const SizedBox(width: AppTheme.paddingMedium),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Text(
                  'Performance Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.paddingSmall),
                Text(
                  'Configure advanced options to optimize scan performance for your system.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.paddingXLarge),

                // CPU Cores Setting Card
                _buildCpuCoresCard(context, settingsProvider),
                
                const SizedBox(height: AppTheme.paddingLarge),

                // Advanced Options Card
                _buildAdvancedOptionsCard(context, settingsProvider),
                
                const SizedBox(height: AppTheme.paddingLarge),

                // System Information Card
                _buildSystemInfoCard(context),
                
                const SizedBox(height: AppTheme.paddingXLarge),

                // Footer info
                _buildFooterInfo(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCpuCoresCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CPU Cores',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Number of CPU cores to use for parallel processing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingLarge),

            // Auto detection toggle
            CheckboxListTile(
              title: const Text('Auto Detection'),
              subtitle: Text(
                'Automatically use all available CPU cores ($_maxCpuCores cores)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: settings.useAutoCpuDetection,
              onChanged: (bool? value) {
                if (value == false) {
                  // Set to manual mode with current CPU count or 1
                  settingsProvider.updateCpuCores(
                    settings.cpuCores ?? 1,
                    useAuto: false,
                  );
                } else {
                  settingsProvider.setAutoCpuDetection();
                }
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Manual CPU selection
            if (!settings.useAutoCpuDetection) ...[
              const SizedBox(height: AppTheme.paddingMedium),
              Text(
                'Manual Selection',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: (settings.cpuCores ?? 1).toDouble(),
                      min: 1,
                      max: _maxCpuCores.toDouble(),
                      divisions: _maxCpuCores - 1,
                      label: '${settings.cpuCores ?? 1} cores',
                      onChanged: (double value) {
                        settingsProvider.updateCpuCores(
                          value.round(),
                          useAuto: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingMedium,
                      vertical: AppTheme.paddingSmall,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Text(
                      '${settings.cpuCores ?? 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              // CPU core buttons for quick selection
              const SizedBox(height: AppTheme.paddingMedium),
              Wrap(
                spacing: AppTheme.paddingSmall,
                children: List.generate(_maxCpuCores, (index) {
                  final coreCount = index + 1;
                  final isSelected = settings.cpuCores == coreCount;
                  
                  return ChoiceChip(
                    label: Text('$coreCount'),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        settingsProvider.updateCpuCores(
                          coreCount,
                          useAuto: false,
                        );
                      }
                    },
                  );
                }),
              ),
            ],

            const SizedBox(height: AppTheme.paddingMedium),
            
            // Current setting display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingSmall),
                  Text(
                    'Current setting: ${settings.getCpuDisplayText()} core${settings.useAutoCpuDetection || (settings.cpuCores ?? 1) > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: AppTheme.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advanced Options',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Configure advanced scanning behavior',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingLarge),

            // Filename Filtering Toggle
            SwitchListTile(
              title: const Text('Smart Filename Filtering'),
              subtitle: Text(
                'Controls how files are initially grouped for duplicate detection:\n\n'
                '✅ ENABLED: Only files with identical names AND sizes are considered potential duplicates\n'
                '• Pros: Faster scanning, fewer false positives\n'
                '• Cons: May miss duplicates with different filenames\n\n'
                '🔍 DISABLED (Default): All files with same size are considered potential duplicates\n'
                '• Pros: Finds all duplicates regardless of filename\n'
                '• Cons: Slower scanning, more files to analyze',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.4,
                ),
              ),
              value: settings.filterByFilename,
              onChanged: (bool value) {
                settingsProvider.updateFilenameFilter(value);
              },
              secondary: Icon(
                settings.filterByFilename ? Icons.filter_alt : Icons.filter_alt_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppTheme.paddingMedium),
            
            // Status display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingSmall),
                  Expanded(
                    child: Text(
                      settings.filterByFilename
                          ? '🎯 Smart filtering is ON: Only files with matching names and sizes will be grouped together for analysis.'
                          : '🔍 Complete scanning is ON: All files with the same size will be analyzed, regardless of filename (recommended for thorough duplicate detection).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.computer,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: AppTheme.paddingMedium),
                Text(
                  'System Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            
            _buildInfoRow(context, 'Platform', Platform.operatingSystem),
            _buildInfoRow(context, 'CPU Cores Available', '$_maxCpuCores'),
            _buildInfoRow(context, 'Architecture', _getPlatformArchitecture()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.paddingSmall),
              Text(
                'Performance Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.paddingSmall),
          Text(
            '• Auto detection uses all available cores for optimal performance\n'
            '• Manual selection allows fine-tuning for specific use cases\n'
            '• Using fewer cores may reduce system load during scanning\n'
            '• Changes take effect on the next scan',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlatformArchitecture() {
    // This is a simplified architecture detection
    // In a real app, you might want to use a more robust method
    if (Platform.isWindows) {
      return Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'Unknown';
    } else if (Platform.isLinux || Platform.isMacOS) {
      return 'x86_64'; // Most common for desktop
    }
    return 'Unknown';
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset Settings'),
          content: const Text(
            'Are you sure you want to reset all settings to their default values?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                context.read<SettingsProvider>().resetToDefaults();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                  ),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
