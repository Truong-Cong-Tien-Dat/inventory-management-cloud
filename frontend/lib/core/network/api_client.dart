import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiEnvelope {
  const ApiEnvelope({required this.data, this.meta});

  final dynamic data;
  final Map<String, dynamic>? meta;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final Duration timeout;

  Future<ApiEnvelope> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<ApiEnvelope> post(String path, {Object? body}) {
    return _send('POST', path, body: body);
  }

  Future<ApiEnvelope> put(String path, {Object? body}) {
    return _send('PUT', path, body: body);
  }

  Future<ApiEnvelope> delete(String path) {
    return _send('DELETE', path);
  }

  Future<ApiEnvelope> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = baseUrl == null
        ? AppConfig.endpoint(path, query)
        : _buildOverrideUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
    };

    try {
      final request = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported HTTP method: $method'),
      };
      final response = await request.timeout(timeout);

      final decodedBody = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, decodedBody);
      }

      if (decodedBody == null) {
        return const ApiEnvelope(data: null);
      }

      return ApiEnvelope(
        data: decodedBody['data'],
        meta: decodedBody['meta'] is Map
            ? Map<String, dynamic>.from(decodedBody['meta'] as Map)
            : null,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException {
      throw ApiException.network();
    } on FormatException {
      throw ApiException.invalidResponse();
    } catch (_) {
      throw ApiException.network();
    }
  }

  Map<String, dynamic>? _decodeBody(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) return null;

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Uri _buildOverrideUri(String path, Map<String, dynamic>? query) {
    final base = baseUrl!.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalizedPath');
    if (query == null || query.isEmpty) return uri;

    final parameters = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) parameters[key] = text;
    });

    return uri.replace(queryParameters: parameters.isEmpty ? null : parameters);
  }

  void close() {
    _client.close();
  }
}
