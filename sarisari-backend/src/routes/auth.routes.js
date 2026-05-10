const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { asyncHandler } = require('../middleware/error.middleware');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();

// ── Helpers ────────────────────────────────────────────────────────────────

const generateTokens = (userId, tenantId, role) => {
  const accessToken = jwt.sign(
    { userId, tenantId, role, type: 'user' },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
  );
  const refreshToken = jwt.sign(
    { userId, tenantId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  );
  return { accessToken, refreshToken };
};

const storeRefreshToken = async (userId, token) => {
  const hash = require('crypto').createHash('sha256').update(token).digest('hex');
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [userId, hash, expiresAt]
  );
};

// ── POST /api/auth/register ────────────────────────────────────────────────
// Register a new business (creates tenant + owner user)
router.post(
  '/register',
  [
    body('businessName').trim().notEmpty().withMessage('Business name is required'),
    body('ownerName').trim().notEmpty().withMessage('Owner name is required'),
    body('email').isEmail().normalizeEmail().withMessage('Invalid email'),
    body('password')
      .isLength({ min: 6 })
      .withMessage('Password must be at least 6 characters'),
    body('subscriptionTier')
      .optional()
      .isIn(['free', 'pro', 'enterprise'])
      .withMessage('Invalid subscription tier'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const {
      businessName,
      ownerName,
      email,
      password,
      phone,
      address,
      subscriptionTier = 'free',
    } = req.body;
    const selectedTier = ['free', 'pro', 'enterprise'].includes(subscriptionTier)
      ? subscriptionTier
      : 'free';
    const registrationSettings = {
      registrationPayment: {
        mode: selectedTier === 'free' ? 'free_plan' : 'simulation',
        status: 'approved',
        simulatedAt: new Date().toISOString(),
      },
    };

    // Check existing user
    const existing = await pool.query(
      'SELECT id FROM users WHERE email = $1', [email]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email is already registered' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Create tenant
      const tenantResult = await client.query(
        `INSERT INTO tenants (
           business_name,
           owner_email,
           phone,
           address,
           subscription_tier,
           subscription_status,
           subscription_started_at,
           settings
         )
         VALUES ($1, $2, $3, $4, $5, 'active', NOW(), $6::jsonb)
         RETURNING *`,
        [
          businessName,
          email,
          phone || null,
          address || null,
          selectedTier,
          JSON.stringify(registrationSettings),
        ]
      );
      const tenant = tenantResult.rows[0];

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      // Create owner user
      const userResult = await client.query(
        `INSERT INTO users (tenant_id, email, password_hash, full_name, role)
         VALUES ($1, $2, $3, $4, 'owner') RETURNING id, email, full_name, role`,
        [tenant.id, email, passwordHash, ownerName]
      );
      const user = userResult.rows[0];

      // Seed default categories for this tenant
      await client.query(
        `INSERT INTO categories (tenant_id, name) VALUES
         ($1, 'Beverages'), ($1, 'Snacks'), ($1, 'Canned Goods'),
         ($1, 'Personal Care'), ($1, 'Household'), ($1, 'Tobacco'),
         ($1, 'Condiments'), ($1, 'Frozen'), ($1, 'Others')`,
        [tenant.id]
      );

      await client.query('COMMIT');

      // Generate tokens
      const { accessToken, refreshToken } = generateTokens(user.id, tenant.id, user.role);
      await storeRefreshToken(user.id, refreshToken);

      res.status(201).json({
        message: 'Registration successful',
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          email: user.email,
          fullName: user.full_name,
          role: user.role,
        },
        tenant: {
          id: tenant.id,
          businessName: tenant.business_name,
          subscriptionTier: tenant.subscription_tier,
          subscriptionStatus: tenant.subscription_status,
          paymentMode: registrationSettings.registrationPayment.mode,
        },
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  })
);

// ── POST /api/auth/login ───────────────────────────────────────────────────
router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    const result = await pool.query(
      `SELECT u.id, u.tenant_id, u.email, u.password_hash, u.full_name,
              u.role, u.is_active,
              t.business_name, t.subscription_tier, t.subscription_status
       FROM users u
       JOIN tenants t ON t.id = u.tenant_id
       WHERE u.email = $1`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Update last login
    await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user.id]);

    const { accessToken, refreshToken } = generateTokens(user.id, user.tenant_id, user.role);
    await storeRefreshToken(user.id, refreshToken);

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
      },
      tenant: {
        id: user.tenant_id,
        businessName: user.business_name,
        subscriptionTier: user.subscription_tier,
        subscriptionStatus: user.subscription_status,
      },
    });
  })
);

// ── POST /api/auth/refresh ─────────────────────────────────────────────────
router.post(
  '/refresh',
  asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    let decoded;
    try {
      decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    } catch {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    // Validate against DB
    const crypto = require('crypto');
    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const tokenResult = await pool.query(
      `SELECT * FROM refresh_tokens WHERE token_hash = $1 AND expires_at > NOW()`,
      [hash]
    );

    if (tokenResult.rows.length === 0) {
      return res.status(401).json({ error: 'Refresh token not found or expired' });
    }

    // Get user info
    const userResult = await pool.query(
      'SELECT id, tenant_id, role FROM users WHERE id = $1',
      [decoded.userId]
    );
    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];

    // Rotate: delete old, issue new
    await pool.query('DELETE FROM refresh_tokens WHERE token_hash = $1', [hash]);
    const { accessToken, refreshToken: newRefreshToken } = generateTokens(
      user.id, user.tenant_id, user.role
    );
    await storeRefreshToken(user.id, newRefreshToken);

    res.json({ accessToken, refreshToken: newRefreshToken });
  })
);

// ── POST /api/auth/logout ──────────────────────────────────────────────────
router.post(
  '/logout',
  authenticate,
  asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    if (refreshToken) {
      const crypto = require('crypto');
      const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      await pool.query('DELETE FROM refresh_tokens WHERE token_hash = $1', [hash]);
    }
    res.json({ message: 'Logged out successfully' });
  })
);

// ── GET /api/auth/me ───────────────────────────────────────────────────────
router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json({ user: req.user });
  })
);

module.exports = router;
