import supertest from 'supertest';
import { createApp } from '../src/app.js';
import { createPool } from '../src/config/database.js';

let counter = 0;

export function uniqueToken(prefix = 'T') {
  counter += 1;
  const stamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `${prefix}-${stamp}-${counter}-${random}`.slice(0, 40);
}

export function createTestContext() {
  const pool = createPool({ max: 10 });
  const app = createApp({ pool });
  return { pool, app, request: supertest(app) };
}

export async function createTestCategory(request, token) {
  const response = await request
    .post('/api/categories')
    .send({ name: `Phase3 Category ${token}` })
    .expect(201);

  return response.body.data;
}

export async function createTestProduct(
  request,
  {
    categoryId,
    token,
    suffix = 'A',
    name = `Phase3 Product ${token} ${suffix}`,
    unitPrice = 1000,
    reorderLevel = 5,
    description = 'Phase 3 automated test product',
  },
) {
  const response = await request
    .post('/api/products')
    .send({
      sku: `P3-${token}-${suffix}`,
      name,
      categoryId,
      description,
      unitPrice,
      reorderLevel,
    })
    .expect(201);

  return response.body.data;
}

export async function cleanupTestData(
  pool,
  { productIds = [], categoryIds = [] } = {},
) {
  if (productIds.length > 0) {
    await pool.query(
      'DELETE FROM inventory_transactions WHERE product_id = ANY($1::bigint[])',
      [productIds],
    );
    await pool.query('DELETE FROM products WHERE id = ANY($1::bigint[])', [
      productIds,
    ]);
  }

  if (categoryIds.length > 0) {
    await pool.query('DELETE FROM categories WHERE id = ANY($1::bigint[])', [
      categoryIds,
    ]);
  }
}
