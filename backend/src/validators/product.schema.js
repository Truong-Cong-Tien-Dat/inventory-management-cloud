import { z } from 'zod';
import {
  limitSchema,
  optionalTextSchema,
  pageSchema,
  positiveIdSchema,
} from './common.schema.js';

const skuSchema = z
  .string()
  .trim()
  .min(1, 'sku is required')
  .max(50, 'sku must be at most 50 characters')
  .transform((value) => value.toUpperCase())
  .refine(
    (value) => /^[A-Z0-9][A-Z0-9._-]*$/.test(value),
    'sku may contain only letters, digits, dot, underscore, and hyphen',
  );

const nameSchema = z
  .string()
  .trim()
  .min(1, 'name is required')
  .max(200, 'name must be at most 200 characters');

const unitPriceSchema = z.coerce
  .number()
  .finite('unitPrice must be a finite number')
  .min(0, 'unitPrice must be greater than or equal to 0')
  .max(9999999999.99, 'unitPrice is too large')
  .refine(
    (value) => Math.abs(value * 100 - Math.round(value * 100)) < 1e-6,
    'unitPrice must have at most 2 decimal places',
  );

const reorderLevelSchema = z.coerce
  .number()
  .int('reorderLevel must be an integer')
  .min(0, 'reorderLevel must be greater than or equal to 0')
  .max(1000000, 'reorderLevel is too large');

export const productCreateSchema = z
  .object({
    sku: skuSchema,
    name: nameSchema,
    categoryId: positiveIdSchema,
    description: optionalTextSchema(2000),
    unitPrice: unitPriceSchema,
    reorderLevel: reorderLevelSchema.default(5),
  })
  .strict();

export const productUpdateSchema = z
  .object({
    sku: skuSchema,
    name: nameSchema,
    categoryId: positiveIdSchema,
    description: optionalTextSchema(2000),
    unitPrice: unitPriceSchema,
    reorderLevel: reorderLevelSchema,
  })
  .strict();

export const productListQuerySchema = z
  .object({
    q: z
      .string()
      .trim()
      .max(100, 'q must be at most 100 characters')
      .optional()
      .transform((value) => (value ? value : undefined)),
    categoryId: positiveIdSchema.optional(),
    page: pageSchema,
    limit: limitSchema,
    sort: z
      .enum(['createdAt', 'updatedAt', 'name', 'sku', 'unitPrice', 'quantity'])
      .default('createdAt'),
    order: z.enum(['asc', 'desc']).default('desc'),
  })
  .strict();
