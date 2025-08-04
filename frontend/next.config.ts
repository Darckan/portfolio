import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /* config options here */
};

module.exports = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination:
          process.env.NEXT_PUBLIC_API_URL ?? 'http://{process.env.NEXT_PUBLIC_API_URL}/api/:path*',
      },
    ];
  },
};

export default nextConfig;
