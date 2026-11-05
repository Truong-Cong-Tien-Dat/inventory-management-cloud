import '../core/utils/json_utils.dart';

class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    this.sort,
    this.order,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final String? sort;
  final String? order;

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return PaginationMeta(
      page: asInt(data['page'], fallback: 1),
      limit: asInt(data['limit'], fallback: 10),
      total: asInt(data['total']),
      totalPages: asInt(data['totalPages']),
      hasNext: data['hasNext'] as bool? ?? false,
      hasPrev: data['hasPrev'] as bool? ?? false,
      sort: data['sort'] as String?,
      order: data['order'] as String?,
    );
  }

  int get firstItem {
    if (total == 0) return 0;
    return (page - 1) * limit + 1;
  }

  int get lastItem {
    if (total == 0) return 0;
    final value = page * limit;
    return value > total ? total : value;
  }
}

class PaginatedResult<T> {
  const PaginatedResult({required this.items, required this.meta});

  final List<T> items;
  final PaginationMeta meta;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => itemParser(Map<String, dynamic>.from(item)))
              .toList()
        : <T>[];

    return PaginatedResult(
      items: items,
      meta: PaginationMeta.fromJson(
        json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : null,
      ),
    );
  }
}
