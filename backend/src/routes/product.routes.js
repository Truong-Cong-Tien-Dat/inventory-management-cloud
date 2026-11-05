import { Router } from 'express';
import {
  createProduct,
  deleteProduct,
  getProduct,
  listProducts,
  updateProduct,
} from '../controllers/product.controller.js';
import { asyncHandler } from '../middleware/async-handler.js';
import { rejectProductStockFields } from '../middleware/reject-stock-fields.js';
import { validate } from '../middleware/validate.js';
import { idParamSchema } from '../validators/common.schema.js';
import {
  productCreateSchema,
  productListQuerySchema,
  productUpdateSchema,
} from '../validators/product.schema.js';

const router = Router();

router.get(
  '/products',
  validate(productListQuerySchema, 'query'),
  asyncHandler(listProducts),
);

router.get(
  '/products/:id',
  validate(idParamSchema, 'params'),
  asyncHandler(getProduct),
);

router.post(
  '/products',
  rejectProductStockFields,
  validate(productCreateSchema),
  asyncHandler(createProduct),
);

router.put(
  '/products/:id',
  validate(idParamSchema, 'params'),
  rejectProductStockFields,
  validate(productUpdateSchema),
  asyncHandler(updateProduct),
);

router.delete(
  '/products/:id',
  validate(idParamSchema, 'params'),
  asyncHandler(deleteProduct),
);

export default router;
