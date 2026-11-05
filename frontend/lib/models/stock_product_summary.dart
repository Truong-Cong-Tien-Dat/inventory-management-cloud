import '../core/utils/json_utils.dart';
import 'stock_status.dart';

class StockProductSummary {
  const StockProductSummary({
    required this.id,
    required this.sku,
    required this.quantity,
    required this.stockStatus,
    required this.updatedAt,
  });

  final int id;
  final String sku;
  final int quantity;
  final StockStatus stockStatus;
  final DateTime updatedAt;

  factory StockProductSummary.fromJson(Map<String, dynamic> json) {
    return StockProductSummary(
      id: asInt(json['id']),
      sku: asString(json['sku']),
      quantity: asInt(json['quantity']),
      stockStatus: StockStatus.fromApi(json['stockStatus'] as String?),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }
}
