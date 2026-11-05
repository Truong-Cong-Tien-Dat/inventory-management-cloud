import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { createTestContext } from './helpers.js';

describe('health, routing, CORS, and database error handling', () => {
  let ctx;

  beforeAll(() => {
    ctx = createTestContext();
  });

  afterAll(async () => {
    await ctx.pool.end();
  });

  it('GET /api/health returns service and database status', async () => {
    const response = await ctx.request.get('/api/health').expect(200);

    expect(response.body.data).toMatchObject({
      status: 'ok',
      database: 'up',
    });
    expect(typeof response.body.data.uptimeSeconds).toBe('number');
    expect(new Date(response.body.data.timestamp).toString()).not.toBe(
      'Invalid Date',
    );
  });

  it('returns 404 ROUTE_NOT_FOUND for unknown API routes', async () => {
    const response = await ctx.request.get('/api/does-not-exist').expect(404);

    expect(response.body.error.code).toBe('ROUTE_NOT_FOUND');
  });

  it('rejects disallowed browser origins with 403', async () => {
    const response = await ctx.request
      .get('/api/health')
      .set('Origin', 'https://evil.example')
      .expect(403);

    expect(response.body.error.code).toBe('CORS_ORIGIN_DENIED');
  });

  it('allows localhost origins in development/test mode', async () => {
    await ctx.request
      .get('/api/health')
      .set('Origin', 'http://localhost:5173')
      .expect(200);
  });

  it('maps a database connection failure to 503 DB_UNAVAILABLE', async () => {
    const failingPool = {
      query: async () => {
        const error = new Error('connect ECONNREFUSED 127.0.0.1:5432');
        error.code = 'ECONNREFUSED';
        throw error;
      },
    };
    const failingApp = createApp({ pool: failingPool });

    const healthResponse = await request(failingApp)
      .get('/api/health')
      .expect(503);
    expect(healthResponse.body.error.code).toBe('DB_UNAVAILABLE');

    const productsResponse = await request(failingApp)
      .get('/api/products')
      .expect(503);
    expect(productsResponse.body.error.code).toBe('DB_UNAVAILABLE');
  });
});
