import path from 'node:path';

import './load-env.js';

function parsePort(value) {
  const port = Number.parseInt(value ?? '3000', 10);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }
  return port;
}

function parsePositiveInt(value, fallback) {
  if (value === undefined || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`Expected a positive integer, received: ${value}`);
  }
  return parsed;
}

function normalizeOrigin(value) {
  const trimmed = value.trim().replace(/\/+$/, '');
  let url;
  try {
    url = new URL(trimmed);
  } catch {
    throw new Error(`Invalid origin: ${trimmed}`);
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error(`Origin must use http or https: ${trimmed}`);
  }
  return url.origin;
}

function parseOrigins(value) {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map(normalizeOrigin);
}

const nodeEnv = process.env.NODE_ENV || 'development';
const allowedOrigins = parseOrigins(process.env.FRONTEND_ORIGIN);

if (process.env.RENDER_EXTERNAL_URL) {
  allowedOrigins.push(normalizeOrigin(process.env.RENDER_EXTERNAL_URL));
}

// Optional directory of prebuilt Flutter Web assets served by the same
// Express process (single-service Render deployment). Empty string disables
// static serving entirely, which keeps API-only behavior for tests/dev.
const staticDir = process.env.STATIC_DIR
  ? path.resolve(process.env.STATIC_DIR)
  : '';

export const env = Object.freeze({
  nodeEnv,
  isProduction: nodeEnv === 'production',
  isTest: nodeEnv === 'test' || Boolean(process.env.VITEST),
  port: parsePort(process.env.PORT),
  jsonBodyLimit: process.env.JSON_BODY_LIMIT || '100kb',
  allowedOrigins: [...new Set(allowedOrigins)],
  staticDir,
  requestLogging:
    nodeEnv !== 'test' && process.env.REQUEST_LOGGING !== 'false',
  dbPoolMax: parsePositiveInt(process.env.DB_POOL_MAX, 10),
  trustProxy: nodeEnv === 'production' ? 1 : false,
});
