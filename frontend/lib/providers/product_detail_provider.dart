import '../core/network/api_exception.dart';
import '../models/inventory_transaction.dart';
import '../models/paginated_result.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../services/product_service.dart';
import 'safe_change_notifier.dart';

class ProductDetailProvider extends SafeChangeNotifier {
  ProductDetailProvider(this._productService, this._inventoryService);

  final ProductService _productService;
  final InventoryService _inventoryService;

  Product? _product;
  List<InventoryTransaction> _transactions = const [];
  bool _loading = false;
  String? _error;
  bool _notFound = false;
  int? _productId;
  int _requestId = 0;

  Product? get product => _product;
  List<InventoryTransaction> get transactions => _transactions;
  bool get loading => _loading;
  String? get error => _error;
  bool get notFound => _notFound;

  Future<void> load(int id) async {
    _productId = id;
    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    _notFound = false;
    safeNotifyListeners();

    try {
      final results = await Future.wait([
        _productService.getById(id),
        _inventoryService.list(productId: id, page: 1, limit: 10),
      ]);
      if (requestId != _requestId || isDisposed) return;

      _product = results[0] as Product;
      final transactionResult =
          results[1] as PaginatedResult<InventoryTransaction>;
      _transactions = transactionResult.items;
    } on ApiException catch (error) {
      if (requestId != _requestId || isDisposed) return;
      _notFound = error.code == 'PRODUCT_NOT_FOUND';
      _error = error.userMessage;
    } catch (_) {
      if (requestId != _requestId || isDisposed) return;
      _error = 'Không thể tải chi tiết sản phẩm. Vui lòng thử lại.';
    } finally {
      if (requestId == _requestId && !isDisposed) {
        _loading = false;
        safeNotifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    final id = _productId;
    if (id != null) await load(id);
  }
}
