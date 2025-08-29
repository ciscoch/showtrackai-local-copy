/// API Configuration for ShowTrackAI
/// Centralized, environment-aware endpoints.
/// - Defaults to same-origin Netlify Functions (/.netlify/functions/)
/// - Can be overridden with --dart-define=FUNCTIONS_BASE=... (prod/preview)
/// - Dev automatically maps to Netlify Dev (http://localhost:9999)

class ApiConfig {
  // Environment (optional)
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

  static bool get isDevelopment => _env == 'development';
  static bool get isProduction  => _env == 'production';
  static String get environment => _env;

  static bool _isRelative(String url) =>
      !(url.startsWith('http://') || url.startsWith('https://'));

  static String _ensureTrailingSlash(String s) =>
      s.endsWith('/') ? s : '$s/';

  /// Effective Functions base for the current environment.
  static String get _functionsBase {
    final base = _ensureTrailingSlash(_functionsBaseDefine);
    if (isDevelopment && _isRelative(base)) {
      // Netlify Dev serves functions on 9999; keep path after the slash.
      return 'http://localhost:9999$base';
    }
    return base;
  }

  /// Build a full function URL (String) with optional query parameters.
  static String fn(String name, [Map<String, String>? qp]) {
    final url = '$_functionsBase$name';
    if (qp == null || qp.isEmpty) return url;
    return Uri.parse(url).replace(queryParameters: qp).toString();
  }

  // -------- Netlify Functions endpoints (Strings) --------
  // Keep names so existing code compiles; these are same-origin by default

  static String get journalCreate             => fn('journal-create');
  static String get journalUpdate             => fn('journal-upda
