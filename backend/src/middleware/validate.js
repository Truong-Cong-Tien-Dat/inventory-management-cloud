import { validationError } from '../utils/errors.js';

export function formatZodIssues(error) {
  return error.issues.map((issue) => ({
    field: issue.path.length > 0 ? issue.path.join('.') : 'body',
    message: issue.message,
  }));
}

export function validate(schema, source = 'body') {
  return function validateRequest(req, res, next) {
    const input =
      source === 'query'
        ? req.query
        : source === 'params'
          ? req.params
          : req.body;

    const result = schema.safeParse(input);
    if (!result.success) {
      return next(validationError(formatZodIssues(result.error)));
    }

    if (source === 'body') {
      req.body = result.data;
    } else if (source === 'params') {
      req.validatedParams = result.data;
    } else {
      req.validatedQuery = result.data;
    }

    return next();
  };
}
