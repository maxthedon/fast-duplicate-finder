import 'package:flutter/material.dart';
import '../models/stage_progress.dart';

class StageProgressWidget extends StatefulWidget {
  final StageProgress stageProgress;
  final VoidCallback? onCancel;

  const StageProgressWidget({
    super.key,
    required this.stageProgress,
    this.onCancel,
  });

  @override
  State<StageProgressWidget> createState() => _StageProgressWidgetState();
}

class _StageProgressWidgetState extends State<StageProgressWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Scroll to current stage after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentStage();
    });
  }

  @override
  void didUpdateWidget(StageProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to current stage when the stage changes
    if (oldWidget.stageProgress.currentStage != widget.stageProgress.currentStage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentStage();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentStage() {
    if (!_scrollController.hasClients) return;

    final currentStageIndex = widget.stageProgress.stages.indexWhere(
      (stage) => stage.type == widget.stageProgress.currentStage
    );

    if (currentStageIndex == -1) return;

    // Calculate the scroll position for the current stage
    // Each stage takes approximately 160px width + connectors (40px)
    const stageWidth = 160.0;
    const connectorWidth = 40.0;
    const totalStageWidth = stageWidth + connectorWidth;
    const padding = 8.0; // Horizontal padding from SingleChildScrollView
    
    // Calculate the target scroll position to center the current stage
    final stagePosition = (currentStageIndex * totalStageWidth) + padding;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition = stagePosition - (screenWidth / 2) + (stageWidth / 2);
    
    // Get the current scroll bounds
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final minScrollExtent = _scrollController.position.minScrollExtent;
    
    // Clamp the position within valid scroll bounds
    final clampedPosition = targetPosition.clamp(minScrollExtent, maxScrollExtent);

    // Only animate if we need to scroll significantly (more than 50px difference)
    final currentOffset = _scrollController.offset;
    if ((clampedPosition - currentOffset).abs() > 50) {
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLowest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern header section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.stageProgress.isCompleted 
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.stageProgress.isCompleted 
                        ? Icons.task_alt_rounded
                        : Icons.timeline_rounded,
                    color: widget.stageProgress.isCompleted 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stageProgress.isCompleted ? 'Scan Completed' : 'Scanning Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (!widget.stageProgress.isCompleted)
                        Text(
                          'Finding duplicates in your files...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!widget.stageProgress.isCompleted && !widget.stageProgress.isCancelled && widget.onCancel != null)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      onPressed: widget.onCancel,
                      tooltip: 'Cancel Scan',
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Enhanced horizontal timeline with auto-scroll
            SizedBox(
              height: 140, // Increased height to prevent overflow
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildTimelineStages(context),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Status summary for completed scans
            if (widget.stageProgress.isCompleted) 
              _buildCompletionSummary(context)
            else if (widget.stageProgress.isCancelled)
              _buildCancellationMessage(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimelineStages(BuildContext context) {
    final stages = widget.stageProgress.stages;
    final widgets = <Widget>[];

    for (int i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final isLast = i == stages.length - 1;
      final isCurrent = widget.stageProgress.currentStage == stage.type;

      // Add stage node  
      widgets.add(_buildStageNode(context, stage, isCurrent));

      // Add connector line (except for last stage)
      if (!isLast) {
        widgets.add(_buildConnector(context, stage.isCompleted));
      }
    }

    return widgets;
  }

  Widget _buildStageNode(BuildContext context, StageInfo stage, bool isCurrent) {
    final theme = Theme.of(context);
    final isCompleted = stage.isCompleted;
    final isActive = stage.isActive;
    
    return SizedBox(
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage circle with enhanced design
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCompleted || isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStageColor(context, stage, isCurrent),
                        _getStageColor(context, stage, isCurrent).withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              color: isCompleted || isActive 
                  ? null 
                  : theme.colorScheme.surfaceContainerHigh,
              border: Border.all(
                color: isCompleted || isActive
                    ? _getStageColor(context, stage, isCurrent).withValues(alpha: 0.3)
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: _getStageColor(context, stage, isCurrent).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main icon
                Icon(
                  _getStageIconData(stage),
                  color: isCompleted || isActive
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                // Loading indicator for active stage
                if (isActive)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8), // Reduced spacing
          
          // Stage title
          Text(
            stage.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
              color: isCompleted || isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12, // Slightly smaller to fit better
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Count badge with modern design or active indicator
          if (stage.count != null && stage.count! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
              decoration: BoxDecoration(
                color: _getStageColor(context, stage, isCurrent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStageColor(context, stage, isCurrent).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                // For "Done" stage, show the count as is (duplicates), for others show as percentage
                stage.type == StageType.done 
                    ? stage.displayCount
                    : '${stage.count}%',
                style: theme.textTheme.labelSmall?.copyWith( // Smaller text
                  color: _getStageColor(context, stage, isCurrent),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (isActive && (stage.count == null || stage.count! == 0))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else if (isCompleted && (stage.count == null || stage.count! == 0))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Done',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnector(BuildContext context, bool isCompleted) {
    final theme = Theme.of(context);
    
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 50), // Adjusted to align with smaller layout
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: isCompleted 
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                  theme.colorScheme.primary.withValues(alpha: 0.4),
                ],
              )
            : null,
        color: isCompleted 
            ? null 
            : theme.colorScheme.outline.withValues(alpha: 0.2),
      ),
    );
  }

  IconData _getStageIconData(StageInfo stage) {
    switch (stage.type) {
      case StageType.started:
        return Icons.play_circle_filled_rounded;
      case StageType.discovering:
        return Icons.folder_open_rounded;
      case StageType.findingSuspects:
        return Icons.search_rounded;
      case StageType.filteringSuspects:
        return Icons.analytics_rounded;
      case StageType.findingFolders:
        return Icons.folder_copy_rounded;
      case StageType.filteringFolders:
        return Icons.filter_list_rounded;
      case StageType.done:
        return Icons.check_circle_rounded;
    }
  }

  Widget _buildCompletionSummary(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Completed Successfully!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your duplicate analysis is ready for review.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationMessage(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cancel_rounded,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Scan was cancelled by user.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Color _getStageColor(BuildContext context, StageInfo stage, bool isCurrent) {
    final theme = Theme.of(context);
    
    if (stage.isCompleted) {
      return theme.colorScheme.primary;
    } else if (stage.isActive || isCurrent) {
      return theme.colorScheme.secondary;
    } else {
      return theme.colorScheme.outline;
    }
  }
}
