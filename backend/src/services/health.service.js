const HEALTH_TIMEOUT_MS = 5000;

export async function checkHealth(pool) {
  let timer;

  try {
    await Promise.race([
      pool.query('SELECT 1'),
      new Promise((resolve, reject) => {
        timer = setTimeout(() => {
          const error = new Error('Health check timed out');
          error.code = 'ETIMEDOUT';
          reject(error);
        }, HEALTH_TIMEOUT_MS);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }

  return {
    status: 'ok',
    database: 'up',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  };
}
