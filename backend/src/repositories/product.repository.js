const PRODUCT_SELECT = `
  SELECT p.id, p.sku, p.name, p.category_id, p.description, p.unit_price,
         p.quantity, p.reorder_level, p.is_active, p.created_at, p.updated_at,
         c.name AS category_name
  FROM products p
  JOIN categories c ON c.id = p.category_id
`;

const SORT_COLUMNS = Object.freeze({
  createdAt: 'p.created_at',
  updatedAt: 'p.updated_at',
  name: 'p.name',
  sku: 'p.sku',
  unitPrice: 'p.unit_price',
  quantity: 'p.quantity',
});

export async function listProducts(
  db,
  { q, categoryId, page, limit, sort, order, offset },
) {
  const conditions = ['p.is_active = TRUE'];
  const values = [];

  if (q) {
    values.push(`%${q}%`);
    conditions.push(
      `(p.name ILIKE $${values.length} OR p.sku ILIKE $${values.length})`,
    );
  }

  if (categoryId !== undefined) {
    values.push(categoryId);
    conditions.push(`p.category_id = $${values.length}`);
  }

  const where = `WHERE ${conditions.join(' AND ')}`;
  const sortColumn = SORT_COLUMNS[sort] ?? SORT_COLUMNS.createdAt;
  const direction = order === 'asc' ? 'ASC' : 'DESC';

  const countResult = await db.query(
    `SELECT COUNT(*)::int AS total FROM products p ${where}`,
    values,
  );

  const limitIndex = values.length + 1;
  const offsetIndex = values.length + 2;
  const dataResult = await db.query(
    `${PRODUCT_SELECT}
     ${where}
     ORDER BY ${sortColumn} ${direction}, p.id DESC
     LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
    [...values, limit, offset],
  );

  return {
    rows: dataResult.rows,
    total: countResult.rows[0].total,
  };
}

export async function findActiveProductById(db, id) {
  const { rows } = await db.query(
    `${PRODUCT_SELECT} WHERE p.id = $1 AND p.is_active = TRUE`,
    [id],
  );
  return rows[0] ?? null;
}

export async function categoryExists(db, categoryId) {
  const { rowCount } = await db.query(
    'SELECT 1 FROM categories WHERE id = $1',
    [categoryId],
  );
  return rowCount > 0;
}

export async function createProduct(db, product) {
  const { rows } = await db.query(
    `INSERT INTO products
       (sku, name, category_id, description, unit_price, reorder_level)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [
      product.sku,
      product.name,
      product.categoryId,
      product.description,
      product.unitPrice,
      product.reorderLevel,
    ],
  );
  return rows[0];
}

export async function updateProduct(db, id, product) {
  const { rows } = await db.query(
    `UPDATE products
     SET sku = $1,
         name = $2,
         category_id = $3,
         description = $4,
         unit_price = $5,
         reorder_level = $6
     WHERE id = $7 AND is_active = TRUE
     RETURNING id`,
    [
      product.sku,
      product.name,
      product.categoryId,
      product.description,
      product.unitPrice,
      product.reorderLevel,
      id,
    ],
  );
  return rows[0] ?? null;
}

export async function softDeleteProduct(db, id) {
  const { rows } = await db.query(
    `UPDATE products
     SET is_active = FALSE
     WHERE id = $1 AND is_active = TRUE
     RETURNING id, sku`,
    [id],
  );
  return rows[0] ?? null;
}
