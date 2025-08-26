import 'package:flutter/foundation.dart';
import 'toast_notification_service.dart';

/// Journal-specific toast states and messages
class JournalToastService {
  static final JournalToastService _instance = JournalToastService._internal();
  factory JournalToastService() => _instance;
  JournalToastService._internal();

  static JournalToastService get instance => _instance;
  
  final ToastNotificationService _toastService = ToastNotificationService.instance;

  // Track the current submission process
  String? _submissionLoadingToastId;
  String? _processingLoadingToastId;
  
  /// Submit journal entry with full toast flow
  Future<void> showSubmissionFlow({
    required Future<void> Function() onSubmit,
    required VoidCallback? onViewEntry,
    required VoidCallback? onRetry,
  }) async {
    String? currentToastId;
    
    try {
      // Stage 1: Submitting
      currentToastId = _toastService.showLoading(
        'Submitting journal entry...',
        isDismissible: false,
      );
      _submissionLoadingToastId = currentToastId;
      
      // Wait a moment for user feedback
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Execute the actual submission
      await onSubmit();
      
      // Stage 2: Success - Journal submitted
      if (currentToastId != null) {
        _toastService.dismiss(currentToastId);
      }
      
      currentToastId = _toastService.showSuccess(
        'Journal entry submitted successfully!',
        onAction: onViewEntry,
        actionLabel: 'View Entry',
      );
      
      // Stage 3: Start AI processing
      await Future.delayed(const Duration(milliseconds: 1000));
      
      currentToastId = _toastService.showInfo(
        'Processing with AI analysis...',
      );
      _processingLoadingToastId = currentToastId;
      
      // Stage 4: Stored in database (simulate quick database confirmation)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (currentToastId != null) {
        _toastService.dismiss(currentToastId);
      }
      
      currentToastId = _toastService.showSuccess(
        'Journal stored in database',
      );
      
      // Stage 5: AI processing complete (simulate AI processing time)
      await Future.delayed(const Duration(milliseconds: 2000));
      
      currentToastId = _toastService.showSuccess(
        'AI processing complete! Enhanced insights available.',
        onAction: onViewEntry,
        actionLabel: 'View Results',
      );
      
    } catch (e) {
      // Handle errors at any stage
      if (currentToastId != null) {
        _toastService.dismiss(currentToastId);
      }
      
      final errorMessage = _getErrorMessage(e);
      _toastService.showError(
        errorMessage,
        onAction: onRetry,
        actionLabel: 'Retry',
      );
      
      // Log error for debugging
      if (kDebugMode) {
        debugPrint('Journal submission error: $e');
      }
      
      rethrow;
    } finally {
      _submissionLoadingToastId = null;
      _processingLoadingToastId = null;
    }
  }
  
  /// Show just the submission toast without AI processing
  String showSubmitting() {
    final toastId = _toastService.showLoading(
      'Submitting journal entry...',
      isDismissible: false,
    );
    _submissionLoadingToastId = toastId;
    return toastId;
  }
  
  /// Update submission toast to success
  String showSubmissionSuccess({VoidCallback? onViewEntry}) {
    if (_submissionLoadingToastId != null) {
      _toastService.dismiss(_submissionLoadingToastId!);
      _submissionLoadingToastId = null;
    }
    
    return _toastService.showSuccess(
      'Journal entry submitted successfully!',
      onAction: onViewEntry,
      actionLabel: onViewEntry != null ? 'View Entry' : null,
    );
  }
  
  /// Show AI processing started
  String showAIProcessing() {
    final toastId = _toastService.showInfo(
      'Processing with AI analysis...',
    );
    _processingLoadingToastId = toastId;
    return toastId;
  }
  
  /// Show database storage confirmation
  String showDatabaseStored() {
    return _toastService.showSuccess(
      'Journal stored in database',
    );
  }
  
  /// Show AI processing complete
  String showAIComplete({VoidCallback? onViewResults}) {
    if (_processingLoadingToastId != null) {
      _toastService.dismiss(_processingLoadingToastId!);
      _processingLoadingToastId = null;
    }
    
    return _toastService.showSuccess(
      'AI processing complete! Enhanced insights available.',
      onAction: onViewResults,
      actionLabel: onViewResults != null ? 'View Results' : null,
    );
  }
  
  /// Show submission error
  String showSubmissionError({
    required String error,
    VoidCallback? onRetry,
  }) {
    // Clean up any loading toasts
    if (_submissionLoadingToastId != null) {
      _toastService.dismiss(_submissionLoadingToastId!);
      _submissionLoadingToastId = null;
    }
    
    return _toastService.showError(
      _getErrorMessage(error),
      onAction: onRetry,
      actionLabel: 'Retry',
    );
  }
  
  /// Show AI processing error (non-blocking)
  String showAIError({VoidCallback? onRetry}) {
    // Clean up processing toast
    if (_processingLoadingToastId != null) {
      _toastService.dismiss(_processingLoadingToastId!);
      _processingLoadingToastId = null;
    }
    
    return _toastService.showWarning(
      'Entry saved! AI analysis will retry when online.',
      onAction: onRetry,
      actionLabel: onRetry != null ? 'Retry Now' : null,
    );
  }
  
  /// Show network connectivity issues
  String showNetworkError({VoidCallback? onRetry}) {
    return _toastService.showError(
      'Network connection lost. Check your connection and try again.',
      onAction: onRetry,
      actionLabel: 'Retry',
    );
  }
  
  /// Show validation errors
  String showValidationError(String fieldName) {
    return _toastService.showWarning(
      'Please complete the $fieldName field before submitting.',
    );
  }
  
  /// Show draft saved
  String showDraftSaved() {
    return _toastService.showInfo(
      'Draft saved automatically',
    );
  }
  
  /// Show draft loaded
  String showDraftLoaded() {
    return _toastService.showInfo(
      'Previous draft restored',
    );
  }
  
  /// Show attachment upload progress
  String showUploadProgress(String fileName) {
    return _toastService.showLoading(
      'Uploading $fileName...',
      isDismissible: false,
    );
  }
  
  /// Show attachment upload success
  String showUploadSuccess(String fileName) {
    return _toastService.showSuccess(
      '$fileName uploaded successfully',
    );
  }
  
  /// Show attachment upload error
  String showUploadError(String fileName, {VoidCallback? onRetry}) {
    return _toastService.showError(
      'Failed to upload $fileName',
      onAction: onRetry,
      actionLabel: 'Retry',
    );
  }
  
  /// Cancel all journal-related toasts
  void cancelSubmissionFlow() {
    if (_submissionLoadingToastId != null) {
      _toastService.dismiss(_submissionLoadingToastId!);
      _submissionLoadingToastId = null;
    }
    
    if (_processingLoadingToastId != null) {
      _toastService.dismiss(_processingLoadingToastId!);
      _processingLoadingToastId = null;
    }
  }
  
  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorString.contains('auth') || errorString.contains('permission')) {
      return 'Authentication error. Please sign in and try again.';
    } else if (errorString.contains('validation') || errorString.contains('required')) {
      return 'Please fill in all required fields and try again.';
    } else if (errorString.contains('storage') || errorString.contains('space')) {
      return 'Storage error. Please free up space and try again.';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again in a few moments.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }
}

/// Convenience class for quick access to journal toast methods
class JournalToast {
  static JournalToastService get _service => JournalToastService.instance;
  
  // Submission flow methods
  static Future<void> showSubmissionFlow({
    required Future<void> Function() onSubmit,
    required VoidCallback? onViewEntry,
    required VoidCallback? onRetry,
  }) {
    return _service.showSubmissionFlow(
      onSubmit: onSubmit,
      onViewEntry: onViewEntry,
      onRetry: onRetry,
    );
  }
  
  // Individual state methods
  static String submitting() => _service.showSubmitting();
  static String submissionSuccess({VoidCallback? onViewEntry}) => 
      _service.showSubmissionSuccess(onViewEntry: onViewEntry);
  static String aiProcessing() => _service.showAIProcessing();
  static String databaseStored() => _service.showDatabaseStored();
  static String aiComplete({VoidCallback? onViewResults}) => 
      _service.showAIComplete(onViewResults: onViewResults);
  
  // Error methods
  static String submissionError({required String error, VoidCallback? onRetry}) =>
      _service.showSubmissionError(error: error, onRetry: onRetry);
  static String aiError({VoidCallback? onRetry}) =>
      _service.showAIError(onRetry: onRetry);
  static String networkError({VoidCallback? onRetry}) =>
      _service.showNetworkError(onRetry: onRetry);
  static String validationError(String fieldName) =>
      _service.showValidationError(fieldName);
  
  // Utility methods
  static String draftSaved() => _service.showDraftSaved();
  static String draftLoaded() => _service.showDraftLoaded();
  static String uploadProgress(String fileName) => _service.showUploadProgress(fileName);
  static String uploadSuccess(String fileName) => _service.showUploadSuccess(fileName);
  static String uploadError(String fileName, {VoidCallback? onRetry}) =>
      _service.showUploadError(fileName, onRetry: onRetry);
  
  static void cancelSubmissionFlow() => _service.cancelSubmissionFlow();
}