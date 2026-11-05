import * as productRepository from '../repositories/product.repository.js';
import { toProduct } from '../utils/serializers.js';
import { buildPaginationMeta, getOffset } from '../utils/pagination.js';
import {
  categoryNotFound,
  duplicateSku,
  productNotFound,
} from '../utils/errors.js';

function normalizeProductInput(input) {
  return {
    ...input,
    description: input.description ?? null,
    unitPrice: Number(Number(input.unitPrice).toFixed(2)),
  };
}

export async function listProducts(db, query) {
  const offset = getOffset(query.page, query.limit);
  const { rows, total } = await productRepository.listProducts(db, {
    ...query,
    offset,
  });

  return {
    data: rows.map(toProduct),
    meta: buildPaginationMeta({
      page: query.page,
      limit: query.limit,
      total,
      sort: query.sort,
      order: query.order,
    }),
  };
}

export async function getProduct(db, id) {
  const row = await productRepository.findActiveProductById(db, id);
  if (!row) {
    throw productNotFound();
  }
  return toProduct(row);
}

export async function createProduct(db, input) {
  const categoryIsValid = await productRepository.categoryExists(
    db,
    input.categoryId,
  );
  if (!categoryIsValid) {
    throw categoryNotFound();
  }

  let created;
  try {
    created = await productRepository.createProduct(
      db,
      normalizeProductInput(input),
    );
  } catch (error) {
    if (error.code === '23505') throw duplicateSku();
    if (error.code === '23503') throw categoryNotFound();
    throw error;
  }

  return getProduct(db, created.id);
}

export async function updateProduct(db, id, input) {
  const categoryIsValid = await productRepository.categoryExists(
    db,
    input.categoryId,
  );
  if (!categoryIsValid) {
    throw categoryNotFound();
  }

  let updated;
  try {
    updated = await productRepository.updateProduct(
      db,
      id,
      normalizeProductInput(input),
    );
  } catch (error) {
    if (error.code === '23505') throw duplicateSku();
    if (error.code === '23503') throw categoryNotFound();
    throw error;
  }

  if (!updated) {
    throw productNotFound();
  }

  return getProduct(db, id);
}

export async function softDeleteProduct(db, id) {
  const deleted = await productRepository.softDeleteProduct(db, id);
  if (!deleted) {
    throw productNotFound();
  }

  return {
    id: deleted.id,
    sku: deleted.sku,
    isActive: false,
  };
}
