function toIsoString(value) {
  if (!value) return null;
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function toMoney(value) {
  if (value === null || value === undefined) return null;
  return Number(Number(value).toFixed(2));
}

export function getStockStatus(quantity, reorderLevel) {
  if (quantity === 0) return 'OUT_OF_STOCK';
  if (quantity <= reorderLevel) return 'LOW_STOCK';
  return 'IN_STOCK';
}

export function toProduct(row) {
  if (!row) return null;

  const quantity = Number(row.quantity);
  const reorderLevel = Number(row.reorder_level);

  return {
    id: row.id,
    sku: row.sku,
    name: row.name,
    categoryId: row.category_id,
    categoryName: row.category_name ?? null,
    description: row.description ?? null,
    unitPrice: toMoney(row.unit_price),
    quantity,
    reorderLevel,
    stockStatus: getStockStatus(quantity, reorderLevel),
    isActive: row.is_active,
    createdAt: toIsoString(row.created_at),
    updatedAt: toIsoString(row.updated_at),
  };
}

export function toProductSummary(row) {
  if (!row) return null;

  const quantity = Number(row.quantity);
  const reorderLevel = Number(row.reorder_level);

  return {
    id: row.id,
    sku: row.sku,
    quantity,
    stockStatus: getStockStatus(quantity, reorderLevel),
    updatedAt: toIsoString(row.updated_at),
  };
}

export function toCategory(row) {
  if (!row) return null;

  return {
    id: row.id,
    name: row.name,
    productCount: Number(row.product_count ?? 0),
    createdAt: toIsoString(row.created_at),
  };
}

export function toTransaction(row) {
  if (!row) return null;

  return {
    id: row.id,
    productId: row.product_id,
    productSku: row.product_sku ?? null,
    productName: row.product_name ?? null,
    type: row.type,
    quantity: Number(row.quantity),
    note: row.note ?? null,
    createdAt: toIsoString(row.created_at),
  };
}
