export async function listCategories(db) {
  const { rows } = await db.query(`
    SELECT c.id, c.name, c.created_at,
           (COUNT(p.id) FILTER (WHERE p.is_active))::int AS product_count
    FROM categories c
    LEFT JOIN products p ON p.category_id = c.id
    GROUP BY c.id
    ORDER BY c.name ASC
  `);
  return rows;
}

export async function findCategoryById(db, id) {
  const { rows } = await db.query(
    'SELECT id, name, created_at FROM categories WHERE id = $1',
    [id],
  );
  return rows[0] ?? null;
}

export async function findCategoryByNameInsensitive(db, name) {
  const { rows } = await db.query(
    'SELECT id, name, created_at FROM categories WHERE LOWER(name) = LOWER($1)',
    [name],
  );
  return rows[0] ?? null;
}

export async function createCategory(db, name) {
  const { rows } = await db.query(
    `INSERT INTO categories (name)
     VALUES ($1)
     RETURNING id, name, created_at`,
    [name],
  );
  return rows[0];
}
