require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Client } = require('pg');
const { getDatabaseConfig } = require('../config/db-client-config');

// ── Credentials ──────────────────────────────────────────────
const MANAGER_EMAIL    = 'dirk@manager.com';
const MANAGER_PASSWORD = 'dirkgwapo';
const MANAGER_NAME     = 'Dirk Manager';
const BUSINESS_NAME    = "Dirk's Sari-Sari Store";
const OWNER_EMAIL      = 'dirk@owner.com'; // tenant owner email (required for tenant record)

// ── Products (with verified Unsplash image URLs) ─────────────
const productSeeds = [
  {
    name: 'Lucky Me Pancit Canton',
    description: 'Instant noodles, calamansi flavor',
    category: 'Snacks',
    barcode: 'DIRK-4807770270011',
    costPrice: 14.5,
    sellingPrice: 18,
    stock: 72,
    imageUrl: 'https://images.unsplash.com/photo-1617093727343-374698b1b08d?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Coca-Cola Mismo 290ml',
    description: 'Chilled soft drink bottle',
    category: 'Beverages',
    barcode: 'DIRK-4803925000012',
    costPrice: 13,
    sellingPrice: 16,
    stock: 64,
    imageUrl: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Nescafe Original Sachet',
    description: 'Single-serve coffee sachet',
    category: 'Beverages',
    barcode: 'DIRK-4800361004825',
    costPrice: 6,
    sellingPrice: 8,
    stock: 95,
    imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'SkyFlakes Crackers',
    description: 'Classic crackers pack',
    category: 'Snacks',
    barcode: 'DIRK-4800016630217',
    costPrice: 7.5,
    sellingPrice: 10,
    stock: 88,
    imageUrl: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Argentina Corned Beef 150g',
    description: 'Canned corned beef',
    category: 'Canned Goods',
    barcode: 'DIRK-4807770001127',
    costPrice: 28,
    sellingPrice: 35,
    stock: 41,
    imageUrl: 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Safeguard White Soap 135g',
    description: 'Antibacterial bath soap',
    category: 'Personal Care',
    barcode: 'DIRK-4902430736618',
    costPrice: 24,
    sellingPrice: 30,
    stock: 37,
    imageUrl: 'https://images.unsplash.com/photo-1607006483225-91d0c682a6b6?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Tide Powder Detergent 66g',
    description: 'Laundry detergent sachet',
    category: 'Household',
    barcode: 'DIRK-4902430912234',
    costPrice: 11,
    sellingPrice: 14,
    stock: 53,
    imageUrl: 'https://images.unsplash.com/photo-1583947582886-f40ec95dd752?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Silver Swan Soy Sauce 200ml',
    description: 'All-purpose soy sauce',
    category: 'Condiments',
    barcode: 'DIRK-4800068200031',
    costPrice: 18,
    sellingPrice: 24,
    stock: 29,
    imageUrl: 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Alaska Evaporada 370ml',
    description: 'Evaporated milk can',
    category: 'Canned Goods',
    barcode: 'DIRK-4800024000185',
    costPrice: 33,
    sellingPrice: 40,
    stock: 22,
    imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Piattos Cheese 40g',
    description: 'Potato crisps snack pack',
    category: 'Snacks',
    barcode: 'DIRK-4800016123456',
    costPrice: 18,
    sellingPrice: 22,
    stock: 46,
    imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Milo Energy Drink Sachet',
    description: 'Chocolate malt energy drink',
    category: 'Beverages',
    barcode: 'DIRK-4800361000001',
    costPrice: 9,
    sellingPrice: 12,
    stock: 80,
    imageUrl: 'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Oishi Prawn Crackers 60g',
    description: 'Light and crispy prawn chips',
    category: 'Snacks',
    barcode: 'DIRK-4800016999001',
    costPrice: 16,
    sellingPrice: 20,
    stock: 55,
    imageUrl: 'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Century Tuna in Oil 155g',
    description: 'Canned tuna flakes in oil',
    category: 'Canned Goods',
    barcode: 'DIRK-4800048000023',
    costPrice: 26,
    sellingPrice: 34,
    stock: 33,
    imageUrl: 'https://images.unsplash.com/photo-1601628828688-632f38a5a7d0?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Sprite Regular 355ml Can',
    description: 'Lemon-lime carbonated soda',
    category: 'Beverages',
    barcode: 'DIRK-4803925000099',
    costPrice: 20,
    sellingPrice: 25,
    stock: 48,
    imageUrl: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Knorr Sinigang Mix 22g',
    description: 'Tamarind soup base sachet',
    category: 'Condiments',
    barcode: 'DIRK-4800016080001',
    costPrice: 8,
    sellingPrice: 12,
    stock: 60,
    imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=800&q=80',
  },
];

async function main() {
  const client = new Client(getDatabaseConfig());
  await client.connect();

  console.log('');
  console.log('🌱 Seeding Dirk\'s store...');

  await client.query('BEGIN');

  try {
    // ── 1. Create or get the tenant ─────────────────────────
    const tenantResult = await client.query(
      `INSERT INTO tenants (business_name, owner_email, subscription_tier, subscription_status)
       VALUES ($1, $2, 'pro', 'active')
       ON CONFLICT (owner_email) DO UPDATE SET business_name = EXCLUDED.business_name
       RETURNING id, business_name`,
      [BUSINESS_NAME, OWNER_EMAIL]
    );
    const tenant = tenantResult.rows[0];
    console.log(`✅ Tenant: ${tenant.business_name} (${tenant.id})`);

    // ── 2. Create the manager user ──────────────────────────
    const passwordHash = await bcrypt.hash(MANAGER_PASSWORD, 12);
    const userResult = await client.query(
      `INSERT INTO users (tenant_id, email, password_hash, full_name, role, is_active)
       VALUES ($1, $2, $3, $4, 'manager', TRUE)
       ON CONFLICT (email) DO UPDATE SET
         password_hash = EXCLUDED.password_hash,
         full_name     = EXCLUDED.full_name,
         role          = 'manager',
         is_active     = TRUE
       RETURNING id, email, role`,
      [tenant.id, MANAGER_EMAIL, passwordHash, MANAGER_NAME]
    );
    const user = userResult.rows[0];
    console.log(`✅ Manager user: ${user.email} (role: ${user.role})`);

    // ── 3. Seed products ────────────────────────────────────
    let productCount = 0;
    for (const product of productSeeds) {
      await client.query(
        `INSERT INTO products
           (tenant_id, name, description, category, barcode, cost_price, selling_price, stock, image_url, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE)
         ON CONFLICT (tenant_id, barcode) DO UPDATE SET
           name          = EXCLUDED.name,
           description   = EXCLUDED.description,
           category      = EXCLUDED.category,
           cost_price    = EXCLUDED.cost_price,
           selling_price = EXCLUDED.selling_price,
           stock         = EXCLUDED.stock,
           image_url     = EXCLUDED.image_url,
           is_active     = TRUE,
           updated_at    = NOW()`,
        [
          tenant.id,
          product.name,
          product.description,
          product.category,
          product.barcode,
          product.costPrice,
          product.sellingPrice,
          product.stock,
          product.imageUrl,
        ]
      );
      productCount++;
    }
    console.log(`✅ Products seeded: ${productCount}`);

    await client.query('COMMIT');

    console.log('');
    console.log('══════════════════════════════════════════');
    console.log('  Seed complete for Dirk\'s Store!');
    console.log('══════════════════════════════════════════');
    console.log('  Store    :', tenant.business_name);
    console.log('  Email    :', MANAGER_EMAIL);
    console.log('  Password :', MANAGER_PASSWORD);
    console.log('  Role     : manager');
    console.log('  Products :', productCount);
    console.log('══════════════════════════════════════════');
    console.log('');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  }

  await client.end();
}

main().catch((err) => {
  console.error('❌ Seed failed:', err.message);
  process.exit(1);
});
