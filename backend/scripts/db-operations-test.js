import assert from 'node:assert/strict';
import { createPool, withTransaction } from '../src/config/database.js';

const pool = createPool({ max: 8 });
const results = [];
const runId = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`.toUpperCase();
const primarySku = `TEST-${runId}`;
const createdProductIds = [];

let categoryId = null;
let primaryProductId = null;

async function run(name, callback) {
  try {
    await callback();
    results.push({ name, ok: true });
    console.log(`PASS  ${name}`);
  } catch (error) {
    results.push({ name, ok: false, message: error.message });
    console.log(`FAIL  ${name}: ${error.message}`);
  }
}

async function expectPgError(callback, expectedCode) {
  let caught;
  try {
    await callback();
  } catch (error) {
    caught = error;
  }
  assert.ok(caught, `Expected PostgreSQL error ${expectedCode}, but no error was thrown`);
  assert.equal(
    caught.code,
    expectedCode,
    `Expected error ${expectedCode}, got ${caught.code}: ${caught.message}`,
  );
}

async function snapshot(productId) {
  const product = await pool.query(
    'SELECT quantity FROM products WHERE id = $1',
    [productId],
  );
  const transactions = await pool.query(
    'SELECT COUNT(*)::int AS count FROM inventory_transactions WHERE product_id = $1',
    [productId],
  );
  return {
    quantity: product.rows[0].quantity,
    transactions: transactions.rows[0].count,
  };
}

async function stockIn(productId, quantity) {
  return withTransaction(pool, async (client) => {
    const { rows } = await client.query(
      'SELECT quantity, is_active FROM products WHERE id = $1 FOR UPDATE',
      [productId],
    );
    assert.equal(rows.length, 1, `Product ${productId} not found`);
    assert.equal(rows[0].is_active, true, 'Product must be active');

    await client.query(
      'UPDATE products SET quantity = quantity + $1 WHERE id = $2',
      [quantity, productId],
    );

    const inserted = await client.query(
      `INSERT INTO inventory_transactions (product_id, type, quantity, note)
       VALUES ($1, 'IN', $2, $3)
       RETURNING id`,
      [productId, quantity, 'Phase 2 test stock in'],
    );

    return inserted.rows[0].id;
  });
}

async function stockOut(productId, quantity) {
  return withTransaction(pool, async (client) => {
    const { rows } = await client.query(
      'SELECT quantity, is_active FROM products WHERE id = $1 FOR UPDATE',
      [productId],
    );
    assert.equal(rows.length, 1, `Product ${productId} not found`);

    if (!rows[0].is_active) {
      const error = new Error('Product is inactive');
      error.code = 'PRODUCT_INACTIVE';
      throw error;
    }

    if (rows[0].quantity < quantity) {
      const error = new Error('Insufficient stock');
      error.code = 'INSUFFICIENT_STOCK';
      throw error;
    }

    await client.query(
      'UPDATE products SET quantity = quantity - $1 WHERE id = $2',
      [quantity, productId],
    );

    const inserted = await client.query(
      `INSERT INTO inventory_transactions (product_id, type, quantity, note)
       VALUES ($1, 'OUT', $2, $3)
       RETURNING id`,
      [productId, quantity, 'Phase 2 test stock out'],
    );

    return inserted.rows[0].id;
  });
}

async function attemptConcurrentStockOut(productId, quantity, delayMs) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      'SELECT quantity FROM products WHERE id = $1 FOR UPDATE',
      [productId],
    );

    if (delayMs > 0) {
      await client.query('SELECT pg_sleep($1)', [delayMs / 1000]);
    }

    if (rows[0].quantity < quantity) {
      await client.query('ROLLBACK');
      return { ok: false, code: 'INSUFFICIENT_STOCK' };
    }

    await client.query(
      'UPDATE products SET quantity = quantity - $1 WHERE id = $2',
      [quantity, productId],
    );
    await client.query(
      `INSERT INTO inventory_transactions (product_id, type, quantity, note)
       VALUES ($1, 'OUT', $2, $3)`,
      [productId, quantity, 'Phase 2 concurrency test'],
    );
    await client.query('COMMIT');
    return { ok: true };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    return { ok: false, code: error.code, message: error.message };
  } finally {
    client.release();
  }
}

try {
  const category = await pool.query(
    'INSERT INTO categories (name) VALUES ($1) RETURNING id',
    [`TEST-CAT-${runId}`],
  );
  categoryId = category.rows[0].id;

  const product = await pool.query(
    `INSERT INTO products (sku, name, category_id, description, unit_price, reorder_level)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [primarySku, 'Phase 2 Test Product', categoryId, 'Created by db-operations-test.js', 100000, 2],
  );
  primaryProductId = product.rows[0].id;
  createdProductIds.push(primaryProductId);

  await run('product starts with quantity 0 and is active', async () => {
    const { rows } = await pool.query(
      'SELECT quantity, reorder_level, is_active FROM products WHERE id = $1',
      [primaryProductId],
    );
    assert.equal(rows[0].quantity, 0);
    assert.equal(rows[0].reorder_level, 2);
    assert.equal(rows[0].is_active, true);
  });

  await run('duplicate category name is rejected case-insensitively', async () => {
    await expectPgError(
      () =>
        pool.query(
          'INSERT INTO categories (name) VALUES ($1)',
          [`test-cat-${runId}`.toLowerCase()],
        ),
      '23505',
    );
  });

  await run('duplicate SKU is rejected case-insensitively', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO products (sku, name, category_id, unit_price)
           VALUES ($1, $2, $3, $4)`,
          [primarySku.toLowerCase(), 'Duplicate SKU', categoryId, 1000],
        ),
      '23505',
    );
  });

  await run('negative unit price is rejected', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO products (sku, name, category_id, unit_price)
           VALUES ($1, $2, $3, $4)`,
          [`NEG-PRICE-${runId}`, 'Negative price', categoryId, -1],
        ),
      '23514',
    );
  });

  await run('negative quantity is rejected', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO products (sku, name, category_id, unit_price, quantity)
           VALUES ($1, $2, $3, $4, $5)`,
          [`NEG-QTY-${runId}`, 'Negative quantity', categoryId, 1000, -1],
        ),
      '23514',
    );
  });

  await run('missing category is rejected by foreign key', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO products (sku, name, category_id, unit_price)
           VALUES ($1, $2, $3, $4)`,
          [`BAD-CAT-${runId}`, 'Missing category', 999999999, 1000],
        ),
      '23503',
    );
  });

  await run('invalid transaction type is rejected', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO inventory_transactions (product_id, type, quantity)
           VALUES ($1, 'BAD', 1)`,
          [primaryProductId],
        ),
      '23514',
    );
  });

  await run('non-positive transaction quantity is rejected', async () => {
    await expectPgError(
      () =>
        pool.query(
          `INSERT INTO inventory_transactions (product_id, type, quantity)
           VALUES ($1, 'IN', 0)`,
          [primaryProductId],
        ),
      '23514',
    );
  });

  await run('stock-in increases quantity and records history', async () => {
    await stockIn(primaryProductId, 10);
    const state = await snapshot(primaryProductId);
    assert.equal(state.quantity, 10);
    assert.equal(state.transactions, 1);
  });

  await run('stock-out decreases quantity and records history', async () => {
    await stockOut(primaryProductId, 4);
    const state = await snapshot(primaryProductId);
    assert.equal(state.quantity, 6);
    assert.equal(state.transactions, 2);
  });

  await run('insufficient stock-out rolls back without changes', async () => {
    const before = await snapshot(primaryProductId);
    await assert.rejects(
      () => stockOut(primaryProductId, 100),
      (error) => error.code === 'INSUFFICIENT_STOCK',
    );
    const after = await snapshot(primaryProductId);
    assert.deepEqual(after, before);
  });

  await run('failed history insert rolls back the quantity update', async () => {
    const before = await snapshot(primaryProductId);
    await assert.rejects(
      () =>
        withTransaction(pool, async (client) => {
          await client.query(
            'UPDATE products SET quantity = quantity + 1 WHERE id = $1',
            [primaryProductId],
          );
          await client.query(
            `INSERT INTO inventory_transactions (product_id, type, quantity)
             VALUES ($1, 'BAD', 1)`,
            [primaryProductId],
          );
        }),
      (error) => error.code === '23514',
    );
    const after = await snapshot(primaryProductId);
    assert.deepEqual(after, before);
  });

  const concurrencyProduct = await pool.query(
    `INSERT INTO products (sku, name, category_id, description, unit_price, reorder_level)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [`CONC-${runId}`, 'Concurrency Test Product', categoryId, 'Concurrency test', 50000, 2],
  );
  const concurrencyProductId = concurrencyProduct.rows[0].id;
  createdProductIds.push(concurrencyProductId);
  await stockIn(concurrencyProductId, 10);

  await run('concurrent stock-outs cannot oversell', async () => {
    const outcomes = await Promise.all([
      attemptConcurrentStockOut(concurrencyProductId, 7, 300),
      attemptConcurrentStockOut(concurrencyProductId, 7, 0),
    ]);

    const successes = outcomes.filter((outcome) => outcome.ok).length;
    const insufficient = outcomes.filter(
      (outcome) => !outcome.ok && outcome.code === 'INSUFFICIENT_STOCK',
    ).length;

    assert.equal(successes, 1, `Expected exactly one success: ${JSON.stringify(outcomes)}`);
    assert.equal(
      insufficient,
      1,
      `Expected exactly one insufficient-stock result: ${JSON.stringify(outcomes)}`,
    );

    const product = await pool.query(
      'SELECT quantity FROM products WHERE id = $1',
      [concurrencyProductId],
    );
    assert.equal(product.rows[0].quantity, 3);

    const outs = await pool.query(
      "SELECT COUNT(*)::int AS count FROM inventory_transactions WHERE product_id = $1 AND type = 'OUT'",
      [concurrencyProductId],
    );
    assert.equal(outs.rows[0].count, 1);
  });

  await run('soft delete hides product and preserves history', async () => {
    await pool.query('UPDATE products SET is_active = false WHERE id = $1', [primaryProductId]);

    const active = await pool.query(
      'SELECT 1 FROM products WHERE id = $1 AND is_active',
      [primaryProductId],
    );
    assert.equal(active.rowCount, 0);

    const anyState = await pool.query(
      'SELECT is_active FROM products WHERE id = $1',
      [primaryProductId],
    );
    assert.equal(anyState.rows[0].is_active, false);

    const history = await pool.query(
      'SELECT COUNT(*)::int AS count FROM inventory_transactions WHERE product_id = $1',
      [primaryProductId],
    );
    assert.equal(history.rows[0].count, 2);
  });

  await run('inactive products are not eligible for stock movement', async () => {
    const { rowCount } = await pool.query(
      'SELECT 1 FROM products WHERE id = $1 AND is_active FOR UPDATE',
      [primaryProductId],
    );
    assert.equal(rowCount, 0);
  });

  await run('updated_at trigger advances the timestamp', async () => {
    const before = await pool.query(
      'SELECT updated_at FROM products WHERE id = $1',
      [concurrencyProductId],
    );
    await new Promise((resolve) => setTimeout(resolve, 20));
    await pool.query(
      'UPDATE products SET name = $1 WHERE id = $2',
      ['Concurrency Test Product Updated', concurrencyProductId],
    );
    const after = await pool.query(
      'SELECT updated_at FROM products WHERE id = $1',
      [concurrencyProductId],
    );
    assert.ok(
      new Date(after.rows[0].updated_at) > new Date(before.rows[0].updated_at),
      'updated_at did not advance',
    );
  });
} catch (error) {
  console.error(`Fatal test error [${error.code || 'ERROR'}]: ${error.message}`);
  process.exitCode = 1;
} finally {
  try {
    if (createdProductIds.length > 0) {
      await pool.query(
        'DELETE FROM inventory_transactions WHERE product_id = ANY($1::bigint[])',
        [createdProductIds],
      );
      await pool.query(
        'DELETE FROM products WHERE id = ANY($1::bigint[])',
        [createdProductIds],
      );
    }
    if (categoryId !== null) {
      await pool.query('DELETE FROM categories WHERE id = $1', [categoryId]);
    }
    console.log('Cleanup complete: temporary test rows removed.');
  } catch (error) {
    console.warn(`Cleanup warning: ${error.message}`);
  }

  const failed = results.filter((result) => !result.ok).length;
  console.log(`\nSummary: ${results.length - failed}/${results.length} operations tests passed.`);
  if (failed > 0) {
    process.exitCode = 1;
    for (const result of results.filter((item) => !item.ok)) {
      console.error(`- ${result.name}: ${result.message}`);
    }
  }

  await pool.end().catch(() => {});
}
