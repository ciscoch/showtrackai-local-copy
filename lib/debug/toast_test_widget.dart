import 'package:flutter/material.dart';
import '../services/toast_notification_service.dart';
import '../services/journal_toast_service.dart';
import '../widgets/toast_notification_widget.dart';

/// Debug widget for testing toast notifications
/// Access via /debug/toast route for comprehensive testing
class ToastTestWidget extends StatefulWidget {
  const ToastTestWidget({super.key});

  @override
  State<ToastTestWidget> createState() => _ToastTestWidgetState();
}

class _ToastTestWidgetState extends State<ToastTestWidget> 
    with ToastMixin<ToastTestWidget> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toast System Test'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Toast Types
            _buildSection(
              'Basic Toast Types',
              [
                ElevatedButton.icon(
                  onPressed: () => showSuccess('Success message test!'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Success Toast'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: () => showError(
                    'Error message test!',
                    onAction: () => showInfo('Retry action triggered'),
                  ),
                  icon: const Icon(Icons.error),
                  label: const Text('Error Toast'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () => showInfo('Information message test!'),
                  icon: const Icon(Icons.info),
                  label: const Text('Info Toast'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: () => showWarning('Warning message test!'),
                  icon: const Icon(Icons.warning),
                  label: const Text('Warning Toast'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final toastId = showLoading('Loading test...', isDismissible: true);
                    // Auto-dismiss after 3 seconds
                    Future.delayed(const Duration(seconds: 3), () {
                      dismissToast(toastId);
                      showSuccess('Loading complete!');
                    });
                  },
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text('Loading Toast'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Journal-Specific Tests
            _buildSection(
              'Journal-Specific Toasts',
              [
                ElevatedButton.icon(
                  onPressed: () => JournalToast.draftSaved(),
                  icon: const Icon(Icons.save),
                  label: const Text('Draft Saved'),
                ),
                ElevatedButton.icon(
                  onPressed: () => JournalToast.draftLoaded(),
                  icon: const Icon(Icons.restore),
                  label: const Text('Draft Loaded'),
                ),
                ElevatedButton.icon(
                  onPressed: () => JournalToast.validationError('title field'),
                  icon: const Icon(Icons.warning),
                  label: const Text('Validation Error'),
                ),
                ElevatedButton.icon(
                  onPressed: () => JournalToast.networkError(onRetry: () {
                    showInfo('Network retry triggered');
                  }),
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('Network Error'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // File Upload Simulation
            _buildSection(
              'File Upload Simulation',
              [
                ElevatedButton.icon(
                  onPressed: () => _simulateFileUpload(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Simulate File Upload'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _simulateMultipleUploads(),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Multiple File Uploads'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _simulateFailedUpload(),
                  icon: const Icon(Icons.error_outline),
                  label: const Text('Failed Upload'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Journal Submission Flow Test
            _buildSection(
              'Journal Submission Flow',
              [
                ElevatedButton.icon(
                  onPressed: () => _testFullSubmissionFlow(),
                  icon: const Icon(Icons.send),
                  label: const Text('Full Submission Flow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testFailedSubmission(),
                  icon: const Icon(Icons.error),
                  label: const Text('Failed Submission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stress Tests
            _buildSection(
              'Stress Tests',
              [
                ElevatedButton.icon(
                  onPressed: () => _showMultipleToasts(),
                  icon: const Icon(Icons.layers),
                  label: const Text('Multiple Toasts'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testLongMessage(),
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Long Message'),
                ),
                ElevatedButton.icon(
                  onPressed: () => dismissAllToasts(),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Dismiss All'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Status Display
            _buildStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...buttons.map((button) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: button,
          ),
        )),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toast System Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<ToastNotification>>(
              stream: ToastNotificationService.instance.toastStream,
              builder: (context, snapshot) {
                final toasts = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Toasts: ${toasts.length}'),
                    if (toasts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...toasts.map((toast) => Text(
                        '• ${toast.type.name}: ${toast.message}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Simulation Methods

  void _simulateFileUpload() {
    final toastId = JournalToast.uploadProgress('test-image.jpg');
    
    Future.delayed(const Duration(seconds: 2), () {
      dismissToast(toastId);
      JournalToast.uploadSuccess('test-image.jpg');
    });
  }

  void _simulateMultipleUploads() async {
    final files = ['photo1.jpg', 'document.pdf', 'video.mp4'];
    
    for (int i = 0; i < files.length; i++) {
      final toastId = JournalToast.uploadProgress(files[i]);
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      dismissToast(toastId);
      JournalToast.uploadSuccess(files[i]);
      
      if (i < files.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    showSuccess('All ${files.length} files uploaded successfully!');
  }

  void _simulateFailedUpload() {
    final toastId = JournalToast.uploadProgress('large-file.mov');
    
    Future.delayed(const Duration(seconds: 1), () {
      dismissToast(toastId);
      JournalToast.uploadError('large-file.mov', onRetry: () {
        showInfo('Upload retry started');
        _simulateFileUpload();
      });
    });
  }

  void _testFullSubmissionFlow() async {
    await JournalToast.showSubmissionFlow(
      onSubmit: () => Future.delayed(const Duration(milliseconds: 800)),
      onViewEntry: () => showInfo('Navigating to journal entry'),
      onRetry: () => showInfo('Retrying submission'),
    );
  }

  void _testFailedSubmission() {
    JournalToast.submissionError(
      error: 'Network connection failed',
      onRetry: () => showInfo('Retry button pressed'),
    );
  }

  void _showMultipleToasts() {
    showInfo('First toast');
    Future.delayed(const Duration(milliseconds: 200), () => showSuccess('Second toast'));
    Future.delayed(const Duration(milliseconds: 400), () => showWarning('Third toast'));
    Future.delayed(const Duration(milliseconds: 600), () => showError('Fourth toast'));
  }

  void _testLongMessage() {
    showInfo(
      'This is a very long toast message that tests how the toast system handles text overflow and wrapping. It should truncate gracefully and maintain good readability across different screen sizes and orientations.',
    );
  }
}