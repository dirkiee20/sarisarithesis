const jwt = require('jsonwebtoken');
const pool = require('../config/database');

/**
 * Middleware to verify JWT and attach user/tenant to req
 * Used on all tenant-user protected routes
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Fetch fresh user data
    const result = await pool.query(
      `SELECT u.id, u.tenant_id, u.email, u.full_name, u.role, u.is_active,
              t.subscription_tier, t.subscription_status, t.business_name
       FROM users u
       JOIN tenants t ON t.id = u.tenant_id
       WHERE u.id = $1`,
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    if (user.subscription_status === 'suspended') {
      return res.status(403).json({
        error: 'Your subscription has been suspended. Please contact support.',
      });
    }

    req.user = user;
    req.tenantId = user.tenant_id;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
};

/**
 * Middleware to verify platform admin JWT
 * Used on /admin/* routes (Software Owner Dashboard)
 */
const authenticateAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    if (decoded.type !== 'platform_admin') {
      return res.status(403).json({ error: 'Access denied: not a platform admin' });
    }

    const result = await pool.query(
      `SELECT id, email, full_name, is_active FROM platform_admins WHERE id = $1`,
      [decoded.adminId]
    );

    if (result.rows.length === 0 || !result.rows[0].is_active) {
      return res.status(401).json({ error: 'Admin not found or deactivated' });
    }

    req.admin = result.rows[0];
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
};

/**
 * Role-based authorization factory
 * Usage: requireRole('owner', 'manager')
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Access denied. Required role(s): ${roles.join(', ')}`,
      });
    }
    next();
  };
};

/**
 * Subscription tier enforcement factory
 * Usage: requireTier('pro', 'enterprise')
 */
const requireTier = (...tiers) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    if (!tiers.includes(req.user.subscription_tier)) {
      return res.status(402).json({
        error: `This feature requires a ${tiers.join(' or ')} subscription.`,
        currentTier: req.user.subscription_tier,
        upgradeRequired: true,
      });
    }
    next();
  };
};

module.exports = { authenticate, authenticateAdmin, requireRole, requireTier };
