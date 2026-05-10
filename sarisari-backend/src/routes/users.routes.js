const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();
router.use(authenticate);

// ── GET /api/users ─────────────────────────────────────────────────────────
// Owner/manager: list staff on this tenant
router.get(
  '/',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `SELECT id, email, full_name, role, is_active, last_login_at, created_at
       FROM users
       WHERE tenant_id = $1
       ORDER BY role, full_name`,
      [req.tenantId]
    );
    res.json({ users: result.rows });
  })
);

// ── POST /api/users/invite ─────────────────────────────────────────────────
// Invite / create a new staff account under this tenant
router.post(
  '/invite',
  requireRole('owner'),
  [
    body('email').isEmail().normalizeEmail(),
    body('fullName').trim().notEmpty(),
    body('password').isLength({ min: 6 }),
    body('role')
      .isIn(['manager', 'staff', 'cashier'])
      .withMessage('Role must be manager, staff, or cashier'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { email, fullName, password, role } = req.body;

    // Check email not already in use
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO users (tenant_id, email, password_hash, full_name, role)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, full_name, role, is_active, created_at`,
      [req.tenantId, email, passwordHash, fullName, role]
    );

    res.status(201).json({ user: result.rows[0] });
  })
);

// ── PUT /api/users/:id ─────────────────────────────────────────────────────
router.put(
  '/:id',
  requireRole('owner'),
  asyncHandler(async (req, res) => {
    const { fullName, role, isActive } = req.body;

    // Can't modify yourself through this endpoint (use /me)
    if (req.params.id === req.user.id) {
      return res.status(400).json({ error: 'Use /me endpoint to update your own profile' });
    }

    const result = await pool.query(
      `UPDATE users SET
         full_name = COALESCE($1, full_name),
         role = COALESCE($2, role),
         is_active = COALESCE($3, is_active),
         updated_at = NOW()
       WHERE id = $4 AND tenant_id = $5
       RETURNING id, email, full_name, role, is_active`,
      [fullName, role, isActive, req.params.id, req.tenantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  })
);

// ── PUT /api/users/me/profile ──────────────────────────────────────────────
router.put(
  '/me/profile',
  asyncHandler(async (req, res) => {
    const { fullName, currentPassword, newPassword } = req.body;
    const updates = [];
    const params = [];
    let paramIndex = 1;

    if (fullName) {
      updates.push(`full_name = $${paramIndex++}`);
      params.push(fullName);
    }

    if (newPassword) {
      if (!currentPassword) {
        return res.status(400).json({ error: 'Current password is required' });
      }
      const userResult = await pool.query(
        'SELECT password_hash FROM users WHERE id = $1', [req.user.id]
      );
      const valid = await bcrypt.compare(currentPassword, userResult.rows[0].password_hash);
      if (!valid) {
        return res.status(401).json({ error: 'Current password is incorrect' });
      }
      if (newPassword.length < 6) {
        return res.status(422).json({ error: 'Password must be at least 6 characters' });
      }
      const hash = await bcrypt.hash(newPassword, 12);
      updates.push(`password_hash = $${paramIndex++}`);
      params.push(hash);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    updates.push('updated_at = NOW()');
    params.push(req.user.id);

    const result = await pool.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${paramIndex}
       RETURNING id, email, full_name, role`,
      params
    );

    res.json({ user: result.rows[0] });
  })
);

module.exports = router;
