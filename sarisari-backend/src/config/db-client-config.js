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

  const databaseUrl = process.env.DATABASE_URL || '';
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
  const config = {
    max: parseInt(process.env.DB_POOL_MAX || '10', 10),
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT_MS || '30000', 10),
    connectionTimeoutMillis: parseInt(
      process.env.DB_CONNECTION_TIMEOUT_MS || '10000',
      10
    ),
  };

  if (process.env.DATABASE_URL) {
    config.connectionString = process.env.DATABASE_URL;
  } else {
    config.host = process.env.DB_HOST || 'localhost';
    config.port = parseInt(process.env.DB_PORT || '5432', 10);
    config.database = options.database || process.env.DB_NAME || 'sarisari_pro';
    config.user = process.env.DB_USER || 'postgres';
    config.password = process.env.DB_PASSWORD;
  }

  const ssl = getSslConfig();
  if (ssl) {
    config.ssl = ssl;
  }

  return config;
}

function getAdminDatabaseConfig() {
  return {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    database: process.env.DB_ADMIN_DATABASE || 'postgres',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    ssl: getSslConfig(),
  };
}

module.exports = {
  getAdminDatabaseConfig,
  getDatabaseConfig,
};
