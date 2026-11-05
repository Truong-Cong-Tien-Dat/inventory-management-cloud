import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/paginated_result.dart';
import '../models/product.dart';
import '../models/product_input.dart';

class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  Future<PaginatedResult<Product>> list({
    String? q,
    int? categoryId,
    int page = 1,
    int limit = 10,
    String sort = 'createdAt',
    String order = 'desc',
  }) async {
    final searchText = q?.trim();
    final envelope = await _client.get(
      '/api/products',
      query: {
        'q': searchText == null || searchText.isEmpty ? null : searchText,
        'categoryId': categoryId,
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      },
    );

    return PaginatedResult.fromJson({
      'data': envelope.data,
      'meta': envelope.meta,
    }, Product.fromJson);
  }

  Future<Product> getById(int id) async {
    final envelope = await _client.get('/api/products/$id');
    return Product.fromJson(_asMap(envelope.data));
  }

  Future<Product> create(ProductInput input) async {
    final envelope = await _client.post('/api/products', body: input.toJson());
    return Product.fromJson(_asMap(envelope.data));
  }

  Future<Product> update(int id, ProductInput input) async {
    final envelope = await _client.put(
      '/api/products/$id',
      body: input.toJson(),
    );
    return Product.fromJson(_asMap(envelope.data));
  }

  Future<void> delete(int id) async {
    await _client.delete('/api/products/$id');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ApiException.invalidResponse();
  }
}
