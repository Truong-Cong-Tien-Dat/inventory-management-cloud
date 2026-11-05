import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPool, databaseInfo } from '../src/config/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function resolveSeedFile() {
  const candidates = [
    process.env.SEED_FILE,
    path.resolve(process.cwd(), 'database/seed.sql'),
    path.resolve(process.cwd(), '../database/seed.sql'),
    path.resolve(__dirname, '../../database/seed.sql'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }

  throw new Error('Seed file not found. Set SEED_FILE or run from the project root/backend.');
}

if (
  process.env.NODE_ENV === 'production' &&
  process.env.ALLOW_PROD_SEED !== 'true'
) {
  console.error(
    'Refusing to seed a production database. Set ALLOW_PROD_SEED=true explicitly to override.',
  );
  process.exit(1);
}

const pool = createPool({ max: 2 });

try {
  const info = databaseInfo();
  console.log(
    `Database: ${info.host}:${info.port}/${info.database} (TLS: ${info.sslMode})`,
  );

  const seedFile = resolveSeedFile();
  const sql = await readFile(seedFile, 'utf8');

  console.log(`Seeding from ${path.relative(process.cwd(), seedFile)} ...`);

  const client = await pool.connect();
  try {
    await client.query(sql);
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }

  const counts = await pool.query(`
    SELECT
      (SELECT COUNT(*) FROM categories) AS categories,
      (SELECT COUNT(*) FROM products) AS products,
      (SELECT COUNT(*) FROM inventory_transactions) AS transactions,
      (SELECT COUNT(*) FROM products WHERE is_active AND quantity > 0
         AND quantity <= reorder_level) AS low_stock,
      (SELECT COUNT(*) FROM products WHERE is_active AND quantity = 0) AS out_of_stock
  `);

  const row = counts.rows[0];
  console.log(
    `Seed complete. categories=${row.categories} products=${row.products} ` +
      `transactions=${row.transactions} lowStock=${row.low_stock} outOfStock=${row.out_of_stock}`,
  );

  const inconsistent = await pool.query(`
    SELECT p.sku, p.quantity,
           COALESCE(SUM(CASE WHEN t.type = 'IN' THEN t.quantity ELSE -t.quantity END), 0) AS computed
    FROM products p
    LEFT JOIN inventory_transactions t ON t.product_id = p.id
    GROUP BY p.id
    HAVING p.quantity <> COALESCE(SUM(CASE WHEN t.type = 'IN' THEN t.quantity ELSE -t.quantity END), 0)
  `);

  if (inconsistent.rowCount > 0) {
    throw new Error(
      `Seed consistency check failed for SKUs: ${inconsistent.rows
        .map((r) => r.sku)
        .join(', ')}`,
    );
  }

  console.log('Seed consistency check passed: quantity = SUM(IN) - SUM(OUT).');
} catch (error) {
  console.error(`Seed failed [${error.code || 'ERROR'}]: ${error.message}`);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => {});
}
