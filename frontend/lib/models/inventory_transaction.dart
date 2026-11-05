import '../core/utils/json_utils.dart';
import 'transaction_type.dart';

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.productId,
    required this.productSku,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String productSku;
  final String productName;
  final TransactionType type;
  final int quantity;
  final String? note;
  final DateTime createdAt;

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: asInt(json['id']),
      productId: asInt(json['productId']),
      productSku: asString(json['productSku']),
      productName: asString(json['productName']),
      type: TransactionType.fromApi(json['type'] as String?),
      quantity: asInt(json['quantity']),
      note: asNullableString(json['note']),
      createdAt: asDateTime(json['createdAt']),
    );
  }
}
