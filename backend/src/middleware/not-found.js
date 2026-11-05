import { routeNotFound } from '../utils/errors.js';

export function notFound(req, res, next) {
  next(routeNotFound(req.method, req.originalUrl));
}
