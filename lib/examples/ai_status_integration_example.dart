import 'package:flutter/material.dart';
import '../widgets/processing_status_indicator.dart';
import '../widgets/ai_status_panel.dart';
import '../widgets/ai_status_card.dart';

/// Example demonstrating comprehensive AI processing status integration
/// This shows how to use all the visual indicators throughout the app
class AIStatusIntegrationExample extends StatefulWidget {
  const AIStatusIntegrationExample({super.key});

  @override
  State<AIStatusIntegrationExample> createState() => _AIStatusIntegrationExampleState();
}

class _AIStatusIntegrationExampleState extends State<AIStatusIntegrationExample> {
  ProcessingStatus _currentStatus = ProcessingStatus.idle;
  String? _statusMessage;
  double? _progress;
  bool _showPanel = false;

  final List<ProcessingStatus> _allStatuses = [
    ProcessingStatus.idle,
    ProcessingStatus.pending,
    ProcessingStatus.processing,
    ProcessingStatus.completed,
    ProcessingStatus.failed,
    ProcessingStatus.timeout,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Status Integration Demo'),
        actions: [
          // Global AI Status Indicator (like in journal list)
          GlobalAIStatusIndicator(
            onTap: () {
              setState(() {
                _showPanel = !_showPanel;
              });
            },
            showBadge: true,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // AI Processing Banner (for top-level notifications)
              AIProcessingBanner(
                status: _currentStatus,
                message: _statusMessage,
                progress: _progress,
                onTap: _showStatusDetails,
                onDismiss: _currentStatus != ProcessingStatus.processing
                    ? () => _updateStatus(ProcessingStatus.idle)
                    : null,
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Control Panel
                    _buildControlPanel(),
                    const SizedBox(height: 24),
                    
                    // Status Cards Examples
                    _buildStatusCardsSection(),
                    const SizedBox(height: 24),
                    
                    // Status Indicators Examples
                    _buildStatusIndicatorsSection(),
                    const SizedBox(height: 24),
                    
                    // Status Chips Examples
                    _buildStatusChipsSection(),
                    const SizedBox(height: 24),
                    
                    // Journal Entry Card Examples
                    _buildJournalCardExamples(),
                  ],
                ),
              ),
            ],
          ),
          
          // Floating AI Status Panel
          AIStatusPanel(
            isVisible: _showPanel,
            onDismiss: () {
              setState(() {
                _showPanel = false;
              });
            },
            position: AIStatusPanelPosition.bottomRight,
            maxEntries: 3,
            autoHideCompleted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Control Panel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Current Status: ${_currentStatus.name}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allStatuses.map((status) {
                return ElevatedButton(
                  onPressed: () => _updateStatus(status),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStatus == status 
                        ? Colors.blue[600] 
                        : Colors.grey[200],
                    foregroundColor: _currentStatus == status 
                        ? Colors.white 
                        : Colors.grey[800],
                  ),
                  child: Text(status.name),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPanel = !_showPanel;
                      });
                    },
                    icon: Icon(_showPanel ? Icons.visibility_off : Icons.visibility),
                    label: Text(_showPanel ? 'Hide Panel' : 'Show Panel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _simulateProcessing,
                    icon: const Icon(Icons.psychology),
                    label: const Text('Simulate AI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Status Cards',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Full-featured card
        AIStatusCard(
          status: _currentStatus,
          title: 'Journal Entry Analysis',
          subtitle: 'Entry: "Daily Health Check for Bessie"',
          message: _statusMessage,
          progress: _progress,
          estimatedTimeRemaining: _currentStatus == ProcessingStatus.processing 
              ? const Duration(seconds: 15) 
              : null,
          currentStep: _currentStatus == ProcessingStatus.processing
              ? 'Analyzing FFA standards and competencies...'
              : null,
          onRetry: _currentStatus == ProcessingStatus.failed 
              ? () => _updateStatus(ProcessingStatus.pending)
              : null,
          onTap: _showStatusDetails,
          showDismissButton: true,
          onDismiss: () => _updateStatus(ProcessingStatus.idle),
        ),
        
        const SizedBox(height: 12),
        
        // Compact card
        AIStatusCard(
          status: _currentStatus,
          title: 'Quick Status Check',
          compact: true,
          onTap: _showStatusDetails,
        ),
      ],
    );
  }

  Widget _buildStatusIndicatorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Processing Status Indicators',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Different sizes
        Row(
          children: [
            Column(
              children: [
                const Text('Small', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                ProcessingStatusIndicator(
                  status: _currentStatus,
                  size: ProcessingStatusSize.small,
                  onTap: _showStatusDetails,
                ),
              ],
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                const Text('Medium', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                ProcessingStatusIndicator(
                  status: _currentStatus,
                  size: ProcessingStatusSize.medium,
                  progress: _progress,
                  onTap: _showStatusDetails,
                ),
              ],
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                const Text('Large', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                ProcessingStatusIndicator(
                  status: _currentStatus,
                  message: _statusMessage,
                  progress: _progress,
                  size: ProcessingStatusSize.large,
                  showRetryButton: true,
                  onRetry: _currentStatus == ProcessingStatus.failed 
                      ? () => _updateStatus(ProcessingStatus.pending)
                      : null,
                  onTap: _showStatusDetails,
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Progress indicator
        if (_currentStatus == ProcessingStatus.processing)
          const AIProcessingProgressIndicator(
            progress: 0.65,
            estimatedTimeRemaining: Duration(seconds: 12),
            currentStep: 'Analyzing FFA standards and skills...',
            showDetails: true,
          ),
      ],
    );
  }

  Widget _buildStatusChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Status Chips',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allStatuses.map((status) {
            return AIStatusChip(
              status: status,
              onTap: () => _updateStatus(status),
              onRetry: status == ProcessingStatus.failed 
                  ? () => _updateStatus(ProcessingStatus.pending)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildJournalCardExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Journal Entry Cards with AI Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        ...List.generate(3, (index) {
          final statuses = [
            ProcessingStatus.processing,
            ProcessingStatus.completed,
            ProcessingStatus.failed,
          ];
          final titles = [
            'Morning Health Check',
            'Feed Strategy Update', 
            'Show Preparation Notes',
          ];
          
          return Column(
            children: [
              _buildMockJournalCard(titles[index], statuses[index]),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMockJournalCard(String title, ProcessingStatus status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ProcessingStatusBadge(
                  status: status,
                  onTap: _showStatusDetails,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            const Text(
              'Checked all animals for signs of illness. Temperature normal, appetite good. Noted slight limp in Bessie\'s left front leg.',
              style: TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Holstein #247', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('2/15/2024', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(ProcessingStatus status) {
    setState(() {
      _currentStatus = status;
      
      switch (status) {
        case ProcessingStatus.idle:
          _statusMessage = 'Ready for AI analysis';
          _progress = null;
          break;
        case ProcessingStatus.pending:
          _statusMessage = 'Queued for AI processing';
          _progress = null;
          break;
        case ProcessingStatus.processing:
          _statusMessage = 'AI analyzing content...';
          _progress = 0.0;
          _simulateProgress();
          break;
        case ProcessingStatus.completed:
          _statusMessage = 'AI analysis completed successfully';
          _progress = 1.0;
          break;
        case ProcessingStatus.failed:
          _statusMessage = 'AI analysis failed';
          _progress = null;
          break;
        case ProcessingStatus.timeout:
          _statusMessage = 'AI analysis timed out';
          _progress = null;
          break;
      }
    });
  }

  void _simulateProcessing() async {
    _updateStatus(ProcessingStatus.pending);
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _updateStatus(ProcessingStatus.processing);
    
    await Future.delayed(const Duration(seconds: 8));
    if (mounted) _updateStatus(ProcessingStatus.completed);
    
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) _updateStatus(ProcessingStatus.idle);
  }

  void _simulateProgress() {
    if (_currentStatus != ProcessingStatus.processing) return;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _currentStatus == ProcessingStatus.processing) {
        setState(() {
          _progress = (_progress ?? 0.0) + 0.1;
          if (_progress! >= 1.0) {
            _progress = 0.9; // Keep at 90% until completion
          }
        });
        _simulateProgress();
      }
    });
  }

  void _showStatusDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('AI Processing Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProcessingStatusIndicator(
              status: _currentStatus,
              message: _statusMessage,
              progress: _progress,
              size: ProcessingStatusSize.large,
              showStatusText: true,
              showRetryButton: true,
              onRetry: _currentStatus == ProcessingStatus.failed 
                  ? () {
                      Navigator.of(context).pop();
                      _updateStatus(ProcessingStatus.pending);
                    }
                  : null,
            ),
            
            const SizedBox(height: 16),
            
            const Text('Status Information:'),
            const SizedBox(height: 8),
            
            _buildDetailRow('Status', _currentStatus.name),
            if (_statusMessage != null) 
              _buildDetailRow('Message', _statusMessage!),
            if (_progress != null)
              _buildDetailRow('Progress', '${(_progress! * 100).toInt()}%'),
            _buildDetailRow('Run ID', 'run_${DateTime.now().millisecondsSinceEpoch}'),
            _buildDetailRow('Created', 'Just now'),
          ],
        ),
        actions: [
          if (_currentStatus == ProcessingStatus.failed)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _updateStatus(ProcessingStatus.pending);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}