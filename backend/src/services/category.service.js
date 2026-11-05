import * as categoryRepository from '../repositories/category.repository.js';
import { toCategory } from '../utils/serializers.js';
import { categoryExists } from '../utils/errors.js';

export async function listCategories(db) {
  const rows = await categoryRepository.listCategories(db);
  return rows.map(toCategory);
}

export async function createCategory(db, { name }) {
  const existing = await categoryRepository.findCategoryByNameInsensitive(db, name);
  if (existing) {
    throw categoryExists();
  }

  let created;
  try {
    created = await categoryRepository.createCategory(db, name);
  } catch (error) {
    if (error.code === '23505') {
      throw categoryExists();
    }
    throw error;
  }

  return toCategory({ ...created, product_count: 0 });
}
