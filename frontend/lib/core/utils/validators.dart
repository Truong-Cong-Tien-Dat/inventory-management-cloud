class AppValidators {
  AppValidators._();

  static String? requiredText(
    String? value, {
    required String label,
    int maxLength = 200,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label không được để trống.';
    if (text.length > maxLength) {
      return '$label không được vượt quá $maxLength ký tự.';
    }
    return null;
  }

  static String? sku(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mã SKU không được để trống.';
    if (text.length > 50) return 'Mã SKU không được vượt quá 50 ký tự.';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(text)) {
      return 'Mã SKU chỉ gồm chữ, số, dấu chấm, gạch dưới và gạch ngang.';
    }
    return null;
  }

  static String? name(String? value) {
    return requiredText(value, label: 'Tên sản phẩm', maxLength: 200);
  }

  static String? category(int? value) {
    if (value == null || value <= 0) return 'Vui lòng chọn danh mục.';
    return null;
  }

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 2000) {
      return 'Mô tả không được vượt quá 2.000 ký tự.';
    }
    return null;
  }

  static String? unitPrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Đơn giá không được để trống.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Đơn giá phải là số nguyên hợp lệ.';
    if (parsed < 0) return 'Đơn giá phải lớn hơn hoặc bằng 0.';
    if (parsed > 9999999999) return 'Đơn giá quá lớn.';
    return null;
  }

  static String? reorderLevel(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mức tồn kho tối thiểu không được để trống.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Mức tồn kho tối thiểu phải là số nguyên.';
    if (parsed < 0) return 'Mức tồn kho tối thiểu phải lớn hơn hoặc bằng 0.';
    if (parsed > 1000000) return 'Mức tồn kho tối thiểu quá lớn.';
    return null;
  }

  static String? quantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Số lượng không được để trống.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Số lượng phải là số nguyên.';
    if (parsed < 1) return 'Số lượng phải lớn hơn 0.';
    if (parsed > 1000000) return 'Số lượng quá lớn.';
    return null;
  }

  static String? note(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 500) return 'Ghi chú không được vượt quá 500 ký tự.';
    return null;
  }

  static String? categoryName(String? value) {
    return requiredText(value, label: 'Tên danh mục', maxLength: 100);
  }
}
