class ProductInput {
  const ProductInput({
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.unitPrice,
    required this.reorderLevel,
  });

  final String sku;
  final String name;
  final int categoryId;
  final String? description;
  final double unitPrice;
  final int reorderLevel;

  Map<String, dynamic> toJson() {
    final descriptionText = description?.trim();
    return {
      'sku': sku.trim().toUpperCase(),
      'name': name.trim(),
      'categoryId': categoryId,
      'description': descriptionText == null || descriptionText.isEmpty
          ? null
          : descriptionText,
      'unitPrice': unitPrice,
      'reorderLevel': reorderLevel,
    };
  }
}
