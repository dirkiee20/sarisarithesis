const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();
router.use(authenticate);

// ── GET /api/expenses ──────────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 20, startDate, endDate, category } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const params = [req.tenantId];
    let whereClause = 'WHERE tenant_id = $1';
    let paramIndex = 2;

    if (startDate) {
      whereClause += ` AND expense_date >= $${paramIndex}`;
      params.push(new Date(startDate));
      paramIndex++;
    }
    if (endDate) {
      whereClause += ` AND expense_date <= $${paramIndex}`;
      params.push(new Date(endDate + 'T23:59:59'));
      paramIndex++;
    }
    if (category) {
      whereClause += ` AND category = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM expenses ${whereClause}`, params
    );
    const expResult = await pool.query(
      `SELECT e.*, u.full_name AS recorded_by_name
       FROM expenses e
       LEFT JOIN users u ON u.id = e.recorded_by
       ${whereClause}
       ORDER BY e.expense_date DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, parseInt(limit), offset]
    );

    const total = parseInt(countResult.rows[0].count);

    res.json({
      expenses: expResult.rows,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / parseInt(limit)),
      },
    });
  })
);

// ── POST /api/expenses ─────────────────────────────────────────────────────
router.post(
  '/',
  [
    body('title').trim().notEmpty().withMessage('Title is required'),
    body('amount').isFloat({ min: 0.01 }).withMessage('Amount must be > 0'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { title, description, amount, category, expenseDate } = req.body;

    const result = await pool.query(
      `INSERT INTO expenses (tenant_id, title, description, amount, category, expense_date, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [
        req.tenantId, title, description || null, amount,
        category || 'General',
        expenseDate ? new Date(expenseDate) : new Date(),
        req.user.id,
      ]
    );

    res.status(201).json({ expense: result.rows[0] });
  })
);

// ── PUT /api/expenses/:id ──────────────────────────────────────────────────
router.put(
  '/:id',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { title, description, amount, category, expenseDate } = req.body;

    const result = await pool.query(
      `UPDATE expenses SET
         title = COALESCE($1, title),
         description = COALESCE($2, description),
         amount = COALESCE($3, amount),
         category = COALESCE($4, category),
         expense_date = COALESCE($5, expense_date)
       WHERE id = $6 AND tenant_id = $7
       RETURNING *`,
      [title, description, amount, category,
       expenseDate ? new Date(expenseDate) : null,
       req.params.id, req.tenantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Expense not found' });
    }

    res.json({ expense: result.rows[0] });
  })
);

// ── DELETE /api/expenses/:id ───────────────────────────────────────────────
router.delete(
  '/:id',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `DELETE FROM expenses WHERE id = $1 AND tenant_id = $2 RETURNING id`,
      [req.params.id, req.tenantId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Expense not found' });
    }
    res.json({ message: 'Expense deleted' });
  })
);

// ── GET /api/expenses/summary/period ──────────────────────────────────────
router.get(
  '/summary/period',
  asyncHandler(async (req, res) => {
    const { period = 'month' } = req.query;
    const now = new Date();
    let startDate;

    switch (period.toLowerCase()) {
      case 'today':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case 'week':
        startDate = new Date(now);
        startDate.setDate(now.getDate() - 6);
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'month':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      case 'year':
        startDate = new Date(now.getFullYear(), 0, 1);
        break;
      default:
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    const result = await pool.query(
      `SELECT
         COALESCE(SUM(amount), 0) AS total,
         COUNT(*) AS count,
         category
       FROM expenses
       WHERE tenant_id = $1 AND expense_date >= $2
       GROUP BY category
       ORDER BY total DESC`,
      [req.tenantId, startDate]
    );

    const totalAll = result.rows.reduce((sum, r) => sum + parseFloat(r.total), 0);

    res.json({
      totalExpenses: totalAll,
      byCategory: result.rows,
      period,
    });
  })
);

module.exports = router;
