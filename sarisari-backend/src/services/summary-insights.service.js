const pool = require('../config/database');

function toNumber(value) {
  return Number(value || 0);
}

function formatDate(date) {
  return date.toISOString().slice(0, 10);
}

function formatLabel(date) {
  return date.toLocaleDateString('en-US', { month: 'short', day: '2-digit' });
}

function buildForecast(historicalRows) {
  const historicalSeries = historicalRows.map((row) => ({
    date: row.date,
    label: row.label,
    revenue: toNumber(row.revenue),
  }));

  const populatedDays = historicalSeries.filter((entry) => entry.revenue > 0).length;
  const totalRevenue30d = historicalSeries.reduce(
    (sum, entry) => sum + entry.revenue,
    0
  );
  const averageDailyRevenue =
    populatedDays > 0 ? totalRevenue30d / populatedDays : 0;

  const last7 = historicalSeries
    .slice(-7)
    .reduce((sum, entry) => sum + entry.revenue, 0);
  const previous7 = historicalSeries
    .slice(-14, -7)
    .reduce((sum, entry) => sum + entry.revenue, 0);
  const deltaPercent30d =
    previous7 > 0 ? ((last7 - previous7) / previous7) * 100 : 0;

  const forecastSeries = [];
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  for (let index = 0; index < 30; index += 1) {
    const date = new Date(tomorrow);
    date.setDate(tomorrow.getDate() + index);
    forecastSeries.push({
      date: formatDate(date),
      label: formatLabel(date),
      predictedRevenue: Number(averageDailyRevenue.toFixed(2)),
    });
  }

  return {
    historicalSeries,
    forecastSeries,
    signal:
      deltaPercent30d > 10
        ? 'growth'
        : deltaPercent30d < -10
          ? 'softening'
          : 'stable',
    confidence: populatedDays >= 14 ? 0.72 : populatedDays >= 7 ? 0.58 : 0.35,
    summary: {
      populatedDays,
      predictedRevenue7d: Number((averageDailyRevenue * 7).toFixed(2)),
      predictedRevenue30d: Number((averageDailyRevenue * 30).toFixed(2)),
      deltaPercent30d: Number(deltaPercent30d.toFixed(1)),
      peakForecastDate:
        forecastSeries.length > 0 ? forecastSeries[0].date : null,
    },
  };
}

async function loadHistoricalSeries(tenantId = null) {
  const params = [];
  let tenantFilter = '';
  if (tenantId) {
    params.push(tenantId);
    tenantFilter = 'AND tenant_id = $1';
  }

  const result = await pool.query(
    `SELECT
       sale_date::text AS date,
       TO_CHAR(sale_date, 'Mon DD') AS label,
       COALESCE(SUM(total_revenue), 0)::float AS revenue
     FROM v_daily_sales
     WHERE sale_date >= CURRENT_DATE - INTERVAL '30 days'
       ${tenantFilter}
     GROUP BY sale_date
     ORDER BY sale_date ASC`,
    params
  );

  return result.rows;
}

async function loadInventorySummary(tenantId = null) {
  const params = [];
  let tenantFilter = '';
  if (tenantId) {
    params.push(tenantId);
    tenantFilter = 'WHERE tenant_id = $1';
  }

  const result = await pool.query(
    `WITH latest AS (
       SELECT DISTINCT ON (tenant_id)
         tenant_id,
         inventory_summary
       FROM cashier_daily_summaries
       WHERE inventory_summary <> '{}'::jsonb
       ORDER BY tenant_id, summary_date DESC, received_at DESC
     )
     SELECT
       COALESCE(SUM(COALESCE(NULLIF(inventory_summary->>'productCount', '')::int,
                            NULLIF(inventory_summary->>'totalProducts', '')::int,
                            0)), 0)::int AS total_products,
       COALESCE(SUM(COALESCE(NULLIF(inventory_summary->>'lowStockCount', '')::int,
                            NULLIF(inventory_summary->>'lowStockProducts', '')::int,
                            0)), 0)::int AS low_stock_count,
       COALESCE(SUM(COALESCE(NULLIF(inventory_summary->>'outOfStockCount', '')::int,
                            0)), 0)::int AS out_of_stock_count
     FROM latest
     ${tenantFilter}`,
    params
  );

  const row = result.rows[0] || {};
  const stockoutRisk = Number(row.low_stock_count || 0) + Number(row.out_of_stock_count || 0);

  return {
    recommendations: [],
    summary: {
      totalProducts: Number(row.total_products || 0),
      actionable: stockoutRisk,
      stockoutRisk,
      plannedRestocks: 0,
      critical: Number(row.out_of_stock_count || 0),
      high: Number(row.low_stock_count || 0),
      overstockRisk: 0,
    },
    message: 'Summary-only mode does not collect product-level restocking details.',
  };
}

async function getTenantSignals(limit = 6) {
  const result = await pool.query(
    `SELECT
       t.id AS "tenantId",
       t.business_name AS "businessName",
       t.subscription_tier AS "subscriptionTier",
       t.subscription_status AS "subscriptionStatus",
       COALESCE(SUM(cds.net_revenue), 0)::float AS "totalRevenue30d",
       COALESCE(SUM(cds.net_revenue), 0)::float AS "projectedRevenue30d",
       COALESCE(SUM(cds.transaction_count), 0)::int AS "transactions30d"
     FROM tenants t
     LEFT JOIN cashier_daily_summaries cds
       ON cds.tenant_id = t.id
      AND cds.summary_date >= CURRENT_DATE - INTERVAL '30 days'
     GROUP BY t.id, t.business_name, t.subscription_tier, t.subscription_status
     ORDER BY "totalRevenue30d" DESC, "transactions30d" DESC
     LIMIT $1`,
    [limit]
  );

  return result.rows;
}

async function getAdminSummaryInsights() {
  const [historicalRows, restock, tenantSignals] = await Promise.all([
    loadHistoricalSeries(),
    loadInventorySummary(),
    getTenantSignals(6),
  ]);

  return {
    mode: 'summary_only',
    forecast: buildForecast(historicalRows),
    restock,
    tenantSignals,
  };
}

async function getTenantSummaryInsights(tenantId) {
  const [historicalRows, restock] = await Promise.all([
    loadHistoricalSeries(tenantId),
    loadInventorySummary(tenantId),
  ]);

  return {
    mode: 'summary_only',
    forecast: buildForecast(historicalRows),
    restock,
  };
}

module.exports = {
  getAdminSummaryInsights,
  getTenantSummaryInsights,
};
