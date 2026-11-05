import { z } from 'zod';

export const MAX_ID = Number.MAX_SAFE_INTEGER;

export const positiveIdSchema = z.coerce
  .number()
  .int('must be an integer')
  .positive('must be greater than 0')
  .max(MAX_ID, 'is too large');

export const idParamSchema = z
  .object({
    id: positiveIdSchema,
  })
  .strict();

export const pageSchema = z.coerce
  .number()
  .int('page must be an integer')
  .min(1, 'page must be at least 1')
  .default(1);

export const limitSchema = z.coerce
  .number()
  .int('limit must be an integer')
  .min(1, 'limit must be at least 1')
  .max(100, 'limit must be at most 100')
  .default(20);

export function optionalTextSchema(maxLength) {
  return z
    .preprocess(
      (value) =>
        typeof value === 'string' && value.trim() === '' ? null : value,
      z.string().trim().max(maxLength).nullable().optional(),
    )
    .transform((value) => value ?? null);
}
