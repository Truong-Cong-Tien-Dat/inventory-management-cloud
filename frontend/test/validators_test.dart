import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_frontend/core/utils/validators.dart';

void main() {
  group('SKU validation', () {
    test('accepts valid SKU characters', () {
      expect(AppValidators.sku('ELEC-001'), isNull);
      expect(AppValidators.sku('sp_01.test'), isNull);
    });

    test('rejects blank and invalid SKU values', () {
      expect(AppValidators.sku(''), isNotNull);
      expect(AppValidators.sku(' SP 001'), isNotNull);
      expect(AppValidators.sku('-ABC'), isNotNull);
    });
  });

  test('validates product names', () {
    expect(AppValidators.name('Bàn phím cơ'), isNull);
    expect(AppValidators.name('   '), isNotNull);
  });

  test('validates unit price', () {
    expect(AppValidators.unitPrice('0'), isNull);
    expect(AppValidators.unitPrice('250000'), isNull);
    expect(AppValidators.unitPrice('-1'), isNotNull);
    expect(AppValidators.unitPrice('abc'), isNotNull);
  });

  test('validates reorder level and quantity', () {
    expect(AppValidators.reorderLevel('0'), isNull);
    expect(AppValidators.reorderLevel('-1'), isNotNull);
    expect(AppValidators.quantity('1'), isNull);
    expect(AppValidators.quantity('0'), isNotNull);
    expect(AppValidators.quantity('1000001'), isNotNull);
  });

  test('validates optional note length', () {
    expect(AppValidators.note(''), isNull);
    expect(AppValidators.note('a' * 501), isNotNull);
  });

  test('validates category name', () {
    expect(AppValidators.categoryName('Đồ gia dụng'), isNull);
    expect(AppValidators.categoryName(''), isNotNull);
  });
}
