import { AppError } from '../utils/errors.js';

const LOCALHOST_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function buildCorsOptions(config) {
  return {
    origin(origin, callback) {
      // Same-origin requests and non-browser clients (curl) send no Origin.
      if (!origin) return callback(null, true);

      if (config.allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      // Development convenience: allow any localhost port.
      if (!config.isProduction && LOCALHOST_ORIGIN.test(origin)) {
        return callback(null, true);
      }

      return callback(
        new AppError(403, 'CORS_ORIGIN_DENIED', 'Origin is not allowed'),
      );
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Accept'],
    exposedHeaders: ['Location'],
    credentials: false,
    maxAge: 86400,
    optionsSuccessStatus: 204,
  };
}
