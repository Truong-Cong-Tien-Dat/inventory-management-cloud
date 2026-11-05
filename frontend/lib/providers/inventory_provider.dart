import '../core/network/api_exception.dart';
import '../models/inventory_transaction.dart';
import '../models/paginated_result.dart';
import '../models/product.dart';
import '../models/stock_movement_result.dart';
import '../models/transaction_type.dart';
import '../services/inventory_service.dart';
import '../services/product_service.dart';
import 'safe_change_notifier.dart';

class InventoryProvider extends SafeChangeNotifier {
  InventoryProvider(this._productService, this._inventoryService);

  final ProductService _productService;
  final InventoryService _inventoryService;

  List<Product> _products = const [];
  List<InventoryTransaction> _transactions = const [];
  PaginationMeta? _meta;
  bool _loadingProducts = false;
  bool _loadingHistory = false;
  String? _productsError;
  String? _historyError;
  int? _filterProductId;
  TransactionType? _filterType;
  int _page = 1;
  final int _limit = 10;
  int _productsRequestId = 0;
  int _historyRequestId = 0;
  bool _initialized = false;

  List<Product> get products => _products;
  List<InventoryTransaction> get transactions => _transactions;
  PaginationMeta? get meta => _meta;
  bool get loadingProducts => _loadingProducts;
  bool get loadingHistory => _loadingHistory;
  String? get productsError => _productsError;
  String? get historyError => _historyError;
  int? get filterProductId => _filterProductId;
  TransactionType? get filterType => _filterType;
  int get page => _page;
  int get limit => _limit;
  bool get initialized => _initialized;

  Future<void> initialize({int? initialProductId}) async {
    _filterProductId = initialProductId;
    _initialized = true;
    await Future.wait([loadProducts(), loadHistory()]);
  }

  Future<void> loadProducts() async {
    final requestId = ++_productsRequestId;
    _loadingProducts = true;
    _productsError = null;
    safeNotifyListeners();

    try {
      final result = await _productService.list(
        page: 1,
        limit: 100,
        sort: 'name',
        order: 'asc',
      );
      if (requestId != _productsRequestId || isDisposed) return;
      _products = result.items;
    } on ApiException catch (error) {
      if (requestId != _productsRequestId || isDisposed) return;
      _productsError = error.userMessage;
    } catch (_) {
      if (requestId != _productsRequestId || isDisposed) return;
      _productsError = 'Không thể tải danh sách sản phẩm. Vui lòng thử lại.';
    } finally {
      if (requestId == _productsRequestId && !isDisposed) {
        _loadingProducts = false;
        safeNotifyListeners();
      }
    }
  }

  Future<void> loadHistory() async {
    final requestId = ++_historyRequestId;
    _loadingHistory = true;
    _historyError = null;
    safeNotifyListeners();

    try {
      final result = await _inventoryService.list(
        productId: _filterProductId,
        type: _filterType,
        page: _page,
        limit: _limit,
      );
      if (requestId != _historyRequestId || isDisposed) return;
      _transactions = result.items;
      _meta = result.meta;
    } on ApiException catch (error) {
      if (requestId != _historyRequestId || isDisposed) return;
      _historyError = error.userMessage;
    } catch (_) {
      if (requestId != _historyRequestId || isDisposed) return;
      _historyError = 'Không thể tải lịch sử giao dịch. Vui lòng thử lại.';
    } finally {
      if (requestId == _historyRequestId && !isDisposed) {
        _loadingHistory = false;
        safeNotifyListeners();
      }
    }
  }

  Future<StockMovementResult> createTransaction({
    required int productId,
    required TransactionType type,
    required int quantity,
    String? note,
  }) async {
    return _inventoryService.createTransaction(
      productId: productId,
      type: type,
      quantity: quantity,
      note: note,
    );
  }

  Future<void> setFilterProduct(int? value) async {
    if (value == _filterProductId) return;
    _filterProductId = value;
    _page = 1;
    await loadHistory();
  }

  Future<void> setFilterType(TransactionType? value) async {
    if (value == _filterType) return;
    _filterType = value;
    _page = 1;
    await loadHistory();
  }

  Future<void> setPage(int value) async {
    if (value < 1 || value == _page) return;
    _page = value;
    await loadHistory();
  }

  Future<void> clearFilters() async {
    _filterProductId = null;
    _filterType = null;
    _page = 1;
    await loadHistory();
  }

  Future<void> refresh() async {
    await Future.wait([loadProducts(), loadHistory()]);
  }

  Product? productById(int? id) {
    if (id == null) return null;
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
