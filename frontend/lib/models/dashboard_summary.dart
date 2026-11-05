import '../core/utils/json_utils.dart';
import 'inventory_transaction.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.totalActiveProducts,
    required this.totalUnitsInStock,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.inventoryValue,
    required this.recentTransactions,
  });

  final int totalActiveProducts;
  final int totalUnitsInStock;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double inventoryValue;
  final List<InventoryTransaction> recentTransactions;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['recentTransactions'];
    return DashboardSummary(
      totalActiveProducts: asInt(json['totalActiveProducts']),
      totalUnitsInStock: asInt(json['totalUnitsInStock']),
      lowStockProducts: asInt(json['lowStockProducts']),
      outOfStockProducts: asInt(json['outOfStockProducts']),
      inventoryValue: asDouble(json['inventoryValue']),
      recentTransactions: rawTransactions is List
          ? rawTransactions
                .whereType<Map>()
                .map(
                  (item) => InventoryTransaction.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <InventoryTransaction>[],
    );
  }
}
