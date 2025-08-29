// lib/services/functions_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Same-origin by default. Can be overridden at build with:
///   --dart-define=FUNCTIONS_BASE=/.netlify/functions/
///   --dart-define=FUNCTIONS_BASE=https://showtrackai.netlify.app/.netlify/functions/
const String kFunctionsBase = String.fromEnvironment(
  'FUNCTIONS_BASE',
  defaultValue: '/.netlify/functions/',
);

Uri fnUrl(String name, [Map<String, dynamic>? qp]) {
  final base = kFunctionsBase.endsWith('/') ? kFunctionsBase : '$kFunctionsBase/';
  final uri = Uri.parse('$base$name');
  if (qp == null || qp.isEmpty) return uri;
  return uri.replace(queryParameters: qp.map(
    (k, v) => MapEntry(k, v?.toString()),
  ));
}

/// Simple GET returning decoded JSON (Map or List)
Future<dynamic> fnGetJson(String name, {Map<String, dynamic>? query}) async {
  final res = await http.get(fnUrl(name, query));
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return res.body.isEmpty ? null : json.decode(res.body);
  }
  throw HttpException('GET $name failed ${res.statusCode}: ${res.body}');
}

/// POST JSON -> JSON
Future<dynamic> fnPostJson(String name, {Object? body, Map<String, String>? headers}) async {
  final res = await http.post(
    fnUrl(name),
    headers: {
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    },
    body: body == null ? null : json.encode(body),
  );
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return res.body.isEmpty ? null : json.decode(res.body);
  }
  throw HttpException('POST $name failed ${res.statusCode}: ${res.body}');
}

/// PUT JSON -> JSON
Future<dynamic> fnPutJson(String name, {Object? body, Map<String, String>? headers}) async {
  final res = await http.put(
    fnUrl(name),
    headers: {
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    },
    body: body == null ? null : json.encode(body),
  );
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return res.body.isEmpty ? null : json.decode(res.body);
  }
  throw HttpException('PUT $name failed ${res.statusCode}: ${res.body}');
}

/// DELETE -> JSON/empty
Future<dynamic> fnDelete(String name, {Map<String, dynamic>? query}) async {
  final res = await http.delete(fnUrl(name, query));
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return res.body.isEmpty ? null : json.decode(res.body);
  }
  throw HttpException('DELETE $name failed ${res.statusCode}: ${res.body}');
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
