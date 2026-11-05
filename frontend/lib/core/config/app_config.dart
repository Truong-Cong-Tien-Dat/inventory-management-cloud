import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String _definedApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Local development uses the Node.js API on port 3000. A release build
  /// without an explicit define uses the current origin, which supports the
  /// planned single-origin Render deployment.
  static String get apiBaseUrl {
    if (_definedApiBaseUrl.trim().isNotEmpty) {
      return _trimTrailingSlash(_definedApiBaseUrl.trim());
    }
    if (kReleaseMode) {
      return _trimTrailingSlash(Uri.base.origin);
    }
    return 'http://localhost:3000';
  }

  static bool get usesSameOrigin =>
      _definedApiBaseUrl.trim().isEmpty && kReleaseMode;

  static String get apiLabel {
    final value = apiBaseUrl;
    return value.isEmpty ? 'same-origin' : value;
  }

  static Uri endpoint(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final base = apiBaseUrl;
    final uri = base.startsWith('http://') || base.startsWith('https://')
        ? Uri.parse('$base$normalizedPath')
        : Uri.base.resolve('$base$normalizedPath');

    if (query == null || query.isEmpty) return uri;

    final parameters = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) parameters[key] = text;
    });

    return uri.replace(queryParameters: parameters.isEmpty ? null : parameters);
  }

  static String _trimTrailingSlash(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
