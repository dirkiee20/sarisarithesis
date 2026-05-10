const pool = require('../config/database');

const FORECAST_HISTORY_DAYS = 90;
const FORECAST_HORIZON_DAYS = 30;
const FORECAST_MODEL_VERSION = 'adaptive-holt-v1';
const RECOMMENDATION_MODEL_VERSION = 'stock-motion-v1';

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function toNumber(value) {
  return Number(value || 0);
}

function round(value, decimals = 2) {
  return Number(toNumber(value).toFixed(decimals));
}

function mean(values) {
  if (!values.length) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function standardDeviation(values) {
  if (!values.length) return 0;
  const average = mean(values);
  const variance =
    values.reduce((sum, value) => sum + Math.pow(value - average, 2), 0) / values.length;
  return Math.sqrt(variance);
}

function startOfUtcDay(date = new Date()) {
  const next = new Date(date);
  next.setUTCHours(0, 0, 0, 0);
  return next;
}

function addUtcDays(date, days) {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function toDateKey(value) {
  if (!value) return '';
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(
    date.getUTCDate()
  ).padStart(2, '0')}`;
}

function fromDateKey(key) {
  const [year, month, day] = key.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function formatDateLabel(key) {
  return fromDateKey(key).toLocaleDateString('en-PH', {
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  });
}

function buildDailySeries(rows, totalDays, valueKey) {
  const valueByDate = new Map(
    rows.map((row) => [toDateKey(row.date), toNumber(row[valueKey])])
  );

  const end = startOfUtcDay(new Date());
  const series = [];

  for (let offset = totalDays - 1; offset >= 0; offset -= 1) {
    const cursor = addUtcDays(end, -offset);
    const key = toDateKey(cursor);
    series.push({
      date: key,
      label: formatDateLabel(key),
      value: toNumber(valueByDate.get(key)),
    });
  }

  return series;
}

function calculateSeasonality(series) {
  if (series.length < 14) {
    return Array(7).fill(1);
  }

  const baseline = mean(series.map((entry) => entry.value));
  if (baseline <= 0) {
    return Array(7).fill(1);
  }

  const buckets = Array.from({ length: 7 }, () => ({ sum: 0, count: 0 }));

  series.slice(-56).forEach((entry) => {
    const dayOfWeek = fromDateKey(entry.date).getUTCDay();
    buckets[dayOfWeek].sum += entry.value / baseline;
    buckets[dayOfWeek].count += 1;
  });

  const rawFactors = buckets.map((bucket) =>
    bucket.count > 0 ? bucket.sum / bucket.count : 1
  );
  const normalizer = mean(rawFactors) || 1;

  return rawFactors.map((factor) => factor / normalizer);
}

function buildMovingAverageForecast(values, horizon) {
  const recent = values.slice(-Math.min(values.length, 14));
  const weightedTotal = recent.reduce((sum, value, index) => sum + value * (index + 1), 0);
  const totalWeight = recent.reduce((sum, _value, index) => sum + index + 1, 0);
  const average = totalWeight > 0 ? weightedTotal / totalWeight : 0;

  return Array.from({ length: horizon }, () => average);
}

function buildHoltForecast(values, horizon, alpha = 0.38, beta = 0.2) {
  if (!values.length) {
    return Array.from({ length: horizon }, () => 0);
  }

  if (values.length < 7) {
    return buildMovingAverageForecast(values, horizon);
  }

  let level = values[0];
  let trend = values.length > 1 ? values[1] - values[0] : 0;

  for (let index = 1; index < values.length; index += 1) {
    const observed = values[index];
    const previousLevel = level;
    level = alpha * observed + (1 - alpha) * (level + trend);
    trend = beta * (level - previousLevel) + (1 - beta) * trend;
  }

  return Array.from({ length: horizon }, (_, index) => Math.max(0, level + (index + 1) * trend));
}

function computeConfidence(values) {
  const populatedDays = values.filter((value) => value > 0).length;
  if (!values.length || populatedDays === 0) {
    return 0.2;
  }

  const historyScore = Math.min(1, values.length / FORECAST_HISTORY_DAYS);
  const coverageScore = populatedDays / values.length;
  const average = mean(values);
  const volatility = average > 0 ? standardDeviation(values) / average : 1.5;

  const confidence =
    0.34 +
    coverageScore * 0.34 +
    historyScore * 0.2 -
    Math.min(0.24, volatility * 0.12);

  return clamp(round(confidence, 2), 0.18, 0.94);
}

function getForecastSignal(deltaPercent30d) {
  if (deltaPercent30d >= 8) return 'growth';
  if (deltaPercent30d <= -8) return 'softening';
  return 'stable';
}

function buildRevenueForecast(rows, label) {
  const historicalSeries = buildDailySeries(rows, FORECAST_HISTORY_DAYS, 'revenue');
  const historicalValues = historicalSeries.map((entry) => entry.value);
  const baseForecast = buildHoltForecast(historicalValues, FORECAST_HORIZON_DAYS);
  const seasonalFactors = calculateSeasonality(historicalSeries);
  const averageRevenue = mean(historicalValues);
  const volatility = averageRevenue > 0 ? standardDeviation(historicalValues) / averageRevenue : 1.2;
  const confidence = computeConfidence(historicalValues);
  const uncertaintyBand = clamp(0.14 + volatility * 0.2, 0.16, 0.42);
  const lastHistoricalDate = fromDateKey(historicalSeries[historicalSeries.length - 1].date);

  const forecastSeries = baseForecast.map((baselineValue, index) => {
    const forecastDate = addUtcDays(lastHistoricalDate, index + 1);
    const key = toDateKey(forecastDate);
    const factor = seasonalFactors[forecastDate.getUTCDay()] || 1;
    const predictedRevenue = Math.max(0, baselineValue * factor);

    return {
      date: key,
      label: formatDateLabel(key),
      predictedRevenue: round(predictedRevenue),
      lowerBound: round(predictedRevenue * (1 - uncertaintyBand)),
      upperBound: round(predictedRevenue * (1 + uncertaintyBand)),
    };
  });

  const recent30 = historicalSeries.slice(-30).reduce((sum, entry) => sum + entry.value, 0);
  const recent7 = historicalSeries.slice(-7).reduce((sum, entry) => sum + entry.value, 0);
  const predicted30 = forecastSeries.reduce((sum, entry) => sum + entry.predictedRevenue, 0);
  const predicted7 = forecastSeries.slice(0, 7).reduce((sum, entry) => sum + entry.predictedRevenue, 0);
  const deltaPercent30d = recent30 > 0 ? ((predicted30 - recent30) / recent30) * 100 : predicted30 > 0 ? 100 : 0;
  const peakForecast = forecastSeries.reduce(
    (best, entry) => (entry.predictedRevenue > best.predictedRevenue ? entry : best),
    forecastSeries[0] || { date: null, predictedRevenue: 0 }
  );

  return {
    modelVersion: FORECAST_MODEL_VERSION,
    label,
    signal: getForecastSignal(deltaPercent30d),
    confidence,
    historicalSeries: historicalSeries.slice(-30).map((entry) => ({
      date: entry.date,
      label: entry.label,
      revenue: round(entry.value),
    })),
    forecastSeries,
    summary: {
      actualRevenue30d: round(recent30),
      actualRevenue7d: round(recent7),
      predictedRevenue30d: round(predicted30),
      predictedRevenue7d: round(predicted7),
      deltaPercent30d: round(deltaPercent30d, 1),
      averageDailyRevenue30d: round(recent30 / 30),
      peakForecastDate: peakForecast.date,
      peakForecastRevenue: round(peakForecast.predictedRevenue),
      daysOfHistory: historicalSeries.length,
      populatedDays: historicalValues.filter((value) => value > 0).length,
    },
  };
}

function buildRestockPriority(actionType, daysUntilStockout, currentStock) {
  if (actionType === 'overstock_risk' || actionType === 'slow_moving') {
    return currentStock > 25 ? 'medium' : 'low';
  }

  if (currentStock <= 0) return 'critical';
  if (daysUntilStockout <= 2) return 'critical';
  if (daysUntilStockout <= 5) return 'high';
  if (daysUntilStockout <= 10) return 'medium';
  return 'low';
}

function buildRestockMessage({
  actionType,
  businessName,
  productName,
  dailyDemand,
  daysUntilStockout,
  stockCoverageDays,
  suggestedOrderQuantity,
  optimalRestockDate,
}) {
  if (actionType === 'overstock_risk') {
    return `${productName} at ${businessName} already covers about ${round(
      stockCoverageDays,
      1
    )} days of demand. Delay the next purchase and let sell-through reduce excess stock.`;
  }

  if (actionType === 'slow_moving') {
    return `${productName} at ${businessName} has little recent movement. Avoid replenishing until demand improves.`;
  }

  if (actionType === 'restock_now') {
    return `${productName} at ${businessName} is projected to run out in ${Math.max(
      0,
      Math.ceil(daysUntilStockout)
    )} days. Order ${suggestedOrderQuantity} units now to keep pace with ${round(
      dailyDemand,
      2
    )} units/day demand.`;
  }

  return `${productName} at ${businessName} should be reordered by ${optimalRestockDate} to avoid dipping below the safety stock threshold.`;
}

function buildRestockRecommendation(row) {
  const currentStock = toNumber(row.stock);
  const sold7d = toNumber(row.sold_7d);
  const sold30d = toNumber(row.sold_30d);
  const sold60d = toNumber(row.sold_60d);
  const avgRestockQty = toNumber(row.avg_restock_qty);
  const activeSalesDays30d = toNumber(row.active_sales_days_30d);

  const demand7d = sold7d / 7;
  const demand30d = sold30d / 30;
  const demand60d = sold60d / 60;
  const dailyDemand = round(demand7d * 0.5 + demand30d * 0.35 + demand60d * 0.15, 2);
  const demandTrend = demand30d > 0 ? (demand7d - demand30d) / demand30d : demand7d > 0 ? 1 : 0;
  const safetyDays =
    dailyDemand > 0
      ? clamp(Math.round(3 + Math.abs(demandTrend) * 4 + (activeSalesDays30d >= 18 ? 1 : 0)), 3, 8)
      : 0;

  let targetCoverageDays = 45;
  if (dailyDemand >= 5) targetCoverageDays = 14;
  else if (dailyDemand >= 2) targetCoverageDays = 21;
  else if (dailyDemand > 0) targetCoverageDays = 30;

  const stockCoverageDays = dailyDemand > 0 ? currentStock / dailyDemand : null;
  const daysUntilStockout = stockCoverageDays;

  let suggestedOrderQuantity =
    dailyDemand > 0 ? Math.max(0, Math.ceil(dailyDemand * targetCoverageDays - currentStock)) : 0;

  if (suggestedOrderQuantity > 0 && avgRestockQty > 0) {
    const minimumUsefulOrder = Math.ceil(dailyDemand * Math.max(7, safetyDays));
    const historicalCap = Math.ceil(Math.max(avgRestockQty * 1.6, minimumUsefulOrder));
    suggestedOrderQuantity = clamp(
      suggestedOrderQuantity,
      Math.max(1, minimumUsefulOrder),
      Math.max(historicalCap, minimumUsefulOrder)
    );
  }

  let actionType = 'healthy';
  if (dailyDemand > 0 && currentStock <= 0) {
    actionType = 'restock_now';
  } else if (dailyDemand > 0 && daysUntilStockout <= safetyDays) {
    actionType = 'restock_now';
  } else if (dailyDemand > 0 && daysUntilStockout <= safetyDays + 7) {
    actionType = 'restock_soon';
  } else if (dailyDemand > 0 && stockCoverageDays > targetCoverageDays * 1.8 && currentStock > sold30d * 1.4) {
    actionType = 'overstock_risk';
    suggestedOrderQuantity = 0;
  } else if (dailyDemand === 0 && currentStock >= Math.max(10, avgRestockQty || 10)) {
    actionType = 'slow_moving';
  } else if (dailyDemand > 0 && suggestedOrderQuantity > 0) {
    actionType = 'restock_soon';
  }

  const optimalRestockInDays =
    actionType === 'restock_now'
      ? 0
      : actionType === 'restock_soon' && daysUntilStockout !== null
        ? Math.max(0, Math.floor(daysUntilStockout - safetyDays))
        : null;

  const optimalRestockDate =
    optimalRestockInDays !== null ? toDateKey(addUtcDays(startOfUtcDay(new Date()), optimalRestockInDays)) : null;

  const priority = buildRestockPriority(actionType, daysUntilStockout ?? 999, currentStock);
  const confidence = clamp(
    round(0.34 + Math.min(1, activeSalesDays30d / 20) * 0.34 + Math.min(1, sold60d / 120) * 0.26, 2),
    0.18,
    0.94
  );

  return {
    productId: row.product_id,
    tenantId: row.tenant_id,
    businessName: row.business_name,
    productName: row.product_name,
    category: row.category,
    currentStock,
    sold7d,
    sold30d,
    sold60d,
    dailyDemand,
    stockCoverageDays: stockCoverageDays === null ? null : round(stockCoverageDays, 1),
    daysUntilStockout: daysUntilStockout === null ? null : round(daysUntilStockout, 1),
    safetyDays,
    targetCoverageDays,
    suggestedOrderQuantity,
    optimalRestockDate,
    optimalRestockInDays,
    priority,
    actionType,
    confidence,
    modelVersion: RECOMMENDATION_MODEL_VERSION,
    message: buildRestockMessage({
      actionType,
      businessName: row.business_name,
      productName: row.product_name,
      dailyDemand,
      daysUntilStockout,
      stockCoverageDays,
      suggestedOrderQuantity,
      optimalRestockDate,
    }),
  };
}

function sortRecommendations(left, right) {
  const priorityWeight = { critical: 0, high: 1, medium: 2, low: 3 };
  const leftPriority = priorityWeight[left.priority] ?? 4;
  const rightPriority = priorityWeight[right.priority] ?? 4;

  if (leftPriority !== rightPriority) {
    return leftPriority - rightPriority;
  }

  const leftStockout = left.daysUntilStockout ?? Number.MAX_SAFE_INTEGER;
  const rightStockout = right.daysUntilStockout ?? Number.MAX_SAFE_INTEGER;

  if (leftStockout !== rightStockout) {
    return leftStockout - rightStockout;
  }

  return right.dailyDemand - left.dailyDemand;
}

async function loadRevenueRows(tenantId) {
  const params = [];
  let filter = '';

  if (tenantId) {
    params.push(tenantId);
    filter = 'AND tenant_id = $1';
  }

  const result = await pool.query(
    `SELECT DATE(transaction_date) AS date, COALESCE(SUM(total_amount), 0) AS revenue
     FROM transactions
     WHERE transaction_date >= NOW() - INTERVAL '${FORECAST_HISTORY_DAYS} days'
       ${filter}
     GROUP BY DATE(transaction_date)
     ORDER BY date ASC`,
    params
  );

  return result.rows;
}

async function loadInventorySignals(tenantId) {
  const params = [];
  const tenantFilter = tenantId ? 'AND p.tenant_id = $1' : '';

  if (tenantId) {
    params.push(tenantId);
  }

  const result = await pool.query(
    `WITH sales AS (
       SELECT
         t.tenant_id,
         ti.product_id,
         COALESCE(SUM(CASE WHEN t.transaction_date >= NOW() - INTERVAL '7 days' THEN ti.quantity ELSE 0 END), 0) AS sold_7d,
         COALESCE(SUM(CASE WHEN t.transaction_date >= NOW() - INTERVAL '30 days' THEN ti.quantity ELSE 0 END), 0) AS sold_30d,
         COALESCE(SUM(CASE WHEN t.transaction_date >= NOW() - INTERVAL '60 days' THEN ti.quantity ELSE 0 END), 0) AS sold_60d,
         COUNT(DISTINCT CASE WHEN t.transaction_date >= NOW() - INTERVAL '30 days' THEN DATE(t.transaction_date) END) AS active_sales_days_30d
       FROM transaction_items ti
       JOIN transactions t ON t.id = ti.transaction_id
       ${tenantId ? 'WHERE t.tenant_id = $1' : ''}
       GROUP BY t.tenant_id, ti.product_id
     ),
     restocks AS (
       SELECT
         sa.tenant_id,
         sa.product_id,
         COALESCE(AVG(CASE WHEN sa.adjustment > 0 THEN sa.adjustment END), 0) AS avg_restock_qty,
         COALESCE(SUM(CASE WHEN sa.adjustment > 0 AND sa.adjusted_at >= NOW() - INTERVAL '90 days' THEN sa.adjustment ELSE 0 END), 0) AS restocked_90d,
         COUNT(*) FILTER (WHERE sa.adjustment > 0 AND sa.adjusted_at >= NOW() - INTERVAL '180 days') AS restock_events_180d,
         MAX(sa.adjusted_at) FILTER (WHERE sa.adjustment > 0) AS last_restocked_at
       FROM stock_adjustments sa
       ${tenantId ? 'WHERE sa.tenant_id = $1' : ''}
       GROUP BY sa.tenant_id, sa.product_id
     )
     SELECT
       p.id AS product_id,
       p.tenant_id,
       p.name AS product_name,
       p.category,
       p.stock,
       t.business_name,
       COALESCE(s.sold_7d, 0) AS sold_7d,
       COALESCE(s.sold_30d, 0) AS sold_30d,
       COALESCE(s.sold_60d, 0) AS sold_60d,
       COALESCE(s.active_sales_days_30d, 0) AS active_sales_days_30d,
       COALESCE(r.avg_restock_qty, 0) AS avg_restock_qty,
       COALESCE(r.restocked_90d, 0) AS restocked_90d,
       COALESCE(r.restock_events_180d, 0) AS restock_events_180d,
       r.last_restocked_at
     FROM products p
     JOIN tenants t ON t.id = p.tenant_id
     LEFT JOIN sales s ON s.tenant_id = p.tenant_id AND s.product_id = p.id
     LEFT JOIN restocks r ON r.tenant_id = p.tenant_id AND r.product_id = p.id
     WHERE p.is_active = TRUE
       ${tenantFilter}
     ORDER BY p.stock ASC, p.name ASC`,
    params
  );

  return result.rows;
}

function summarizeRecommendations(recommendations, totalProducts) {
  return {
    totalProducts,
    actionable: recommendations.length,
    critical: recommendations.filter((entry) => entry.priority === 'critical').length,
    high: recommendations.filter((entry) => entry.priority === 'high').length,
    medium: recommendations.filter((entry) => entry.priority === 'medium').length,
    low: recommendations.filter((entry) => entry.priority === 'low').length,
    stockoutRisk: recommendations.filter((entry) => entry.actionType === 'restock_now').length,
    plannedRestocks: recommendations.filter((entry) => entry.actionType === 'restock_soon').length,
    overstockRisk: recommendations.filter((entry) => ['overstock_risk', 'slow_moving'].includes(entry.actionType)).length,
    healthy: Math.max(totalProducts - recommendations.length, 0),
  };
}

async function getRestockInsights(tenantId, limit = 8) {
  const rawSignals = await loadInventorySignals(tenantId);
  const generated = rawSignals.map(buildRestockRecommendation);
  const actionable = generated
    .filter((entry) => entry.actionType !== 'healthy')
    .sort(sortRecommendations);

  return {
    modelVersion: RECOMMENDATION_MODEL_VERSION,
    summary: summarizeRecommendations(actionable, rawSignals.length),
    recommendations: actionable.slice(0, limit),
  };
}

async function getTenantPerformanceSignals(limit = 6) {
  const result = await pool.query(
    `SELECT
       t.id,
       t.business_name,
       t.subscription_tier,
       t.subscription_status,
       COALESCE(SUM(CASE WHEN tx.transaction_date >= NOW() - INTERVAL '7 days' THEN tx.total_amount ELSE 0 END), 0) AS revenue_7d,
       COALESCE(SUM(CASE WHEN tx.transaction_date >= NOW() - INTERVAL '30 days' THEN tx.total_amount ELSE 0 END), 0) AS revenue_30d,
       COUNT(CASE WHEN tx.transaction_date >= NOW() - INTERVAL '30 days' THEN 1 END) AS transactions_30d
     FROM tenants t
     LEFT JOIN transactions tx
       ON tx.tenant_id = t.id
       AND tx.transaction_date >= NOW() - INTERVAL '30 days'
     GROUP BY t.id, t.business_name, t.subscription_tier, t.subscription_status
     HAVING COALESCE(SUM(CASE WHEN tx.transaction_date >= NOW() - INTERVAL '30 days' THEN tx.total_amount ELSE 0 END), 0) > 0
     ORDER BY revenue_30d DESC
     LIMIT 24`
  );

  return result.rows
    .map((row) => {
      const revenue7d = toNumber(row.revenue_7d);
      const revenue30d = toNumber(row.revenue_30d);
      const currentVelocity = revenue7d / 7;
      const baselineVelocity = revenue30d / 30;
      const projectedRevenue30d = currentVelocity * 12 + baselineVelocity * 18;
      const deltaPercent =
        baselineVelocity > 0 ? ((currentVelocity - baselineVelocity) / baselineVelocity) * 100 : 0;

      return {
        tenantId: row.id,
        businessName: row.business_name,
        subscriptionTier: row.subscription_tier,
        subscriptionStatus: row.subscription_status,
        revenue7d: round(revenue7d),
        revenue30d: round(revenue30d),
        projectedRevenue30d: round(projectedRevenue30d),
        deltaPercent30d: round(deltaPercent, 1),
        transactions30d: toNumber(row.transactions_30d),
        signal: getForecastSignal(deltaPercent),
      };
    })
    .sort((left, right) => right.projectedRevenue30d - left.projectedRevenue30d)
    .slice(0, limit);
}

async function getTenantAiInsights(tenantId) {
  const [revenueRows, restockInsights] = await Promise.all([
    loadRevenueRows(tenantId),
    getRestockInsights(tenantId, 8),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    forecast: buildRevenueForecast(revenueRows, 'Tenant revenue'),
    restock: restockInsights,
  };
}

async function getAdminAiOverview() {
  const [revenueRows, restockInsights, tenantSignals] = await Promise.all([
    loadRevenueRows(null),
    getRestockInsights(null, 10),
    getTenantPerformanceSignals(6),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    forecast: buildRevenueForecast(revenueRows, 'Platform revenue'),
    restock: restockInsights,
    tenantSignals,
  };
}

module.exports = {
  getAdminAiOverview,
  getTenantAiInsights,
};
