import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/category.dart';

class CategoryService {
  CategoryService(this._client);

  final ApiClient _client;

  Future<List<Category>> list() async {
    final envelope = await _client.get('/api/categories');
    final data = envelope.data;
    if (data is! List) throw ApiException.invalidResponse();

    return data
        .whereType<Map>()
        .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Category> create(String name) async {
    final envelope = await _client.post(
      '/api/categories',
      body: {'name': name.trim()},
    );
    final data = envelope.data;
    if (data is! Map) throw ApiException.invalidResponse();
    return Category.fromJson(Map<String, dynamic>.from(data));
  }
}
