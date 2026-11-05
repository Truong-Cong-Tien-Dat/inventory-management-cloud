import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_frontend/models/product.dart';
import 'package:inventory_frontend/models/stock_status.dart';
import 'package:inventory_frontend/widgets/empty_state.dart';
import 'package:inventory_frontend/widgets/product_card.dart';
import 'package:inventory_frontend/widgets/stock_badge.dart';

void main() {
  testWidgets('StockBadge renders the Vietnamese status label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StockBadge(status: StockStatus.lowStock)),
      ),
    );

    expect(find.text('Sắp hết'), findsOneWidget);
  });

  testWidgets('EmptyState exposes a working action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Chưa có sản phẩm',
            message: 'Thêm sản phẩm đầu tiên.',
            actionLabel: 'Thêm sản phẩm',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Chưa có sản phẩm'), findsOneWidget);
    await tester.tap(find.text('Thêm sản phẩm'));
    expect(tapped, isTrue);
  });

  testWidgets('ProductCard displays product metadata', (tester) async {
    final product = Product(
      id: 1,
      sku: 'ELEC-001',
      name: 'Bàn phím cơ',
      categoryId: 1,
      categoryName: 'Thiết bị điện tử',
      description: null,
      unitPrice: 1290000,
      quantity: 24,
      reorderLevel: 5,
      stockStatus: StockStatus.inStock,
      isActive: true,
      createdAt: DateTime(2026, 11, 3),
      updatedAt: DateTime(2026, 11, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            onOpen: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('ELEC-001'), findsOneWidget);
    expect(find.text('Bàn phím cơ'), findsOneWidget);
    expect(find.text('Còn hàng'), findsOneWidget);
    expect(find.textContaining('1.290.000'), findsOneWidget);
  });
}
