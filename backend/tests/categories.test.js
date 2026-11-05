import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  cleanupTestData,
  createTestContext,
  uniqueToken,
} from './helpers.js';

describe('category API', () => {
  let ctx;
  const token = uniqueToken('CAT');
  const categoryIds = [];

  beforeAll(() => {
    ctx = createTestContext();
  });

  afterAll(async () => {
    await cleanupTestData(ctx.pool, { categoryIds });
    await ctx.pool.end();
  });

  it('lists categories with active product counts', async () => {
    const response = await ctx.request.get('/api/categories').expect(200);

    expect(Array.isArray(response.body.data)).toBe(true);
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.data[0]).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        name: expect.any(String),
        productCount: expect.any(Number),
        createdAt: expect.any(String),
      }),
    );
  });

  it('creates a category and returns 201 with Location', async () => {
    const name = `Phase3 Category ${token}`;
    const response = await ctx.request
      .post('/api/categories')
      .send({ name })
      .expect(201);

    categoryIds.push(response.body.data.id);
    expect(response.headers.location).toBe(
      `/api/categories/${response.body.data.id}`,
    );
    expect(response.body.data).toMatchObject({
      name,
      productCount: 0,
    });
  });

  it('rejects duplicate category names case-insensitively', async () => {
    const response = await ctx.request
      .post('/api/categories')
      .send({ name: `phase3 category ${token.toLowerCase()}` })
      .expect(409);

    expect(response.body.error.code).toBe('CATEGORY_EXISTS');
  });

  it('validates category payloads', async () => {
    const blank = await ctx.request
      .post('/api/categories')
      .send({ name: '   ' })
      .expect(400);
    expect(blank.body.error.code).toBe('VALIDATION_ERROR');

    const missing = await ctx.request
      .post('/api/categories')
      .send({})
      .expect(400);
    expect(missing.body.error.code).toBe('VALIDATION_ERROR');

    const unknownField = await ctx.request
      .post('/api/categories')
      .send({ name: `Phase3 Category ${token} extra`, isActive: true })
      .expect(400);
    expect(unknownField.body.error.code).toBe('VALIDATION_ERROR');

    const tooLong = await ctx.request
      .post('/api/categories')
      .send({ name: 'x'.repeat(101) })
      .expect(400);
    expect(tooLong.body.error.code).toBe('VALIDATION_ERROR');
  });
});
