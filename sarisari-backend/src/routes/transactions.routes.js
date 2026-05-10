const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();
router.use(authenticate);

// ── POST /api/transactions ──────────────────────────────────────────────────
// Create a new transaction (checkout)
router.post(
  '/',
  [
    body('items').isArray({ min: 1 }).withMessage('At least one item is required'),
    body('items.*.productId').notEmpty().withMessage('Product ID is required'),
    body('items.*.quantity').isInt({ min: 1 }).withMessage('Quantity must be >= 1'),
    body('paymentMethod').notEmpty().withMessage('Payment method is required'),
    body('paymentAmount').isFloat({ min: 0 }).withMessage('Payment amount must be >= 0'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { items, paymentMethod, paymentAmount, notes } = req.body;
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      let totalAmount = 0;
      let totalCost = 0;
      const resolvedItems = [];

      // Resolve products and calculate totals
      for (const item of items) {
        const productResult = await client.query(
          `SELECT id, name, selling_price, cost_price, stock
           FROM products WHERE id = $1 AND tenant_id = $2 AND is_active = TRUE`,
          [item.productId, req.tenantId]
        );

        if (productResult.rows.length === 0) {
          throw { status: 400, message: `Product not found: ${item.productId}` };
        }

        const product = productResult.rows[0];

        if (product.stock < item.quantity) {
          throw {
            status: 400,
            message: `Insufficient stock for "${product.name}". Available: ${product.stock}`,
          };
        }

        const subtotal = product.selling_price * item.quantity;
        const itemCost = product.cost_price * item.quantity;
        const itemProfit = subtotal - itemCost;

        totalAmount += subtotal;
        totalCost += itemCost;

        resolvedItems.push({
          productId: product.id,
          productName: product.name,
          quantity: item.quantity,
          sellingPrice: product.selling_price,
          costPrice: product.cost_price,
          subtotal,
          itemProfit,
        });
      }

      const totalProfit = totalAmount - totalCost;
      const changeAmount = parseFloat(paymentAmount) - totalAmount;

      // Create transaction record
      const txResult = await client.query(
        `INSERT INTO transactions
           (tenant_id, total_amount, total_cost, total_profit,
            payment_method, payment_amount, change_amount, notes, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          req.tenantId, totalAmount, totalCost, totalProfit,
          paymentMethod, paymentAmount, changeAmount, notes || null,
          req.user.id,
        ]
      );
      const transaction = txResult.rows[0];

      // Insert transaction items and deduct stock
      for (const item of resolvedItems) {
        await client.query(
          `INSERT INTO transaction_items
             (transaction_id, product_id, product_name, quantity,
              selling_price, cost_price, subtotal, item_profit)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            transaction.id, item.productId, item.productName, item.quantity,
            item.sellingPrice, item.costPrice, item.subtotal, item.itemProfit,
          ]
        );

        // Deduct stock
        await client.query(
          `UPDATE products SET stock = stock - $1, updated_at = NOW()
           WHERE id = $2 AND tenant_id = $3`,
          [item.quantity, item.productId, req.tenantId]
        );
      }

      await client.query('COMMIT');

      res.status(201).json({
        transaction: {
          ...transaction,
          items: resolvedItems,
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

// ── GET /api/transactions ──────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 20, startDate, endDate, paymentMethod } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const params = [req.tenantId];
    let whereClause = 'WHERE tenant_id = $1';
    let paramIndex = 2;

    if (startDate) {
      whereClause += ` AND transaction_date >= $${paramIndex}`;
      params.push(new Date(startDate));
      paramIndex++;
    }
    if (endDate) {
      whereClause += ` AND transaction_date <= $${paramIndex}`;
      params.push(new Date(endDate + 'T23:59:59'));
      paramIndex++;
    }
    if (paymentMethod) {
      whereClause += ` AND payment_method = $${paramIndex}`;
      params.push(paymentMethod);
      paramIndex++;
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM transactions ${whereClause}`, params
    );

    const txResult = await pool.query(
      `SELECT * FROM transactions ${whereClause}
       ORDER BY transaction_date DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, parseInt(limit), offset]
    );

    const total = parseInt(countResult.rows[0].count);

    res.json({
      transactions: txResult.rows,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / parseInt(limit)),
      },
    });
  })
);

// ── GET /api/transactions/:id ─────────────────────────────────────────────
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const txResult = await pool.query(
      `SELECT * FROM transactions WHERE id = $1 AND tenant_id = $2`,
      [req.params.id, req.tenantId]
    );
    if (txResult.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const itemsResult = await pool.query(
      `SELECT * FROM transaction_items WHERE transaction_id = $1`,
      [req.params.id]
    );

    res.json({
      transaction: {
        ...txResult.rows[0],
        items: itemsResult.rows,
      },
    });
  })
);

// ── GET /api/transactions/summary/period ──────────────────────────────────
router.get(
  '/summary/period',
  asyncHandler(async (req, res) => {
    const { period = 'today' } = req.query;

    let startDate, endDate;
    const now = new Date();

    switch (period.toLowerCase()) {
      case 'today':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
        break;
      case 'week':
        const dayOfWeek = now.getDay() || 7;
        startDate = new Date(now);
        startDate.setDate(now.getDate() - dayOfWeek + 1);
        startDate.setHours(0, 0, 0, 0);
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
        break;
      case 'month':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
        break;
      case 'year':
        startDate = new Date(now.getFullYear(), 0, 1);
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
        break;
      default:
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    }

    const result = await pool.query(
      `SELECT
         COUNT(*) AS transaction_count,
         COALESCE(SUM(total_amount), 0) AS total_revenue,
         COALESCE(SUM(total_profit), 0) AS total_profit,
         COALESCE(SUM(total_cost), 0) AS total_cost,
         COALESCE(AVG(total_amount), 0) AS avg_transaction_value
       FROM transactions
       WHERE tenant_id = $1
         AND transaction_date BETWEEN $2 AND $3`,
      [req.tenantId, startDate, endDate]
    );

    res.json({ summary: result.rows[0], period, startDate, endDate });
  })
);

module.exports = router;
