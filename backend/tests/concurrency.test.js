import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  cleanupTestData,
  createTestCategory,
  createTestContext,
  createTestProduct,
  uniqueToken,
} from './helpers.js';

describe('concurrent stock-out safety', () => {
  let ctx;
  let category;
  let product;

  const token = uniqueToken('CONC');
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
      name: `Concurrency ${token}`,
      unitPrice: 1000,
      reorderLevel: 2,
    });
    productIds.push(product.id);

    await ctx.request
      .post('/api/inventory/transactions')
      .send({ productId: product.id, type: 'IN', quantity: 10 })
      .expect(201);
  });

  afterAll(async () => {
    await cleanupTestData(ctx.pool, { productIds, categoryIds });
    await ctx.pool.end();
  });

  it('allows only one of two concurrent stock-outs against limited stock', async () => {
    const requests = [
      ctx.request
        .post('/api/inventory/transactions')
        .send({ productId: product.id, type: 'OUT', quantity: 7 }),
      ctx.request
        .post('/api/inventory/transactions')
        .send({ productId: product.id, type: 'OUT', quantity: 7 }),
    ];

    const [first, second] = await Promise.all(requests);
    const statuses = [first.status, second.status].sort((a, b) => a - b);

    expect(statuses).toEqual([201, 409]);

    const rejected = first.status === 409 ? first : second;
    expect(rejected.body.error.code).toBe('INSUFFICIENT_STOCK');

    const detail = await ctx.request
      .get(`/api/products/${product.id}`)
      .expect(200);
    expect(detail.body.data.quantity).toBe(3);
    expect(detail.body.data.stockStatus).toBe('IN_STOCK');

    const stockOuts = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id, type: 'OUT' })
      .expect(200);
    expect(stockOuts.body.meta.total).toBe(1);
    expect(stockOuts.body.data[0].quantity).toBe(7);
  });
});
