import { getDashboardCounts } from '../repositories/dashboard.repository.js';
import { listTransactions } from '../repositories/inventory.repository.js';
import { toTransaction } from '../utils/serializers.js';

export async function getDashboardSummary(db) {
  const counts = await getDashboardCounts(db);
  const recent = await listTransactions(db, {
    page: 1,
    limit: 10,
    offset: 0,
  });

  return {
    totalActiveProducts: counts.total_active_products,
    totalUnitsInStock: counts.total_units_in_stock,
    lowStockProducts: counts.low_stock_products,
    outOfStockProducts: counts.out_of_stock_products,
    inventoryValue: Number(Number(counts.inventory_value).toFixed(2)),
    recentTransactions: recent.rows.map(toTransaction),
  };
}
