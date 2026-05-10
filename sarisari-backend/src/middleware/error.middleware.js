/**
 * Standard error response helper
 */
const errorHandler = (err, req, res, next) => {
  console.error(`[${new Date().toISOString()}] ERROR:`, err.stack || err.message);

  // Postgres duplicate key
  if (err.code === '23505') {
    const detail = err.detail || '';
    return res.status(409).json({
      error: 'Duplicate entry',
      detail,
    });
  }

  // Postgres foreign key violation
  if (err.code === '23503') {
    return res.status(400).json({
      error: 'Referenced record does not exist',
    });
  }

  // Postgres check violation
  if (err.code === '23514') {
    return res.status(400).json({ error: 'Invalid value for field' });
  }

  // Validation errors (express-validator)
  if (err.type === 'validation') {
    return res.status(422).json({ errors: err.errors });
  }

  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
  });
};

/**
 * Wrap async route handlers to catch errors
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = { errorHandler, asyncHandler };
