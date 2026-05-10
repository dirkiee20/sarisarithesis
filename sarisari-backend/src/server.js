require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth.routes');
const productsRoutes = require('./routes/products.routes');
const transactionsRoutes = require('./routes/transactions.routes');
const expensesRoutes = require('./routes/expenses.routes');
const stockAdjustmentsRoutes = require('./routes/stock-adjustments.routes');
const analyticsRoutes = require('./routes/analytics.routes');
const usersRoutes = require('./routes/users.routes');
const adminRoutes = require('./routes/admin.routes');
const summariesRoutes = require('./routes/summaries.routes');
const ensureSummarySchema = require('./database/ensure-summary-schema');

const { errorHandler } = require('./middleware/error.middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const SUMMARY_ONLY_MODE = process.env.SUMMARY_ONLY_MODE !== 'false';

const DEFAULT_ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost:4000',
  'http://localhost:5173',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3001',
  'http://127.0.0.1:4000',
  'http://127.0.0.1:5173',
];

const EXTRA_ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const ALLOWED_ORIGINS = new Set([
  ...DEFAULT_ALLOWED_ORIGINS,
  ...EXTRA_ALLOWED_ORIGINS,
]);

function isPrivateDevOrigin(origin) {
  if (process.env.NODE_ENV === 'production') return false;

  try {
    const { protocol, hostname, port } = new URL(origin);
    const allowedPort = ['3000', '3001', '4000', '5173'].includes(port);
    const isPrivateAddress =
      hostname === 'localhost' ||
      hostname === '127.0.0.1' ||
      /^192\.168\.\d{1,3}\.\d{1,3}$/.test(hostname) ||
      /^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname) ||
      /^172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}$/.test(hostname);

    return protocol === 'http:' && allowedPort && isPrivateAddress;
  } catch (_error) {
    return false;
  }
}

function isAllowedOrigin(origin) {
  return ALLOWED_ORIGINS.has(origin) || isPrivateDevOrigin(origin);
}

app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || isAllowedOrigin(origin)) {
        return callback(null, true);
      }

      return callback(new Error(`Origin ${origin} is not allowed by CORS`));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: { error: 'Too many requests, please try again later.' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many auth attempts, please try again later.' },
});

app.use('/api/', generalLimiter);
app.use('/api/auth/', authLimiter);
app.use('/api/admin/auth/', authLimiter);

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    app: 'Sarisari Pro API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/summaries', summariesRoutes);

function summaryOnlyBlocker(resourceName) {
  return (_req, res) => {
    res.status(410).json({
      error: `${resourceName} detail sync is disabled. Send aggregate summaries to /api/summaries/cashier instead.`,
      mode: 'summary_only',
    });
  };
}

if (SUMMARY_ONLY_MODE) {
  app.use('/api/products', summaryOnlyBlocker('Product'));
  app.use('/api/transactions', summaryOnlyBlocker('Transaction'));
  // Owner-entered operating expenses are not cashier detail sync, so keep them enabled.
  app.use('/api/expenses', expensesRoutes);
  app.use('/api/stock-adjustments', summaryOnlyBlocker('Stock adjustment'));
} else {
  app.use('/api/products', productsRoutes);
  app.use('/api/transactions', transactionsRoutes);
  app.use('/api/expenses', expensesRoutes);
  app.use('/api/stock-adjustments', stockAdjustmentsRoutes);
}

app.use('/api/analytics', analyticsRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/admin', adminRoutes);

app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

app.use(errorHandler);

async function startServer() {
  await ensureSummarySchema();

  app.listen(PORT, () => {
  console.log('');
  console.log('==========================================');
  console.log('      SARISARI PRO API SERVER');
  console.log('==========================================');
  console.log(`Running at: http://localhost:${PORT}`);
  console.log(`Health:     http://localhost:${PORT}/health`);
  console.log(`Data mode:  ${SUMMARY_ONLY_MODE ? 'summary-only' : 'legacy detail routes enabled'}`);
  console.log('Available endpoints:');
  console.log('  POST /api/auth/register');
  console.log('  POST /api/auth/login');
  console.log('  POST /api/summaries/cashier');
  console.log('  GET  /api/summaries/store');
  console.log('  GET  /api/analytics/overview');
  console.log('  POST /api/admin/auth/login');
  console.log('');
  });
}

if (require.main === module) {
  startServer().catch((err) => {
    console.error('Failed to start API server:', err);
    process.exit(1);
  });
}

module.exports = app;
