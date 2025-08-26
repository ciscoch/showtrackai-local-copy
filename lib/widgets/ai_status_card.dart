import 'package:flutter/material.dart';
import 'processing_status_indicator.dart';

/// A card widget that displays AI processing status with comprehensive information
class AIStatusCard extends StatelessWidget {
  /// Current processing status
  final ProcessingStatus status;
  
  /// Optional title for the card
  final String? title;
  
  /// Optional subtitle/description
  final String? subtitle;
  
  /// Optional processing message
  final String? message;
  
  /// Optional error message for failed status
  final String? errorMessage;
  
  /// Progress value (0.0 to 1.0) for processing status
  final double? progress;
  
  /// Estimated time remaining
  final Duration? estimatedTimeRemaining;
  
  /// Current processing step
  final String? currentStep;
  
  /// Whether to show the card in compact mode
  final bool compact;
  
  /// Whether to show retry button on failure
  final bool showRetryButton;
  
  /// Callback for retry action
  final VoidCallback? onRetry;
  
  /// Callback when card is tapped
  final VoidCallback? onTap;
  
  /// Callback when dismiss/close is tapped
  final VoidCallback? onDismiss;
  
  /// Whether to show dismiss button
  final bool showDismissButton;

  const AIStatusCard({
    super.key,
    required this.status,
    this.title,
    this.subtitle,
    this.message,
    this.errorMessage,
    this.progress,
    this.estimatedTimeRemaining,
    this.currentStep,
    this.compact = false,
    this.showRetryButton = true,
    this.onRetry,
    this.onTap,
    this.onDismiss,
    this.showDismissButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildStatusSection(context),
              if (!compact && _shouldShowProgress()) ...[
                const SizedBox(height: 12),
                _buildProgressSection(context),
              ],
              if (_shouldShowActions()) ...[
                const SizedBox(height: 16),
                _buildActionButtons(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.psychology,
          color: _getStatusColor(),
          size: compact ? 20 : 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? _getDefaultTitle(),
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDismissButton && onDismiss != null)
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Row(
      children: [
        ProcessingStatusIndicator(
          status: status,
          message: message,
          errorMessage: errorMessage,
          progress: progress,
          size: compact ? ProcessingStatusSize.small : ProcessingStatusSize.medium,
          showStatusText: true,
          showRetryButton: false, // We'll handle retry in action buttons
        ),
        if (estimatedTimeRemaining != null && status == ProcessingStatus.processing) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              '~${estimatedTimeRemaining!.inSeconds}s',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    if (status != ProcessingStatus.processing && status != ProcessingStatus.pending) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentStep != null) ...[
          Text(
            currentStep!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (progress != null) ...[
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.blue[100],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress! * 100).toInt()}% complete',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[600],
                ),
              ),
              if (estimatedTimeRemaining != null)
                Text(
                  '${estimatedTimeRemaining!.inSeconds}s remaining',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[600],
                  ),
                ),
            ],
          ),
        ] else if (status == ProcessingStatus.processing) ...[
          LinearProgressIndicator(
            backgroundColor: Colors.blue[100],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 4),
          Text(
            'Processing...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (status == ProcessingStatus.failed && showRetryButton && onRetry != null) {
      buttons.add(
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange[700],
            backgroundColor: Colors.orange[50],
          ),
        ),
      );
    }

    if (status == ProcessingStatus.completed && onTap != null) {
      buttons.add(
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.visibility),
          label: const Text('View Results'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green[700],
            backgroundColor: Colors.green[50],
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(
      children: buttons
          .expand((button) => [button, const SizedBox(width: 8)])
          .take(buttons.length * 2 - 1)
          .toList(),
    );
  }

  bool _shouldShowProgress() {
    return status == ProcessingStatus.processing || 
           status == ProcessingStatus.pending ||
           progress != null;
  }

  bool _shouldShowActions() {
    return (status == ProcessingStatus.failed && showRetryButton && onRetry != null) ||
           (status == ProcessingStatus.completed && onTap != null);
  }

  Color _getStatusColor() {
    switch (status) {
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

  String _getDefaultTitle() {
    switch (status) {
      case ProcessingStatus.idle:
        return 'AI Analysis Ready';
      case ProcessingStatus.pending:
        return 'AI Analysis Queued';
      case ProcessingStatus.processing:
        return 'AI Analyzing Content';
      case ProcessingStatus.completed:
        return 'AI Analysis Complete';
      case ProcessingStatus.failed:
        return 'AI Analysis Failed';
      case ProcessingStatus.timeout:
        return 'AI Analysis Timed Out';
    }
  }
}

/// A compact version of AIStatusCard for use in lists or tight spaces
class AIStatusChip extends StatelessWidget {
  final ProcessingStatus status;
  final String? message;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const AIStatusChip({
    super.key,
    required this.status,
    this.message,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _getBorderColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProcessingStatusIndicator(
              status: status,
              size: ProcessingStatusSize.small,
              showStatusText: false,
            ),
            const SizedBox(width: 6),
            Text(
              message ?? _getDefaultMessage(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(),
              ),
            ),
            if (status == ProcessingStatus.failed && onRetry != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.refresh,
                    size: 14,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ],
        ),
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

  Color _getStatusColor() {
    switch (status) {
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
    switch (status) {
      case ProcessingStatus.idle:
        return 'Ready';
      case ProcessingStatus.pending:
        return 'Queued';
      case ProcessingStatus.processing:
        return 'Processing';
      case ProcessingStatus.completed:
        return 'Complete';
      case ProcessingStatus.failed:
        return 'Failed';
      case ProcessingStatus.timeout:
        return 'Timeout';
    }
  }
}

/// A banner widget for showing AI processing status across the top of screens
class AIProcessingBanner extends StatelessWidget {
  final ProcessingStatus status;
  final String? message;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const AIProcessingBanner({
    super.key,
    required this.status,
    this.message,
    this.progress,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ProcessingStatus.idle) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        border: Border.all(color: _getBorderColor()),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ProcessingStatusIndicator(
                status: status,
                size: ProcessingStatusSize.small,
                showStatusText: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message ?? _getDefaultMessage(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(),
                      ),
                    ),
                    if (progress != null && status == ProcessingStatus.processing) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: _getStatusColor().withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        ),
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

  Color _getStatusColor() {
    switch (status) {
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
    switch (status) {
      case ProcessingStatus.idle:
        return 'AI Ready';
      case ProcessingStatus.pending:
        return 'AI analysis queued...';
      case ProcessingStatus.processing:
        return 'AI analyzing your content...';
      case ProcessingStatus.completed:
        return 'AI analysis completed successfully';
      case ProcessingStatus.failed:
        return 'AI analysis failed - tap to retry';
      case ProcessingStatus.timeout:
        return 'AI analysis timed out - tap to retry';
    }
  }
}