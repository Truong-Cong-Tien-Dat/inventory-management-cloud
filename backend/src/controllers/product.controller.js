import * as productService from '../services/product.service.js';

export async function listProducts(req, res) {
  const result = await productService.listProducts(
    req.app.locals.pool,
    req.validatedQuery,
  );
  res.json(result);
}

export async function getProduct(req, res) {
  const data = await productService.getProduct(
    req.app.locals.pool,
    req.validatedParams.id,
  );
  res.json({ data });
}

export async function createProduct(req, res) {
  const data = await productService.createProduct(
    req.app.locals.pool,
    req.body,
  );
  res.status(201).location(`/api/products/${data.id}`).json({ data });
}

export async function updateProduct(req, res) {
  const data = await productService.updateProduct(
    req.app.locals.pool,
    req.validatedParams.id,
    req.body,
  );
  res.json({ data });
}

export async function deleteProduct(req, res) {
  const data = await productService.softDeleteProduct(
    req.app.locals.pool,
    req.validatedParams.id,
  );
  res.json({ data });
}
