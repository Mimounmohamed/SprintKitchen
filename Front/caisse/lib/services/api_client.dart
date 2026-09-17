import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper around the backend's JSON API.
/// GET /api/products and /api/categories require no auth token today
/// (see productController.js — the GET routes skip the `protect` middleware),
/// so no auth header is needed here yet.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 10));
    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    final body = response.body.isEmpty ? {} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = (body is Map && body['message'] != null)
        ? body['message']
        : 'Erreur serveur (${response.statusCode})';
    throw ApiException(message.toString());
  }
}