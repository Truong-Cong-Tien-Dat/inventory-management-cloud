import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/inventory_transaction.dart';
import '../models/paginated_result.dart';
import '../models/stock_movement_result.dart';
import '../models/transaction_type.dart';

class InventoryService {
  InventoryService(this._client);

  final ApiClient _client;

  Future<StockMovementResult> createTransaction({
    required int productId,
    required TransactionType type,
    required int quantity,
    String? note,
  }) async {
    final noteText = note?.trim();
    final envelope = await _client.post(
      '/api/inventory/transactions',
      body: {
        'productId': productId,
        'type': type.apiValue,
        'quantity': quantity,
        'note': noteText == null || noteText.isEmpty ? null : noteText,
      },
    );
    final data = envelope.data;
    if (data is! Map) throw ApiException.invalidResponse();
    return StockMovementResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaginatedResult<InventoryTransaction>> list({
    int? productId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 10,
  }) async {
    final envelope = await _client.get(
      '/api/inventory/transactions',
      query: {
        'productId': productId,
        'type': type?.apiValue,
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
        'page': page,
        'limit': limit,
      },
    );

    return PaginatedResult.fromJson({
      'data': envelope.data,
      'meta': envelope.meta,
    }, InventoryTransaction.fromJson);
  }
}
