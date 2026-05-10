-- ============================================================
-- Sarisari Pro SaaS - Complete Database Schema
-- Run this script to initialize the database
-- PostgreSQL 18 compatible
-- ============================================================

-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TENANTS (one per store/business)
-- ============================================================
CREATE TABLE IF NOT EXISTS tenants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  owner_email   TEXT NOT NULL UNIQUE,
  phone         TEXT,
  address       TEXT,
  -- Subscription
  subscription_tier   TEXT NOT NULL DEFAULT 'free'
                      CHECK (subscription_tier IN ('free','pro','enterprise')),
  subscription_status TEXT NOT NULL DEFAULT 'active'
                      CHECK (subscription_status IN ('active','inactive','suspended','cancelled')),
  subscription_started_at TIMESTAMPTZ,
  subscription_expires_at TIMESTAMPTZ,
  -- Settings & limits
  settings      JSONB NOT NULL DEFAULT '{}',
  -- Timestamps
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- USERS (owners, managers, staff — all linked to a tenant)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'staff'
                CHECK (role IN ('owner','manager','staff','cashier')),
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Software owner (platform admin) — separate from tenant users
CREATE TABLE IF NOT EXISTS platform_admins (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh tokens for JWT rotation
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  admin_id    UUID REFERENCES platform_admins(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT must_have_one_user CHECK (
    (user_id IS NOT NULL AND admin_id IS NULL) OR
    (user_id IS NULL AND admin_id IS NOT NULL)
  )
);

-- ============================================================
-- CATEGORIES (tenant-scoped)
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, name)
);

-- ============================================================
-- PRODUCTS (tenant-scoped — mirrors existing ProductModel)
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL DEFAULT 'Uncategorized',
  barcode       TEXT,
  cost_price    DECIMAL(12,2) NOT NULL DEFAULT 0,
  selling_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock         INTEGER NOT NULL DEFAULT 0,
  image_url     TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, barcode)
);

-- ============================================================
-- STOCK ADJUSTMENTS (tenant-scoped)
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  product_id    UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_name  TEXT NOT NULL,
  adjustment    INTEGER NOT NULL,           -- positive = restock, negative = shrinkage
  reason        TEXT,
  adjusted_by   UUID REFERENCES users(id),
  adjusted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSACTIONS (tenant-scoped — mirrors existing TransactionModel)
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  total_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_cost       DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_profit     DECIMAL(12,2) NOT NULL DEFAULT 0,
  payment_method   TEXT DEFAULT 'cash',
  payment_amount   DECIMAL(12,2),
  change_amount    DECIMAL(12,2),
  notes            TEXT,
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSACTION ITEMS (line items per transaction)
-- ============================================================
CREATE TABLE IF NOT EXISTS transaction_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id   UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  product_id       UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name     TEXT NOT NULL,
  quantity         INTEGER NOT NULL DEFAULT 1,
  selling_price    DECIMAL(12,2) NOT NULL,
  cost_price       DECIMAL(12,2) NOT NULL DEFAULT 0,
  subtotal         DECIMAL(12,2) NOT NULL,
  item_profit      DECIMAL(12,2) NOT NULL DEFAULT 0
);

-- ============================================================
-- EXPENSES (tenant-scoped — mirrors existing ExpenseModel)
-- ============================================================
CREATE TABLE IF NOT EXISTS expenses (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT,
  amount       DECIMAL(12,2) NOT NULL,
  category     TEXT DEFAULT 'General',
  expense_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  recorded_by  UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CASHIER DAILY SUMMARIES (summary-only sync from phones)
-- ============================================================
CREATE TABLE IF NOT EXISTS cashier_daily_summaries (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  cashier_user_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  cashier_key        TEXT NOT NULL,
  cashier_name       TEXT,
  device_id          TEXT,
  summary_date       DATE NOT NULL,
  period_start       TIMESTAMPTZ,
  period_end         TIMESTAMPTZ,
  currency           TEXT NOT NULL DEFAULT 'PHP',
  transaction_count  INTEGER NOT NULL DEFAULT 0 CHECK (transaction_count >= 0),
  items_sold_count   INTEGER NOT NULL DEFAULT 0 CHECK (items_sold_count >= 0),
  gross_revenue      DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (gross_revenue >= 0),
  net_revenue        DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (net_revenue >= 0),
  total_cost         DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
  gross_profit       DECIMAL(12,2) NOT NULL DEFAULT 0,
  expense_total      DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (expense_total >= 0),
  expense_count      INTEGER NOT NULL DEFAULT 0 CHECK (expense_count >= 0),
  discount_total     DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
  refund_total       DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (refund_total >= 0),
  cash_sales         DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (cash_sales >= 0),
  gcash_sales        DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (gcash_sales >= 0),
  credit_sales       DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (credit_sales >= 0),
  other_payment_sales DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (other_payment_sales >= 0),
  payment_breakdown  JSONB NOT NULL DEFAULT '{}',
  expense_breakdown  JSONB NOT NULL DEFAULT '{}',
  inventory_summary  JSONB NOT NULL DEFAULT '{}',
  metadata           JSONB NOT NULL DEFAULT '{}',
  client_batch_id    TEXT,
  received_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, cashier_key, summary_date)
);

CREATE TABLE IF NOT EXISTS cashier_product_summaries (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  cashier_summary_id  UUID NOT NULL REFERENCES cashier_daily_summaries(id) ON DELETE CASCADE,
  cashier_user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  cashier_key         TEXT NOT NULL,
  summary_date        DATE NOT NULL,
  product_key         TEXT NOT NULL,
  product_name        TEXT NOT NULL,
  category            TEXT,
  stock_on_hand       INTEGER NOT NULL DEFAULT 0 CHECK (stock_on_hand >= 0),
  low_stock_threshold INTEGER NOT NULL DEFAULT 0 CHECK (low_stock_threshold >= 0),
  units_sold          INTEGER NOT NULL DEFAULT 0 CHECK (units_sold >= 0),
  sales_revenue       DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (sales_revenue >= 0),
  gross_profit        DECIMAL(12,2) NOT NULL DEFAULT 0,
  selling_price       DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
  last_sold_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (cashier_summary_id, product_key)
);

-- ============================================================
-- AI FORECASTS (cached predictions per tenant)
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_forecasts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  forecast_type   TEXT NOT NULL,  -- 'sales_revenue' | 'product_demand' | 'category_trend'
  period          TEXT NOT NULL,  -- 'next_7_days' | 'next_30_days'
  forecast_data   JSONB NOT NULL,
  generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until     TIMESTAMPTZ NOT NULL,
  model_version   TEXT DEFAULT '1.0'
);

-- ============================================================
-- AI SUGGESTIONS (actionable insights per tenant)
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_suggestions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  product_id       UUID REFERENCES products(id) ON DELETE CASCADE,
  suggestion_type  TEXT NOT NULL,
                   -- 'stock_up' | 'price_reduce' | 'trend_alert' | 'slow_moving'
                   -- 'peak_hours' | 'cross_sell' | 'low_margin'
  title            TEXT NOT NULL,
  message          TEXT NOT NULL,
  priority         TEXT NOT NULL DEFAULT 'medium'
                   CHECK (priority IN ('low','medium','high','critical')),
  is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  is_dismissed     BOOLEAN NOT NULL DEFAULT FALSE,
  metadata         JSONB DEFAULT '{}',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================

-- Users
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Products
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(tenant_id, category);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(tenant_id, barcode);
CREATE INDEX IF NOT EXISTS idx_products_low_stock ON products(tenant_id, stock) WHERE stock > 0;

-- Transactions
CREATE INDEX IF NOT EXISTS idx_transactions_tenant_id ON transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(tenant_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_payment ON transactions(tenant_id, payment_method);

-- Transaction Items
CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_product ON transaction_items(product_id);

-- Expenses
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_id ON expenses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(tenant_id, expense_date);

-- Cashier summaries
CREATE INDEX IF NOT EXISTS idx_cashier_summaries_tenant_date
  ON cashier_daily_summaries(tenant_id, summary_date);
CREATE INDEX IF NOT EXISTS idx_cashier_summaries_cashier
  ON cashier_daily_summaries(tenant_id, cashier_key, summary_date);
CREATE INDEX IF NOT EXISTS idx_cashier_summaries_received
  ON cashier_daily_summaries(received_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cashier_summaries_client_batch
  ON cashier_daily_summaries(tenant_id, client_batch_id)
  WHERE client_batch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_tenant_date
  ON cashier_product_summaries(tenant_id, summary_date);
CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_product
  ON cashier_product_summaries(tenant_id, product_key, summary_date);
CREATE INDEX IF NOT EXISTS idx_cashier_product_summaries_summary
  ON cashier_product_summaries(cashier_summary_id);

-- Stock Adjustments
CREATE INDEX IF NOT EXISTS idx_stock_adj_tenant ON stock_adjustments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_adj_product ON stock_adjustments(product_id);

-- AI
CREATE INDEX IF NOT EXISTS idx_ai_forecasts_tenant ON ai_forecasts(tenant_id, forecast_type);
CREATE INDEX IF NOT EXISTS idx_ai_suggestions_tenant ON ai_suggestions(tenant_id, is_dismissed);

-- ============================================================
-- TRIGGERS: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trigger_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trigger_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trigger_cashier_summaries_updated_at
  BEFORE UPDATE ON cashier_daily_summaries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trigger_cashier_product_summaries_updated_at
  BEFORE UPDATE ON cashier_product_summaries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- DEFAULT PLATFORM ADMIN (change password after first run!)
-- ============================================================
-- Password: Admin@123456 (bcrypt hashed — CHANGE THIS!)
INSERT INTO platform_admins (email, password_hash, full_name)
VALUES (
  'admin@sarisaripro.com',
  '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeXzYBbKaX6KPxG2',
  'Platform Administrator'
) ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- VIEWS for analytics convenience
-- ============================================================
DROP VIEW IF EXISTS v_store_summary_totals;
DROP VIEW IF EXISTS v_monthly_expenses;
DROP VIEW IF EXISTS v_product_sales;
DROP VIEW IF EXISTS v_daily_sales;

-- Daily sales summary per tenant
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
GROUP BY tenant_id, summary_date;

-- Product sales summary per tenant
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
GROUP BY tenant_id, product_key, product_name;

-- Monthly expense summary per tenant
CREATE OR REPLACE VIEW v_monthly_expenses AS
SELECT
  tenant_id,
  DATE_TRUNC('month', summary_date::TIMESTAMPTZ) AS month,
  SUM(expense_total) AS total_amount,
  SUM(expense_count) AS expense_count
FROM cashier_daily_summaries
GROUP BY tenant_id, DATE_TRUNC('month', summary_date::TIMESTAMPTZ);

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
GROUP BY tenant_id;
