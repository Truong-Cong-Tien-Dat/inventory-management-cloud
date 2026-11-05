import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  cleanupTestData,
  createTestCategory,
  createTestContext,
  createTestProduct,
  uniqueToken,
} from './helpers.js';

describe('inventory API', () => {
  let ctx;
  let category;
  let product;

  const token = uniqueToken('INV');
  const productIds = [];
  const categoryIds = [];

  beforeAll(async () => {
    ctx = createTestContext();
    category = await createTestCategory(ctx.request, token);
    categoryIds.push(category.id);
    product = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'A',
      name: `Inventory ${token}`,
      unitPrice: 2500,
      reorderLevel: 5,
    });
    productIds.push(product.id);
  });

  afterAll(async () => {
    await cleanupTestData(ctx.pool, { productIds, categoryIds });
    await ctx.pool.end();
  });

  it('stocks in and returns the updated product summary', async () => {
    const response = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'IN',
        quantity: 10,
        note: 'Nhập kho ban đầu',
      })
      .expect(201);

    expect(response.body.data.transaction).toMatchObject({
      productId: product.id,
      productSku: product.sku,
      productName: product.name,
      type: 'IN',
      quantity: 10,
      note: 'Nhập kho ban đầu',
    });
    expect(response.body.data.product).toMatchObject({
      id: product.id,
      sku: product.sku,
      quantity: 10,
      stockStatus: 'IN_STOCK',
    });

    const detail = await ctx.request
      .get(`/api/products/${product.id}`)
      .expect(200);
    expect(detail.body.data.quantity).toBe(10);
  });

  it('stocks out and updates the stock status', async () => {
    const response = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'OUT',
        quantity: 4,
        note: 'Xuất bán',
      })
      .expect(201);

    expect(response.body.data.product).toMatchObject({
      quantity: 6,
      stockStatus: 'IN_STOCK',
    });

    const lowStock = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'OUT',
        quantity: 2,
      })
      .expect(201);

    expect(lowStock.body.data.product).toMatchObject({
      quantity: 4,
      stockStatus: 'LOW_STOCK',
    });
  });

  it('rejects stock-out that exceeds available quantity without changing stock', async () => {
    const response = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'OUT',
        quantity: 100,
      })
      .expect(409);

    expect(response.body.error.code).toBe('INSUFFICIENT_STOCK');
    expect(response.body.error.details[0].field).toBe('quantity');

    const detail = await ctx.request
      .get(`/api/products/${product.id}`)
      .expect(200);
    expect(detail.body.data.quantity).toBe(4);

    const history = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id })
      .expect(200);
    expect(history.body.meta.total).toBe(3);
  });

  it('lists history with filters and pagination', async () => {
    const all = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id, page: 1, limit: 2 })
      .expect(200);

    expect(all.body.meta).toMatchObject({
      page: 1,
      limit: 2,
      total: 3,
      totalPages: 2,
      hasNext: true,
      hasPrev: false,
    });
    expect(all.body.data).toHaveLength(2);

    const page2 = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id, page: 2, limit: 2 })
      .expect(200);
    expect(page2.body.data).toHaveLength(1);
    expect(page2.body.meta.hasPrev).toBe(true);

    const stockIn = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id, type: 'IN' })
      .expect(200);
    expect(stockIn.body.meta.total).toBe(1);
    expect(stockIn.body.data[0].type).toBe('IN');

    const stockOut = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id, type: 'OUT' })
      .expect(200);
    expect(stockOut.body.meta.total).toBe(2);
    expect(stockOut.body.data.every((item) => item.type === 'OUT')).toBe(true);
  });

  it('validates transaction payloads', async () => {
    const zero = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'IN', quantity: 0 })
      .expect(400);
    expect(zero.body.error.code).toBe('VALIDATION_ERROR');

    const negative = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'OUT', quantity: -1 })
      .expect(400);
    expect(negative.body.error.code).toBe('VALIDATION_ERROR');

    const fractional = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'IN', quantity: 1.5 })
      .expect(400);
    expect(fractional.body.error.code).toBe('VALIDATION_ERROR');

    const badType = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'TRANSFER', quantity: 1 })
      .expect(400);
    expect(badType.body.error.code).toBe('VALIDATION_ERROR');

    const missingProduct = await ctx.request
      .post('/api/inventory/transactions')
      .send({ type: 'IN', quantity: 1 })
      .expect(400);
    expect(missingProduct.body.error.code).toBe('VALIDATION_ERROR');

    const longNote = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'IN',
        quantity: 1,
        note: 'x'.repeat(501),
      })
      .expect(400);
    expect(longNote.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('returns PRODUCT_NOT_FOUND for a missing product', async () => {
    const response = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: 999999999, type: 'IN', quantity: 1 })
      .expect(404);

    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND');
  });

  it('rejects stock movements for inactive products', async () => {
    await ctx.request.delete(`/api/products/${product.id}`).expect(200);

    const response = await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'IN', quantity: 1 })
      .expect(409);

    expect(response.body.error.code).toBe('PRODUCT_INACTIVE');
  });
});
