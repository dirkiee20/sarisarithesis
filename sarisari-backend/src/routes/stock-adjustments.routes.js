const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();
router.use(authenticate);

// ── GET /api/stock-adjustments ─────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { productId, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const params = [req.tenantId];
    let whereClause = 'WHERE sa.tenant_id = $1';

    if (productId) {
      whereClause += ` AND sa.product_id = $2`;
      params.push(productId);
    }

    const result = await pool.query(
      `SELECT sa.*, u.full_name AS adjusted_by_name
       FROM stock_adjustments sa
       LEFT JOIN users u ON u.id = sa.adjusted_by
       ${whereClause}
       ORDER BY sa.adjusted_at DESC
       LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, parseInt(limit), offset]
    );

    res.json({ adjustments: result.rows });
  })
);

// ── POST /api/stock-adjustments ────────────────────────────────────────────
router.post(
  '/',
  requireRole('owner', 'manager', 'staff'),
  [
    body('productId').notEmpty().withMessage('Product ID is required'),
    body('adjustment').isInt().not().equals(0).withMessage('Adjustment must be non-zero'),
    body('reason').trim().notEmpty().withMessage('Reason is required'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { productId, adjustment, reason } = req.body;
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Validate product belongs to tenant
      const productResult = await client.query(
        `SELECT id, name, stock FROM products
         WHERE id = $1 AND tenant_id = $2 AND is_active = TRUE`,
        [productId, req.tenantId]
      );

      if (productResult.rows.length === 0) {
        throw { status: 404, message: 'Product not found' };
      }

      const product = productResult.rows[0];
      const newStock = product.stock + parseInt(adjustment);

      if (newStock < 0) {
        throw {
          status: 400,
          message: `Cannot reduce stock below 0. Current stock: ${product.stock}`,
        };
      }

      // Update product stock
      await client.query(
        `UPDATE products SET stock = $1, updated_at = NOW()
         WHERE id = $2 AND tenant_id = $3`,
        [newStock, productId, req.tenantId]
      );

      // Record the adjustment
      const adjustResult = await client.query(
        `INSERT INTO stock_adjustments
           (tenant_id, product_id, product_name, adjustment, reason, adjusted_by)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [req.tenantId, productId, product.name, adjustment, reason, req.user.id]
      );

      await client.query('COMMIT');

      res.status(201).json({
        adjustment: adjustResult.rows[0],
        newStock,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  })
);

module.exports = router;
