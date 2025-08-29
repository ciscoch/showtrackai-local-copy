/// API Configuration for ShowTrackAI
/// Centralized, environment-aware endpoints.
/// - Defaults to same-origin Netlify Functions (/.netlify/functions/)
/// - Can be overridden with --dart-define=FUNCTIONS_BASE=... (prod/preview)
/// - Dev automatically maps to Netlify Dev (http://localhost:9999)

class ApiConfig {
  // Environment (optional toggle you already use)
  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'production');

  /// Functions base:
  /// - default: same-origin (/.netlify/functions/)
  /// - override: --dart-define=FUNCTIONS_BASE=https://showtrackai.netlify.app/.netlify/functions/
  static const String _functionsBaseDefine =
      String.fromEnvironment('FUNCTIONS_BASE', defaultValue: '/.netlify/functions/');

  /// N8N webhooks (external; keep absolute)
  static const String n8nJournalWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
  static const String n8nContentGenWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/journal-content-gen';
  static const String n8nFinancialWebhook =
      'https://showtrackai.app.n8n.cloud/webhook/8aP7U2qh0leVggTL';

  // -------- Base resolution --------

  /// Returns the effective Functions base for the current environment.
  /// Production/preview: use the dart-define (defaults to same-origin path).
  /// Development: map to Netlify Dev if the base looks relative.
  static String get _functionsBase {
    final base = _ensureTrailingSlash(_functionsBaseDefine);
    if (isDevelopment && _isRelative(base)) {
      // Netlify Dev serves functions on 9999; keep path after the slash.
      return 'http://localhost:9999$base';
    }
    return base;
  }

  static bool _isRelative(String url) =>
      !(url.startsWith('http://') || url.startsWith('https://'));

  static String _ensureTrailingSlash(String s) =>
      s.endsWith('/') ? s : '$s/';

  /// Build a full function URL (String), optionally with query parameters.
  static String fn(String name, [Map<String, String>? qp]) {
    final url = '$_functionsBase$name';
    if (qp == null || qp.isEmpty) return url;
    return Uri.parse(url).replace(queryParameters: qp).toString();
  }

  // -------- Netlify Functions endpoints (Strings) --------
  // Keep names so existing code compiles; these are same-origin by default
  static String get journalCreate            => fn('journal-create');
  static String get journalUpdate            => fn('journal-update');
  static String get journalDelete            => fn('journal-delete'); // append ?id=
  static String get journalList              => fn('journal-list');
  static String get journalGet               => fn('journal-get');
  static String get journalSuggestions       => fn('journal-suggestions');
  static String get journalGenerateContent   => fn('journal-generate-content');
  static String get journalSuggestionFeedback=> fn('journal-suggestion-feedback');
  static String get n8nRelay                 => fn('n8n-relay');

  // Timeline
  static String get timelineList             => fn('timeline-list');
  static String get timelineStats            => fn('timeline-stats');

  // -------- Environment helpers --------
  static bool get isDevelopment => _env == 'development';
  static bool get isProduction  => _env == 'production';
  static String get environment => _env;

  /// If already absolute, return as-is; otherwise return the resolved same-origin URL.
  static String getFullUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    // Treat as relative functions path
    return '$_functionsBase${pathOrUrl.replaceFirst(RegExp(r"^/+"), "")}';
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

/// Development convenience (used through ApiConfig only)
class DevApiConfig {
  static const String localBaseUrl     = 'http://localhost:8888'; // flutter run -d chrome serves web
  static const String netlifyDevBaseUrl= 'http://localhost:9999'; // netlify dev for functions

  static String getDevUrl(String endpoint) {
    // Left for backward-compat; ApiConfig now handles this centrally.
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

/// Optional logical groups (kept for compatibility)
class ApiEndpoints {
  static const Map<String, String> journal = {
    'create': ApiConfig.journalCreate,
    'update': ApiConfig.journalUpdate,
    'delete': ApiConfig.journalDelete,
    'list':   ApiConfig.journalList,
    'get':    ApiConfig.journalGet,
    'suggestions':       ApiConfig.journalSuggestions,
    'generate_content':  ApiConfig.journalGenerateContent,
    'feedback':          ApiConfig.journalSuggestionFeedback,
  };

  static const Map<String, String> n8n = {
    'journal_process': ApiConfig.n8nJournalWebhook,
    'content_gen':     ApiConfig.n8nContentGenWebhook,
    'financial_analysis': ApiConfig.n8nFinancialWebhook,
    'relay':           ApiConfig.n8nRelay,
  };

  static const Map<String, String> timeline = {
    'list':  ApiConfig.timelineList,
    'stats': ApiConfig.timelineStats,
  };
}
