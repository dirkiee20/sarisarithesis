const pool = require('../config/database');

async function ensureSummarySchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cashier_daily_summaries (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      cashier_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      cashier_key TEXT NOT NULL,
      cashier_name TEXT,
      device_id TEXT,
      summary_date DATE NOT NULL,
      period_start TIMESTAMPTZ,
      period_end TIMESTAMPTZ,
      currency TEXT NOT NULL DEFAULT 'PHP',
      transaction_count INTEGER NOT NULL DEFAULT 0 CHECK (transaction_count >= 0),
      items_sold_count INTEGER NOT NULL DEFAULT 0 CHECK (items_sold_count >= 0),
      gross_revenue DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (gross_revenue >= 0),
      net_revenue DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (net_revenue >= 0),
      total_cost DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
      gross_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
      expense_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (expense_total >= 0),
      expense_count INTEGER NOT NULL DEFAULT 0 CHECK (expense_count >= 0),
      discount_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
      refund_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (refund_total >= 0),
      cash_sales DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (cash_sales >= 0),
      gcash_sales DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (gcash_sales >= 0),
      credit_sales DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (credit_sales >= 0),
      other_payment_sales DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (other_payment_sales >= 0),
      payment_breakdown JSONB NOT NULL DEFAULT '{}',
      expense_breakdown JSONB NOT NULL DEFAULT '{}',
      inventory_summary JSONB NOT NULL DEFAULT '{}',
      metadata JSONB NOT NULL DEFAULT '{}',
      client_batch_id TEXT,
      received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (tenant_id, cashier_key, summary_date)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS cashier_product_summaries (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      cashier_summary_id UUID NOT NULL REFERENCES cashier_daily_summaries(id) ON DELETE CASCADE,
      cashier_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      cashier_key TEXT NOT NULL,
      summary_date DATE NOT NULL,
      product_key TEXT NOT NULL,
      product_name TEXT NOT NULL,
      category TEXT,
      stock_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (stock_on_hand >= 0),
      low_stock_threshold INTEGER NOT NULL DEFAULT 0 CHECK (low_stock_threshold >= 0),
      units_sold INTEGER NOT NULL DEFAULT 0 CHECK (units_sold >= 0),
      sales_revenue DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (sales_revenue >= 0),
      gross_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
      selling_price DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
      last_sold_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (cashier_summary_id, product_key)
    )
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_summaries_tenant_date
    ON cashier_daily_summaries(tenant_id, summary_date)
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_summaries_cashier
    ON cashier_daily_summaries(tenant_id, cashier_key, summary_date)
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_summaries_received
    ON cashier_daily_summaries(received_at)
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_cashier_summaries_client_batch
    ON cashier_daily_summaries(tenant_id, client_batch_id)
    WHERE client_batch_id IS NOT NULL
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_tenant_date
    ON cashier_product_summaries(tenant_id, summary_date)
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_product
    ON cashier_product_summaries(tenant_id, product_key, summary_date)
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_summary
    ON cashier_product_summaries(cashier_summary_id)
  `);

  await pool.query('DROP VIEW IF EXISTS v_store_summary_totals');
  await pool.query('DROP VIEW IF EXISTS v_product_sales');
  await pool.query('DROP VIEW IF EXISTS v_daily_sales');

  await pool.query(`
    CREATE OR REPLACE VIEW v_daily_sales AS
    SELECT
      tenant_id,
      summary_date AS sale_date,
      SUM(transaction_count) AS transaction_count,
      SUM(net_revenue) AS total_revenue,
      SUM(gross_profit) AS total_profit,
      SUM(total_cost) AS total_cost,
      SUM(expense_total) AS total_expenses,
      MAX(received_at) AS latest_summary_at
    FROM cashier_daily_summaries
    GROUP BY tenant_id, summary_date
  `);

  await pool.query(`
    CREATE OR REPLACE VIEW v_product_sales AS
    SELECT
      tenant_id,
      product_key AS product_id,
      product_name,
      MAX(category) AS category,
      SUM(units_sold) AS total_quantity_sold,
      SUM(sales_revenue) AS total_revenue,
      SUM(gross_profit) AS total_profit,
      COUNT(DISTINCT cashier_summary_id) AS times_sold,
      MAX(summary_date) AS latest_summary_date
    FROM cashier_product_summaries
    GROUP BY tenant_id, product_key, product_name
  `);

  await pool.query(`
    CREATE OR REPLACE VIEW v_store_summary_totals AS
    SELECT
      tenant_id,
      SUM(transaction_count) AS transaction_count,
      SUM(items_sold_count) AS items_sold_count,
      SUM(net_revenue) AS total_revenue,
      SUM(gross_revenue) AS gross_revenue,
      SUM(gross_profit) AS gross_profit,
      SUM(expense_total) AS total_expenses,
      COUNT(DISTINCT cashier_key) AS reporting_cashiers,
      COUNT(*) AS summary_count,
      MAX(received_at) AS latest_summary_at
    FROM cashier_daily_summaries
    GROUP BY tenant_id
  `);
}

module.exports = ensureSummarySchema;
