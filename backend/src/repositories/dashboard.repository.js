export async function getDashboardCounts(db) {
  const { rows } = await db.query(`
    SELECT
      (COUNT(*) FILTER (WHERE is_active))::int AS total_active_products,
      (COALESCE(SUM(quantity) FILTER (WHERE is_active), 0))::int AS total_units_in_stock,
      (COUNT(*) FILTER (
        WHERE is_active AND quantity > 0 AND quantity <= reorder_level
      ))::int AS low_stock_products,
      (COUNT(*) FILTER (
        WHERE is_active AND quantity = 0
      ))::int AS out_of_stock_products,
      COALESCE(SUM(quantity * unit_price) FILTER (WHERE is_active), 0) AS inventory_value
    FROM products
  `);
  return rows[0];
}
