import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  cleanupTestData,
  createTestCategory,
  createTestContext,
  createTestProduct,
  uniqueToken,
} from './helpers.js';

describe('product API', () => {
  let ctx;
  let category;
  let product;
  let secondProduct;
  let thirdProduct;
  let fourthProduct;

  const token = uniqueToken('PROD');
  const productIds = [];
  const categoryIds = [];

  beforeAll(async () => {
    ctx = createTestContext();
    category = await createTestCategory(ctx.request, token);
    categoryIds.push(category.id);

    product = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'A',
      name: `Zulu ${token}`,
      unitPrice: 1000,
    });
    secondProduct = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'B',
      name: `Alpha ${token}`,
      unitPrice: 2000,
    });
    thirdProduct = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'C',
      name: `Bravo ${token}`,
      unitPrice: 3000,
    });
    fourthProduct = await createTestProduct(ctx.request, {
      categoryId: category.id,
      token,
      suffix: 'D',
      name: `Charlie ${token}`,
      unitPrice: 4000,
    });
    productIds.push(
      product.id,
      secondProduct.id,
      thirdProduct.id,
      fourthProduct.id,
    );
  });

  afterAll(async () => {
    await cleanupTestData(ctx.pool, { productIds, categoryIds });
    await ctx.pool.end();
  });

  it('creates a product with quantity 0 and a computed stock status', () => {
    expect(product).toMatchObject({
      categoryId: category.id,
      categoryName: category.name,
      quantity: 0,
      reorderLevel: 5,
      stockStatus: 'OUT_OF_STOCK',
      isActive: true,
    });
    expect(product.unitPrice).toBe(1000);
    expect(product.sku).toBe(`P3-${token}-A`);
    expect(product.createdAt).toEqual(expect.any(String));
  });

  it('normalizes SKU to uppercase', async () => {
    const response = await ctx.request
      .post('/api/products')
      .send({
        sku: `p3-${token.toLowerCase()}-norm`,
        name: `Normalized ${token}`,
        categoryId: category.id,
        description: '',
        unitPrice: 123.45,
        reorderLevel: 0,
      })
      .expect(201);

    productIds.push(response.body.data.id);
    expect(response.body.data.sku).toBe(`P3-${token}-NORM`);
    expect(response.body.data.description).toBeNull();

    await ctx.request.delete(`/api/products/${response.body.data.id}`).expect(200);
  });

  it('rejects duplicate SKUs case-insensitively', async () => {
    const response = await ctx.request
      .post('/api/products')
      .send({
        sku: `p3-${token.toLowerCase()}-a`,
        name: `Duplicate ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(409);

    expect(response.body.error.code).toBe('DUPLICATE_SKU');
  });

  it('rejects quantity and isActive during product creation', async () => {
    const quantityResponse = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-Q`,
        name: `Quantity ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
        quantity: 10,
      })
      .expect(400);

    expect(quantityResponse.body.error.code).toBe('FIELD_NOT_EDITABLE');

    const activeResponse = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-ACTIVE`,
        name: `Active ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
        isActive: true,
      })
      .expect(400);

    expect(activeResponse.body.error.code).toBe('FIELD_NOT_EDITABLE');
  });

  it('validates product payloads', async () => {
    const missingName = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-MISS`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(400);
    expect(missingName.body.error.code).toBe('VALIDATION_ERROR');

    const negativePrice = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-NEG`,
        name: `Negative ${token}`,
        categoryId: category.id,
        unitPrice: -1,
        reorderLevel: 5,
      })
      .expect(400);
    expect(negativePrice.body.error.code).toBe('VALIDATION_ERROR');

    const tooManyDecimals = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-DEC`,
        name: `Decimals ${token}`,
        categoryId: category.id,
        unitPrice: 1.234,
        reorderLevel: 5,
      })
      .expect(400);
    expect(tooManyDecimals.body.error.code).toBe('VALIDATION_ERROR');

    const invalidSku = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3 ${token} SPACE`,
        name: `Invalid SKU ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(400);
    expect(invalidSku.body.error.code).toBe('VALIDATION_ERROR');

    const unknownField = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-UNKNOWN`,
        name: `Unknown ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
        foo: 'bar',
      })
      .expect(400);
    expect(unknownField.body.error.code).toBe('VALIDATION_ERROR');

    const missingCategory = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-NOCAT`,
        name: `No category ${token}`,
        categoryId: 999999999,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(400);
    expect(missingCategory.body.error.code).toBe('CATEGORY_NOT_FOUND');
  });

  it('gets product details and handles missing/invalid IDs', async () => {
    const response = await ctx.request
      .get(`/api/products/${product.id}`)
      .expect(200);
    expect(response.body.data.id).toBe(product.id);

    const missing = await ctx.request
      .get('/api/products/999999999')
      .expect(404);
    expect(missing.body.error.code).toBe('PRODUCT_NOT_FOUND');

    const invalid = await ctx.request.get('/api/products/not-a-number').expect(400);
    expect(invalid.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('searches, filters, sorts, and paginates active products', async () => {
    const page1 = await ctx.request
      .get('/api/products')
      .query({
        categoryId: category.id,
        sort: 'name',
        order: 'asc',
        page: 1,
        limit: 2,
      })
      .expect(200);

    expect(page1.body.data).toHaveLength(2);
    expect(page1.body.data.map((item) => item.name)).toEqual([
      `Alpha ${token}`,
      `Bravo ${token}`,
    ]);
    expect(page1.body.meta).toMatchObject({
      page: 1,
      limit: 2,
      total: 4,
      totalPages: 2,
      hasNext: true,
      hasPrev: false,
      sort: 'name',
      order: 'asc',
    });

    const page2 = await ctx.request
      .get('/api/products')
      .query({
        categoryId: category.id,
        sort: 'name',
        order: 'asc',
        page: 2,
        limit: 2,
      })
      .expect(200);

    expect(page2.body.data.map((item) => item.name)).toEqual([
      `Charlie ${token}`,
      `Zulu ${token}`,
    ]);
    expect(page2.body.meta).toMatchObject({
      page: 2,
      total: 4,
      hasNext: false,
      hasPrev: true,
    });

    const byName = await ctx.request
      .get('/api/products')
      .query({ categoryId: category.id, q: 'Alpha' })
      .expect(200);
    expect(byName.body.meta.total).toBe(1);
    expect(byName.body.data[0].id).toBe(secondProduct.id);

    const bySku = await ctx.request
      .get('/api/products')
      .query({ categoryId: category.id, q: secondProduct.sku })
      .expect(200);
    expect(bySku.body.meta.total).toBe(1);
    expect(bySku.body.data[0].id).toBe(secondProduct.id);

    const byPrice = await ctx.request
      .get('/api/products')
      .query({
        categoryId: category.id,
        sort: 'unitPrice',
        order: 'desc',
        limit: 100,
      })
      .expect(200);
    expect(byPrice.body.data.map((item) => item.unitPrice)).toEqual([
      4000, 3000, 2000, 1000,
    ]);

    const badSort = await ctx.request
      .get('/api/products')
      .query({ sort: 'password' })
      .expect(400);
    expect(badSort.body.error.code).toBe('VALIDATION_ERROR');

    const badPage = await ctx.request
      .get('/api/products')
      .query({ page: 0 })
      .expect(400);
    expect(badPage.body.error.code).toBe('VALIDATION_ERROR');

    const unknownQuery = await ctx.request
      .get('/api/products')
      .query({ limit: 20, unknown: 'x' })
      .expect(400);
    expect(unknownQuery.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('updates metadata without changing stock quantity', async () => {
    await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'IN',
        quantity: 7,
        note: 'Initial stock for update test',
      })
      .expect(201);

    const response = await ctx.request
      .put(`/api/products/${product.id}`)
      .send({
        sku: product.sku,
        name: `Zulu Updated ${token}`,
        categoryId: category.id,
        description: 'Updated description',
        unitPrice: 1500.5,
        reorderLevel: 3,
      })
      .expect(200);

    expect(response.body.data).toMatchObject({
      id: product.id,
      name: `Zulu Updated ${token}`,
      description: 'Updated description',
      unitPrice: 1500.5,
      reorderLevel: 3,
      quantity: 7,
      stockStatus: 'IN_STOCK',
    });
  });

  it('rejects duplicate SKU on update', async () => {
    const response = await ctx.request
      .put(`/api/products/${product.id}`)
      .send({
        sku: secondProduct.sku,
        name: `Zulu Updated ${token}`,
        categoryId: category.id,
        description: 'Updated description',
        unitPrice: 1500.5,
        reorderLevel: 3,
      })
      .expect(409);

    expect(response.body.error.code).toBe('DUPLICATE_SKU');
  });

  it('rejects stock fields on update', async () => {
    const response = await ctx.request
      .put(`/api/products/${product.id}`)
      .send({
        sku: product.sku,
        name: `Zulu Updated ${token}`,
        categoryId: category.id,
        description: 'Updated description',
        unitPrice: 1500.5,
        reorderLevel: 3,
        quantity: 99,
      })
      .expect(400);

    expect(response.body.error.code).toBe('FIELD_NOT_EDITABLE');
  });

  it('handles missing product and invalid category on update', async () => {
    const missing = await ctx.request
      .put('/api/products/999999999')
      .send({
        sku: `P3-${token}-MISSING-UPDATE`,
        name: `Missing ${token}`,
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(404);
    expect(missing.body.error.code).toBe('PRODUCT_NOT_FOUND');

    const invalidCategory = await ctx.request
      .put(`/api/products/${product.id}`)
      .send({
        sku: product.sku,
        name: `Zulu Updated ${token}`,
        categoryId: 999999999,
        unitPrice: 1500.5,
        reorderLevel: 3,
      })
      .expect(400);
    expect(invalidCategory.body.error.code).toBe('CATEGORY_NOT_FOUND');
  });

  it('soft-deletes a product and preserves its history', async () => {
    const response = await ctx.request
      .delete(`/api/products/${product.id}`)
      .expect(200);

    expect(response.body.data).toEqual({
      id: product.id,
      sku: product.sku,
      isActive: false,
    });

    const detail = await ctx.request
      .get(`/api/products/${product.id}`)
      .expect(404);
    expect(detail.body.error.code).toBe('PRODUCT_NOT_FOUND');

    const search = await ctx.request
      .get('/api/products')
      .query({ categoryId: category.id, q: `Zulu Updated ${token}` })
      .expect(200);
    expect(search.body.meta.total).toBe(0);

    const secondDelete = await ctx.request
      .delete(`/api/products/${product.id}`)
      .expect(404);
    expect(secondDelete.body.error.code).toBe('PRODUCT_NOT_FOUND');

    const stockAttempt = await ctx.request
      .post('/api/inventory/transactions')
      .send({
        productId: product.id,
        type: 'IN',
        quantity: 1,
      })
      .expect(409);
    expect(stockAttempt.body.error.code).toBe('PRODUCT_INACTIVE');

    const history = await ctx.request
      .get('/api/inventory/transactions')
      .query({ productId: product.id })
      .expect(200);
    expect(history.body.meta.total).toBe(1);
    expect(history.body.data[0].productSku).toBe(product.sku);
  });

  it('returns validation errors for malformed and oversized JSON', async () => {
    const malformed = await ctx.request
      .post('/api/products')
      .set('Content-Type', 'application/json')
      .send('{"sku":')
      .expect(400);
    expect(malformed.body.error.code).toBe('VALIDATION_ERROR');

    const oversized = await ctx.request
      .post('/api/products')
      .send({
        sku: `P3-${token}-BIG`,
        name: 'x'.repeat(110000),
        categoryId: category.id,
        unitPrice: 1000,
        reorderLevel: 5,
      })
      .expect(413);
    expect(oversized.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });
});
