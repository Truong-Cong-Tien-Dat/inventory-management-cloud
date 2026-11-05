import * as inventoryService from '../services/inventory.service.js';

export async function createTransaction(req, res) {
  const data = await inventoryService.createStockTransaction(
    req.app.locals.pool,
    req.body,
  );
  res.status(201).json({ data });
}

export async function listTransactions(req, res) {
  const result = await inventoryService.listTransactions(
    req.app.locals.pool,
    req.validatedQuery,
  );
  res.json(result);
}
