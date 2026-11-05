import '../services/health_service.dart';
import 'safe_change_notifier.dart';

class HealthProvider extends SafeChangeNotifier {
  HealthProvider(this._service);

  final HealthService _service;

  bool? _online;
  bool _checking = false;
  int _requestId = 0;

  bool? get online => _online;
  bool get checking => _checking;

  Future<void> check() async {
    final requestId = ++_requestId;
    _checking = true;
    safeNotifyListeners();

    try {
      final result = await _service.check();
      if (requestId != _requestId || isDisposed) return;
      _online = result;
    } catch (_) {
      if (requestId != _requestId || isDisposed) return;
      _online = false;
    } finally {
      if (requestId == _requestId && !isDisposed) {
        _checking = false;
        safeNotifyListeners();
      }
    }
  }
}
