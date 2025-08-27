import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility class for sanitizing and validating user input
/// to prevent XSS attacks and other security vulnerabilities
class InputSanitizer {
  // Private constructor to prevent instantiation
  InputSanitizer._();

  // HTML and script patterns to detect and remove
  static final RegExp _htmlTagPattern = RegExp(
    r'<[^>]*>',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _scriptPattern = RegExp(
    r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _eventHandlerPattern = RegExp(
    'on\\w+\\s*=\\s*["\'][^"\']*["\']',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _javascriptProtocolPattern = RegExp(
    r'javascript:',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _dataUriPattern = RegExp(
    r'data:[^,]*script',
    multiLine: true,
    caseSensitive: false,
  );

  // SQL injection patterns
  static final RegExp _sqlPattern = RegExp(
    r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|TRUNCATE|EXEC|EXECUTE)\b)',
    multiLine: true,
    caseSensitive: false,
  );

  /// Sanitizes general text input by removing potentially dangerous content
  /// while preserving legitimate text
  static String sanitizeText(String? input, {int? maxLength}) {
    if (input == null || input.isEmpty) {
      return '';
    }

    String sanitized = input;

    // Remove script tags and their content
    sanitized = sanitized.replaceAll(_scriptPattern, '');
    
    // Remove HTML tags
    sanitized = sanitized.replaceAll(_htmlTagPattern, '');
    
    // Remove event handlers
    sanitized = sanitized.replaceAll(_eventHandlerPattern, '');
    
    // Remove javascript: protocol
    sanitized = sanitized.replaceAll(_javascriptProtocolPattern, '');
    
    // Remove data URIs with script content
    sanitized = sanitized.replaceAll(_dataUriPattern, '');
    
    // Trim whitespace
    sanitized = sanitized.trim();
    
    // Apply max length if specified
    if (maxLength != null && sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    return sanitized;
  }

  /// Validates and sanitizes animal names
  /// Only allows letters, numbers, spaces, hyphens, and apostrophes
  static String? sanitizeAnimalName(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }

    // First apply general sanitization
    String sanitized = sanitizeText(input, maxLength: 50);
    
    // Remove any characters that aren't allowed in animal names
    // Allow: letters, numbers, spaces, hyphens, apostrophes
    sanitized = sanitized.replaceAll(RegExp(r"[^a-zA-Z0-9\s\-']"), '');
    
    // Remove multiple consecutive spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim and check length
    sanitized = sanitized.trim();
    
    if (sanitized.isEmpty) {
      return null;
    }
    
    if (sanitized.length < 2) {
      return null; // Name too short
    }
    
    return sanitized;
  }

  /// Validates and sanitizes tag numbers
  /// Only allows alphanumeric characters and hyphens
  static String? sanitizeTagNumber(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }

    // First apply general sanitization
    String sanitized = sanitizeText(input, maxLength: 20);
    
    // Only allow alphanumeric and hyphens
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
    
    // Remove consecutive hyphens
    sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');
    
    // Trim hyphens from start and end
    sanitized = sanitized.replaceAll(RegExp(r'^-+|-+$'), '');
    
    // Convert to uppercase for consistency
    sanitized = sanitized.toUpperCase();
    
    if (sanitized.isEmpty) {
      return null;
    }
    
    return sanitized;
  }

  /// Sanitizes description and notes fields
  /// Allows more characters but still removes dangerous content
  static String? sanitizeDescription(String? input, {int maxLength = 500}) {
    if (input == null || input.isEmpty) {
      return null;
    }

    // Apply general sanitization
    String sanitized = sanitizeText(input, maxLength: maxLength);
    
    // For descriptions, we can be slightly more permissive
    // but still remove SQL injection attempts
    if (_sqlPattern.hasMatch(sanitized)) {
      // Log potential SQL injection attempt
      _logSecurityEvent('Potential SQL injection in description', sanitized);
      sanitized = sanitized.replaceAll(_sqlPattern, '');
    }
    
    // Normalize whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    sanitized = sanitized.trim();
    
    if (sanitized.isEmpty) {
      return null;
    }
    
    return sanitized;
  }

  /// Sanitizes numeric input (weight, price, etc.)
  static double? sanitizeNumeric(String? input, {
    double? min,
    double? max,
    int? decimalPlaces = 2,
  }) {
    if (input == null || input.isEmpty) {
      return null;
    }

    // Remove any non-numeric characters except decimal point
    String sanitized = input.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Ensure only one decimal point
    int decimalCount = '.'.allMatches(sanitized).length;
    if (decimalCount > 1) {
      // Keep only the first decimal point
      int firstDecimal = sanitized.indexOf('.');
      sanitized = sanitized.substring(0, firstDecimal + 1) +
          sanitized.substring(firstDecimal + 1).replaceAll('.', '');
    }
    
    // Parse the number
    double? value = double.tryParse(sanitized);
    
    if (value == null) {
      return null;
    }
    
    // Apply min/max constraints
    if (min != null && value < min) {
      return null;
    }
    
    if (max != null && value > max) {
      return null;
    }
    
    // Round to specified decimal places
    if (decimalPlaces != null) {
      double multiplier = 10.0 * decimalPlaces;
      value = (value * multiplier).round() / multiplier;
    }
    
    return value;
  }

  /// Validates breed input
  static String? sanitizeBreed(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }

    // Apply general sanitization
    String sanitized = sanitizeText(input, maxLength: 50);
    
    // Allow letters, numbers, spaces, hyphens, parentheses for breeds
    // e.g., "Angus (Black)", "Cross-bred"
    sanitized = sanitized.replaceAll(RegExp(r"[^a-zA-Z0-9\s\-\(\)]"), '');
    
    // Remove multiple consecutive spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    sanitized = sanitized.trim();
    
    if (sanitized.isEmpty) {
      return null;
    }
    
    return sanitized;
  }

  /// Logs security events for monitoring
  static void _logSecurityEvent(String event, String input) {
    if (kDebugMode) {
      print('[SECURITY] $event: ${input.substring(0, input.length.clamp(0, 100))}');
    }
    // In production, you would send this to your logging service
    // Example: Analytics.logSecurityEvent(event, input);
  }

  /// Creates a user-friendly error message without exposing technical details
  static String createUserFriendlyError(String technicalError) {
    // Log the technical error for debugging
    _logSecurityEvent('Technical error', technicalError);
    
    // Return generic user-friendly messages based on error patterns
    if (technicalError.toLowerCase().contains('network')) {
      return 'Network connection issue. Please check your internet and try again.';
    } else if (technicalError.toLowerCase().contains('permission')) {
      return 'You do not have permission to perform this action.';
    } else if (technicalError.toLowerCase().contains('duplicate')) {
      return 'This item already exists. Please use a different value.';
    } else if (technicalError.toLowerCase().contains('not found')) {
      return 'The requested item could not be found.';
    } else if (technicalError.toLowerCase().contains('timeout')) {
      return 'The operation took too long. Please try again.';
    } else if (technicalError.toLowerCase().contains('auth')) {
      return 'Please log in to continue.';
    } else {
      return 'An error occurred. Please try again or contact support if the issue persists.';
    }
  }
}

/// Debouncer utility to prevent rapid repeated calls
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  
  Debouncer({required this.milliseconds});
  
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  
  void cancel() {
    _timer?.cancel();
  }
  
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Request cancellation token for managing async operations
class CancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _onCancelCallbacks = [];
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (var callback in _onCancelCallbacks) {
      callback();
    }
    _onCancelCallbacks.clear();
  }
  
  void onCancel(VoidCallback callback) {
    if (_isCancelled) {
      callback();
    } else {
      _onCancelCallbacks.add(callback);
    }
  }
  
  void throwIfCancelled() {
    if (_isCancelled) {
      throw Exception('Operation was cancelled');
    }
  }
}