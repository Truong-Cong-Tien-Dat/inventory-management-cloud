import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/dashboard_summary.dart';

class DashboardService {
  DashboardService(this._client);

  final ApiClient _client;

  Future<DashboardSummary> getSummary() async {
    final envelope = await _client.get('/api/dashboard/summary');
    final data = envelope.data;
    if (data is! Map) throw ApiException.invalidResponse();
    return DashboardSummary.fromJson(Map<String, dynamic>.from(data));
  }
}
