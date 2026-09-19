import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;

  /// null => no HTTP response (timeout / offline).
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin wrapper around the backend's JSON API with automatic
/// token authentication (matches the admin portal's silent login).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _readTimeout = Duration(seconds: 10);
  static const _writeTimeout = Duration(seconds: 15);

  /// Shared JWT token across all ApiClient instances.
  static String? _token;
  static Completer<String?>? _loginCompleter;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  /// Ensures a valid Bearer token exists by silently logging in if needed.
  Future<String?> _ensureToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;
    if (_loginCompleter != null) return _loginCompleter!.future;

    final completer = Completer<String?>();
    _loginCompleter = completer;

    try {
      final response = await _client
          .post(
            _uri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': ApiConfig.defaultEmail,
              'password': ApiConfig.defaultPassword,
            }),
          )
          .timeout(_writeTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final token = (data is Map && data['token'] != null)
            ? data['token'] as String
            : (data is Map && data['data'] is Map)
                ? data['data']['token'] as String?
                : null;
        _token = token;
        completer.complete(_token);
        return _token;
      }
      completer.complete(null);
      return null;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _loginCompleter = null;
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = await _ensureToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _executeWithAuth(
        (headers) => _client.get(_uri(path, query), headers: headers),
        _readTimeout,
      );

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _executeWithAuth(
        (headers) => _client.post(_uri(path),
            headers: headers, body: jsonEncode(body)),
        _writeTimeout,
      );

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _executeWithAuth(
        (headers) => _client.patch(_uri(path),
            headers: headers, body: jsonEncode(body)),
        _writeTimeout,
      );

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _executeWithAuth(
        (headers) => _client.put(_uri(path),
            headers: headers, body: jsonEncode(body)),
        _writeTimeout,
      );

  Future<dynamic> delete(String path) =>
      _executeWithAuth(
        (headers) => _client.delete(_uri(path), headers: headers),
        _writeTimeout,
      );

  Future<dynamic> _executeWithAuth(
    Future<http.Response> Function(Map<String, String> headers) request,
    Duration timeout, {
    bool isRetry = false,
  }) async {
    final headers = await _headers();
    http.Response response;
    try {
      response = await request(headers).timeout(timeout);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas. Vérifiez la connexion.');
    } on http.ClientException {
      throw ApiException('Connexion au serveur impossible.');
    }

    // If 401 Unauthorized, clear cached token and retry once with fresh login
    if (response.statusCode == 401 && !isRetry) {
      _token = null;
      return _executeWithAuth(request, timeout, isRetry: true);
    }

    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    dynamic body = {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = {}; // e.g. an HTML 502 page from the host
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = (body is Map && body['message'] != null)
        ? body['message']
        : 'Erreur serveur (${response.statusCode})';
    throw ApiException(message.toString(), statusCode: response.statusCode);
  }
}