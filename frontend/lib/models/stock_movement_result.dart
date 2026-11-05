import 'inventory_transaction.dart';
import 'stock_product_summary.dart';

class StockMovementResult {
  const StockMovementResult({required this.transaction, required this.product});

  final InventoryTransaction transaction;
  final StockProductSummary product;

  factory StockMovementResult.fromJson(Map<String, dynamic> json) {
    final transaction = json['transaction'];
    final product = json['product'];
    return StockMovementResult(
      transaction: InventoryTransaction.fromJson(
        Map<String, dynamic>.from(transaction as Map),
      ),
      product: StockProductSummary.fromJson(
        Map<String, dynamic>.from(product as Map),
      ),
    );
  }
}
