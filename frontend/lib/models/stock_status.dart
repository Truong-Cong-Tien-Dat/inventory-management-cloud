enum StockStatus {
  inStock('IN_STOCK', 'Còn hàng'),
  lowStock('LOW_STOCK', 'Sắp hết'),
  outOfStock('OUT_OF_STOCK', 'Hết hàng');

  const StockStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static StockStatus fromApi(String? value) {
    return switch (value) {
      'LOW_STOCK' => StockStatus.lowStock,
      'OUT_OF_STOCK' => StockStatus.outOfStock,
      _ => StockStatus.inStock,
    };
  }
}
