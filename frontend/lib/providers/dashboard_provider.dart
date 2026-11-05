import '../core/network/api_exception.dart';
import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';
import 'safe_change_notifier.dart';

class DashboardProvider extends SafeChangeNotifier {
  DashboardProvider(this._service);

  final DashboardService _service;

  DashboardSummary? _summary;
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  DashboardSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _summary != null;

  Future<void> load() async {
    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    safeNotifyListeners();

    try {
      final result = await _service.getSummary();
      if (requestId != _requestId || isDisposed) return;
      _summary = result;
    } on ApiException catch (error) {
      if (requestId != _requestId || isDisposed) return;
      _error = error.userMessage;
    } catch (_) {
      if (requestId != _requestId || isDisposed) return;
      _error = 'Không thể tải dữ liệu tổng quan. Vui lòng thử lại.';
    } finally {
      if (requestId == _requestId && !isDisposed) {
        _loading = false;
        safeNotifyListeners();
      }
    }
  }

  Future<void> refresh() => load();
}
