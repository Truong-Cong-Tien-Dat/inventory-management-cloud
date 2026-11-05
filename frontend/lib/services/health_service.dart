import '../core/network/api_client.dart';

class HealthService {
  HealthService(this._client);

  final ApiClient _client;

  Future<bool> check() async {
    final envelope = await _client.get('/api/health');
    final data = envelope.data;
    return data is Map && data['status'] == 'ok';
  }
}
