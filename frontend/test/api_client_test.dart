import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventory_frontend/core/network/api_client.dart';
import 'package:inventory_frontend/core/network/api_exception.dart';

void main() {
  test('parses success envelope and forwards query parameters', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        expect(request.url.path, '/api/products');
        expect(request.url.queryParameters['q'], 'abc');
        expect(request.url.queryParameters['page'], '2');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1},
            ],
            'meta': {'page': 2, 'limit': 10, 'total': 1},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await client.get(
      '/api/products',
      query: {'q': 'abc', 'page': 2, 'empty': ''},
    );

    expect(result.data, isA<List<dynamic>>());
    expect(result.meta?['page'], 2);
  });

  test('maps API error envelopes to Vietnamese messages', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'INSUFFICIENT_STOCK',
              'message': 'Insufficient stock',
            },
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    try {
      await client.post('/api/inventory/transactions', body: {});
      fail('Expected ApiException');
    } on ApiException catch (error) {
      expect(error.code, 'INSUFFICIENT_STOCK');
      expect(error.statusCode, 409);
      expect(error.userMessage, contains('không đủ'));
    }
  });

  test('maps transport failures to a network error', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      client.get('/api/health'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'NETWORK_ERROR')
            .having(
              (error) => error.userMessage,
              'message',
              contains('kết nối'),
            ),
      ),
    );
  });

  test('rejects malformed JSON responses', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        return http.Response('not-json', 200);
      }),
    );

    await expectLater(
      client.get('/api/health'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });
}
