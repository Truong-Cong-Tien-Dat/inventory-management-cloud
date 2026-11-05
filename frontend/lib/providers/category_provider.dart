import '../core/network/api_exception.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import 'safe_change_notifier.dart';

class CategoryProvider extends SafeChangeNotifier {
  CategoryProvider(this._service);

  final CategoryService _service;

  List<Category> _categories = const [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  List<Category> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;
  bool get isEmpty => _categories.isEmpty;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_categories.isNotEmpty && !force) return;

    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    safeNotifyListeners();

    try {
      final result = await _service.list();
      if (requestId != _requestId || isDisposed) return;
      _categories = result;
    } on ApiException catch (error) {
      if (requestId != _requestId || isDisposed) return;
      _error = error.userMessage;
    } catch (_) {
      if (requestId != _requestId || isDisposed) return;
      _error = 'Không thể tải danh mục. Vui lòng thử lại.';
    } finally {
      if (requestId == _requestId && !isDisposed) {
        _loading = false;
        safeNotifyListeners();
      }
    }
  }

  Future<Category> create(String name) async {
    final category = await _service.create(name);
    await load(force: true);
    return category;
  }

  Category? findById(int? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> refresh() => load(force: true);
}
