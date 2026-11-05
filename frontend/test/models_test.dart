import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_frontend/models/category.dart';
import 'package:inventory_frontend/models/dashboard_summary.dart';
import 'package:inventory_frontend/models/inventory_transaction.dart';
import 'package:inventory_frontend/models/pagination_meta.dart';
import 'package:inventory_frontend/models/product.dart';
import 'package:inventory_frontend/models/stock_status.dart';
import 'package:inventory_frontend/models/transaction_type.dart';

void main() {
  group('Product.fromJson', () {
    test('parses the API product object', () {
      final product = Product.fromJson({
        'id': 3,
        'sku': 'ELEC-003',
        'name': 'Bàn phím cơ',
        'categoryId': 1,
        'categoryName': 'Thiết bị điện tử',
        'description': 'Bàn phím cơ 87 phím',
        'unitPrice': 1290000,
        'quantity': 24,
        'reorderLevel': 5,
        'stockStatus': 'IN_STOCK',
        'isActive': true,
        'createdAt': '2026-11-03T08:00:00.000Z',
        'updatedAt': '2026-11-03T08:00:00.000Z',
      });

      expect(product.id, 3);
      expect(product.sku, 'ELEC-003');
      expect(product.name, 'Bàn phím cơ');
      expect(product.categoryId, 1);
      expect(product.categoryName, 'Thiết bị điện tử');
      expect(product.description, 'Bàn phím cơ 87 phím');
      expect(product.unitPrice, 1290000);
      expect(product.quantity, 24);
      expect(product.reorderLevel, 5);
      expect(product.stockStatus, StockStatus.inStock);
      expect(product.isActive, isTrue);
      expect(product.createdAt.isUtc, isTrue);
    });

    test('handles a missing description', () {
      final product = Product.fromJson({
        'id': 1,
        'sku': 'A-1',
        'name': 'A',
        'categoryId': 1,
        'categoryName': 'C',
        'description': null,
        'unitPrice': 0,
        'quantity': 0,
        'reorderLevel': 0,
        'stockStatus': 'OUT_OF_STOCK',
        'isActive': true,
        'createdAt': '2026-11-03T08:00:00.000Z',
        'updatedAt': '2026-11-03T08:00:00.000Z',
      });

      expect(product.description, isNull);
      expect(product.stockStatus, StockStatus.outOfStock);
    });
  });

  test('Category.fromJson parses active product count', () {
    final category = Category.fromJson({
      'id': 1,
      'name': 'Thiết bị điện tử',
      'productCount': 4,
      'createdAt': '2026-11-03T08:00:00.000Z',
    });

    expect(category.id, 1);
    expect(category.name, 'Thiết bị điện tử');
    expect(category.productCount, 4);
  });

  test('InventoryTransaction.fromJson parses transaction type', () {
    final transaction = InventoryTransaction.fromJson({
      'id': 42,
      'productId': 3,
      'productSku': 'ELEC-003',
      'productName': 'Bàn phím cơ',
      'type': 'OUT',
      'quantity': 5,
      'note': 'Xuất bán đơn #1002',
      'createdAt': '2026-11-03T08:20:00.000Z',
    });

    expect(transaction.type, TransactionType.stockOut);
    expect(transaction.type.isStockIn, isFalse);
    expect(transaction.quantity, 5);
    expect(transaction.note, 'Xuất bán đơn #1002');
  });

  test('DashboardSummary.fromJson parses recent transactions', () {
    final summary = DashboardSummary.fromJson({
      'totalActiveProducts': 12,
      'totalUnitsInStock': 420,
      'lowStockProducts': 3,
      'outOfStockProducts': 1,
      'inventoryValue': 123456789,
      'recentTransactions': [
        {
          'id': 42,
          'productId': 3,
          'productSku': 'ELEC-003',
          'productName': 'Bàn phím cơ',
          'type': 'OUT',
          'quantity': 5,
          'note': null,
          'createdAt': '2026-11-03T08:20:00.000Z',
        },
      ],
    });

    expect(summary.totalActiveProducts, 12);
    expect(summary.totalUnitsInStock, 420);
    expect(summary.lowStockProducts, 3);
    expect(summary.outOfStockProducts, 1);
    expect(summary.inventoryValue, 123456789);
    expect(summary.recentTransactions, hasLength(1));
    expect(summary.recentTransactions.first.type, TransactionType.stockOut);
  });

  test('PaginationMeta computes visible range', () {
    final meta = PaginationMeta.fromJson({
      'page': 2,
      'limit': 10,
      'total': 25,
      'totalPages': 3,
      'hasNext': true,
      'hasPrev': true,
      'sort': 'name',
      'order': 'asc',
    });

    expect(meta.firstItem, 11);
    expect(meta.lastItem, 20);
    expect(meta.hasNext, isTrue);
    expect(meta.hasPrev, isTrue);
  });
}
