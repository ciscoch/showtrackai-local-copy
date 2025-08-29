/// API Configuration for ShowTrackAI
/// Provides centralized configuration for all API endpoints with environment-aware URL handling
class ApiConfig {
  // Environment detection
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'production');
  
  // Base URLs - these will work on any domain (local or production)
  static const String _netlifyFunctionsBase = '/.netlify/functions';
  
  // N8N Webhook URLs - these remain absolute as they point to external service
  static const String n8nJournalWebhook = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const String n8nContentGenWebhook = 'https://showtrackai.app.n8n.cloud/webhook/journal-content-gen';
  static const String n8nFinancialWebhook = 'https://showtrackai.app.n8n.cloud/webhook/8aP7U2qh0leVggTL';
  
  // Netlify Functions URLs - relative to current domain
  static const String journalCreate = '$_netlifyFunctionsBase/journal-create';
  static const String journalUpdate = '$_netlifyFunctionsBase/journal-update';
  static const String journalDelete = '$_netlifyFunctionsBase/journal-delete';
  static const String journalList = '$_netlifyFunctionsBase/journal-list';
  static const String journalGet = '$_netlifyFunctionsBase/journal-get';
  static const String journalSuggestions = '$_netlifyFunctionsBase/journal-suggestions';
  static const String journalGenerateContent = '$_netlifyFunctionsBase/journal-generate-content';
  static const String journalSuggestionFeedback = '$_netlifyFunctionsBase/journal-suggestion-feedback';
  static const String n8nRelay = '$_netlifyFunctionsBase/n8n-relay';
  
  // Timeline functions
  static const String timelineList = '$_netlifyFunctionsBase/timeline-list';
  static const String timelineStats = '$_netlifyFunctionsBase/timeline-stats';
  
  // Environment info
  static bool get isDevelopment => _env == 'development';
  static bool get isProduction => _env == 'production';
  static String get environment => _env;
  
  /// Get full URL for a relative endpoint
  /// This ensures URLs work in both local development and production
  static String getFullUrl(String relativePath) {
    // If it's already a full URL, return as-is
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    
    // For relative paths, they'll resolve based on the current domain
    return relativePath;
  }
  
  /// Get request timeout for API calls
  static Duration get requestTimeout => const Duration(seconds: 30);
  
  /// Get short timeout for quick operations
  static Duration get quickTimeout => const Duration(seconds: 10);
  
  /// Default headers for API requests
  static Map<String, String> getDefaultHeaders({String? authToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    return headers;
  }
  
  /// Get headers with trace ID for debugging
  static Map<String, String> getHeadersWithTrace({
    String? authToken,
    String? traceId,
  }) {
    final headers = getDefaultHeaders(authToken: authToken);
    
    if (traceId != null) {
      headers['X-Trace-ID'] = traceId;
    }
    
    return headers;
  }
  
  /// Check if a URL is for N8N webhook
  static bool isN8NUrl(String url) {
    return url.contains('n8n.cloud') || url.contains('showtrackai.app.n8n.cloud');
  }
  
  /// Check if a URL is for Netlify function
  static bool isNetlifyFunction(String url) {
    return url.contains('/.netlify/functions/');
  }
  
  /// Get appropriate timeout based on URL type
  static Duration getTimeoutForUrl(String url) {
    if (isN8NUrl(url)) {
      // N8N webhooks may take longer due to AI processing
      return const Duration(seconds: 60);
    } else if (isNetlifyFunction(url)) {
      // Netlify functions should be fast
      return requestTimeout;
    } else {
      // Default timeout
      return requestTimeout;
    }
  }
}

/// Development-specific configuration
class DevApiConfig {
  static const String localBaseUrl = 'http://localhost:8888';
  static const String netlifyDevBaseUrl = 'http://localhost:9999';
  
  /// Override URLs for local development if needed
  static String getDevUrl(String endpoint) {
    if (ApiConfig.isDevelopment) {
      return '$netlifyDevBaseUrl$endpoint';
    }
    return endpoint;
  }
}

/// API Response wrapper for consistent error handling
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int statusCode;
  final bool success;
  final Map<String, dynamic>? metadata;
  
  const ApiResponse({
    this.data,
    this.error,
    required this.statusCode,
    required this.success,
    this.metadata,
  });
  
  factory ApiResponse.success(T data, {int statusCode = 200, Map<String, dynamic>? metadata}) {
    return ApiResponse<T>(
      data: data,
      statusCode: statusCode,
      success: true,
      metadata: metadata,
    );
  }
  
  factory ApiResponse.error(String error, {int statusCode = 500, Map<String, dynamic>? metadata}) {
    return ApiResponse<T>(
      error: error,
      statusCode: statusCode,
      success: false,
      metadata: metadata,
    );
  }
}

/// Endpoint configuration for different API operations
class ApiEndpoints {
  // Journal operations
  static const Map<String, String> journal = {
    'create': ApiConfig.journalCreate,
    'update': ApiConfig.journalUpdate,
    'delete': ApiConfig.journalDelete,
    'list': ApiConfig.journalList,
    'get': ApiConfig.journalGet,
    'suggestions': ApiConfig.journalSuggestions,
    'generate_content': ApiConfig.journalGenerateContent,
    'feedback': ApiConfig.journalSuggestionFeedback,
  };
  
  // N8N webhooks
  static const Map<String, String> n8n = {
    'journal_process': ApiConfig.n8nJournalWebhook,
    'content_gen': ApiConfig.n8nContentGenWebhook,
    'financial_analysis': ApiConfig.n8nFinancialWebhook,
    'relay': ApiConfig.n8nRelay,
  };
  
  // Timeline operations
  static const Map<String, String> timeline = {
    'list': ApiConfig.timelineList,
    'stats': ApiConfig.timelineStats,
  };
}