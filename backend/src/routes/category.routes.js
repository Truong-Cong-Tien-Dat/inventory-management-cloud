import { Router } from 'express';
import {
  createCategory,
  listCategories,
} from '../controllers/category.controller.js';
import { asyncHandler } from '../middleware/async-handler.js';
import { validate } from '../middleware/validate.js';
import { createCategorySchema } from '../validators/category.schema.js';

const router = Router();

router.get('/categories', asyncHandler(listCategories));
router.post(
  '/categories',
  validate(createCategorySchema),
  asyncHandler(createCategory),
);

export default router;
