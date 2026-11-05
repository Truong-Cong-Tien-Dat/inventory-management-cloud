import '../core/utils/json_utils.dart';
import 'stock_status.dart';

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.unitPrice,
    required this.quantity,
    required this.reorderLevel,
    required this.stockStatus,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String sku;
  final String name;
  final int categoryId;
  final String categoryName;
  final String? description;
  final double unitPrice;
  final int quantity;
  final int reorderLevel;
  final StockStatus stockStatus;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: asInt(json['id']),
      sku: asString(json['sku']),
      name: asString(json['name']),
      categoryId: asInt(json['categoryId']),
      categoryName: asString(json['categoryName']),
      description: asNullableString(json['description']),
      unitPrice: asDouble(json['unitPrice']),
      quantity: asInt(json['quantity']),
      reorderLevel: asInt(json['reorderLevel']),
      stockStatus: StockStatus.fromApi(json['stockStatus'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: asDateTime(json['createdAt']),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }

  Product copyWith({
    int? id,
    String? sku,
    String? name,
    int? categoryId,
    String? categoryName,
    String? description,
    double? unitPrice,
    int? quantity,
    int? reorderLevel,
    StockStatus? stockStatus,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      stockStatus: stockStatus ?? this.stockStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
