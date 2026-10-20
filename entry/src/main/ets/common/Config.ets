// 后端地址（末尾不要带 /）
//
// 临时调试方案：域名 yoji.zhdstudy.cyou 在阿里云大陆服务器上未备案，
// 80 端口会被备案拦截页（Server: Beaver）挡住，443 的 TLS 也对鸿蒙不兼容。
// 用「公网 IP + HTTP」可以绕过域名备案拦截，但密码/token 会明文传输，
// 仅限课程演示/内网联调；正式上线必须换成已备案域名 + HTTPS。
export const API_BASE_URL: string = 'http://120.24.171.99';
