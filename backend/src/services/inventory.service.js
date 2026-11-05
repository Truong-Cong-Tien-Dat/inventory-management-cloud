import { withTransaction } from '../config/database.js';
import * as inventoryRepository from '../repositories/inventory.repository.js';
import { buildPaginationMeta, getOffset } from '../utils/pagination.js';
import { toProductSummary, toTransaction } from '../utils/serializers.js';
import {
  insufficientStock,
  productInactive,
  productNotFound,
} from '../utils/errors.js';

export async function createStockTransaction(pool, input) {
  return withTransaction(pool, async (client) => {
    const product = await inventoryRepository.lockProductForUpdate(
      client,
      input.productId,
    );

    if (!product) {
      throw productNotFound();
    }

    if (!product.is_active) {
      throw productInactive();
    }

    if (input.type === 'OUT' && product.quantity < input.quantity) {
      throw insufficientStock(product.quantity, input.quantity);
    }

    const delta = input.type === 'IN' ? input.quantity : -input.quantity;
    const updated = await inventoryRepository.updateProductQuantity(
      client,
      input.productId,
      delta,
    );

    const transaction = await inventoryRepository.insertTransaction(
      client,
      input,
    );

    return {
      transaction: toTransaction({
        ...transaction,
        product_sku: product.sku,
        product_name: product.name,
      }),
      product: toProductSummary(updated),
    };
  });
}

export async function listTransactions(db, query) {
  const offset = getOffset(query.page, query.limit);
  const { rows, total } = await inventoryRepository.listTransactions(db, {
    ...query,
    offset,
  });

  return {
    data: rows.map(toTransaction),
    meta: buildPaginationMeta({
      page: query.page,
      limit: query.limit,
      total,
    }),
  };
}
