export async function lockProductForUpdate(client, productId) {
  const { rows } = await client.query(
    `SELECT id, sku, name, quantity, reorder_level, is_active, updated_at
     FROM products
     WHERE id = $1
     FOR UPDATE`,
    [productId],
  );
  return rows[0] ?? null;
}

export async function updateProductQuantity(client, productId, delta) {
  const { rows } = await client.query(
    `UPDATE products
     SET quantity = quantity + $1
     WHERE id = $2
     RETURNING id, sku, quantity, reorder_level, updated_at`,
    [delta, productId],
  );
  return rows[0] ?? null;
}

export async function insertTransaction(client, transaction) {
  const { rows } = await client.query(
    `INSERT INTO inventory_transactions (product_id, type, quantity, note)
     VALUES ($1, $2, $3, $4)
     RETURNING id, product_id, type, quantity, note, created_at`,
    [
      transaction.productId,
      transaction.type,
      transaction.quantity,
      transaction.note,
    ],
  );
  return rows[0];
}

export async function listTransactions(
  db,
  { productId, type, from, to, page, limit, offset },
) {
  const conditions = [];
  const values = [];

  if (productId !== undefined) {
    values.push(productId);
    conditions.push(`t.product_id = $${values.length}`);
  }

  if (type) {
    values.push(type);
    conditions.push(`t.type = $${values.length}`);
  }

  if (from) {
    values.push(from);
    conditions.push(`t.created_at >= $${values.length}`);
  }

  if (to) {
    values.push(to);
    conditions.push(`t.created_at <= $${values.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const countResult = await db.query(
    `SELECT COUNT(*)::int AS total
     FROM inventory_transactions t
     ${where}`,
    values,
  );

  const limitIndex = values.length + 1;
  const offsetIndex = values.length + 2;
  const dataResult = await db.query(
    `SELECT t.id, t.product_id, t.type, t.quantity, t.note, t.created_at,
            p.sku AS product_sku, p.name AS product_name
     FROM inventory_transactions t
     JOIN products p ON p.id = t.product_id
     ${where}
     ORDER BY t.created_at DESC, t.id DESC
     LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
    [...values, limit, offset],
  );

  return {
    rows: dataResult.rows,
    total: countResult.rows[0].total,
    page,
    limit,
  };
}
