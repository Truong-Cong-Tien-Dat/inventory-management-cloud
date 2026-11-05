enum TransactionType {
  stockIn('IN', 'Nhập kho'),
  stockOut('OUT', 'Xuất kho');

  const TransactionType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get isStockIn => this == TransactionType.stockIn;

  static TransactionType fromApi(String? value) {
    return value == 'OUT' ? TransactionType.stockOut : TransactionType.stockIn;
  }
}
