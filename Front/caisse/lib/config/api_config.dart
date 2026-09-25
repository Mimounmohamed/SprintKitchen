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

/// Thin wrapper around the backend's JSON API (no authentication: the
/// software runs on the client's own PC).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _readTimeout = Duration(seconds: 10);
  static const _writeTimeout = Duration(seconds: 15);

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers),
          _readTimeout);

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
      () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      _writeTimeout);

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send(
      () =>
          _client.patch(_uri(path), headers: _headers, body: jsonEncode(body)),
      _writeTimeout);

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(
      () => _client.put(_uri(path), headers: _headers, body: jsonEncode(body)),
      _writeTimeout);

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers), _writeTimeout);

  Future<dynamic> _send(
    Future<http.Response> Function() request,
    Duration timeout,
  ) async {
    try {
      final response = await request().timeout(timeout);
      return _handle(response);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas. Vérifiez la connexion.');
    } on http.ClientException {
      throw ApiException('Connexion au serveur impossible.');
    }
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