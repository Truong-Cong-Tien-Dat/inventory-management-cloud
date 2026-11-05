import 'package:go_router/go_router.dart';

import '../../screens/categories/categories_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/not_found_screen.dart';
import '../../screens/products/product_detail_screen.dart';
import '../../screens/products/product_list_screen.dart';
import '../../screens/shell/app_shell.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) {
              final categoryId = int.tryParse(
                state.uri.queryParameters['categoryId'] ?? '',
              );
              return ProductListScreen(initialCategoryId: categoryId);
            },
          ),
          GoRoute(
            path: '/products/:id',
            name: 'product-detail',
            redirect: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null || id <= 0) return '/products';
              return null;
            },
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ProductDetailScreen(productId: id);
            },
          ),
          GoRoute(
            path: '/inventory',
            name: 'inventory',
            builder: (context, state) {
              final productId = int.tryParse(
                state.uri.queryParameters['productId'] ?? '',
              );
              return InventoryScreen(initialProductId: productId);
            },
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
