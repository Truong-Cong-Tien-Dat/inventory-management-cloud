export class AppError extends Error {
  constructor(statusCode, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    if (details !== undefined) this.details = details;
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

export function validationError(details, message = 'Request validation failed') {
  return new AppError(400, 'VALIDATION_ERROR', message, details);
}

export function routeNotFound(method, path) {
  return new AppError(404, 'ROUTE_NOT_FOUND', `Route ${method} ${path} was not found`);
}

export function productNotFound() {
  return new AppError(404, 'PRODUCT_NOT_FOUND', 'Product was not found');
}

export function categoryNotFound() {
  return new AppError(400, 'CATEGORY_NOT_FOUND', 'Category was not found');
}

export function duplicateSku() {
  return new AppError(409, 'DUPLICATE_SKU', 'SKU already exists');
}

export function categoryExists() {
  return new AppError(409, 'CATEGORY_EXISTS', 'Category name already exists');
}

export function insufficientStock(available, requested) {
  return new AppError(
    409,
    'INSUFFICIENT_STOCK',
    'Insufficient stock for this transaction',
    [
      {
        field: 'quantity',
        message: `Requested ${requested}, but only ${available} unit(s) are available`,
      },
    ],
  );
}

export function productInactive() {
  return new AppError(
    409,
    'PRODUCT_INACTIVE',
    'Inventory transactions are not allowed for inactive products',
  );
}

export function fieldNotEditable(fields) {
  return new AppError(
    400,
    'FIELD_NOT_EDITABLE',
    `Fields cannot be modified through this endpoint: ${fields.join(', ')}`,
    fields.map((field) => ({
      field,
      message:
        field === 'quantity'
          ? 'Use POST /api/inventory/transactions to change stock'
          : 'Use DELETE /api/products/:id to soft-delete a product',
    })),
  );
}

export function payloadTooLarge() {
  return new AppError(413, 'PAYLOAD_TOO_LARGE', 'Request body is too large');
}

export function dbUnavailable() {
  return new AppError(503, 'DB_UNAVAILABLE', 'Database is unavailable');
}

export function internalError() {
  return new AppError(500, 'INTERNAL_ERROR', 'An unexpected error occurred');
}
