import os from 'node:os';

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  'https://sarisarithesis-production.up.railway.app';

function getLocalDevOrigins() {
  const origins = new Set(['localhost', '127.0.0.1']);

  for (const entries of Object.values(os.networkInterfaces())) {
    for (const entry of entries || []) {
      if (entry.family !== 'IPv4' || entry.internal) continue;
      origins.add(entry.address);
    }
  }

  return [...origins];
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  allowedDevOrigins: getLocalDevOrigins(),
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${API_URL}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
