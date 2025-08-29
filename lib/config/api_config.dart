/// API Configuration for ShowTrackAI
/// - Netlify Functions default to same-origin: /.netlify/functions/
/// - You can override with: --dart-define=FUNCTIONS_BASE=https://showtrackai.netlify.app/.netlify/functions/
/// - ENV is optional (development/production)

class ApiConfig {
  // Environment toggle (optional)
  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'production');

  // Functions base (override-able via dart-define)
  static const String _functionsBaseDefine =
      String.fromEnvironment('FUNCTIONS_BASE', defaultValue: '/.netlify/functions/');

  // External N8N webhooks (absolute)
  static const String n8nJournalWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const String n8nContentGenWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/journal-content-gen';
  static const String n8nFinancialWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/8aP7U2qh0leVggTL';

  // -------- Environment helpers --------
  static bool get isDevelopment => _env == 'development';
  static bool get isProduction  => _env == 'production';
  static String get environment => _env;

  // -------- Base resolution --------
  static bool _isRelative(String url) =>
      !(url.startsWith('http://') || url.startsWith('https://'));

  static String _ensureTrailingSlash(String s) =>
      s.endsWith('/') ? s : '$s/';

  /// Effective Functions base for the current environment.
  static String get _functionsBase {
    final base = _ensureTrailingSlash(_functionsBaseDefine);
    if (isDevelopment && _isRelative(base)) {
      // When running Netlify Dev locally, functions are on :9999
      return 'http://localhost:9999$base';
    }
    return base;
  }

  /// Build a full function URL as String.
  static String fn(String name, [Map<String, String>? qp]) {
    final url = '$_functionsBase$name';
    if (qp == null || qp.isEmpty) return url;
    return Uri.parse(url).replace(queryParameters: qp).toString();
  }

  // -------- Netlify Functions endpoints (Strings) --------
  static String get journalCreate             => fn('journal-create');
  static String get journalUpdate             => fn('journal-update');
  static String get journalDelete             => fn('journal-delete'); // you append ?id=
  static String get journalList               => fn('journal-list');
  static String get journalGet                => fn('journal-get');
  static String get journalSuggestions        => fn('journal-suggestions');
  static String get journalGenerateContent    => fn('journal-generate-content');
  static String get journalSuggestionFeedback => fn('journal-suggestion-feedback');
  static String get n8nRelay                  => fn('n8n-relay');

  // Timeline
  static String get timelineList              => fn('timeline-list');
  static String get timelineStats             => fn('timeline-stats');

  /// If already absolute, return as-is; otherwise treat as relative to functions base.
  static String getFullUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final cleaned = pathOrUrl.replaceFirst(RegExp(r'^/+'), '');
    return '$_functionsBase$cleaned';
  }

  // -------- Timeouts --------
  static Duration get requestTimeout => const Duration(seconds: 30);
  static Duration get quickTimeout   => const Duration(seconds: 10);

  // -------- Headers --------
  static Map<String, String> getDefaultHeaders({String? authToken}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  static Map<String, String> getHeadersWithTrace({
    String? authToken,
    String? traceId,
  }) {
    final headers = getDefaultHeaders(authToken: authToken);
    if (traceId != null && traceId.isNotEmpty) {
      headers['X-Trace-ID'] = traceId;
    }
    return headers;
  }

  // -------- URL helpers --------
  static bool isN8NUrl(String url) =>
      url.contains('n8n.cloud') || url.contains('showtrackai.app.n8n.cloud');

  static bool isNetlifyFunction(String url) =>
      url.contains('/.netlify/functions/');

  static Duration getTimeoutForUrl(String url) {
    if (isN8NUrl(url)) return const Duration(seconds: 60);
    if (isNetlifyFunction(url)) return requestTimeout;
    return requestTimeout;
  }
}

/// Optional dev helper (kept for compatibility; not used directly)
class DevApiConfig {
  static const String localBaseUrl      = 'http://localhost:8888';
  static const String netlifyDevBaseUrl = 'http://localhost:9999';

  static String getDevUrl(String endpoint) {
    // Base resolution is handled by ApiConfig now.
    return endpoint;
  }
}

/// Simple typed API response
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

  factory ApiResponse.success(T data,
          {int statusCode = 200, Map<String, dynamic>? metadata}) =>
      ApiResponse<T>(data: data, statusCode: statusCode, success: true, metadata: metadata);

  factory ApiResponse.error(String error,
          {int statusCode = 500, Map<String, dynamic>? metadata}) =>
      ApiResponse<T>(error: error, statusCode: statusCode, success: false, metadata: metadata);
}

/// Grouped endpoints (changed to `final` so we don’t require const-eval)
class ApiEndpoints {
  static final Map<String, String> journal = {
    'create':            ApiConfig.journalCreate,
    'update':            ApiConfig.journalUpdate,
    'delete':            ApiConfig.journalDelete,
    'list':              ApiConfig.journalList,
    'get':               ApiConfig.journalGet,
    'suggestions':       ApiConfig.journalSuggestions,
    'generate_content':  ApiConfig.journalGenerateContent,
    'feedback':          ApiConfig.journalSuggestionFeedback,
  };

  static final Map<String, String> n8n = {
    'journal_process':   ApiConfig.n8nJournalWebhook,
    'content_gen':       ApiConfig.n8nContentGenWebhook,
    'financial_analysis':ApiConfig.n8nFinancialWebhook,
    'relay':             ApiConfig.n8nRelay,
  };

  static final Map<String, String> timeline = {
    'list':  ApiConfig.timelineList,
    'stats': ApiConfig.timelineStats,
  };
}
