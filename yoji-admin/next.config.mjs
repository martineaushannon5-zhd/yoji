/** @type {import('next').NextConfig} */
const nextConfig = {
  // 纯静态导出：next build 后把 out/ 目录丢给宝塔/Nginx 即可
  output: "export",

  // 生成 /dashboard/index.html 这种目录结构，Nginx 直接按目录访问更稳
  trailingSlash: true,

  // 静态导出不能用 Next 的图片优化服务
  images: {
    unoptimized: true,
  },

  reactStrictMode: true,
};

export default nextConfig;
