import { fieldNotEditable } from '../utils/errors.js';

export function rejectProductStockFields(req, res, next) {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return next();
  }

  const forbidden = ['quantity', 'isActive', 'is_active'].filter((field) =>
    Object.prototype.hasOwnProperty.call(req.body, field),
  );

  if (forbidden.length > 0) {
    return next(fieldNotEditable(forbidden));
  }

  return next();
}
