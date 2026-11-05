import { Router } from 'express';
import {
  createTransaction,
  listTransactions,
} from '../controllers/inventory.controller.js';
import { asyncHandler } from '../middleware/async-handler.js';
import { validate } from '../middleware/validate.js';
import {
  createTransactionSchema,
  transactionListQuerySchema,
} from '../validators/inventory.schema.js';

const router = Router();

router.post(
  '/inventory/transactions',
  validate(createTransactionSchema),
  asyncHandler(createTransaction),
);

router.get(
  '/inventory/transactions',
  validate(transactionListQuerySchema, 'query'),
  asyncHandler(listTransactions),
);

export default router;
