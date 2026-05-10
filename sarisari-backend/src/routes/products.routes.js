const express = require('express');
const { body, query, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();

// All product routes require authentication
router.use(authenticate);

// ── GET /api/products ──────────────────────────────────────────────────────
// List all products for the tenant
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const {
      search,
      category,
      lowStock,
      page = 1,
      limit = 50,
      sortBy = 'name',
      sortDir = 'ASC',
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [req.tenantId];
    let whereClause = 'WHERE p.tenant_id = $1 AND p.is_active = TRUE';
    let paramIndex = 2;

    if (search) {
      whereClause += ` AND (p.name ILIKE $${paramIndex} OR p.barcode ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    if (category) {
      whereClause += ` AND p.category = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }

    if (lowStock === 'true') {
      whereClause += ` AND p.stock <= 10`;
    }

    const allowedSort = ['name', 'category', 'stock', 'selling_price', 'created_at'];
    const sortColumn = allowedSort.includes(sortBy) ? sortBy : 'name';
    const sortDirection = sortDir === 'DESC' ? 'DESC' : 'ASC';

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM products p ${whereClause}`,
      params
    );

    const productsResult = await pool.query(
      `SELECT p.id, p.name, p.description, p.category, p.barcode,
              p.cost_price, p.selling_price, p.stock, p.image_url,
              p.created_at, p.updated_at
       FROM products p
       ${whereClause}
       ORDER BY p.${sortColumn} ${sortDirection}
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, parseInt(limit), offset]
    );

    const total = parseInt(countResult.rows[0].count);

    res.json({
      products: productsResult.rows,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / parseInt(limit)),
      },
    });
  })
);

// ── GET /api/products/:id ──────────────────────────────────────────────────
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `SELECT * FROM products WHERE id = $1 AND tenant_id = $2 AND is_active = TRUE`,
      [req.params.id, req.tenantId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json({ product: result.rows[0] });
  })
);

// ── GET /api/products/barcode/:barcode ────────────────────────────────────
router.get(
  '/barcode/:barcode',
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `SELECT * FROM products WHERE barcode = $1 AND tenant_id = $2 AND is_active = TRUE`,
      [req.params.barcode, req.tenantId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json({ product: result.rows[0] });
  })
);

// ── POST /api/products ─────────────────────────────────────────────────────
router.post(
  '/',
  requireRole('owner', 'manager'),
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('category').trim().notEmpty().withMessage('Category is required'),
    body('costPrice').isFloat({ min: 0 }).withMessage('Cost price must be >= 0'),
    body('sellingPrice').isFloat({ min: 0 }).withMessage('Selling price must be >= 0'),
    body('stock').isInt({ min: 0 }).withMessage('Stock must be >= 0'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }

    const { name, description, category, barcode, costPrice, sellingPrice, stock, imageUrl } =
      req.body;

    const result = await pool.query(
      `INSERT INTO products
         (tenant_id, name, description, category, barcode, cost_price, selling_price, stock, image_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        req.tenantId, name, description || null, category,
        barcode || null, costPrice, sellingPrice, stock, imageUrl || null,
      ]
    );

    res.status(201).json({ product: result.rows[0] });
  })
);

// ── PUT /api/products/:id ──────────────────────────────────────────────────
router.put(
  '/:id',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const { name, description, category, barcode, costPrice, sellingPrice, stock, imageUrl } =
      req.body;

    const result = await pool.query(
      `UPDATE products SET
         name = COALESCE($1, name),
         description = COALESCE($2, description),
         category = COALESCE($3, category),
         barcode = COALESCE($4, barcode),
         cost_price = COALESCE($5, cost_price),
         selling_price = COALESCE($6, selling_price),
         stock = COALESCE($7, stock),
         image_url = COALESCE($8, image_url),
         updated_at = NOW()
       WHERE id = $9 AND tenant_id = $10 AND is_active = TRUE
       RETURNING *`,
      [name, description, category, barcode, costPrice, sellingPrice, stock, imageUrl,
       req.params.id, req.tenantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json({ product: result.rows[0] });
  })
);

// ── DELETE /api/products/:id (soft delete) ─────────────────────────────────
router.delete(
  '/:id',
  requireRole('owner', 'manager'),
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `UPDATE products SET is_active = FALSE, updated_at = NOW()
       WHERE id = $1 AND tenant_id = $2
       RETURNING id`,
      [req.params.id, req.tenantId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json({ message: 'Product deleted successfully' });
  })
);

// ── GET /api/products/categories/list ─────────────────────────────────────
router.get(
  '/categories/list',
  asyncHandler(async (req, res) => {
    const result = await pool.query(
      `SELECT DISTINCT category FROM products
       WHERE tenant_id = $1 AND is_active = TRUE
       ORDER BY category ASC`,
      [req.tenantId]
    );
    res.json({ categories: result.rows.map((r) => r.category) });
  })
);

// ── GET /api/products/low-stock/list ──────────────────────────────────────
router.get(
  '/low-stock/list',
  asyncHandler(async (req, res) => {
    const threshold = parseInt(req.query.threshold) || 10;
    const result = await pool.query(
      `SELECT id, name, category, stock, selling_price, image_url
       FROM products
       WHERE tenant_id = $1 AND is_active = TRUE AND stock <= $2
       ORDER BY stock ASC`,
      [req.tenantId, threshold]
    );
    res.json({ products: result.rows, threshold });
  })
);

module.exports = router;
