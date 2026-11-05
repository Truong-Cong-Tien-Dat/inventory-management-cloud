import { createApp } from './app.js';
import { createPool, waitForDatabase } from './config/database.js';
import { env } from './config/env.js';

const pool = createPool({ max: env.dbPoolMax });
let server;
let shuttingDown = false;

pool.on('error', (error) => {
  // Idle client errors must not crash the process.
  console.error('[db] idle client error:', error.message);
});

async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[server] ${signal} received; shutting down`);

  const forceExit = setTimeout(() => {
    console.error('[server] graceful shutdown timed out; forcing exit');
    process.exit(1);
  }, 10_000);
  forceExit.unref();

  const closePool = async () => {
    try {
      await pool.end();
    } catch (error) {
      console.error('[db] error while closing pool:', error.message);
    }
  };

  if (!server) {
    await closePool();
    clearTimeout(forceExit);
    process.exit(0);
  }

  server.close(async (error) => {
    if (error) {
      console.error('[server] error while closing HTTP server:', error.message);
    }
    await closePool();
    clearTimeout(forceExit);
    process.exit(error ? 1 : 0);
  });
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

async function start() {
  try {
    await waitForDatabase(pool);
    console.log('[db] connection verified');
  } catch (error) {
    console.error('[db] connection failed:', error.message);
    await pool.end().catch(() => {});
    process.exit(1);
  }

  const app = createApp({ pool });
  server = app.listen(env.port, '0.0.0.0', () => {
    console.log(
      `[server] API listening on 0.0.0.0:${env.port} (${env.nodeEnv})`,
    );
  });

  server.on('error', async (error) => {
    console.error('[server] failed to start:', error.message);
    await pool.end().catch(() => {});
    process.exit(1);
  });
}

void start();
