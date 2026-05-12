const express = require('express');
const pool = require('../config/database');
const { authenticate, requireRole, requireTier } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const {
  SUMMARY_TOTALS_SQL,
  getDateRange: getSummaryDateRange,
  latestInventorySelect,
} = require('../services/summary.service');
const { getTenantAiInsights } = require('../services/ai-insights.service');

const router = express.Router();
router.use(authenticate);

// Helper: get date range
const getDateRange = (period) => {
  const now = new Date();
  let startDate;
  const endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

  switch (period?.toLowerCase()) {
    case 'today':
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      break;
    case 'week':
      startDate = new Date(now);
      const dow = now.getDay() || 7;
      startDate.setDate(now.getDate() - dow + 1);
      startDate.setHours(0, 0, 0, 0);
      break;
    case 'month':
      startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      break;
    case 'year':
      startDate = new Date(now.getFullYear(), 0, 1, 0, 0, 0);
      break;
    default:
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  }
  return { startDate, endDate };
};

// ── GET /api/analytics/overview ────────────────────────────────────────────
// Main KPI dashboard: revenue, profit, expenses, transactions
router.get(
  '/overview',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { period = 'today' } = req.query;
    const { startDate, endDate } = getSummaryDateRange(req.query);

    const [summaryResult, latestInventoryResult] = await Promise.all([
      pool.query(
        `${SUMMARY_TOTALS_SQL}
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3`,
        [req.tenantId, startDate, endDate]
      ),
      pool.query(
        `SELECT ${latestInventorySelect('latest_summary')}
         FROM cashier_daily_summaries latest_summary
         WHERE latest_summary.tenant_id = $1
           AND latest_summary.inventory_summary <> '{}'::jsonb
         ORDER BY latest_summary.summary_date DESC, latest_summary.received_at DESC
         LIMIT 1`,
        [req.tenantId]
      ),
    ]);

    const summary = summaryResult.rows[0];
    const inventory = latestInventoryResult.rows[0] || {};
    const revenue = Number(summary.total_revenue || 0);
    const grossProfit = Number(summary.gross_profit || 0);
    const businessExpenses = Number(summary.total_expenses || 0);
    const netProfit = grossProfit - businessExpenses;
    const profitMargin = revenue > 0 ? (grossProfit / revenue) * 100 : 0;

    res.json({
      period,
      kpis: {
        revenue,
        grossProfit,
        businessExpenses,
        netProfit,
        profitMarginPercent: parseFloat(profitMargin.toFixed(2)),
        transactionCount: Number(summary.transaction_count || 0),
        totalProducts: Number(inventory.product_count || 0),
        lowStockCount: Number(inventory.low_stock_count || 0),
      },
    });
  })
);

// ── GET /api/analytics/sales-trend ─────────────────────────────────────────
// Revenue/profit grouped by time for charts
router.get(
  '/sales-trend',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { period = 'week' } = req.query;
    const { startDate, endDate } = getSummaryDateRange(req.query);

    let dateFormat;
    switch (period.toLowerCase()) {
      case 'today':    dateFormat = 'HH24:00'; break;
      case 'week':     dateFormat = 'Dy'; break;
      case 'month':    dateFormat = 'DD Mon'; break;
      case 'year':     dateFormat = 'Mon YYYY'; break;
      default:         dateFormat = 'DD Mon';
    }

    const result = await pool.query(
      `SELECT
         TO_CHAR(summary_date::date, $1) AS label,
         COALESCE(SUM(net_revenue), 0) AS revenue,
         COALESCE(SUM(gross_profit), 0) AS profit,
         COALESCE(SUM(transaction_count), 0) AS transactions
       FROM cashier_daily_summaries
       WHERE tenant_id = $2 AND summary_date BETWEEN $3 AND $4
       GROUP BY TO_CHAR(summary_date::date, $1)
       ORDER BY MIN(summary_date)`,
      [dateFormat, req.tenantId, startDate, endDate]
    );

    res.json({ trend: result.rows, period });
  })
);

// ── GET /api/analytics/top-products ────────────────────────────────────────
router.get(
  '/top-products',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { period = 'month', limit = 10 } = req.query;
    const { startDate, endDate } = getSummaryDateRange(req.query);

    const result = await pool.query(
      `SELECT
         product_key AS product_id,
         MAX(product_name) AS product_name,
         MAX(category) AS category,
         COALESCE(SUM(units_sold), 0)::int AS total_quantity,
         COALESCE(SUM(sales_revenue), 0)::float AS total_revenue,
         COALESCE(SUM(gross_profit), 0)::float AS total_profit
       FROM cashier_product_summaries
       WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
       GROUP BY product_key
       ORDER BY total_revenue DESC, total_quantity DESC
       LIMIT $4`,
      [req.tenantId, startDate, endDate, parseInt(limit)]
    );

    res.json({
      topProducts: result.rows,
      period,
      privacy: {
        source: 'owner_redacted_product_summaries',
        excludedFields: ['barcode', 'image', 'customer', 'rawTransaction'],
      },
    });
  })
);

// ── GET /api/analytics/payment-methods ─────────────────────────────────────
router.get(
  '/payment-methods',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { period = 'month' } = req.query;
    const { startDate, endDate } = getSummaryDateRange(req.query);

    const result = await pool.query(
      `SELECT payment_method, transaction_count, total_amount
       FROM (
         SELECT 'cash' AS payment_method, 0::int AS transaction_count, COALESCE(SUM(cash_sales), 0)::float AS total_amount
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
         UNION ALL
         SELECT 'gcash', 0::int, COALESCE(SUM(gcash_sales), 0)::float
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
         UNION ALL
         SELECT 'credit', 0::int, COALESCE(SUM(credit_sales), 0)::float
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
         UNION ALL
         SELECT 'other', 0::int, COALESCE(SUM(other_payment_sales), 0)::float
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
       ) payment_totals
       WHERE total_amount > 0
       ORDER BY total_amount DESC`,
      [req.tenantId, startDate, endDate]
    );

    res.json({ paymentMethods: result.rows, period });
  })
);

// ── GET /api/analytics/expenses-by-category ────────────────────────────────
router.get(
  '/expenses-by-category',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { period = 'month' } = req.query;
    const { startDate, endDate } = getSummaryDateRange(req.query);

    const result = await pool.query(
      `SELECT
         category,
         SUM(total)::float AS total,
         COUNT(*)::int AS count
       FROM (
         SELECT
           entry.key AS category,
           COALESCE(NULLIF(entry.value, '')::numeric, 0) AS total
         FROM cashier_daily_summaries summaries
         CROSS JOIN LATERAL jsonb_each_text(summaries.expense_breakdown) entry
         WHERE summaries.tenant_id = $1
           AND summaries.summary_date BETWEEN $2 AND $3
       ) expense_rows
       GROUP BY category
       ORDER BY total DESC`,
      [req.tenantId, startDate, endDate]
    );

    if (result.rows.length > 0) {
      return res.json({ expensesByCategory: result.rows, period });
    }

    const fallback = await pool.query(
      `SELECT
         'General' AS category,
         COALESCE(SUM(expense_total), 0)::float AS total,
         COALESCE(SUM(expense_count), 0)::int AS count
       FROM cashier_daily_summaries
       WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
         AND expense_total > 0`,
      [req.tenantId, startDate, endDate]
    );

    res.json({
      expensesByCategory:
        Number(fallback.rows[0].total || 0) > 0 ? fallback.rows : [],
      period,
    });
  })
);

// ── GET /api/analytics/inventory-value ─────────────────────────────────────
router.get(
  '/inventory-value',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `SELECT
         ${latestInventorySelect('latest_summary')},
         latest_summary.inventory_summary,
         latest_summary.received_at
       FROM cashier_daily_summaries latest_summary
       WHERE latest_summary.tenant_id = $1
         AND latest_summary.inventory_summary <> '{}'::jsonb
       ORDER BY latest_summary.summary_date DESC, latest_summary.received_at DESC
       LIMIT 1`,
      [req.tenantId]
    );

    const latest = result.rows[0] || {};

    res.json({
      summary: {
        total_products: latest.product_count || 0,
        low_stock_count: latest.low_stock_count || 0,
        out_of_stock_count: latest.out_of_stock_count || 0,
        cost_value: latest.inventory_cost_value || 0,
        selling_value: latest.inventory_retail_value || 0,
        potential_profit:
          Number(latest.inventory_retail_value || 0) -
          Number(latest.inventory_cost_value || 0),
        latest_summary_at: latest.received_at || null,
      },
      byCategory: [],
      message: 'Inventory is represented as a store-level summary only.',
    });
  })
);

// ── GET /api/analytics/daily-breakdown ─────────────────────────────────────
// Daily sales for the past N days (for sparklines/mini-charts)
router.get(
  '/daily-breakdown',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const days = Math.min(parseInt(req.query.days) || 30, 90);

    const result = await pool.query(
      `SELECT
         summary_date AS date,
         COALESCE(SUM(net_revenue), 0) AS revenue,
         COALESCE(SUM(gross_profit), 0) AS profit,
         COALESCE(SUM(transaction_count), 0) AS transactions
       FROM cashier_daily_summaries
       WHERE tenant_id = $1
         AND summary_date >= (CURRENT_DATE - INTERVAL '${days} days')
       GROUP BY summary_date
       ORDER BY date ASC`,
      [req.tenantId]
    );

    res.json({ dailyBreakdown: result.rows, days });
  })
);

// ── GET /api/analytics/ai-insights ─────────────────────────────────────────
// AI-powered forecasting and restock recommendations
router.get(
  '/ai-insights',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const insights = await getTenantAiInsights(req.tenantId);
    res.json(insights);
  })
);

module.exports = router;
