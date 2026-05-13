const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://postgres.ioywqgnpervijvrdrsoh:SarisariStore%4020@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

async function seed() {
  try {
    const userRes = await pool.query("SELECT id, tenant_id FROM users WHERE email = $1", ['dirk@manager.com']);
    if (userRes.rowCount === 0) {
      console.log("User not found!");
      return;
    }
    
    const userId = userRes.rows[0].id;
    const tenantId = userRes.rows[0].tenant_id;
    console.log("Found tenant:", tenantId);
    
    // Check if we already have some recent summaries to avoid duplicating too much
    await pool.query("DELETE FROM cashier_daily_summaries WHERE tenant_id = $1", [tenantId]);
    await pool.query("DELETE FROM cashier_product_summaries WHERE tenant_id = $1", [tenantId]);
    console.log("Cleared old summaries for tenant.");

    // Create 30 days of summaries
    const summaries = [];
    const now = new Date();
    
    for (let i = 0; i < 30; i++) {
      const date = new Date(now);
      date.setDate(now.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      
      const transactions = Math.floor(Math.random() * 20) + 15; // 15 to 35
      const revenue = Math.floor(Math.random() * 1000) + 1000; // 1000 to 2000
      const cost = revenue * 0.7;
      const profit = revenue - cost;
      
      await pool.query(`
        INSERT INTO cashier_daily_summaries (
          tenant_id, cashier_user_id, cashier_key, summary_date, 
          transaction_count, items_sold_count, gross_revenue, net_revenue, 
          total_cost, gross_profit, cash_sales, gcash_sales
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      `, [
        tenantId, userId, 'device-1', dateStr,
        transactions, transactions * 2, revenue, revenue,
        cost, profit, revenue * 0.8, revenue * 0.2
      ]);
      
      // Add a couple of product summaries
      await pool.query(`
        INSERT INTO cashier_product_summaries (
          tenant_id, cashier_summary_id, cashier_key, product_key, product_name, 
          summary_date, units_sold, sales_revenue, gross_profit
        ) 
        SELECT $1, id, 'device-1', 'prod-1', 'Coke 1.5L', $2, $3, $4, $5
        FROM cashier_daily_summaries 
        WHERE tenant_id = $1 AND summary_date = $2 LIMIT 1
      `, [
        tenantId, dateStr, Math.floor(Math.random() * 5) + 2, 350, 100
      ]);
    }
    
    console.log("Successfully seeded 30 days of data!");
  } catch (err) {
    console.error("Error seeding:", err);
  } finally {
    pool.end();
  }
}

seed();
