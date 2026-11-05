import '../core/network/api_exception.dart';
import '../models/paginated_result.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'safe_change_notifier.dart';

class ProductListProvider extends SafeChangeNotifier {
  ProductListProvider(this._service);

  final ProductService _service;

  List<Product> _products = const [];
  PaginationMeta? _meta;
  bool _loading = false;
  String? _error;
  String _search = '';
  int? _categoryId;
  int _page = 1;
  final int _limit = 10;
  String _sort = 'createdAt';
  String _order = 'desc';
  int _requestId = 0;

  List<Product> get products => _products;
  PaginationMeta? get meta => _meta;
  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;
  int? get categoryId => _categoryId;
  int get page => _page;
  int get limit => _limit;
  String get sort => _sort;
  String get order => _order;
  bool get hasActiveFilters =>
      _search.isNotEmpty ||
      _categoryId != null ||
      _sort != 'createdAt' ||
      _order != 'desc';

  Future<void> load() async {
    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    safeNotifyListeners();

    try {
      final result = await _service.list(
        q: _search,
        categoryId: _categoryId,
        page: _page,
        limit: _limit,
        sort: _sort,
        order: _order,
      );
      if (requestId != _requestId || isDisposed) return;
      _products = result.items;
      _meta = result.meta;
    } on ApiException catch (error) {
      if (requestId != _requestId || isDisposed) return;
      _error = error.userMessage;
    } catch (_) {
      if (requestId != _requestId || isDisposed) return;
      _error = 'Không thể tải danh sách sản phẩm. Vui lòng thử lại.';
    } finally {
      if (requestId == _requestId && !isDisposed) {
        _loading = false;
        safeNotifyListeners();
      }
    }
  }

  Future<void> setSearch(String value) async {
    final normalized = value.trim();
    if (normalized == _search) return;
    _search = normalized;
    _page = 1;
    await load();
  }

  Future<void> setCategory(int? value) async {
    if (value == _categoryId) return;
    _categoryId = value;
    _page = 1;
    await load();
  }

  Future<void> setSort(String value) async {
    if (value == _sort) return;
    _sort = value;
    _page = 1;
    await load();
  }

  Future<void> setOrder(String value) async {
    if (value == _order) return;
    _order = value;
    _page = 1;
    await load();
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value == _page) return;
    _page = value;
    await load();
  }

  Future<void> clearFilters() async {
    _search = '';
    _categoryId = null;
    _sort = 'createdAt';
    _order = 'desc';
    _page = 1;
    await load();
  }

  Future<void> refresh() => load();
}
