import { ZodError } from 'zod';
import { AppError } from '../utils/errors.js';
import { formatZodIssues } from './validate.js';

const DB_CONNECTION_CODES = new Set([
  'ECONNREFUSED',
  'ECONNRESET',
  'ENOTFOUND',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'ENETUNREACH',
  '08000',
  '08003',
  '08006',
  '08001',
  '08004',
  '57P01',
  '57P02',
  '57P03',
  '53300',
]);

function isDatabaseConnectionError(error) {
  if (DB_CONNECTION_CODES.has(error.code)) return true;

  if (Array.isArray(error.errors)) {
    return error.errors.some((item) => DB_CONNECTION_CODES.has(item.code));
  }

  return false;
}

function normalizeError(error) {
  if (error instanceof AppError) {
    return {
      statusCode: error.statusCode,
      code: error.code,
      message: error.message,
      details: error.details,
    };
  }

  if (error instanceof ZodError) {
    return {
      statusCode: 400,
      code: 'VALIDATION_ERROR',
      message: 'Request validation failed',
      details: formatZodIssues(error),
    };
  }

  if (error?.type === 'entity.parse.failed') {
    return {
      statusCode: 400,
      code: 'VALIDATION_ERROR',
      message: 'Malformed JSON body',
    };
  }

  if (error?.type === 'entity.too.large') {
    return {
      statusCode: 413,
      code: 'PAYLOAD_TOO_LARGE',
      message: 'Request body is too large',
    };
  }

  if (error?.code === '23505') {
    return {
      statusCode: 409,
      code: 'CONFLICT',
      message: 'A record with the same unique value already exists',
    };
  }

  if (error?.code === '23503') {
    return {
      statusCode: 400,
      code: 'INVALID_REFERENCE',
      message: 'A referenced record does not exist',
    };
  }

  if (error?.code === '23514') {
    return {
      statusCode: 400,
      code: 'VALIDATION_ERROR',
      message: 'A database constraint was violated',
    };
  }

  if (isDatabaseConnectionError(error)) {
    return {
      statusCode: 503,
      code: 'DB_UNAVAILABLE',
      message: 'Database is unavailable',
    };
  }

  return {
    statusCode: 500,
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
  };
}

export function errorHandler(error, req, res, next) {
  if (res.headersSent) {
    return next(error);
  }

  const normalized = normalizeError(error);

  // Log server-side only. Never log request bodies, headers, or credentials.
  if (normalized.statusCode >= 500) {
    console.error(
      `[error] ${req.method} ${req.originalUrl} -> ${normalized.statusCode} ${normalized.code}`,
      error,
    );
  }

  const payload = {
    error: {
      code: normalized.code,
      message: normalized.message,
    },
  };

  if (normalized.details !== undefined) {
    payload.error.details = normalized.details;
  }

  return res.status(normalized.statusCode).json(payload);
}
