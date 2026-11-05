import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventory_frontend/core/network/api_client.dart';
import 'package:inventory_frontend/providers/category_provider.dart';
import 'package:inventory_frontend/providers/health_provider.dart';
import 'package:inventory_frontend/providers/inventory_provider.dart';
import 'package:inventory_frontend/providers/product_detail_provider.dart';
import 'package:inventory_frontend/providers/product_list_provider.dart';
import 'package:inventory_frontend/screens/shell/app_shell.dart';
import 'package:inventory_frontend/services/category_service.dart';
import 'package:inventory_frontend/services/dashboard_service.dart';
import 'package:inventory_frontend/services/health_service.dart';
import 'package:inventory_frontend/services/inventory_service.dart';
import 'package:inventory_frontend/services/product_service.dart';
import 'package:provider/provider.dart';

/// Flutter-level responsive layout verification for the application shell.
///
/// These tests use `tester.view` to simulate three real device logical widths
/// (1440/768/390) and assert the navigation shell adapts:
/// desktop >= 1024 -> sidebar, tablet 600..1023 -> NavigationRail,
/// mobile < 600 -> AppBar + Drawer.
/// No real browser rendering is involved here (browser coverage is manual).
void main() {
  const healthBody = '{"data":{"status":"ok"}}';
  const categoriesBody =
      '{"data":[{"id":1,"name":"Khác","productCount":0,"createdAt":"2026-11-03T08:00:00.000Z"}]}';

  Future<void> pumpShell(WidgetTester tester, Size logicalSize) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = ApiClient(
      client: MockClient((request) async {
        final body = request.url.path.endsWith('/health')
            ? healthBody
            : categoriesBody;
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: client),
          Provider<ProductService>(create: (_) => ProductService(client)),
          Provider<CategoryService>(create: (_) => CategoryService(client)),
          Provider<InventoryService>(create: (_) => InventoryService(client)),
          Provider<DashboardService>(create: (_) => DashboardService(client)),
          Provider<HealthService>(create: (_) => HealthService(client)),
          ChangeNotifierProvider(
            create: (_) => HealthProvider(HealthService(client)),
          ),
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(CategoryService(client)),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductListProvider(ProductService(client)),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductDetailProvider(
              ProductService(client),
              InventoryService(client),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => InventoryProvider(
              ProductService(client),
              InventoryService(client),
            ),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(location: '/products', child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('desktop viewport (1440) uses the sidebar shell', (tester) async {
    await pumpShell(tester, const Size(1440, 900));

    // The desktop sidebar renders the application brand.
    expect(find.text('Kho Thông Minh'), findsOneWidget);
    expect(find.text('ĐIỀU HƯỚNG'), findsOneWidget);
    expect(find.text('Dữ liệu trực tiếp'), findsOneWidget);
    // No tablet navigation rail on a desktop viewport.
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('tablet viewport (768) uses the NavigationRail shell', (
    tester,
  ) async {
    await pumpShell(tester, const Size(768, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    // Desktop-only content must be absent.
    expect(find.text('Dữ liệu trực tiếp'), findsNothing);
  });

  testWidgets('mobile viewport (390) uses the AppBar + Drawer shell', (
    tester,
  ) async {
    await pumpShell(tester, const Size(390, 844));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Dữ liệu trực tiếp'), findsNothing);

    // The Flutter AppBar exposes a hamburger toggle; under the default test
    // English material localizations the automatic menu icon is Icons.menu.
    final menuFinder = find.byIcon(Icons.menu);
    expect(menuFinder, findsOneWidget);

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    // The opened mobile drawer shows brand + nav labels. The AppBar title on
    // /products also reads "Sản phẩm", so it appears twice.
    expect(find.text('Kho Thông Minh'), findsOneWidget);
    expect(find.text('Sản phẩm'), findsNWidgets(2));
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Kho hàng'), findsOneWidget);
    expect(find.text('Danh mục'), findsOneWidget);
  });
}
