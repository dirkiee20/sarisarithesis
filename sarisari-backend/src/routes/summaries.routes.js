const express = require('express');
const pool = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const {
  SUMMARY_TOTALS_SQL,
  getDateRange,
  latestInventorySelect,
  normalizeSummaryPayload,
} = require('../services/summary.service');

const router = express.Router();
router.use(authenticate);

router.post(
  '/cashier',
  requireRole('owner', 'manager', 'staff', 'cashier'),
  asyncHandler(async (req, res) => {
    const summary = normalizeSummaryPayload(req.body || {}, req.user);
    const client = await pool.connect();

    let result;
    try {
      await client.query('BEGIN');
      result = await client.query(
        `
        INSERT INTO cashier_daily_summaries (
          tenant_id,
          cashier_user_id,
          cashier_key,
          cashier_name,
          device_id,
          summary_date,
          period_start,
          period_end,
          currency,
          transaction_count,
          items_sold_count,
          gross_revenue,
          net_revenue,
          total_cost,
          gross_profit,
          expense_total,
          expense_count,
          discount_total,
          refund_total,
          cash_sales,
          gcash_sales,
          credit_sales,
          other_payment_sales,
          payment_breakdown,
          expense_breakdown,
          inventory_summary,
          metadata,
          client_batch_id,
          received_at
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8,
          $9, $10, $11, $12, $13, $14, $15,
          $16, $17, $18, $19, $20, $21, $22,
          $23, $24, $25, $26, $27, $28, NOW()
        )
        ON CONFLICT (tenant_id, cashier_key, summary_date)
        DO UPDATE SET
          cashier_user_id = EXCLUDED.cashier_user_id,
          cashier_name = EXCLUDED.cashier_name,
          device_id = EXCLUDED.device_id,
          period_start = EXCLUDED.period_start,
          period_end = EXCLUDED.period_end,
          currency = EXCLUDED.currency,
          transaction_count = EXCLUDED.transaction_count,
          items_sold_count = EXCLUDED.items_sold_count,
          gross_revenue = EXCLUDED.gross_revenue,
          net_revenue = EXCLUDED.net_revenue,
          total_cost = EXCLUDED.total_cost,
          gross_profit = EXCLUDED.gross_profit,
          expense_total = EXCLUDED.expense_total,
          expense_count = EXCLUDED.expense_count,
          discount_total = EXCLUDED.discount_total,
          refund_total = EXCLUDED.refund_total,
          cash_sales = EXCLUDED.cash_sales,
          gcash_sales = EXCLUDED.gcash_sales,
          credit_sales = EXCLUDED.credit_sales,
          other_payment_sales = EXCLUDED.other_payment_sales,
          payment_breakdown = EXCLUDED.payment_breakdown,
          expense_breakdown = EXCLUDED.expense_breakdown,
          inventory_summary = EXCLUDED.inventory_summary,
          metadata = EXCLUDED.metadata,
          client_batch_id = EXCLUDED.client_batch_id,
          received_at = NOW(),
          updated_at = NOW()
        RETURNING
          id,
          tenant_id,
          cashier_user_id,
          cashier_key,
          cashier_name,
          device_id,
          summary_date,
          transaction_count,
          items_sold_count,
          gross_revenue,
          net_revenue,
          total_cost,
          gross_profit,
          expense_total,
          expense_count,
          received_at
        `,
        [
          req.tenantId,
          summary.cashierUserId,
          summary.cashierKey,
          summary.cashierName,
          summary.deviceId,
          summary.summaryDate,
          summary.periodStart,
          summary.periodEnd,
          summary.currency,
          summary.transactionCount,
          summary.itemsSoldCount,
          summary.grossRevenue,
          summary.netRevenue,
          summary.totalCost,
          summary.grossProfit,
          summary.expenseTotal,
          summary.expenseCount,
          summary.discountTotal,
          summary.refundTotal,
          summary.cashSales,
          summary.gcashSales,
          summary.creditSales,
          summary.otherPaymentSales,
          summary.paymentBreakdown,
          summary.expenseBreakdown,
          summary.inventorySummary,
          summary.metadata,
          summary.clientBatchId,
        ]
      );

      const summaryId = result.rows[0].id;
      await client.query(
        'DELETE FROM cashier_product_summaries WHERE cashier_summary_id = $1',
        [summaryId]
      );

      for (const product of summary.productSummaries) {
        await client.query(
          `INSERT INTO cashier_product_summaries (
             tenant_id,
             cashier_summary_id,
             cashier_user_id,
             cashier_key,
             summary_date,
             product_key,
             product_name,
             category,
             stock_on_hand,
             low_stock_threshold,
             units_sold,
             sales_revenue,
             gross_profit,
             selling_price,
             last_sold_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8,
             $9, $10, $11, $12, $13, $14, $15
           )`,
          [
            req.tenantId,
            summaryId,
            summary.cashierUserId,
            summary.cashierKey,
            summary.summaryDate,
            product.productKey,
            product.productName,
            product.category,
            product.stockOnHand,
            product.lowStockThreshold,
            product.unitsSold,
            product.salesRevenue,
            product.grossProfit,
            product.sellingPrice,
            product.lastSoldAt,
          ]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    res.status(201).json({
      message: 'Summary received',
      summary: result.rows[0],
      productSummaryCount: summary.productSummaries.length,
      privacy: {
        stored: 'summary_and_owner_product_summaries',
        rejectedDetails: [
          'barcodes',
          'images',
          'customers',
          'rawLineItems',
          'rawTransactions',
        ],
      },
    });
  })
);

router.get(
  '/store',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { startDate, endDate } = getDateRange(req.query);

    const [totalsResult, dailyResult, latestInventoryResult] = await Promise.all([
      pool.query(
        `${SUMMARY_TOTALS_SQL}
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3`,
        [req.tenantId, startDate, endDate]
      ),
      pool.query(
        `SELECT
           summary_date AS date,
           COALESCE(SUM(transaction_count), 0)::int AS transaction_count,
           COALESCE(SUM(items_sold_count), 0)::int AS items_sold_count,
           COALESCE(SUM(net_revenue), 0)::float AS revenue,
           COALESCE(SUM(gross_profit), 0)::float AS gross_profit,
           COALESCE(SUM(expense_total), 0)::float AS expenses,
           MAX(received_at) AS latest_summary_at
         FROM cashier_daily_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
         GROUP BY summary_date
         ORDER BY summary_date ASC`,
        [req.tenantId, startDate, endDate]
      ),
      pool.query(
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
      ),
    ]);

    const totals = totalsResult.rows[0];
    const inventory = latestInventoryResult.rows[0] || {};

    res.json({
      period: { startDate, endDate },
      summary: {
        ...totals,
        net_income: Number(totals.gross_profit || 0) - Number(totals.total_expenses || 0),
        inventory,
      },
      daily: dailyResult.rows,
    });
  })
);

router.get(
  '/cashiers',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { startDate, endDate } = getDateRange(req.query);

    const result = await pool.query(
      `SELECT
         cashier_key,
         cashier_user_id,
         COALESCE(MAX(cashier_name), 'Unknown cashier') AS cashier_name,
         COALESCE(SUM(transaction_count), 0)::int AS transaction_count,
         COALESCE(SUM(items_sold_count), 0)::int AS items_sold_count,
         COALESCE(SUM(net_revenue), 0)::float AS total_revenue,
         COALESCE(SUM(gross_profit), 0)::float AS gross_profit,
         COALESCE(SUM(expense_total), 0)::float AS total_expenses,
         COUNT(*)::int AS summary_count,
         MAX(received_at) AS latest_summary_at
       FROM cashier_daily_summaries
       WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
       GROUP BY cashier_key, cashier_user_id
       ORDER BY total_revenue DESC, latest_summary_at DESC`,
      [req.tenantId, startDate, endDate]
    );

    res.json({
      period: { startDate, endDate },
      cashiers: result.rows,
    });
  })
);

router.get(
  '/expenses',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { startDate, endDate } = getDateRange(req.query);
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);

    const [summaryTotalsResult, manualTotalsResult, expensesResult] = await Promise.all([
      pool.query(
        `SELECT
           COALESCE(SUM(CASE WHEN summary_date = CURRENT_DATE THEN expense_total ELSE 0 END), 0)::float AS today_total,
           COALESCE(SUM(CASE
             WHEN summary_date >= (CURRENT_DATE - ((EXTRACT(ISODOW FROM CURRENT_DATE)::int - 1) * INTERVAL '1 day'))::date
             THEN expense_total ELSE 0
           END), 0)::float AS week_total,
           COALESCE(SUM(CASE
             WHEN summary_date >= DATE_TRUNC('month', CURRENT_DATE)::date
             THEN expense_total ELSE 0
           END), 0)::float AS month_total
         FROM cashier_daily_summaries
         WHERE tenant_id = $1`,
        [req.tenantId]
      ),
      pool.query(
        `SELECT
           COALESCE(SUM(CASE WHEN expense_date::date = CURRENT_DATE THEN amount ELSE 0 END), 0)::float AS today_total,
           COALESCE(SUM(CASE
             WHEN expense_date::date >= (CURRENT_DATE - ((EXTRACT(ISODOW FROM CURRENT_DATE)::int - 1) * INTERVAL '1 day'))::date
             THEN amount ELSE 0
           END), 0)::float AS week_total,
           COALESCE(SUM(CASE
             WHEN expense_date::date >= DATE_TRUNC('month', CURRENT_DATE)::date
             THEN amount ELSE 0
           END), 0)::float AS month_total
         FROM expenses
         WHERE tenant_id = $1`,
        [req.tenantId]
      ),
      pool.query(
        `WITH expense_rows AS (
           SELECT
             summaries.summary_date,
             entry.key AS category,
             NULL::text AS title,
             COALESCE(NULLIF(entry.value, '')::numeric, 0) AS amount,
             1::int AS expense_count,
             summaries.received_at,
             'cashier_summary'::text AS source
           FROM cashier_daily_summaries summaries
           CROSS JOIN LATERAL jsonb_each_text(summaries.expense_breakdown) entry
           WHERE summaries.tenant_id = $1
             AND summaries.summary_date BETWEEN $2 AND $3
             AND COALESCE(NULLIF(entry.value, '')::numeric, 0) > 0

           UNION ALL

           SELECT
             summary_date,
             'General' AS category,
             NULL::text AS title,
             expense_total::numeric AS amount,
             GREATEST(expense_count, 1)::int AS expense_count,
             received_at,
             'cashier_summary'::text AS source
           FROM cashier_daily_summaries
           WHERE tenant_id = $1
             AND summary_date BETWEEN $2 AND $3
             AND expense_total > 0
             AND expense_breakdown = '{}'::jsonb

           UNION ALL

           SELECT
             expense_date::date AS summary_date,
             COALESCE(category, 'General') AS category,
             title,
             amount::numeric AS amount,
             1::int AS expense_count,
             created_at AS received_at,
             'manual_expense'::text AS source
           FROM expenses
           WHERE tenant_id = $1
             AND expense_date::date BETWEEN $2 AND $3
         )
         SELECT
           summary_date AS date,
           category,
           title,
           source,
           COALESCE(SUM(amount), 0)::float AS amount,
           COALESCE(SUM(expense_count), 0)::int AS count,
           MAX(received_at) AS latest_summary_at
         FROM expense_rows
         GROUP BY source, summary_date, category, title
         ORDER BY summary_date DESC, latest_summary_at DESC, amount DESC, category ASC
         LIMIT $4`,
        [req.tenantId, startDate, endDate, limit]
      ),
    ]);
    const summaryTotals = summaryTotalsResult.rows[0] || {};
    const manualTotals = manualTotalsResult.rows[0] || {};
    const totals = {
      today_total: Number(summaryTotals.today_total || 0) + Number(manualTotals.today_total || 0),
      week_total: Number(summaryTotals.week_total || 0) + Number(manualTotals.week_total || 0),
      month_total: Number(summaryTotals.month_total || 0) + Number(manualTotals.month_total || 0),
    };

    res.json({
      period: { startDate, endDate },
      totals,
      expenses: expensesResult.rows,
      privacy: {
        source: 'cashier_daily_summary_expense_breakdown_and_owner_expenses',
        excludedFields: ['receipt', 'vendor', 'rawExpenseRecord'],
      },
    });
  })
);

router.get(
  '/products',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { startDate, endDate } = getDateRange(req.query);
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);

    const result = await pool.query(
      `WITH filtered AS (
         SELECT *
         FROM cashier_product_summaries
         WHERE tenant_id = $1 AND summary_date BETWEEN $2 AND $3
       ),
       totals AS (
         SELECT
           product_key,
           MAX(product_name) AS product_name,
           MAX(category) AS category,
           COALESCE(SUM(units_sold), 0)::int AS units_sold,
           COALESCE(SUM(sales_revenue), 0)::float AS sales_revenue,
           COALESCE(SUM(gross_profit), 0)::float AS gross_profit,
           COUNT(DISTINCT cashier_summary_id)::int AS reporting_days
         FROM filtered
         GROUP BY product_key
       ),
       latest AS (
         SELECT DISTINCT ON (product_key)
           product_key,
           product_name,
           category,
           stock_on_hand,
           low_stock_threshold,
           selling_price,
           summary_date AS latest_summary_date,
           created_at AS latest_synced_at
         FROM filtered
         ORDER BY product_key, summary_date DESC, created_at DESC
       )
       SELECT
         totals.product_key,
         COALESCE(latest.product_name, totals.product_name) AS product_name,
         COALESCE(latest.category, totals.category) AS category,
         COALESCE(latest.stock_on_hand, 0)::int AS stock_on_hand,
         COALESCE(latest.low_stock_threshold, 0)::int AS low_stock_threshold,
         COALESCE(latest.selling_price, 0)::float AS selling_price,
         totals.units_sold,
         totals.sales_revenue,
         totals.gross_profit,
         totals.reporting_days,
         latest.latest_summary_date,
         latest.latest_synced_at
       FROM totals
       LEFT JOIN latest ON latest.product_key = totals.product_key
       ORDER BY totals.sales_revenue DESC, totals.units_sold DESC, product_name ASC
       LIMIT $4`,
      [req.tenantId, startDate, endDate, limit]
    );

    res.json({
      period: { startDate, endDate },
      products: result.rows,
      privacy: {
        stored: 'owner_redacted_product_summaries',
        excludedFields: ['barcode', 'image', 'customer', 'rawTransaction'],
      },
    });
  })
);

module.exports = router;
