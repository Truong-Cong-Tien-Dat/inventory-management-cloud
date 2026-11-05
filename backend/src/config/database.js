import './load-env.js';
import pg from 'pg';

const { Pool, types } = pg;

// Identity columns are BIGINT. The demo uses small values, so mapping int8 to
// a JavaScript number keeps API payloads simple. This is documented in the
// implementation plan.
types.setTypeParser(20, (value) => Number(value));

const SSL_MODES = new Set(['disable', 'require', 'no-verify']);

function getRequiredDatabaseUrl() {
  const value = process.env.DATABASE_URL?.trim();
  if (!value) {
    throw new Error(
      'DATABASE_URL is not configured. Copy backend/.env.example to backend/.env and set it.',
    );
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('DATABASE_URL is not a valid URL.');
  }

  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    throw new Error('DATABASE_URL must use the postgres:// or postgresql:// protocol.');
  }

  if (!parsed.hostname || !parsed.pathname || parsed.pathname === '/') {
    throw new Error('DATABASE_URL must include a host and a database name.');
  }

  return value;
}

function resolveSslMode() {
  const explicit = (process.env.DATABASE_SSL || '').trim().toLowerCase();
  if (explicit) {
    if (!SSL_MODES.has(explicit)) {
      throw new Error('DATABASE_SSL must be one of: disable, require, no-verify.');
    }
    return explicit;
  }

  const url = new URL(getRequiredDatabaseUrl());
  const sslmode = (url.searchParams.get('sslmode') || '').toLowerCase();

  if (sslmode === 'disable') return 'disable';
  if (sslmode === 'no-verify') return 'no-verify';

  // Render internal connection strings use a short hostname without a domain
  // (for example "dpg-xxxx-a"). Those connections stay on Render's private
  // network, so TLS is not required. External Render hosts use a public
  // hostname and present a publicly trusted certificate.
  if (!url.hostname.includes('.')) return 'disable';
  if (url.hostname.endsWith('.render.com')) return 'require';

  return 'disable';
}

export function resolveSslConfig() {
  const mode = resolveSslMode();
  if (mode === 'disable') return false;
  if (mode === 'no-verify') return { rejectUnauthorized: false };
  return { rejectUnauthorized: true };
}

export function databaseInfo() {
  const url = new URL(getRequiredDatabaseUrl());
  return {
    host: url.hostname,
    port: url.port || '5432',
    database: decodeURIComponent(url.pathname.replace(/^\//, '')),
    sslMode: resolveSslMode(),
  };
}

export function createPool({
  connectionString = getRequiredDatabaseUrl(),
  ssl = resolveSslConfig(),
  max = 10,
  ...overrides
} = {}) {
  return new Pool({
    connectionString,
    ssl,
    max,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 15_000,
    application_name: 'inventory-management',
    ...overrides,
  });
}

export async function inspectConnection(pool) {
  const { rows } = await pool.query(`
    SELECT current_database() AS database,
           current_setting('server_version') AS "serverVersion",
           (SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()) AS ssl
  `);
  return rows[0];
}

export async function withTransaction(pool, callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function waitForDatabase(
  pool,
  { attempts = 5, baseDelayMs = 1000 } = {},
) {
  let lastError;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await pool.query('SELECT 1');
      return;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        const delay = baseDelayMs * 2 ** (attempt - 1);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError;
}
