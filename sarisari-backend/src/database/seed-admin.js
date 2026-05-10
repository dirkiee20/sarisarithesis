require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Client } = require('pg');
const { getDatabaseConfig } = require('../config/db-client-config');

async function seedAdmin() {
  const client = new Client(getDatabaseConfig());

  await client.connect();

  const email = 'admin@sarisaripro.com';
  const password = 'Admin@123456';
  const hash = await bcrypt.hash(password, 12);

  await client.query(
    `INSERT INTO platform_admins (email, password_hash, full_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (email) DO UPDATE SET password_hash = $2`,
    [email, hash, 'Platform Administrator']
  );

  console.log('✅ Platform admin seeded successfully!');
  console.log('   Email   :', email);
  console.log('   Password:', password);

  await client.end();
}

seedAdmin().catch((err) => {
  console.error('❌ Error seeding admin:', err.message);
  process.exit(1);
});
