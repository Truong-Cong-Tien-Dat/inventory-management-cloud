class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;
}

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const [],
  });

  final String code;
  final String message;
  final int? statusCode;
  final List<ApiFieldError> details;

  factory ApiException.fromResponse(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    final rawError = body?['error'];
    final error = rawError is Map
        ? Map<String, dynamic>.from(rawError)
        : const <String, dynamic>{};
    final rawDetails = error['details'];
    final details = rawDetails is List
        ? rawDetails
              .whereType<Map>()
              .map(
                (item) => ApiFieldError(
                  field: item['field']?.toString() ?? 'body',
                  message: item['message']?.toString() ?? '',
                ),
              )
              .toList()
        : const <ApiFieldError>[];

    return ApiException(
      code: error['code']?.toString() ?? 'HTTP_$statusCode',
      message: error['message']?.toString() ?? 'Yêu cầu không thành công.',
      statusCode: statusCode,
      details: details,
    );
  }

  factory ApiException.network() {
    return const ApiException(
      code: 'NETWORK_ERROR',
      message: 'Không thể kết nối đến máy chủ.',
    );
  }

  factory ApiException.timeout() {
    return const ApiException(
      code: 'TIMEOUT',
      message: 'Máy chủ phản hồi quá chậm.',
    );
  }

  factory ApiException.invalidResponse() {
    return const ApiException(
      code: 'INVALID_RESPONSE',
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  String get userMessage {
    return switch (code) {
      'NETWORK_ERROR' => 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
      'TIMEOUT' => 'Máy chủ phản hồi quá chậm. Vui lòng thử lại sau.',
      'INVALID_RESPONSE' =>
        'Dữ liệu máy chủ trả về không hợp lệ. Vui lòng thử lại.',
      'VALIDATION_ERROR' =>
        'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại các trường đã nhập.',
      'CATEGORY_NOT_FOUND' => 'Danh mục không tồn tại hoặc đã bị xóa.',
      'FIELD_NOT_EDITABLE' => 'Không thể thay đổi tồn kho trực tiếp tại màn hình sản phẩm. Vui lòng dùng chức năng nhập/xuất kho.',
      'PRODUCT_NOT_FOUND' =>
        'Không tìm thấy sản phẩm hoặc sản phẩm đã ngừng hoạt động.',
      'ROUTE_NOT_FOUND' => 'Không tìm thấy chức năng trên máy chủ.',
      'DUPLICATE_SKU' => 'Mã SKU đã tồn tại. Vui lòng nhập mã khác.',
      'CATEGORY_EXISTS' => 'Tên danh mục đã tồn tại. Vui lòng nhập tên khác.',
      'INSUFFICIENT_STOCK' =>
        'Số lượng tồn kho không đủ để thực hiện giao dịch này.',
      'PRODUCT_INACTIVE' =>
        'Sản phẩm đã ngừng hoạt động nên không thể nhập/xuất kho.',
      'PAYLOAD_TOO_LARGE' =>
        'Dữ liệu gửi lên quá lớn. Vui lòng nhập nội dung ngắn hơn.',
      'CORS_ORIGIN_DENIED' =>
        'Nguồn truy cập hiện tại chưa được máy chủ cho phép.',
      'DB_UNAVAILABLE' =>
        'Cơ sở dữ liệu tạm thời không khả dụng. Vui lòng thử lại sau.',
      'INTERNAL_ERROR' =>
        'Máy chủ gặp lỗi không mong muốn. Vui lòng thử lại sau.',
      _ =>
        message.isNotEmpty ? message : 'Đã xảy ra lỗi. Vui lòng thử lại sau.',
    };
  }

  String? fieldError(String field) {
    for (final detail in details) {
      if (detail.field == field || detail.field.endsWith('.$field')) {
        return _localizedFieldMessage(field);
      }
    }
    return null;
  }

  String _localizedFieldMessage(String field) {
    return switch (field) {
      'sku' => 'Mã SKU không hợp lệ hoặc đã tồn tại.',
      'name' => 'Tên sản phẩm không hợp lệ.',
      'categoryId' => 'Danh mục không hợp lệ.',
      'unitPrice' => 'Đơn giá không hợp lệ.',
      'reorderLevel' => 'Mức tồn kho tối thiểu không hợp lệ.',
      'description' => 'Mô tả không hợp lệ.',
      'quantity' => 'Số lượng không hợp lệ.',
      'type' => 'Loại giao dịch không hợp lệ.',
      'note' => 'Ghi chú không hợp lệ.',
      _ => 'Dữ liệu không hợp lệ.',
    };
  }
}
