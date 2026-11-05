import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_frontend/core/network/api_client.dart';
import 'package:inventory_frontend/core/network/api_exception.dart';
import 'package:inventory_frontend/models/product_input.dart';
import 'package:inventory_frontend/models/transaction_type.dart';
import 'package:inventory_frontend/services/inventory_service.dart';
import 'package:inventory_frontend/services/product_service.dart';

/// Reversible, real-data CRUD + inventory verification through the same
/// services the Flutter UI uses. Requires the backend at http://localhost:3000.
///
/// Side effects documented in PHASE4_HANDOVER.md:
/// - creates one product (unique SKU prefix);
/// - edits that product, runs stock IN/OUT, verifies INSUFFICIENT_STOCK;
/// - soft-deletes it at the end (history is preserved by design).
///
/// Run: `flutter test tool/crud_smoke_test.dart`
void main() {
  late ApiClient client;
  late ProductService productService;
  late InventoryService inventoryService;

  setUpAll(() {
    client = ApiClient(baseUrl: 'http://localhost:3000');
    productService = ProductService(client);
    inventoryService = InventoryService(client);
  });

  tearDownAll(() => client.close());

  test(
    'create -> edit -> stock IN -> stock OUT -> oversell -> soft delete',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final sku = 'UIVERIFY-$stamp';

      // 1. Create (quantity always starts at 0).
      final categoryId = await _firstCategoryId(productService);
      final created = await productService.create(
        ProductInput(
          sku: sku,
          name: 'UI Verify Product',
          categoryId: categoryId,
          description: 'Phase 4 verification record - safe to keep inactive',
          unitPrice: 42000,
          reorderLevel: 3,
        ),
      );
      expect(created.id, greaterThan(0));
      expect(created.quantity, 0);

      // 2. Edit full metadata.
      final updated = await productService.update(
        created.id,
        ProductInput(
          sku: sku,
          name: 'UI Verify Product (edited)',
          categoryId: categoryId,
          description: 'Edited during Phase 4 verification',
          unitPrice: 45000,
          reorderLevel: 2,
        ),
      );
      expect(updated.name, 'UI Verify Product (edited)');
      expect(updated.unitPrice, 45000);
      expect(updated.reorderLevel, 2);

      // 3. Stock IN +10 -> quantity 10, status IN_STOCK.
      final afterIn = await inventoryService.createTransaction(
        productId: created.id,
        type: TransactionType.stockIn,
        quantity: 10,
        note: 'Phase 4 UI verify IN',
      );
      expect(afterIn.product.quantity, 10);
      expect(afterIn.product.stockStatus.apiValue, 'IN_STOCK');

      // 4. Stock OUT -3 -> quantity 7.
      final afterOut = await inventoryService.createTransaction(
        productId: created.id,
        type: TransactionType.stockOut,
        quantity: 3,
        note: 'Phase 4 UI verify OUT',
      );
      expect(afterOut.product.quantity, 7);

      // 5. Oversell rejection leaves quantity unchanged.
      try {
        await inventoryService.createTransaction(
          productId: created.id,
          type: TransactionType.stockOut,
          quantity: 100,
        );
        fail('Expected INSUFFICIENT_STOCK');
      } on ApiException catch (error) {
        expect(error.code, 'INSUFFICIENT_STOCK');
      }
      final reloaded = await productService.getById(created.id);
      expect(reloaded.quantity, 7);

      // 6. Soft delete -> detail 404, active list excludes it.
      await productService.delete(created.id);
      await expectLater(
        productService.getById(created.id),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'PRODUCT_NOT_FOUND',
          ),
        ),
      );
      final search = await productService.list(q: sku, page: 1, limit: 5);
      expect(search.items, isEmpty);
    },
  );

  test(
    'direct quantity edit is rejected by API and mapped client-side',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final sku = 'UIVERIFYQ-$stamp';
      final categoryId = await _firstCategoryId(productService);
      final created = await productService.create(
        ProductInput(
          sku: sku,
          name: 'UI Verify Field Not Editable',
          categoryId: categoryId,
          description: null,
          unitPrice: 12000,
          reorderLevel: 1,
        ),
      );

      // Direct quantity/id editing must be rejected by the API contract.
      await expectLater(
        client.put(
          '/api/products/${created.id}',
          body: {
            'sku': sku,
            'name': 'UI Verify Field Not Editable',
            'categoryId': categoryId,
            'unitPrice': 12000,
            'reorderLevel': 1,
            'quantity': 99,
          },
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'FIELD_NOT_EDITABLE',
          ),
        ),
      );

      await productService.delete(created.id);
    },
  );
}

Future<int> _firstCategoryId(ProductService productService) async {
  final products = await productService.list(page: 1, limit: 1);
  expect(
    products.items,
    isNotEmpty,
    reason:
        'Seed data must contain at least one product to reuse its category id',
  );
  return products.items.first.categoryId;
}
