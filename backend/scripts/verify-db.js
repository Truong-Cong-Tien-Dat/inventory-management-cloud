import assert from 'node:assert/strict';
import {
  createPool,
  databaseInfo,
  inspectConnection,
} from '../src/config/database.js';

const pool = createPool({ max: 2 });
const results = [];

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

try {
  const info = databaseInfo();
  console.log(
    `Database: ${info.host}:${info.port}/${info.database} (TLS: ${info.sslMode})`,
  );

  let connection;

  await run('connection uses TLS', async () => {
    connection = await inspectConnection(pool);
    assert.equal(connection.ssl, true, 'Expected pg_stat_ssl.ssl = true');
    console.log(`      PostgreSQL ${connection.serverVersion}, database ${connection.database}`);
  });

  await run('PostgreSQL version is 16 or newer', async () => {
    assert.ok(connection, 'Connection check did not run');
    const major = Number.parseInt(connection.serverVersion.split('.')[0], 10);
    assert.ok(major >= 16, `Expected PostgreSQL >= 16, got ${connection.serverVersion}`);
  });

  await run('application tables exist', async () => {
    const { rows } = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = ANY($1::text[])
      ORDER BY table_name
    `, [['categories', 'products', 'inventory_transactions', 'schema_migrations']]);
    const names = rows.map((row) => row.table_name);
    assert.deepEqual(names, [
      'categories',
      'inventory_transactions',
      'products',
      'schema_migrations',
    ]);
  });

  await run('initial migration is recorded', async () => {
    const { rowCount } = await pool.query(
      "SELECT 1 FROM schema_migrations WHERE version = '001_init.sql'",
    );
    assert.equal(rowCount, 1);
  });

  await run('pg_trgm extension is installed', async () => {
    const { rowCount } = await pool.query(
      "SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'",
    );
    assert.equal(rowCount, 1);
  });

  await run('expected constraints exist', async () => {
    const expected = [
      'categories_pkey',
      'categories_name_unique',
      'categories_name_not_blank',
      'products_pkey',
      'products_sku_unique',
      'products_category_fk',
      'products_unit_price_nonnegative',
      'products_quantity_nonnegative',
      'products_reorder_level_nonnegative',
      'products_sku_not_blank',
      'products_name_not_blank',
      'inventory_transactions_pkey',
      'inventory_product_fk',
      'inventory_type_valid',
      'inventory_quantity_positive',
    ];

    const { rows } = await pool.query(`
      SELECT conname
      FROM pg_constraint
      WHERE conrelid = ANY (ARRAY[
        'categories'::regclass,
        'products'::regclass,
        'inventory_transactions'::regclass
      ])
    `);
    const names = new Set(rows.map((row) => row.conname));
    const missing = expected.filter((name) => !names.has(name));
    assert.deepEqual(missing, [], `Missing constraints: ${missing.join(', ')}`);
  });

  await run('expected indexes exist', async () => {
    const expected = [
      'categories_name_lower_unique',
      'products_sku_upper_unique',
      'products_category_idx',
      'products_active_created_idx',
      'products_name_trgm_idx',
      'products_sku_trgm_idx',
      'transactions_product_created_idx',
      'transactions_created_idx',
      'transactions_type_idx',
    ];

    const { rows } = await pool.query(
      "SELECT indexname FROM pg_indexes WHERE schemaname = 'public'",
    );
    const names = new Set(rows.map((row) => row.indexname));
    const missing = expected.filter((name) => !names.has(name));
    assert.deepEqual(missing, [], `Missing indexes: ${missing.join(', ')}`);
  });

  await run('updated_at trigger exists', async () => {
    const { rowCount } = await pool.query(`
      SELECT 1
      FROM pg_trigger
      WHERE tgrelid = 'products'::regclass
        AND tgname = 'products_set_updated_at'
        AND NOT tgisinternal
    `);
    assert.equal(rowCount, 1);
  });

  await run('seed data is present', async () => {
    const { rows } = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM categories)::int AS categories,
        (SELECT COUNT(*) FROM products)::int AS products,
        (SELECT COUNT(*) FROM inventory_transactions)::int AS transactions
    `);
    const row = rows[0];
    assert.ok(row.categories >= 5, `Expected >= 5 categories, got ${row.categories}`);
    assert.ok(row.products >= 12, `Expected >= 12 products, got ${row.products}`);
    assert.ok(row.transactions >= 24, `Expected >= 24 transactions, got ${row.transactions}`);
    console.log(
      `      categories=${row.categories} products=${row.products} transactions=${row.transactions}`,
    );
  });

  await run('seed quantities match IN minus OUT', async () => {
    const { rows } = await pool.query(`
      SELECT p.sku, p.quantity,
             COALESCE(SUM(CASE WHEN t.type = 'IN' THEN t.quantity ELSE -t.quantity END), 0)::int AS computed
      FROM products p
      LEFT JOIN inventory_transactions t ON t.product_id = p.id
      GROUP BY p.id
      HAVING p.quantity <> COALESCE(SUM(CASE WHEN t.type = 'IN' THEN t.quantity ELSE -t.quantity END), 0)
    `);
    assert.deepEqual(
      rows,
      [],
      `Inconsistent products: ${rows.map((row) => row.sku).join(', ')}`,
    );
  });

  await run('search by partial name works', async () => {
    const { rowCount } = await pool.query(`
      SELECT 1
      FROM products
      WHERE is_active AND name ILIKE '%bàn phím%'
    `);
    assert.ok(rowCount >= 1, 'Expected at least one matching product');
  });

  await run('search by partial SKU works', async () => {
    const { rowCount } = await pool.query(`
      SELECT 1
      FROM products
      WHERE is_active AND sku ILIKE '%ELEC%'
    `);
    assert.ok(rowCount >= 4, 'Expected at least four ELEC products');
  });

  await run('category filter works', async () => {
    const { rowCount } = await pool.query(`
      SELECT 1
      FROM products p
      JOIN categories c ON c.id = p.category_id
      WHERE p.is_active AND c.name = 'Thiết bị điện tử'
    `);
    assert.ok(rowCount >= 4, 'Expected at least four products in the electronics category');
  });

  await run('seed includes low-stock and out-of-stock products', async () => {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE quantity > 0 AND quantity <= reorder_level)::int AS low_stock,
        COUNT(*) FILTER (WHERE quantity = 0)::int AS out_of_stock
      FROM products
      WHERE is_active
    `);
    assert.ok(rows[0].low_stock >= 2, `Expected >= 2 low-stock products, got ${rows[0].low_stock}`);
    assert.ok(rows[0].out_of_stock >= 1, `Expected >= 1 out-of-stock product, got ${rows[0].out_of_stock}`);
    console.log(
      `      lowStock=${rows[0].low_stock} outOfStock=${rows[0].out_of_stock}`,
    );
  });

  await run('database health query works', async () => {
    const { rows } = await pool.query('SELECT 1 AS ok');
    assert.equal(rows[0].ok, 1);
  });
} catch (error) {
  console.error(`Verification failed [${error.code || 'ERROR'}]: ${error.message}`);
  process.exitCode = 1;
} finally {
  const failed = results.filter((result) => !result.ok).length;
  console.log(`\nSummary: ${results.length - failed}/${results.length} checks passed.`);
  if (failed > 0) {
    process.exitCode = 1;
    for (const result of results.filter((item) => !item.ok)) {
      console.error(`- ${result.name}: ${result.message}`);
    }
  }
  await pool.end().catch(() => {});
}
