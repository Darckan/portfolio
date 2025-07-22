import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /* config options here */
};

module.exports = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: process.env.API_URL ?? 'http://backend:3050/api/:path*',
      },
    ];
  },
};

export default nextConfig;
