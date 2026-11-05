import assert from 'node:assert/strict';
import { createPool } from '../src/config/database.js';

const baseUrl = (process.env.API_BASE_URL || 'http://localhost:3000').replace(
  /\/+$/,
  '',
);

let createdProductId = null;
let createdCategoryId = null;

async function api(method, path, body, expectedStatus = 200) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = { raw: text };
    }
  }

  if (response.status !== expectedStatus) {
    throw new Error(
      `${method} ${path} expected ${expectedStatus}, received ${response.status}: ${text}`,
    );
  }

  return { response, body: payload };
}

function pass(message) {
  console.log(`PASS ${message}`);
}

async function cleanup() {
  if (!createdProductId && !createdCategoryId) return;

  let pool;
  try {
    pool = createPool({ max: 1 });

    if (createdProductId) {
      await pool.query(
        'DELETE FROM inventory_transactions WHERE product_id = $1',
        [createdProductId],
      );
      await pool.query('DELETE FROM products WHERE id = $1', [
        createdProductId,
      ]);
    }

    if (createdCategoryId) {
      await pool.query('DELETE FROM categories WHERE id = $1', [
        createdCategoryId,
      ]);
    }
    console.log('PASS isolated smoke-test records removed');
  } catch (error) {
    console.warn(
      `WARN smoke-test cleanup skipped: ${error.message}. The product remains soft-deleted.`,
    );
  } finally {
    await pool?.end().catch(() => {});
  }
}

async function main() {
  const health = await api('GET', '/api/health');
  assert.equal(health.body.data.status, 'ok');
  pass('health check');

  const categories = await api('GET', '/api/categories');
  let categoryId;
  if (categories.body.data.length > 0) {
    categoryId = categories.body.data[0].id;
  } else {
    const category = await api(
      'POST',
      '/api/categories',
      { name: `Smoke Category ${Date.now()}` },
      201,
    );
    categoryId = category.body.data.id;
    createdCategoryId = categoryId;
  }
  pass('category list/create');

  const sku = `SMOKE-${Date.now().toString(36).toUpperCase()}-${Math.random()
    .toString(36)
    .slice(2, 6)
    .toUpperCase()}`;

  const created = await api(
    'POST',
    '/api/products',
    {
      sku,
      name: `Smoke Product ${sku}`,
      categoryId,
      description: 'Created by scripts/smoke-test.mjs',
      unitPrice: 1234.56,
      reorderLevel: 2,
    },
    201,
  );
  createdProductId = created.body.data.id;
  assert.equal(created.body.data.quantity, 0);
  assert.equal(created.body.data.sku, sku);
  pass('product create with quantity 0');

  const stockIn = await api(
    'POST',
    '/api/inventory/transactions',
    {
      productId: createdProductId,
      type: 'IN',
      quantity: 10,
      note: 'Smoke test stock in',
    },
    201,
  );
  assert.equal(stockIn.body.data.product.quantity, 10);
  pass('stock IN');

  const stockOut = await api(
    'POST',
    '/api/inventory/transactions',
    {
      productId: createdProductId,
      type: 'OUT',
      quantity: 4,
      note: 'Smoke test stock out',
    },
    201,
  );
  assert.equal(stockOut.body.data.product.quantity, 6);
  pass('stock OUT');

  const search = await api(
    'GET',
    `/api/products?categoryId=${categoryId}&q=${encodeURIComponent(sku)}`,
  );
  assert.equal(search.body.meta.total, 1);
  assert.equal(search.body.data[0].id, createdProductId);
  pass('product search');

  const oversell = await api(
    'POST',
    '/api/inventory/transactions',
    { productId: createdProductId, type: 'OUT', quantity: 999 },
    409,
  );
  assert.equal(oversell.body.error.code, 'INSUFFICIENT_STOCK');
  pass('insufficient stock rejected');

  const summary = await api('GET', '/api/dashboard/summary');
  assert.ok(Array.isArray(summary.body.data.recentTransactions));
  pass('dashboard summary');

  const deleted = await api(
    'DELETE',
    `/api/products/${createdProductId}`,
  );
  assert.equal(deleted.body.data.isActive, false);

  const hidden = await api(
    'GET',
    `/api/products/${createdProductId}`,
    undefined,
    404,
  );
  assert.equal(hidden.body.error.code, 'PRODUCT_NOT_FOUND');
  pass('soft delete and hidden from detail');

  const history = await api(
    'GET',
    `/api/inventory/transactions?productId=${createdProductId}`,
  );
  assert.equal(history.body.meta.total, 2);
  pass('history preserved after soft delete');
}

try {
  await main();
  console.log(`Smoke test passed against ${baseUrl}`);
} catch (error) {
  console.error(`FAIL ${error.message}`);
  process.exitCode = 1;
} finally {
  await cleanup();
}
