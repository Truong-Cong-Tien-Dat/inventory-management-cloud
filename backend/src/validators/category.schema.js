import { z } from 'zod';

export const createCategorySchema = z
  .object({
    name: z
      .string()
      .trim()
      .min(1, 'name is required')
      .max(100, 'name must be at most 100 characters'),
  })
  .strict();
