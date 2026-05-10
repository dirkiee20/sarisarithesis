const DETAIL_KEYS = new Set([
  'barcode',
  'barcodes',
  'cartitems',
  'cart_items',
  'customer',
  'customercontact',
  'customer_contact',
  'customername',
  'customer_name',
  'customers',
  'item',
  'items',
  'lineitems',
  'line_items',
  'product',
  'productid',
  'product_id',
  'productname',
  'product_name',
  'products',
  'sku',
  'transaction',
  'transactionitems',
  'transaction_items',
  'transactions',
]);

function normalizeKey(key) {
  return String(key).replace(/[^a-zA-Z0-9_]/g, '').toLowerCase();
}

function findDetailedPayloadKeys(value, path = []) {
  if (value === null || typeof value !== 'object') return [];

  if (Array.isArray(value)) {
    return value.flatMap((item, index) =>
      findDetailedPayloadKeys(item, [...path, String(index)])
    );
  }

  const violations = [];
  for (const [key, nested] of Object.entries(value)) {
    const normalized = normalizeKey(key);
    const nextPath = [...path, key];
    if (DETAIL_KEYS.has(normalized)) {
      violations.push(nextPath.join('.'));
      continue;
    }
    violations.push(...findDetailedPayloadKeys(nested, nextPath));
  }
  return violations;
}

function assertSummaryOnlyPayload(payload) {
  const violations = findDetailedPayloadKeys(payload);
  if (violations.length > 0) {
    const unique = [...new Set(violations)].slice(0, 8);
    const error = new Error(
      `Summary sync cannot include product, item, barcode, or customer details: ${unique.join(', ')}`
    );
    error.statusCode = 400;
    throw error;
  }
}

function toNumber(value, fallback = 0) {
  if (value === null || value === undefined || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toNonNegativeNumber(value, fallback = 0) {
  return Math.max(0, toNumber(value, fallback));
}

function toNonNegativeInt(value, fallback = 0) {
  return Math.max(0, Math.trunc(toNumber(value, fallback)));
}

function toDateOnly(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) {
    const error = new Error('Invalid summaryDate');
    error.statusCode = 400;
    throw error;
  }
  return date.toISOString().slice(0, 10);
}

function toOptionalDate(value, fieldName) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    const error = new Error(`Invalid ${fieldName}`);
    error.statusCode = 400;
    throw error;
  }
  return date.toISOString();
}

function cleanObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
}

function cleanString(value, maxLength = 255) {
  if (value === null || value === undefined) return null;
  const cleaned = String(value).replace(/[\u0000-\u001F\u007F]/g, '').trim();
  if (!cleaned) return null;
  return cleaned.slice(0, maxLength);
}

function amountFromPayment(paymentBreakdown, key) {
  const value = paymentBreakdown?.[key];
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return toNonNegativeNumber(value.amount);
  }
  return toNonNegativeNumber(value);
}

function knownPaymentTotal(paymentBreakdown) {
  return ['cash', 'gcash', 'credit'].reduce(
    (sum, key) => sum + amountFromPayment(paymentBreakdown, key),
    0
  );
}

const PRODUCT_SUMMARY_KEYS = new Set([
  'category',
  'currentstock',
  'grossprofit',
  'lastsoldat',
  'lowstockthreshold',
  'name',
  'productkey',
  'productname',
  'quantitysold',
  'reorderlevel',
  'revenue',
  'salesquantity',
  'salesrevenue',
  'sellingprice',
  'sold',
  'stock',
  'stockonhand',
  'unitssold',
]);

function assertAllowedProductSummary(entry, index) {
  if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
    const error = new Error(`productSummaries[${index}] must be an object`);
    error.statusCode = 400;
    throw error;
  }

  const blocked = [];
  const unsupported = [];
  for (const key of Object.keys(entry)) {
    const normalized = normalizeKey(key);
    if (
      normalized.includes('barcode') ||
      normalized.includes('image') ||
      normalized.includes('photo') ||
      normalized.includes('customer') ||
      normalized === 'id' ||
      normalized === 'productid' ||
      normalized === 'product_id'
    ) {
      blocked.push(key);
    } else if (!PRODUCT_SUMMARY_KEYS.has(normalized)) {
      unsupported.push(key);
    }
  }

  if (blocked.length > 0 || unsupported.length > 0) {
    const error = new Error(
      `productSummaries[${index}] contains unsupported fields: ${[
        ...blocked,
        ...unsupported,
      ].join(', ')}`
    );
    error.statusCode = 400;
    throw error;
  }
}

function normalizeProductSummaries(payload = {}) {
  const raw = payload.productSummaries ?? payload.ownerProductSummaries ?? [];
  if (!raw) return [];

  if (!Array.isArray(raw)) {
    const error = new Error('productSummaries must be an array');
    error.statusCode = 400;
    throw error;
  }

  if (raw.length > 1000) {
    const error = new Error('productSummaries cannot contain more than 1000 rows');
    error.statusCode = 400;
    throw error;
  }

  return raw.map((entry, index) => {
    assertAllowedProductSummary(entry, index);

    const productName = cleanString(entry.productName ?? entry.name, 160);
    if (!productName) {
      const error = new Error(`productSummaries[${index}] requires productName`);
      error.statusCode = 400;
      throw error;
    }

    const category = cleanString(entry.category, 120);
    const productKey =
      cleanString(entry.productKey, 180) ||
      `${productName}|${category || ''}`.toLowerCase();

    return {
      productKey,
      productName,
      category,
      stockOnHand: toNonNegativeInt(
        entry.stockOnHand ?? entry.currentStock ?? entry.stock
      ),
      lowStockThreshold: toNonNegativeInt(
        entry.lowStockThreshold ?? entry.reorderLevel
      ),
      unitsSold: toNonNegativeInt(
        entry.unitsSold ??
          entry.quantitySold ??
          entry.salesQuantity ??
          entry.sold
      ),
      salesRevenue: toNonNegativeNumber(
        entry.salesRevenue ?? entry.revenue
      ),
      grossProfit: toNumber(entry.grossProfit),
      sellingPrice: toNonNegativeNumber(entry.sellingPrice),
      lastSoldAt: toOptionalDate(entry.lastSoldAt, `productSummaries[${index}].lastSoldAt`),
    };
  });
}

function normalizeSummaryPayload(payload, user) {
  const input = payload || {};
  const { productSummaries, ownerProductSummaries, ...summaryOnlyPayload } =
    input;
  assertSummaryOnlyPayload(summaryOnlyPayload);

  const sales = cleanObject(input.sales);
  const expenses = cleanObject(input.expenses);
  const inventory = cleanObject(input.inventory || input.inventorySummary);
  const paymentBreakdown = cleanObject(
    input.paymentBreakdown || input.payments || sales.paymentBreakdown
  );
  const expenseBreakdown = cleanObject(
    input.expenseBreakdown || expenses.byCategory || expenses.breakdown
  );

  const discountTotal = toNonNegativeNumber(
    sales.discountTotal ?? input.discountTotal
  );
  const refundTotal = toNonNegativeNumber(sales.refundTotal ?? input.refundTotal);
  const grossRevenue = toNonNegativeNumber(
    sales.grossRevenue ?? sales.revenue ?? input.grossRevenue ?? input.revenue
  );
  const netRevenue = toNonNegativeNumber(
    sales.netRevenue ?? input.netRevenue,
    Math.max(0, grossRevenue - discountTotal - refundTotal)
  );
  const totalCost = toNonNegativeNumber(sales.totalCost ?? input.totalCost);
  const grossProfit = toNumber(
    sales.grossProfit ?? input.grossProfit,
    netRevenue - totalCost
  );

  const cashSales = amountFromPayment(paymentBreakdown, 'cash');
  const gcashSales = amountFromPayment(paymentBreakdown, 'gcash');
  const creditSales = amountFromPayment(paymentBreakdown, 'credit');
  const otherPaymentSales = Math.max(0, netRevenue - knownPaymentTotal(paymentBreakdown));

  const deviceId = input.deviceId ? String(input.deviceId).slice(0, 120) : null;
  const cashierKey = deviceId || String(user.id);

  return {
    cashierUserId: user.id,
    cashierKey,
    cashierName: user.full_name || null,
    deviceId,
    summaryDate: toDateOnly(input.summaryDate || input.date),
    periodStart: toOptionalDate(input.periodStart, 'periodStart'),
    periodEnd: toOptionalDate(input.periodEnd, 'periodEnd'),
    currency: String(input.currency || 'PHP').slice(0, 8).toUpperCase(),
    transactionCount: toNonNegativeInt(
      sales.transactionCount ?? input.transactionCount
    ),
    itemsSoldCount: toNonNegativeInt(
      sales.itemsSoldCount ?? sales.itemsSold ?? input.itemsSoldCount
    ),
    grossRevenue,
    netRevenue,
    totalCost,
    grossProfit,
    expenseTotal: toNonNegativeNumber(
      expenses.total ?? expenses.amount ?? input.expenseTotal
    ),
    expenseCount: toNonNegativeInt(expenses.count ?? input.expenseCount),
    discountTotal,
    refundTotal,
    cashSales,
    gcashSales,
    creditSales,
    otherPaymentSales,
    paymentBreakdown,
    expenseBreakdown,
    inventorySummary: inventory,
    metadata: cleanObject(input.metadata),
    clientBatchId: input.clientBatchId
      ? String(input.clientBatchId).slice(0, 160)
      : null,
    productSummaries: normalizeProductSummaries({
      productSummaries: productSummaries ?? ownerProductSummaries,
    }),
  };
}

function getDateRange(query = {}) {
  if (query.startDate || query.endDate) {
    const start = query.startDate ? toDateOnly(query.startDate) : '1970-01-01';
    const end = query.endDate ? toDateOnly(query.endDate) : toDateOnly(new Date());
    return { startDate: start, endDate: end };
  }

  const now = new Date();
  const end = toDateOnly(now);
  const startDate = new Date(now);

  switch (String(query.period || 'today').toLowerCase()) {
    case 'week': {
      const day = startDate.getDay() || 7;
      startDate.setDate(startDate.getDate() - day + 1);
      break;
    }
    case 'month':
      startDate.setDate(1);
      break;
    case 'year':
      startDate.setMonth(0, 1);
      break;
    case 'all':
      return { startDate: '1970-01-01', endDate: end };
    case 'today':
    default:
      break;
  }

  return { startDate: toDateOnly(startDate), endDate: end };
}

const SUMMARY_TOTALS_SQL = `
  SELECT
    COALESCE(SUM(transaction_count), 0)::int AS transaction_count,
    COALESCE(SUM(items_sold_count), 0)::int AS items_sold_count,
    COALESCE(SUM(gross_revenue), 0)::float AS gross_revenue,
    COALESCE(SUM(net_revenue), 0)::float AS total_revenue,
    COALESCE(SUM(total_cost), 0)::float AS total_cost,
    COALESCE(SUM(gross_profit), 0)::float AS gross_profit,
    COALESCE(SUM(expense_total), 0)::float AS total_expenses,
    COALESCE(SUM(expense_count), 0)::int AS expense_count,
    COALESCE(SUM(discount_total), 0)::float AS discount_total,
    COALESCE(SUM(refund_total), 0)::float AS refund_total,
    COALESCE(SUM(cash_sales), 0)::float AS cash_sales,
    COALESCE(SUM(gcash_sales), 0)::float AS gcash_sales,
    COALESCE(SUM(credit_sales), 0)::float AS credit_sales,
    COALESCE(SUM(other_payment_sales), 0)::float AS other_payment_sales,
    COUNT(DISTINCT cashier_key)::int AS reporting_cashiers,
    COUNT(*)::int AS summary_count,
    MAX(received_at) AS latest_summary_at
`;

function latestInventorySelect(alias = 'latest_summary') {
  return `
    COALESCE(NULLIF(${alias}.inventory_summary->>'productCount', '')::int,
             NULLIF(${alias}.inventory_summary->>'totalProducts', '')::int,
             0) AS product_count,
    COALESCE(NULLIF(${alias}.inventory_summary->>'lowStockCount', '')::int,
             NULLIF(${alias}.inventory_summary->>'lowStockProducts', '')::int,
             0) AS low_stock_count,
    COALESCE(NULLIF(${alias}.inventory_summary->>'outOfStockCount', '')::int,
             0) AS out_of_stock_count,
    COALESCE(NULLIF(${alias}.inventory_summary->>'inventoryCostValue', '')::float,
             NULLIF(${alias}.inventory_summary->>'costValue', '')::float,
             0) AS inventory_cost_value,
    COALESCE(NULLIF(${alias}.inventory_summary->>'inventoryRetailValue', '')::float,
             NULLIF(${alias}.inventory_summary->>'sellingValue', '')::float,
             0) AS inventory_retail_value
  `;
}

module.exports = {
  SUMMARY_TOTALS_SQL,
  assertSummaryOnlyPayload,
  getDateRange,
  latestInventorySelect,
  normalizeProductSummaries,
  normalizeSummaryPayload,
};
