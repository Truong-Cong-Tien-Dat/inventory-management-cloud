import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/global_refresh_controller.dart';

mixin GlobalRefreshMixin<T extends StatefulWidget> on State<T> {
  GlobalRefreshController? _refreshController;
  int _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<GlobalRefreshController>();
      _refreshController = controller;
      _lastRevision = controller.revision;
      controller.addListener(_handleGlobalRefresh);
    });
  }

  void _handleGlobalRefresh() {
    if (!mounted) return;
    final controller = _refreshController;
    if (controller == null || controller.revision == _lastRevision) return;
    _lastRevision = controller.revision;
    onGlobalRefresh();
  }

  Future<void> onGlobalRefresh();

  @override
  void dispose() {
    _refreshController?.removeListener(_handleGlobalRefresh);
    super.dispose();
  }
}
