import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../models/scan_report.dart';
import 'home_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              context.read<ScanProvider>().reset();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('New Scan'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<ScanProvider>(
        builder: (context, scanProvider, child) {
          final result = scanProvider.scanResult;
          if (result == null) {
            return const Center(
              child: Text('No scan results available'),
            );
          }

          if (result.duplicateGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Duplicates Found!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your selected folder is clean.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Separate and sort folders and files
          final folders = result.duplicateGroups
              .where((group) => group.type == FileType.folder)
              .toList()
            ..sort((a, b) => (b.fileSize * b.duplicateCount).compareTo(a.fileSize * a.duplicateCount));
          
          final files = result.duplicateGroups
              .where((group) => group.type == FileType.file)
              .toList()
            ..sort((a, b) => (b.fileSize * b.duplicateCount).compareTo(a.fileSize * a.duplicateCount));

          return Column(
            children: [
              // Header with summary
              Container(
                padding: const EdgeInsets.all(24),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.duplicateGroupCount} duplicate groups found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total wasted space: ${result.formattedWastedSpace}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Results list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Folders section
                    if (folders.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.folder, 
                               color: Theme.of(context).colorScheme.primary,
                               size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Duplicate Folders (${folders.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...folders.map((group) => _DuplicateGroupCard(
                        group: group,
                        onToggleSelection: () {
                          scanProvider.toggleGroupSelection(group.id);
                        },
                        onShowInExplorer: (path) {
                          scanProvider.showInExplorer(path);
                        },
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Divider between folders and files
                    if (folders.isNotEmpty && files.isNotEmpty)
                      Divider(
                        thickness: 2,
                        color: Theme.of(context).colorScheme.outline,
                      ),

                    // Files section
                    if (files.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.description, 
                               color: Theme.of(context).colorScheme.secondary,
                               size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Duplicate Files (${files.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...files.map((group) => _DuplicateGroupCard(
                        group: group,
                        onToggleSelection: () {
                          scanProvider.toggleGroupSelection(group.id);
                        },
                        onShowInExplorer: (path) {
                          scanProvider.showInExplorer(path);
                        },
                      )),
                    ],
                  ],
                ),
              ),

              // Footer with bulk actions - temporarily disabled as we've moved to individual path selection
              // TODO: We could potentially add a global selection system here if needed
              /*
              if (result.duplicateGroups.any((g) => g.isSelected))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected: ${result.selectedCount} items',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => scanProvider.selectAllGroups(),
                            child: const Text('Select All'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => scanProvider.deselectAllGroups(),
                            child: const Text('Deselect All'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showDeleteConfirmation(
                              context,
                              scanProvider,
                            ),
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete Selected'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              */
            ],
          );
        },
      ),
    );
  }
}

class _DuplicateGroupCard extends StatefulWidget {
  final DuplicateGroup group;
  final VoidCallback onToggleSelection;
  final Function(String) onShowInExplorer;

  const _DuplicateGroupCard({
    required this.group,
    required this.onToggleSelection,
    required this.onShowInExplorer,
  });

  @override
  State<_DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<_DuplicateGroupCard> {
  bool _isExpanded = false;
  // ignore: prefer_final_fields
  Set<String> _selectedPaths = <String>{};

  String _formatSizeInfo() {
    final individualSize = widget.group.formattedSize;
    final totalSize = _formatBytes(widget.group.fileSize * widget.group.duplicateCount);
    return '$totalSize ($individualSize × ${widget.group.duplicateCount})';
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  void _showDeleteIndividualConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Selected Paths'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete ${_selectedPaths.length} selected files/folders?',
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _selectedPaths.map((path) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          path,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSelectedPaths();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedPaths() async {
    // Here we need to access the scan provider to delete the selected paths
    // We'll use a try/catch to handle any errors
    try {
      final scanProvider = Provider.of<ScanProvider>(context, listen: false);
      
      // Convert Set to List for the service
      final pathsToDelete = _selectedPaths.toList();
      
      // Call the service to delete the files
      final success = await scanProvider.deleteIndividualPaths(pathsToDelete);
      
      if (success) {
        setState(() {
          _selectedPaths.clear();
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted ${pathsToDelete.length} files/folders'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete some files/folders'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting files: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxPathsToShow = 3;
    final hasMorePaths = widget.group.filePaths.length > maxPathsToShow;
    final pathsToShow = _isExpanded 
        ? widget.group.filePaths 
        : widget.group.filePaths.take(maxPathsToShow).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon and name
            Row(
              children: [
                Icon(
                  widget.group.type == FileType.folder ? Icons.folder : Icons.description,
                  color: widget.group.type == FileType.folder 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.group.fileName} (${widget.group.duplicateCount} copies)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSizeInfo(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Paths list
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with locations label
                  Text(
                    'Locations:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Select All checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _selectedPaths.length == widget.group.filePaths.length && _selectedPaths.isNotEmpty,
                        tristate: true,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              // Select all paths in this group
                              _selectedPaths.addAll(widget.group.filePaths);
                            } else {
                              // Deselect all paths in this group
                              _selectedPaths.removeWhere((path) => widget.group.filePaths.contains(path));
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select All',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Scrollable paths container
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _isExpanded && widget.group.filePaths.length > maxPathsToShow 
                          ? 200 
                          : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: pathsToShow.map((path) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                // Individual checkbox for each path
                                Checkbox(
                                  value: _selectedPaths.contains(path),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedPaths.add(path);
                                      } else {
                                        _selectedPaths.remove(path);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          path,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Individual Show button for each path
                                OutlinedButton(
                                  onPressed: () => widget.onShowInExplorer(path),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(60, 32),
                                  ),
                                  child: const Text(
                                    'Show',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Actions for individually selected paths
                  if (_selectedPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selectedPaths.length} individual paths selected',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedPaths.clear();
                                  });
                                },
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedPaths.addAll(pathsToShow);
                                  });
                                },
                                child: Text(
                                  'All Visible',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showDeleteIndividualConfirmation(context),
                                child: Text(
                                  'Delete Selected',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Expand/Collapse button if there are more paths
                  if (hasMorePaths)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isExpanded 
                              ? 'Show less' 
                              : 'Show ${widget.group.filePaths.length - maxPathsToShow} more...'),
                          Icon(_isExpanded 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            
            // Size visualization bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((widget.group.fileSize * widget.group.duplicateCount) / 1073741824).clamp(0.0, 1.0), // Scale relative to 1GB
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.group.type == FileType.folder
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary,
                        widget.group.type == FileType.folder
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
