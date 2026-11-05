import { existsSync, statSync } from 'node:fs';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPool, databaseInfo } from '../src/config/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LOCK_KEY = 2026110301;

function resolveMigrationsDir() {
  const candidates = [
    process.env.MIGRATIONS_DIR,
    path.resolve(process.cwd(), 'database/migrations'),
    path.resolve(process.cwd(), '../database/migrations'),
    path.resolve(__dirname, '../../database/migrations'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (existsSync(candidate) && statSync(candidate).isDirectory()) {
      return candidate;
    }
  }

  throw new Error(
    'Migrations directory not found. Set MIGRATIONS_DIR or run from the project root/backend.',
  );
}

const pool = createPool({ max: 2 });
let client;
let locked = false;

try {
  const info = databaseInfo();
  console.log(
    `Database: ${info.host}:${info.port}/${info.database} (TLS: ${info.sslMode})`,
  );

  const migrationsDir = resolveMigrationsDir();
  const files = (await readdir(migrationsDir))
    .filter((file) => file.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    throw new Error(`No .sql migration files found in ${migrationsDir}`);
  }

  client = await pool.connect();
  await client.query('SELECT pg_advisory_lock($1::bigint)', [LOCK_KEY]);
  locked = true;

  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version     TEXT PRIMARY KEY,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  let applied = 0;
  let skipped = 0;

  for (const file of files) {
    const existing = await client.query(
      'SELECT 1 FROM schema_migrations WHERE version = $1',
      [file],
    );

    if (existing.rowCount > 0) {
      skipped += 1;
      console.log(`SKIP   ${file}`);
      continue;
    }

    const sql = await readFile(path.join(migrationsDir, file), 'utf8');
    console.log(`APPLY  ${file}`);

    try {
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [file],
      );
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      throw error;
    }

    applied += 1;
  }

  console.log(`Migrations complete. applied=${applied} skipped=${skipped}`);
} catch (error) {
  console.error(`Migration failed [${error.code || 'ERROR'}]: ${error.message}`);
  process.exitCode = 1;
} finally {
  if (client) {
    if (locked) {
      await client
        .query('SELECT pg_advisory_unlock($1::bigint)', [LOCK_KEY])
        .catch(() => {});
    }
    client.release();
  }
  await pool.end().catch(() => {});
}
