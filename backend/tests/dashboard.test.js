import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  cleanupTestData,
  createTestCategory,
  createTestContext,
  createTestProduct,
  uniqueToken,
} from './helpers.js';

describe('dashboard API', () => {
  let ctx;
  let category;
  let product;
  let baseline;

  const token = uniqueToken('DASH');
  const productIds = [];
  const categoryIds = [];

  beforeAll(async () => {
    ctx = createTestContext();
    category = await createTestCategory(ctx.request, token);
    categoryIds.push(category.id);

    // Capture the baseline before adding the isolated test product so the
    // assertions measure only this test's changes.
    const response = await ctx.request.get('/api/dashboard/summary').expect(200);
    baseline = response.body.data;

    product = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'A',
      name: `Dashboard ${token}`,
      unitPrice: 1000,
      reorderLevel: 0,
    });
    productIds.push(product.id);
  });

  afterAll(async () => {
    await cleanupTestData(ctx.pool, { productIds, categoryIds });
    await ctx.pool.end();
  });

  it('returns the expected dashboard summary shape', () => {
    expect(baseline).toEqual({
      totalActiveProducts: expect.any(Number),
      totalUnitsInStock: expect.any(Number),
      lowStockProducts: expect.any(Number),
      outOfStockProducts: expect.any(Number),
      inventoryValue: expect.any(Number),
      recentTransactions: expect.any(Array),
    });
  });

  it('reflects stock-in and stock-out changes in summary totals', async () => {
    const stockIn = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'IN',
        quantity: 5,
        note: 'Dashboard test stock in',
      })
      .expect(201);

    const afterIn = await ctx.request
      .get('/api/dashboard/summary')
      .expect(200);
    expect(afterIn.body.data.totalActiveProducts).toBe(
      baseline.totalActiveProducts + 1,
    );
    expect(afterIn.body.data.totalUnitsInStock).toBe(
      baseline.totalUnitsInStock + 5,
    );
    expect(afterIn.body.data.lowStockProducts).toBe(
      baseline.lowStockProducts,
    );
    expect(afterIn.body.data.outOfStockProducts).toBe(
      baseline.outOfStockProducts,
    );
    expect(afterIn.body.data.inventoryValue).toBeCloseTo(
      baseline.inventoryValue + 5000,
      2,
    );
    expect(
      afterIn.body.data.recentTransactions.some(
        (item) => item.id === stockIn.body.data.transaction.id,
      ),
    ).toBe(true);

    const stockOut = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'OUT',
        quantity: 5,
        note: 'Dashboard test stock out',
      })
      .expect(201);

    const afterOut = await ctx.request
      .get('/api/dashboard/summary')
      .expect(200);
    expect(afterOut.body.data.totalUnitsInStock).toBe(
      baseline.totalUnitsInStock,
    );
    expect(afterOut.body.data.outOfStockProducts).toBe(
      baseline.outOfStockProducts + 1,
    );
    expect(afterOut.body.data.inventoryValue).toBeCloseTo(
      baseline.inventoryValue,
      2,
    );
    expect(
      afterOut.body.data.recentTransactions.some(
        (item) => item.id === stockOut.body.data.transaction.id,
      ),
    ).toBe(true);
  });
});
