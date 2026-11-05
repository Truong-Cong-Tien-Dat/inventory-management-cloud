import * as categoryService from '../services/category.service.js';

export async function listCategories(req, res) {
  const data = await categoryService.listCategories(req.app.locals.pool);
  res.json({ data });
}

export async function createCategory(req, res) {
  const data = await categoryService.createCategory(
    req.app.locals.pool,
    req.body,
  );
  res.status(201).location(`/api/categories/${data.id}`).json({ data });
}
