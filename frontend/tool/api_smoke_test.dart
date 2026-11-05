import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_frontend/core/network/api_client.dart';
import 'package:inventory_frontend/core/network/api_exception.dart';
import 'package:inventory_frontend/services/category_service.dart';
import 'package:inventory_frontend/services/dashboard_service.dart';
import 'package:inventory_frontend/services/health_service.dart';
import 'package:inventory_frontend/services/inventory_service.dart';
import 'package:inventory_frontend/services/product_service.dart';

/// Optional live integration check. Run with:
/// `flutter test tool/api_smoke_test.dart`
/// Requires the backend at http://localhost:3000.
void main() {
  late ApiClient client;
  late HealthService healthService;
  late CategoryService categoryService;
  late ProductService productService;
  late InventoryService inventoryService;
  late DashboardService dashboardService;

  setUpAll(() {
    client = ApiClient(baseUrl: 'http://localhost:3000');
    healthService = HealthService(client);
    categoryService = CategoryService(client);
    productService = ProductService(client);
    inventoryService = InventoryService(client);
    dashboardService = DashboardService(client);
  });

  tearDownAll(() => client.close());

  test('health endpoint reports database up', () async {
    expect(await healthService.check(), isTrue);
  });

  test('categories endpoint returns real categories', () async {
    final categories = await categoryService.list();
    expect(categories, isNotEmpty);
    expect(categories.first.name, isNotEmpty);
    expect(categories.first.productCount, greaterThanOrEqualTo(0));
  });

  test('products endpoint parses pagination and product fields', () async {
    final result = await productService.list(page: 1, limit: 5);
    expect(result.items, isNotEmpty);
    expect(result.meta.total, greaterThan(0));
    expect(result.meta.limit, 5);
    expect(result.items.first.sku, isNotEmpty);
    expect(result.items.first.name, isNotEmpty);
    expect(result.items.first.categoryName, isNotEmpty);
  });

  test('product detail endpoint returns the selected product', () async {
    final result = await productService.list(page: 1, limit: 1);
    final product = await productService.getById(result.items.first.id);
    expect(product.id, result.items.first.id);
    expect(product.sku, result.items.first.sku);
  });

  test('dashboard endpoint returns summary counters', () async {
    final summary = await dashboardService.getSummary();
    expect(summary.totalActiveProducts, greaterThan(0));
    expect(summary.totalUnitsInStock, greaterThanOrEqualTo(0));
    expect(summary.inventoryValue, greaterThanOrEqualTo(0));
    expect(summary.recentTransactions, isNotEmpty);
  });

  test('inventory endpoint returns transaction history', () async {
    final result = await inventoryService.list(page: 1, limit: 5);
    expect(result.items, isNotEmpty);
    expect(result.meta.total, greaterThan(0));
    expect(result.items.first.productSku, isNotEmpty);
  });

  test('missing product maps to PRODUCT_NOT_FOUND', () async {
    await expectLater(
      productService.getById(999999999),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'PRODUCT_NOT_FOUND',
        ),
      ),
    );
  });
}
