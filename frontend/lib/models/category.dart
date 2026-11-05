import '../core/utils/json_utils.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.productCount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int productCount;
  final DateTime createdAt;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: asInt(json['id']),
      name: asString(json['name']),
      productCount: asInt(json['productCount']),
      createdAt: asDateTime(json['createdAt']),
    );
  }
}
