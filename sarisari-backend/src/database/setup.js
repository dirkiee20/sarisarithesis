require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const {
  getAdminDatabaseConfig,
  getDatabaseConfig,
} = require('../config/db-client-config');

function shouldSkipDatabaseCreate() {
  return (
    process.argv.includes('--skip-create') ||
    process.env.SKIP_DB_CREATE === 'true' ||
    process.env.SUPABASE_DB === 'true' ||
    Boolean(process.env.DATABASE_URL)
  );
}

function assertSafeDatabaseName(dbName) {
  if (!/^[a-zA-Z0-9_]+$/.test(dbName)) {
    throw new Error(
      'DB_NAME may only contain letters, numbers, and underscores when auto-creating a local database.'
    );
  }
}

async function createDatabaseIfNeeded(dbName) {
  if (shouldSkipDatabaseCreate()) {
    console.log('Skipping database creation; using existing database.');
    return;
  }

  assertSafeDatabaseName(dbName);

  const adminClient = new Client(getAdminDatabaseConfig());

  try {
    await adminClient.connect();
    console.log('Connected to PostgreSQL server.');

    const result = await adminClient.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [dbName]
    );

    if (result.rows.length === 0) {
      await adminClient.query(`CREATE DATABASE ${dbName}`);
      console.log(`Database "${dbName}" created.`);
    } else {
      console.log(`Database "${dbName}" already exists.`);
    }
  } finally {
    await adminClient.end();
  }
}

async function applySchema(dbName) {
  const dbClient = new Client(getDatabaseConfig({ database: dbName }));

  try {
    await dbClient.connect();
    console.log(`Connected to target database.`);

    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    await dbClient.query(schema);
    console.log('Schema applied successfully.');
    console.log('');
    console.log('Database setup complete.');
    console.log('');
    console.log('Default platform admin credentials:');
    console.log('  Email   : admin@sarisaripro.com');
    console.log('  Password: Admin@123456');
    console.log('  Change this password after first login.');
    console.log('');
  } finally {
    await dbClient.end();
  }
}

async function setupDatabase() {
  const dbName = process.env.DB_NAME || 'sarisari_pro';

  try {
    await createDatabaseIfNeeded(dbName);
    await applySchema(dbName);
  } catch (err) {
    console.error('Database setup failed:', err.message);
    process.exit(1);
  }
}

setupDatabase();
