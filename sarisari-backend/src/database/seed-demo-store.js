require('dotenv').config();
const { Client } = require('pg');
const { getDatabaseConfig } = require('../config/db-client-config');

const OWNER_EMAIL = 'juan@sarisaristore.com';

const productSeeds = [
  {
    name: 'Lucky Me Pancit Canton',
    description: 'Instant noodles, calamansi flavor',
    category: 'Snacks',
    barcode: '4807770270011',
    costPrice: 14.5,
    sellingPrice: 18,
    stock: 72,
    imageUrl:
      'https://images.unsplash.com/photo-1617093727343-374698b1b08d?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Coca-Cola Mismo 290ml',
    description: 'Chilled soft drink bottle',
    category: 'Beverages',
    barcode: '4803925000012',
    costPrice: 13,
    sellingPrice: 16,
    stock: 64,
    imageUrl:
      'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Nescafe Original Sachet',
    description: 'Single-serve coffee sachet',
    category: 'Beverages',
    barcode: '4800361004825',
    costPrice: 6,
    sellingPrice: 8,
    stock: 95,
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'SkyFlakes Crackers',
    description: 'Classic crackers pack',
    category: 'Snacks',
    barcode: '4800016630217',
    costPrice: 7.5,
    sellingPrice: 10,
    stock: 88,
    imageUrl:
      'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Argentina Corned Beef 150g',
    description: 'Canned corned beef',
    category: 'Canned Goods',
    barcode: '4807770001127',
    costPrice: 28,
    sellingPrice: 35,
    stock: 41,
    imageUrl:
      'https://images.unsplash.com/photo-1585238342024-78d387f4a707?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Safeguard White Soap',
    description: 'Bath soap 135g',
    category: 'Personal Care',
    barcode: '4902430736618',
    costPrice: 24,
    sellingPrice: 30,
    stock: 37,
    imageUrl:
      'https://images.unsplash.com/photo-1607006483225-91d0c682a6b6?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Tide Powder 66g',
    description: 'Laundry detergent sachet',
    category: 'Household',
    barcode: '4902430912234',
    costPrice: 11,
    sellingPrice: 14,
    stock: 53,
    imageUrl:
      'https://images.unsplash.com/photo-1583947582886-f40ec95dd752?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Silver Swan Soy Sauce 200ml',
    description: 'Soy sauce bottle',
    category: 'Condiments',
    barcode: '4800068200031',
    costPrice: 18,
    sellingPrice: 24,
    stock: 29,
    imageUrl:
      'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Alaska Evaporada 370ml',
    description: 'Evaporated milk can',
    category: 'Canned Goods',
    barcode: '4800024000185',
    costPrice: 33,
    sellingPrice: 40,
    stock: 22,
    imageUrl:
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Marlboro Lights Stick',
    description: 'Single cigarette stick',
    category: 'Tobacco',
    barcode: '9000000000101',
    costPrice: 7,
    sellingPrice: 10,
    stock: 120,
    imageUrl:
      'https://images.unsplash.com/photo-1572010841053-21ec8f88f4f5?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Bear Brand Sterilized 110ml',
    description: 'Ready-to-drink milk',
    category: 'Beverages',
    barcode: '4800361410121',
    costPrice: 24,
    sellingPrice: 29,
    stock: 31,
    imageUrl:
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80',
  },
  {
    name: 'Piattos Cheese 40g',
    description: 'Potato crisps snack',
    category: 'Snacks',
    barcode: '4800016123456',
    costPrice: 18,
    sellingPrice: 22,
    stock: 46,
    imageUrl:
      'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=800&q=80',
  },
];

const expenseSeeds = [
  {
    title: '[SEED] Electric Bill',
    description: 'Weekly utility payment for store operations',
    amount: 1850,
    category: 'Utilities',
    daysAgo: 6,
  },
  {
    title: '[SEED] Restocking Transportation',
    description: 'Tricycle and delivery fees from wholesaler',
    amount: 420,
    category: 'Logistics',
    daysAgo: 5,
  },
  {
    title: '[SEED] Ice Supply',
    description: 'Daily ice delivery for chilled drinks',
    amount: 260,
    category: 'Operations',
    daysAgo: 4,
  },
  {
    title: '[SEED] Store Cleaning Supplies',
    description: 'Mop refill, bleach, and trash bags',
    amount: 315,
    category: 'Maintenance',
    daysAgo: 2,
  },
  {
    title: '[SEED] Mobile Load Float',
    description: 'Additional e-load wallet top-up',
    amount: 1000,
    category: 'Operations',
    daysAgo: 1,
  },
];

const transactionSeeds = [
  {
    daysAgo: 6,
    paymentMethod: 'cash',
    paymentAmount: 250,
    notes: '[SEED] Morning rush basket',
    items: [
      ['4807770270011', 3],
      ['4803925000012', 4],
      ['4800016630217', 2],
      ['9000000000101', 5],
    ],
  },
  {
    daysAgo: 5,
    paymentMethod: 'gcash',
    paymentAmount: 180,
    notes: '[SEED] Student snack run',
    items: [
      ['4800016123456', 3],
      ['4803925000012', 2],
      ['4800361004825', 4],
    ],
  },
  {
    daysAgo: 4,
    paymentMethod: 'cash',
    paymentAmount: 300,
    notes: '[SEED] Pantry refill order',
    items: [
      ['4807770001127', 2],
      ['4800068200031', 1],
      ['4800024000185', 2],
      ['4902430912234', 3],
    ],
  },
  {
    daysAgo: 3,
    paymentMethod: 'cash',
    paymentAmount: 150,
    notes: '[SEED] Neighborhood essentials',
    items: [
      ['4902430736618', 2],
      ['4902430912234', 2],
      ['4800361410121', 1],
      ['4800016630217', 2],
    ],
  },
  {
    daysAgo: 2,
    paymentMethod: 'credit',
    paymentAmount: 210,
    notes: '[SEED] Suki tab purchase',
    items: [
      ['4807770270011', 4],
      ['4803925000012', 3],
      ['4800361004825', 3],
      ['4800068200031', 1],
    ],
  },
  {
    daysAgo: 1,
    paymentMethod: 'gcash',
    paymentAmount: 200,
    notes: '[SEED] Evening combo sale',
    items: [
      ['4800016123456', 2],
      ['4803925000012', 3],
      ['4800361410121', 2],
      ['9000000000101', 4],
    ],
  },
  {
    daysAgo: 0,
    paymentMethod: 'cash',
    paymentAmount: 120,
    notes: '[SEED] Breakfast essentials',
    items: [
      ['4800361004825', 3],
      ['4800016630217', 2],
      ['4803925000012', 2],
    ],
  },
  {
    daysAgo: 0,
    paymentMethod: 'cash',
    paymentAmount: 500,
    notes: '[SEED] Family convenience haul',
    items: [
      ['4807770001127', 3],
      ['4800024000185', 2],
      ['4902430736618', 2],
      ['4902430912234', 2],
      ['4800068200031', 2],
    ],
  },
];

function toDate(daysAgo, hour) {
  const date = new Date();
  date.setHours(hour, 15, 0, 0);
  date.setDate(date.getDate() - daysAgo);
  return date;
}

async function main() {
  const client = new Client(getDatabaseConfig());

  await client.connect();

  const tenantResult = await client.query(
    `SELECT id, business_name FROM tenants WHERE owner_email = $1 LIMIT 1`,
    [OWNER_EMAIL]
  );

  if (tenantResult.rows.length === 0) {
    throw new Error(`Tenant for ${OWNER_EMAIL} not found`);
  }

  const tenant = tenantResult.rows[0];

  const userResult = await client.query(
    `SELECT id, role, full_name
     FROM users
     WHERE tenant_id = $1 AND role IN ('owner', 'cashier', 'staff')
     ORDER BY CASE role WHEN 'cashier' THEN 1 WHEN 'staff' THEN 2 ELSE 3 END, created_at ASC`,
    [tenant.id]
  );

  if (userResult.rows.length === 0) {
    throw new Error('No usable user found for seeded records');
  }

  const actingUser = userResult.rows[0];

  await client.query('BEGIN');

  try {
    for (const product of productSeeds) {
      await client.query(
        `INSERT INTO products
           (tenant_id, name, description, category, barcode, cost_price, selling_price, stock, image_url, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE)
         ON CONFLICT (tenant_id, barcode) DO UPDATE SET
           name = EXCLUDED.name,
           description = EXCLUDED.description,
           category = EXCLUDED.category,
           cost_price = EXCLUDED.cost_price,
           selling_price = EXCLUDED.selling_price,
           stock = EXCLUDED.stock,
           image_url = EXCLUDED.image_url,
           is_active = TRUE,
           updated_at = NOW()`,
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
    }

    await client.query(
      `DELETE FROM expenses
       WHERE tenant_id = $1
         AND title LIKE '[SEED] %'`,
      [tenant.id]
    );

    for (const expense of expenseSeeds) {
      await client.query(
        `INSERT INTO expenses
           (tenant_id, title, description, amount, category, expense_date, recorded_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          tenant.id,
          expense.title,
          expense.description,
          expense.amount,
          expense.category,
          toDate(expense.daysAgo, 18),
          actingUser.id,
        ]
      );
    }

    await client.query(
      `DELETE FROM transactions
       WHERE tenant_id = $1
         AND notes LIKE '[SEED] %'`,
      [tenant.id]
    );

    const productMapResult = await client.query(
      `SELECT id, name, barcode, cost_price, selling_price
       FROM products
       WHERE tenant_id = $1`,
      [tenant.id]
    );

    const productsByBarcode = new Map(
      productMapResult.rows.map((row) => [row.barcode, row])
    );

    for (let index = 0; index < transactionSeeds.length; index += 1) {
      const seed = transactionSeeds[index];
      const transactionDate = toDate(seed.daysAgo, 8 + index);

      let totalAmount = 0;
      let totalCost = 0;
      const items = seed.items.map(([barcode, quantity]) => {
        const product = productsByBarcode.get(barcode);
        if (!product) {
          throw new Error(`Seed product with barcode ${barcode} not found`);
        }

        const sellingPrice = parseFloat(product.selling_price);
        const costPrice = parseFloat(product.cost_price);
        const subtotal = sellingPrice * quantity;
        const itemCost = costPrice * quantity;
        const itemProfit = subtotal - itemCost;

        totalAmount += subtotal;
        totalCost += itemCost;

        return {
          productId: product.id,
          productName: product.name,
          quantity,
          sellingPrice,
          costPrice,
          subtotal,
          itemProfit,
        };
      });

      const totalProfit = totalAmount - totalCost;
      const paymentAmount = Math.max(seed.paymentAmount, totalAmount);
      const changeAmount = paymentAmount - totalAmount;

      const transactionResult = await client.query(
        `INSERT INTO transactions
           (tenant_id, total_amount, total_cost, total_profit, payment_method, payment_amount, change_amount, notes, transaction_date, created_by, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $9)
         RETURNING id`,
        [
          tenant.id,
          totalAmount.toFixed(2),
          totalCost.toFixed(2),
          totalProfit.toFixed(2),
          seed.paymentMethod,
          paymentAmount.toFixed(2),
          changeAmount.toFixed(2),
          seed.notes,
          transactionDate,
          actingUser.id,
        ]
      );

      const transactionId = transactionResult.rows[0].id;

      for (const item of items) {
        await client.query(
          `INSERT INTO transaction_items
             (transaction_id, product_id, product_name, quantity, selling_price, cost_price, subtotal, item_profit)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            transactionId,
            item.productId,
            item.productName,
            item.quantity,
            item.sellingPrice.toFixed(2),
            item.costPrice.toFixed(2),
            item.subtotal.toFixed(2),
            item.itemProfit.toFixed(2),
          ]
        );
      }
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }

  const summary = await client.query(
    `SELECT
       (SELECT COUNT(*)::int FROM products WHERE tenant_id = $1) AS products,
       (SELECT COUNT(*)::int FROM transactions WHERE tenant_id = $1) AS transactions,
       (SELECT COUNT(*)::int FROM expenses WHERE tenant_id = $1) AS expenses,
       (SELECT COALESCE(SUM(total_amount), 0) FROM transactions WHERE tenant_id = $1) AS revenue`,
    [tenant.id]
  );

  console.log('');
  console.log('Demo store seeded successfully.');
  console.log('Store:', tenant.business_name);
  console.log('Acting user:', actingUser.full_name, `(${actingUser.role})`);
  console.log('Products:', summary.rows[0].products);
  console.log('Transactions:', summary.rows[0].transactions);
  console.log('Expenses:', summary.rows[0].expenses);
  console.log('Revenue:', summary.rows[0].revenue);
  console.log('');

  await client.end();
}

main().catch((error) => {
  console.error('Failed to seed demo store:', error.message);
  process.exit(1);
});
