import 'package:flutter/material.dart';
import '../services/spar_runs_service.dart';

/// Processing status values for AI operations
enum ProcessingStatus {
  idle,       // No processing happening
  pending,    // Submitted, waiting to start
  processing, // Currently processing
  completed,  // Successfully completed
  failed,     // Failed with error
  timeout,    // Timed out
}

/// A versatile widget that displays AI processing status with animations and indicators
class ProcessingStatusIndicator extends StatefulWidget {
  /// The current processing status
  final ProcessingStatus status;
  
  /// Optional status message to display
  final String? message;
  
  /// Optional error message for failed status
  final String? errorMessage;
  
  /// Progress value (0.0 to 1.0) for processing status
  final double? progress;
  
  /// Size variant of the indicator
  final ProcessingStatusSize size;
  
  /// Whether to show the status text
  final bool showStatusText;
  
  /// Whether to show the retry button on failure
  final bool showRetryButton;
  
  /// Callback for retry action
  final VoidCallback? onRetry;
  
  /// Callback when tapped (for details/info)
  final VoidCallback? onTap;
  
  /// Custom icon to override default status icons
  final IconData? customIcon;
  
  /// Custom color to override status colors
  final Color? customColor;

  const ProcessingStatusIndicator({
    super.key,
    required this.status,
    this.message,
    this.errorMessage,
    this.progress,
    this.size = ProcessingStatusSize.medium,
    this.showStatusText = true,
    this.showRetryButton = true,
    this.onRetry,
    this.onTap,
    this.customIcon,
    this.customColor,
  });

  @override
  State<ProcessingStatusIndicator> createState() => _ProcessingStatusIndicatorState();
}

class _ProcessingStatusIndicatorState extends State<ProcessingStatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation for pulsing effect (pending/processing states)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animation for rotating effect (processing state)
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_rotationController);

    _updateAnimations();
  }

  @override
  void didUpdateWidget(ProcessingStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    switch (widget.status) {
      case ProcessingStatus.pending:
        _pulseController.repeat(reverse: true);
        _rotationController.stop();
        break;
      case ProcessingStatus.processing:
        _pulseController.repeat(reverse: true);
        _rotationController.repeat();
        break;
      case ProcessingStatus.completed:
      case ProcessingStatus.failed:
      case ProcessingStatus.timeout:
      case ProcessingStatus.idle:
        _pulseController.stop();
        _rotationController.stop();
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: _getPadding(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(),
            if (widget.showStatusText && _shouldShowText()) ...[
              const SizedBox(width: 8),
              _buildStatusText(),
            ],
            if (widget.showRetryButton && 
                widget.status == ProcessingStatus.failed && 
                widget.onRetry != null) ...[
              const SizedBox(width: 8),
              _buildRetryButton(),
            ],
          ],
        ),
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case ProcessingStatusSize.small:
        return const EdgeInsets.all(4);
      case ProcessingStatusSize.medium:
        return const EdgeInsets.all(8);
      case ProcessingStatusSize.large:
        return const EdgeInsets.all(12);
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ProcessingStatusSize.small:
        return 16;
      case ProcessingStatusSize.medium:
        return 20;
      case ProcessingStatusSize.large:
        return 24;
    }
  }

  bool _shouldShowText() {
    return widget.size != ProcessingStatusSize.small;
  }

  Widget _buildStatusIcon() {
    final iconSize = _getIconSize();
    final color = widget.customColor ?? _getStatusColor();
    final icon = widget.customIcon ?? _getStatusIcon();

    Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: color,
    );

    // Apply animations based on status
    switch (widget.status) {
      case ProcessingStatus.pending:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: iconWidget,
            );
          },
        );
      case ProcessingStatus.processing:
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background pulsing circle
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: iconSize * _pulseAnimation.value,
                  height: iconSize * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                  ),
                );
              },
            ),
            // Rotating icon
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: iconWidget,
                );
              },
            ),
            // Progress indicator if available
            if (widget.progress != null)
              SizedBox(
                width: iconSize * 1.5,
                height: iconSize * 1.5,
                child: CircularProgressIndicator(
                  value: widget.progress,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: color.withOpacity(0.2),
                ),
              ),
          ],
        );
      default:
        return iconWidget;
    }
  }

  Widget _buildStatusText() {
    final message = widget.message ?? _getDefaultMessage();
    final color = widget.customColor ?? _getStatusColor();
    
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: _getTextSize(),
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.status == ProcessingStatus.failed && widget.errorMessage != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.errorMessage!,
              style: TextStyle(
                fontSize: _getTextSize() - 2,
                color: Colors.red[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  double _getTextSize() {
    switch (widget.size) {
      case ProcessingStatusSize.small:
        return 10;
      case ProcessingStatusSize.medium:
        return 12;
      case ProcessingStatusSize.large:
        return 14;
    }
  }

  Widget _buildRetryButton() {
    return InkWell(
      onTap: widget.onRetry,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              size: _getIconSize() * 0.8,
              color: Colors.orange[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Retry',
              style: TextStyle(
                fontSize: _getTextSize(),
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case ProcessingStatus.idle:
        return Icons.offline_bolt_outlined;
      case ProcessingStatus.pending:
        return Icons.pending_outlined;
      case ProcessingStatus.processing:
        return Icons.psychology_outlined;
      case ProcessingStatus.completed:
        return Icons.check_circle_outline;
      case ProcessingStatus.failed:
        return Icons.error_outline;
      case ProcessingStatus.timeout:
        return Icons.timer_off_outlined;
    }
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case ProcessingStatus.idle:
        return Colors.grey[600]!;
      case ProcessingStatus.pending:
        return Colors.orange[600]!;
      case ProcessingStatus.processing:
        return Colors.blue[600]!;
      case ProcessingStatus.completed:
        return Colors.green[600]!;
      case ProcessingStatus.failed:
        return Colors.red[600]!;
      case ProcessingStatus.timeout:
        return Colors.orange[800]!;
    }
  }

  String _getDefaultMessage() {
    switch (widget.status) {
      case ProcessingStatus.idle:
        return 'AI Ready';
      case ProcessingStatus.pending:
        return 'Queued for AI Analysis';
      case ProcessingStatus.processing:
        return 'AI Processing...';
      case ProcessingStatus.completed:
        return 'AI Analysis Complete';
      case ProcessingStatus.failed:
        return 'AI Analysis Failed';
      case ProcessingStatus.timeout:
        return 'AI Analysis Timed Out';
    }
  }
}

/// Size variants for the processing status indicator
enum ProcessingStatusSize {
  small,   // Icon only, minimal text
  medium,  // Icon + text
  large,   // Full display with details
}

/// Helper extension to convert SPAR service status to ProcessingStatus
extension ProcessingStatusExtension on String {
  ProcessingStatus toProcessingStatus() {
    switch (this) {
      case SPARRunsService.STATUS_PENDING:
        return ProcessingStatus.pending;
      case SPARRunsService.STATUS_PROCESSING:
        return ProcessingStatus.processing;
      case SPARRunsService.STATUS_COMPLETED:
        return ProcessingStatus.completed;
      case SPARRunsService.STATUS_FAILED:
        return ProcessingStatus.failed;
      case SPARRunsService.STATUS_TIMEOUT:
        return ProcessingStatus.timeout;
      default:
        return ProcessingStatus.idle;
    }
  }
}

/// Widget that shows processing status as a badge/chip
class ProcessingStatusBadge extends StatelessWidget {
  final ProcessingStatus status;
  final String? message;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const ProcessingStatusBadge({
    super.key,
    required this.status,
    this.message,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor()),
      ),
      child: ProcessingStatusIndicator(
        status: status,
        message: message,
        size: ProcessingStatusSize.small,
        showStatusText: false,
        showRetryButton: false,
        onTap: onTap,
        onRetry: onRetry,
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case ProcessingStatus.idle:
        return Colors.grey[50]!;
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
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case ProcessingStatus.idle:
        return Colors.grey[300]!;
      case ProcessingStatus.pending:
        return Colors.orange[300]!;
      case ProcessingStatus.processing:
        return Colors.blue[300]!;
      case ProcessingStatus.completed:
        return Colors.green[300]!;
      case ProcessingStatus.failed:
        return Colors.red[300]!;
      case ProcessingStatus.timeout:
        return Colors.orange[400]!;
    }
  }
}

/// Progress indicator specifically for AI processing with estimated time
class AIProcessingProgressIndicator extends StatefulWidget {
  final double? progress; // 0.0 to 1.0
  final Duration? estimatedTimeRemaining;
  final String? currentStep;
  final bool showDetails;

  const AIProcessingProgressIndicator({
    super.key,
    this.progress,
    this.estimatedTimeRemaining,
    this.currentStep,
    this.showDetails = true,
  });

  @override
  State<AIProcessingProgressIndicator> createState() => _AIProcessingProgressIndicatorState();
}

class _AIProcessingProgressIndicatorState extends State<AIProcessingProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value * 2 * 3.14159,
                    child: Icon(
                      Icons.psychology,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Processing Your Entry',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    if (widget.currentStep != null)
                      Text(
                        widget.currentStep!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.estimatedTimeRemaining != null)
                Text(
                  '~${widget.estimatedTimeRemaining!.inSeconds}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: widget.progress,
            backgroundColor: Colors.blue[100],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          if (widget.showDetails) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.progress != null 
                      ? '${(widget.progress! * 100).toInt()}% complete'
                      : 'Processing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
                Text(
                  'Analyzing content & standards',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}