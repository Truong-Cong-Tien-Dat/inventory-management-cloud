import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/category_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/global_refresh_controller.dart';
import 'providers/health_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/product_detail_provider.dart';
import 'providers/product_list_provider.dart';
import 'services/category_service.dart';
import 'services/dashboard_service.dart';
import 'services/health_service.dart';
import 'services/inventory_service.dart';
import 'services/product_service.dart';

class InventoryApp extends StatefulWidget {
  const InventoryApp({super.key});

  @override
  State<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends State<InventoryApp> {
  late final ApiClient _apiClient;
  late final ProductService _productService;
  late final CategoryService _categoryService;
  late final InventoryService _inventoryService;
  late final DashboardService _dashboardService;
  late final HealthService _healthService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _productService = ProductService(_apiClient);
    _categoryService = CategoryService(_apiClient);
    _inventoryService = InventoryService(_apiClient);
    _dashboardService = DashboardService(_apiClient);
    _healthService = HealthService(_apiClient);
    _router = buildAppRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<ProductService>.value(value: _productService),
        Provider<CategoryService>.value(value: _categoryService),
        Provider<InventoryService>.value(value: _inventoryService),
        Provider<DashboardService>.value(value: _dashboardService),
        Provider<HealthService>.value(value: _healthService),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(_dashboardService),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(_categoryService),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductListProvider(_productService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ProductDetailProvider(_productService, _inventoryService),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(_productService, _inventoryService),
        ),
        ChangeNotifierProvider(create: (_) => HealthProvider(_healthService)),
        ChangeNotifierProvider(create: (_) => GlobalRefreshController()),
      ],
      child: MaterialApp.router(
        title: 'Kho Thông Minh',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
