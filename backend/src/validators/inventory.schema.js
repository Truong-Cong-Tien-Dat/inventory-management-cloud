import { z } from 'zod';
import {
  limitSchema,
  optionalTextSchema,
  pageSchema,
  positiveIdSchema,
} from './common.schema.js';

export const createTransactionSchema = z
  .object({
    productId: positiveIdSchema,
    type: z.enum(['IN', 'OUT'], {
      message: 'type must be either IN or OUT',
    }),
    quantity: z.coerce
      .number()
      .int('quantity must be an integer')
      .min(1, 'quantity must be at least 1')
      .max(1000000, 'quantity is too large'),
    note: optionalTextSchema(500),
  })
  .strict();

export const transactionListQuerySchema = z
  .object({
    productId: positiveIdSchema.optional(),
    type: z
      .enum(['IN', 'OUT'], {
        message: 'type must be either IN or OUT',
      })
      .optional(),
    from: z.coerce.date().optional(),
    to: z.coerce.date().optional(),
    page: pageSchema,
    limit: limitSchema,
  })
  .strict()
  .refine(
    (data) => !data.from || !data.to || data.from.getTime() <= data.to.getTime(),
    {
      message: 'from must be before or equal to to',
      path: ['from'],
    },
  );
