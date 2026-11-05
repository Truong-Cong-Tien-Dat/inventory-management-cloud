import 'package:flutter/foundation.dart';

class GlobalRefreshController extends ChangeNotifier {
  int _revision = 0;

  int get revision => _revision;

  void refresh() {
    _revision++;
    notifyListeners();
  }
}
