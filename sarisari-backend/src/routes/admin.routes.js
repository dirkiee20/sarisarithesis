const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/database');
const { authenticateAdmin } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const { latestInventorySelect } = require('../services/summary.service');
const {
  getAdminSummaryInsights,
  getTenantSummaryInsights,
} = require('../services/summary-insights.service');

const router = express.Router();

// ── POST /api/admin/auth/login ─────────────────────────────────────────────
router.post(
  '/auth/login',
  asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    const result = await pool.query(
      'SELECT * FROM platform_admins WHERE email = $1 AND is_active = TRUE',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const admin = result.rows[0];
    const valid = await bcrypt.compare(password, admin.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { adminId: admin.id, type: 'platform_admin' },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      admin: { id: admin.id, email: admin.email, fullName: admin.full_name },
    });
  })
);

// All routes below require platform admin auth
router.use(authenticateAdmin);

// ── GET /api/admin/tenants ─────────────────────────────────────────────────
router.get(
  '/tenants',
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 20, search, tier, status } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const params = [];
    let whereClause = 'WHERE 1=1';
    let paramIndex = 1;

    if (search) {
      whereClause += ` AND (t.business_name ILIKE $${paramIndex} OR t.owner_email ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    if (tier) {
      whereClause += ` AND t.subscription_tier = $${paramIndex++}`;
      params.push(tier);
    }
    if (status) {
      whereClause += ` AND t.subscription_status = $${paramIndex++}`;
      params.push(status);
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM tenants t ${whereClause}`, params
    );

    const tenantsResult = await pool.query(
      `SELECT
         t.*,
         (SELECT COUNT(*) FROM users u WHERE u.tenant_id = t.id) AS user_count,
         COALESCE(summary.transaction_count, 0) AS transaction_count,
         COALESCE(summary.total_revenue, 0) AS total_revenue,
         COALESCE(summary.gross_profit, 0) AS gross_profit,
         COALESCE(summary.total_expenses, 0) AS total_expenses,
         COALESCE(summary.reporting_cashiers, 0) AS reporting_cashiers,
         summary.latest_summary_at,
         COALESCE(inventory.product_count, 0) AS product_count,
         COALESCE(inventory.low_stock_count, 0) AS low_stock_count
       FROM tenants t
       LEFT JOIN v_store_summary_totals summary ON summary.tenant_id = t.id
       LEFT JOIN LATERAL (
         SELECT ${latestInventorySelect('latest_summary')}
         FROM cashier_daily_summaries latest_summary
         WHERE latest_summary.tenant_id = t.id
           AND latest_summary.inventory_summary <> '{}'::jsonb
         ORDER BY latest_summary.summary_date DESC, latest_summary.received_at DESC
         LIMIT 1
       ) inventory ON TRUE
       ${whereClause}
       ORDER BY t.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, parseInt(limit), offset]
    );

    res.json({
      tenants: tenantsResult.rows,
      pagination: {
        total: parseInt(countResult.rows[0].count),
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(parseInt(countResult.rows[0].count) / parseInt(limit)),
      },
    });
  })
);

// ── GET /api/admin/users ───────────────────────────────────────────────────
router.get(
  '/users',
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 20, search, role, status } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const params = [];
    let whereClause = 'WHERE 1=1';
    let paramIndex = 1;

    if (search) {
      whereClause += ` AND (
        u.full_name ILIKE $${paramIndex}
        OR u.email ILIKE $${paramIndex}
        OR t.business_name ILIKE $${paramIndex}
      )`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    if (role) {
      whereClause += ` AND u.role = $${paramIndex++}`;
      params.push(role);
    }

    if (status === 'active') {
      whereClause += ` AND u.is_active = TRUE`;
    } else if (status === 'inactive') {
      whereClause += ` AND u.is_active = FALSE`;
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) AS count
       FROM users u
       JOIN tenants t ON t.id = u.tenant_id
       ${whereClause}`,
      params
    );

    const usersResult = await pool.query(
      `SELECT
         u.id,
         u.email,
         u.full_name,
         u.role,
         u.is_active,
         u.last_login_at,
         u.created_at,
         u.tenant_id,
         t.business_name,
         t.subscription_tier,
         t.subscription_status
       FROM users u
       JOIN tenants t ON t.id = u.tenant_id
       ${whereClause}
       ORDER BY
         u.last_login_at DESC NULLS LAST,
         u.created_at DESC,
         u.full_name ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, parseInt(limit), offset]
    );

    const statsResult = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COUNT(*) FROM users WHERE is_active = TRUE) AS active_users,
        (SELECT COUNT(*) FROM users WHERE is_active = FALSE) AS inactive_users,
        (SELECT COUNT(*) FROM users WHERE role = 'owner') AS owners,
        (SELECT COUNT(*) FROM users WHERE role = 'manager') AS managers,
        (SELECT COUNT(*) FROM users WHERE role = 'staff') AS staff,
        (SELECT COUNT(*) FROM users WHERE role = 'cashier') AS cashiers,
        (SELECT COUNT(*) FROM users WHERE last_login_at >= NOW() - INTERVAL '7 days') AS recent_logins_7d
    `);

    res.json({
      users: usersResult.rows,
      pagination: {
        total: parseInt(countResult.rows[0].count),
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(parseInt(countResult.rows[0].count) / parseInt(limit)),
      },
      stats: statsResult.rows[0],
    });
  })
);

// ── GET /api/admin/tenants/:id ─────────────────────────────────────────────
router.get(
  '/tenants/:id',
  asyncHandler(async (req, res) => {
    const tenantResult = await pool.query(
      'SELECT * FROM tenants WHERE id = $1', [req.params.id]
    );
    if (tenantResult.rows.length === 0) {
      return res.status(404).json({ error: 'Tenant not found' });
    }

    const usersResult = await pool.query(
      `SELECT id, email, full_name, role, is_active, last_login_at
       FROM users WHERE tenant_id = $1 ORDER BY role`, [req.params.id]
    );

    const statsResult = await pool.query(
      `SELECT
         COALESCE(summary.transaction_count, 0) AS transactions,
         COALESCE(summary.total_revenue, 0) AS total_revenue,
         COALESCE(summary.gross_profit, 0) AS gross_profit,
         COALESCE(summary.total_expenses, 0) AS expenses,
         COALESCE(summary.reporting_cashiers, 0) AS reporting_cashiers,
         summary.latest_summary_at,
         COALESCE(inventory.product_count, 0) AS products,
         COALESCE(inventory.low_stock_count, 0) AS low_stock_count,
         COALESCE(inventory.out_of_stock_count, 0) AS out_of_stock_count
       FROM tenants t
       LEFT JOIN v_store_summary_totals summary ON summary.tenant_id = t.id
       LEFT JOIN LATERAL (
         SELECT ${latestInventorySelect('latest_summary')}
         FROM cashier_daily_summaries latest_summary
         WHERE latest_summary.tenant_id = t.id
           AND latest_summary.inventory_summary <> '{}'::jsonb
         ORDER BY latest_summary.summary_date DESC, latest_summary.received_at DESC
         LIMIT 1
       ) inventory ON TRUE
       WHERE t.id = $1`,
      [req.params.id]
    );

    res.json({
      tenant: tenantResult.rows[0],
      users: usersResult.rows,
      stats: statsResult.rows[0],
    });
  })
);

router.get(
  '/tenants/:id/ai-insights',
  asyncHandler(async (req, res) => {
    const tenantResult = await pool.query(
      'SELECT id, business_name, subscription_tier, subscription_status FROM tenants WHERE id = $1',
      [req.params.id]
    );

    if (tenantResult.rows.length === 0) {
      return res.status(404).json({ error: 'Tenant not found' });
    }

    const insights = await getTenantSummaryInsights(req.params.id);

    res.json({
      tenant: tenantResult.rows[0],
      ...insights,
    });
  })
);

// ── PATCH /api/admin/tenants/:id/subscription ──────────────────────────────
router.patch(
  '/tenants/:id/subscription',
  asyncHandler(async (req, res) => {
    const { tier, status } = req.body;

    const allowed_tiers = ['free', 'pro', 'enterprise'];
    const allowed_statuses = ['active', 'inactive', 'suspended', 'cancelled'];

    if (tier && !allowed_tiers.includes(tier)) {
      return res.status(400).json({ error: 'Invalid tier' });
    }
    if (status && !allowed_statuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const result = await pool.query(
      `UPDATE tenants SET
         subscription_tier = COALESCE($1, subscription_tier),
         subscription_status = COALESCE($2, subscription_status),
         updated_at = NOW()
       WHERE id = $3
       RETURNING id, business_name, subscription_tier, subscription_status`,
      [tier, status, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tenant not found' });
    }

    res.json({ tenant: result.rows[0], message: 'Subscription updated' });
  })
);

// ── GET /api/admin/platform-stats ──────────────────────────────────────────
router.get(
  '/platform-stats',
  asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM tenants) AS total_tenants,
        (SELECT COUNT(*) FROM tenants WHERE subscription_status = 'active') AS active_tenants,
        (SELECT COUNT(*) FROM tenants WHERE subscription_tier = 'free') AS free_tenants,
        (SELECT COUNT(*) FROM tenants WHERE subscription_tier = 'pro') AS pro_tenants,
        (SELECT COUNT(*) FROM tenants WHERE subscription_tier = 'enterprise') AS enterprise_tenants,
        (SELECT COUNT(*) FROM tenants WHERE subscription_status = 'suspended') AS suspended_tenants,
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COALESCE(SUM(transaction_count), 0) FROM cashier_daily_summaries) AS total_transactions,
        (SELECT COALESCE(SUM(net_revenue), 0) FROM cashier_daily_summaries) AS platform_total_revenue,
        (SELECT COALESCE(SUM(gross_profit), 0) FROM cashier_daily_summaries) AS platform_gross_profit,
        (SELECT COUNT(DISTINCT tenant_id) FROM cashier_daily_summaries) AS tenants_reporting,
        (SELECT COUNT(*) FROM tenants WHERE created_at >= NOW() - INTERVAL '30 days') AS new_tenants_30d
    `);

    // New signups per day (last 30 days)
    const signupTrend = await pool.query(`
      SELECT DATE(created_at) AS date, COUNT(*) AS count
      FROM tenants
      WHERE created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `);

    res.json({
      stats: result.rows[0],
      signupTrend: signupTrend.rows,
    });
  })
);

router.get(
  '/ai/overview',
  asyncHandler(async (_req, res) => {
    const insights = await getAdminSummaryInsights();
    res.json(insights);
  })
);

module.exports = router;
