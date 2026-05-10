function getEnvValue(names) {
  for (const name of names) {
    const value = process.env[name];
    if (value) return value;
  }

  return undefined;
}

function getConnectionString() {
  return getEnvValue([
    'DATABASE_URL',
    'DATABASE_PRIVATE_URL',
    'DATABASE_PUBLIC_URL',
    'POSTGRES_URL',
    'POSTGRES_PRIVATE_URL',
    'POSTGRES_PUBLIC_URL',
  ]);
}

function useSsl() {
  const value = String(
    process.env.DB_SSL || process.env.PGSSLMODE || ''
  ).toLowerCase();

  if (
    ['1', 'true', 'require', 'required', 'verify-ca', 'verify-full'].includes(
      value
    )
  ) {
    return true;
  }

  const databaseUrl = getConnectionString() || '';
  return /supabase\.(co|com)|pooler\.supabase\.(co|com)/i.test(databaseUrl);
}

function getSslConfig() {
  if (!useSsl()) return undefined;

  const mode = String(process.env.PGSSLMODE || process.env.DB_SSL || '')
    .toLowerCase();
  const shouldVerify = mode === 'verify-ca' || mode === 'verify-full';

  return { rejectUnauthorized: shouldVerify };
}

function getDatabaseConfig(options = {}) {
  const connectionString = getConnectionString();
  const host = getEnvValue(['DB_HOST', 'PGHOST']);
  const database = options.database || getEnvValue(['DB_NAME', 'PGDATABASE']);
  const user = getEnvValue(['DB_USER', 'PGUSER']);
  const password = getEnvValue(['DB_PASSWORD', 'PGPASSWORD']);

  if (
    process.env.NODE_ENV === 'production' &&
    !connectionString &&
    !host
  ) {
    throw new Error(
      'Production database configuration is missing. Set DATABASE_URL for Supabase, or attach a Railway Postgres service and expose DATABASE_PRIVATE_URL/POSTGRES_URL/PGHOST variables.'
    );
  }

  const config = {
    max: parseInt(process.env.DB_POOL_MAX || '10', 10),
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT_MS || '30000', 10),
    connectionTimeoutMillis: parseInt(
      process.env.DB_CONNECTION_TIMEOUT_MS || '10000',
      10
    ),
  };

  if (connectionString) {
    config.connectionString = connectionString;
  } else {
    config.host = host || 'localhost';
    config.port = parseInt(getEnvValue(['DB_PORT', 'PGPORT']) || '5432', 10);
    config.database = database || 'sarisari_pro';
    config.user = user || 'postgres';
    config.password = password;
  }

  const ssl = getSslConfig();
  if (ssl) {
    config.ssl = ssl;
  }

  return config;
}

function getAdminDatabaseConfig() {
  return {
    host: getEnvValue(['DB_HOST', 'PGHOST']) || 'localhost',
    port: parseInt(getEnvValue(['DB_PORT', 'PGPORT']) || '5432', 10),
    database: process.env.DB_ADMIN_DATABASE || 'postgres',
    user: getEnvValue(['DB_USER', 'PGUSER']) || 'postgres',
    password: getEnvValue(['DB_PASSWORD', 'PGPASSWORD']),
    ssl: getSslConfig(),
  };
}

module.exports = {
  getConnectionString,
  getAdminDatabaseConfig,
  getDatabaseConfig,
};
