import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'processing_status_indicator.dart';
import '../services/spar_runs_service.dart';

/// A floating panel that displays current AI processing status and activities
class AIStatusPanel extends StatefulWidget {
  /// Whether to show the panel
  final bool isVisible;
  
  /// Callback when panel is dismissed
  final VoidCallback? onDismiss;
  
  /// Position of the panel on screen
  final AIStatusPanelPosition position;
  
  /// Maximum number of entries to show
  final int maxEntries;
  
  /// Whether to auto-hide completed items after delay
  final bool autoHideCompleted;
  
  /// Auto-hide delay for completed items
  final Duration autoHideDelay;

  const AIStatusPanel({
    super.key,
    this.isVisible = true,
    this.onDismiss,
    this.position = AIStatusPanelPosition.bottomRight,
    this.maxEntries = 3,
    this.autoHideCompleted = true,
    this.autoHideDelay = const Duration(seconds: 3),
  });

  @override
  State<AIStatusPanel> createState() => _AIStatusPanelState();
}

class _AIStatusPanelState extends State<AIStatusPanel>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  Timer? _refreshTimer;
  Timer? _autoHideTimer;
  List<Map<String, dynamic>> _activeRuns = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: _getHiddenOffset(),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);
    
    if (widget.isVisible) {
      _show();
    }
    
    _startRefreshTimer();
    _loadActiveRuns();
  }

  @override
  void didUpdateWidget(AIStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && !oldWidget.isVisible) {
      _show();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hide();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _refreshTimer?.cancel();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _show() {
    _slideController.forward();
    _fadeController.forward();
  }

  void _hide() {
    _slideController.reverse();
    _fadeController.reverse();
  }

  Offset _getHiddenOffset() {
    switch (widget.position) {
      case AIStatusPanelPosition.topLeft:
        return const Offset(-1.0, 0.0);
      case AIStatusPanelPosition.topRight:
        return const Offset(1.0, 0.0);
      case AIStatusPanelPosition.bottomLeft:
        return const Offset(-1.0, 0.0);
      case AIStatusPanelPosition.bottomRight:
        return const Offset(1.0, 0.0);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadActiveRuns();
    });
  }

  Future<void> _loadActiveRuns() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final runs = await SPARRunsService.getUserSPARRuns(
        userId: user.id,
        limit: widget.maxEntries * 2, // Get more to filter
      );

      // Filter to active runs (pending, processing) and recent completed/failed
      final activeRuns = runs.where((run) {
        final status = run['status'] as String;
        
        // Always include pending and processing
        if (status == SPARRunsService.STATUS_PENDING || 
            status == SPARRunsService.STATUS_PROCESSING) {
          return true;
        }
        
        // Include recent completed/failed runs for a short time
        if (status == SPARRunsService.STATUS_COMPLETED || 
            status == SPARRunsService.STATUS_FAILED ||
            status == SPARRunsService.STATUS_TIMEOUT) {
          final createdAt = DateTime.parse(run['created_at']);
          final age = DateTime.now().difference(createdAt);
          return age.inMinutes < 2; // Show for 2 minutes after completion
        }
        
        return false;
      }).take(widget.maxEntries).toList();

      if (mounted) {
        setState(() {
          _activeRuns = activeRuns;
        });
        
        // Auto-hide if no active runs
        if (activeRuns.isEmpty && widget.autoHideCompleted) {
          _scheduleAutoHide();
        }
      }
    } catch (e) {
      print('Error loading active runs: $e');
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.autoHideDelay, () {
      if (mounted && _activeRuns.isEmpty) {
        widget.onDismiss?.call();
      }
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _retryRun(String runId) async {
    try {
      await SPARRunsService.retrySPARRun(runId);
      _loadActiveRuns(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI analysis retry initiated'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeRuns.isEmpty && !widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: _getTop(),
      bottom: _getBottom(),
      left: _getLeft(),
      right: _getRight(),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 320,
                maxHeight: _isExpanded ? 400 : 120,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _buildPanelContent(),
            ),
          ),
        ),
      ),
    );
  }

  double? _getTop() {
    switch (widget.position) {
      case AIStatusPanelPosition.topLeft:
      case AIStatusPanelPosition.topRight:
        return 80;
      case AIStatusPanelPosition.bottomLeft:
      case AIStatusPanelPosition.bottomRight:
        return null;
    }
  }

  double? _getBottom() {
    switch (widget.position) {
      case AIStatusPanelPosition.topLeft:
      case AIStatusPanelPosition.topRight:
        return null;
      case AIStatusPanelPosition.bottomLeft:
      case AIStatusPanelPosition.bottomRight:
        return 100;
    }
  }

  double? _getLeft() {
    switch (widget.position) {
      case AIStatusPanelPosition.topLeft:
      case AIStatusPanelPosition.bottomLeft:
        return 16;
      case AIStatusPanelPosition.topRight:
      case AIStatusPanelPosition.bottomRight:
        return null;
    }
  }

  double? _getRight() {
    switch (widget.position) {
      case AIStatusPanelPosition.topLeft:
      case AIStatusPanelPosition.bottomLeft:
        return null;
      case AIStatusPanelPosition.topRight:
      case AIStatusPanelPosition.bottomRight:
        return 16;
    }
  }

  Widget _buildPanelContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        if (_isExpanded || _activeRuns.length <= 1) _buildRunsList(),
      ],
    );
  }

  Widget _buildHeader() {
    final activeCount = _activeRuns.where((run) {
      final status = run['status'] as String;
      return status == SPARRunsService.STATUS_PENDING || 
             status == SPARRunsService.STATUS_PROCESSING;
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology,
            size: 18,
            color: Colors.blue[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeCount > 0 
                  ? 'AI Processing ($activeCount active)'
                  : 'AI Processing Complete',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
                fontSize: 14,
              ),
            ),
          ),
          if (_activeRuns.length > 1)
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.blue[600],
                ),
              ),
            ),
          InkWell(
            onTap: widget.onDismiss,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunsList() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: _isExpanded ? 320 : 200,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        itemCount: _activeRuns.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildRunItem(_activeRuns[index]);
        },
      ),
    );
  }

  Widget _buildRunItem(Map<String, dynamic> run) {
    final status = (run['status'] as String).toProcessingStatus();
    final journalId = run['journal_entry_id'] as String;
    final createdAt = DateTime.parse(run['created_at']);
    final age = DateTime.now().difference(createdAt);
    
    String timeText;
    if (age.inMinutes < 1) {
      timeText = '${age.inSeconds}s ago';
    } else if (age.inHours < 1) {
      timeText = '${age.inMinutes}m ago';
    } else {
      timeText = '${age.inHours}h ago';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getRunBackgroundColor(status),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getRunBorderColor(status)),
      ),
      child: Row(
        children: [
          ProcessingStatusIndicator(
            status: status,
            size: ProcessingStatusSize.small,
            showStatusText: false,
            progress: _getRunProgress(run),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journal Entry Analysis',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_getStatusDisplayText(status)} • $timeText',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (status == ProcessingStatus.failed)
            InkWell(
              onTap: () => _retryRun(run['run_id']),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 12,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getRunBackgroundColor(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.pending:
        return Colors.orange[50]!;
      case ProcessingStatus.processing:
        return Colors.blue[50]!;
      case ProcessingStatus.completed:
        return Colors.green[50]!;
      case ProcessingStatus.failed:
        return Colors.red[50]!;
      case ProcessingStatus.timeout:
        return Colors.orange[100]!;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getRunBorderColor(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.pending:
        return Colors.orange[200]!;
      case ProcessingStatus.processing:
        return Colors.blue[200]!;
      case ProcessingStatus.completed:
        return Colors.green[200]!;
      case ProcessingStatus.failed:
        return Colors.red[200]!;
      case ProcessingStatus.timeout:
        return Colors.orange[300]!;
      default:
        return Colors.grey[200]!;
    }
  }

  double? _getRunProgress(Map<String, dynamic> run) {
    final status = run['status'] as String;
    if (status == SPARRunsService.STATUS_PROCESSING) {
      // Simulate progress based on time elapsed
      final createdAt = DateTime.parse(run['created_at']);
      final elapsed = DateTime.now().difference(createdAt).inSeconds;
      const estimatedDuration = 30; // 30 seconds estimated processing time
      return (elapsed / estimatedDuration).clamp(0.0, 0.9);
    }
    return null;
  }

  String _getStatusDisplayText(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.pending:
        return 'Queued';
      case ProcessingStatus.processing:
        return 'Processing';
      case ProcessingStatus.completed:
        return 'Complete';
      case ProcessingStatus.failed:
        return 'Failed';
      case ProcessingStatus.timeout:
        return 'Timed out';
      default:
        return 'Idle';
    }
  }
}

/// Position options for the AI status panel
enum AIStatusPanelPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Global AI status indicator for app bars
class GlobalAIStatusIndicator extends StatefulWidget {
  /// Callback when tapped to show details
  final VoidCallback? onTap;
  
  /// Whether to show badge with count
  final bool showBadge;

  const GlobalAIStatusIndicator({
    super.key,
    this.onTap,
    this.showBadge = true,
  });

  @override
  State<GlobalAIStatusIndicator> createState() => _GlobalAIStatusIndicatorState();
}

class _GlobalAIStatusIndicatorState extends State<GlobalAIStatusIndicator> {
  Timer? _refreshTimer;
  int _activeCount = 0;
  ProcessingStatus _overallStatus = ProcessingStatus.idle;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
    _loadStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadStatus();
    });
  }

  Future<void> _loadStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final runs = await SPARRunsService.getUserSPARRuns(
        userId: user.id,
        limit: 20,
      );

      final activeRuns = runs.where((run) {
        final status = run['status'] as String;
        return status == SPARRunsService.STATUS_PENDING || 
               status == SPARRunsService.STATUS_PROCESSING;
      }).toList();

      ProcessingStatus overallStatus;
      if (activeRuns.isEmpty) {
        overallStatus = ProcessingStatus.idle;
      } else if (activeRuns.any((r) => r['status'] == SPARRunsService.STATUS_PROCESSING)) {
        overallStatus = ProcessingStatus.processing;
      } else {
        overallStatus = ProcessingStatus.pending;
      }

      if (mounted) {
        setState(() {
          _activeCount = activeRuns.length;
          _overallStatus = overallStatus;
        });
      }
    } catch (e) {
      print('Error loading global AI status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProcessingStatusIndicator(
              status: _overallStatus,
              size: ProcessingStatusSize.small,
              showStatusText: false,
            ),
            if (widget.showBadge && _activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _activeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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