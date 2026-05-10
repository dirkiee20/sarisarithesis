const { Pool } = require('pg');
const { getDatabaseConfig } = require('./db-client-config');

const pool = new Pool(getDatabaseConfig());

pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL pool error:', err);
  process.exit(-1);
});

pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to PostgreSQL:', err.stack);
    return;
  }

  console.log(
    'Connected to PostgreSQL database:',
    process.env.DB_NAME || (process.env.DATABASE_URL ? 'DATABASE_URL' : 'sarisari_pro')
  );
  release();
});

module.exports = pool;
