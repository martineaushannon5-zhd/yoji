# Yoji Admin

Yoji 背单词项目的后台管理系统。**阶段一：项目初始化与全局设计系统已完成。**

> 前端为纯静态导出，不跑 Next.js 服务端，也不在 Next.js 里连数据库。
> 所有数据都通过远程 Node API（`http://120.24.171.99`）获取。

## 技术栈

- Next.js 14（App Router，`output: "export"` 纯静态导出）
- TypeScript + Tailwind CSS 3
- Shadcn UI（Radix 版，classic registry）+ Lucide 图标
- 字体：[`@fontsource-variable/lora`](https://fontsource.org/fonts/lora) + [`@fontsource-variable/inter`](https://fontsource.org/fonts/inter)（构建时自托管，不依赖 Google Fonts 运行时）
- 后续阶段：Axios、SWR、Recharts

## 快速开始

```bash
cd yoji-admin
npm install
npm run dev      # 开发：http://localhost:3000
npm run build    # 静态导出到 yoji-admin/out/
npm start        # 本地预览 out/：http://localhost:4173
```

把 `out/` 整个目录上传到宝塔站点根目录即可，详细 Nginx 配置见阶段七。

## 阶段一完成内容

| 项 | 说明 |
| --- | --- |
| 项目初始化 | `create-next-app@14`，App Router + TS + Tailwind |
| 静态导出 | `next.config.mjs`：`output: "export"`、`trailingSlash: true`、图片不优化 |
| 设计系统 | `app/globals.css` 中的 Claude 色板 / 圆角 / 字体变量 |
| 字体 | Lora（标题衬线）+ Inter（正文无衬线），fontsource 本地打包 |
| 基础组件 | `components/ui/`：Button、Card、Input、Label、Badge、Table、Separator、Skeleton、DropdownMenu |
| 占位首页 | `app/page.tsx`：设计令牌与组件预览，后续阶段会被 Dashboard 替换 |

### Claude 风格令牌

| Token | 值 | 用途 |
| --- | --- | --- |
| Paper | `#F9F8F6` | 页面背景 |
| Ink | `#2D2A26` | 标题 / 正文 |
| Terracotta | `#D97757` | 主色 / 强调 |
| Border | `#E7E3DC` | 极细浅灰边框 |
| Radius | `0.75rem` | 卡片 / 输入框圆角 |
| Heading | Lora | 标题 |
| Body | Inter | 正文 |

色值以 HSL 变量写在 `app/globals.css`，Tailwind 通过 `hsl(var(--x) / <alpha-value>)` 引用，所以 `bg-card/80`、`text-terracotta` 这类写法都可用。

## 可复现的初始化命令

```bash
# 1. 创建项目
npx create-next-app@14 yoji-admin \
  --ts --tailwind --eslint --app --no-src-dir \
  --import-alias "@/*" --use-npm

# 2. 运行依赖
npm install axios swr recharts lucide-react \
  @fontsource-variable/inter @fontsource-variable/lora

# 3. Shadcn UI（固定 2.3.0，避免新版 registry 的 Tailwind 4 预设）
npx shadcn@2.3.0 init -d -y -f
npx shadcn@2.3.0 add button card input label badge table separator skeleton dropdown-menu -y
```

> Shadcn 4.x 的 `init` 会使用 `nova/vega/...` 预设并引入 Tailwind v4 风格的 CSS；本项目是 Next 14 + Tailwind 3，因此固定使用 `shadcn@2.3.0` 的 classic `new-york` registry。

## 目录结构

```
yoji-admin/
├─ app/
│  ├─ globals.css        # Claude 色板、字体变量、全局基础样式
│  ├─ layout.tsx         # 根布局、字体导入、metadata
│  └─ page.tsx           # 阶段一设计预览页
├─ components/ui/        # Shadcn 基础组件
├─ lib/utils.ts          # cn()
├─ next.config.mjs       # 静态导出配置
├─ tailwind.config.ts    # 语义色 / 字体 / 圆角 / 阴影
└─ out/                  # npm run build 产物（部署用）
```

## 与后端的关系

后端接口目前使用独立的 `X-Admin-Token` 鉴权，且还没有：

- `POST /api/admin/login`（管理员账号密码换 JWT）
- `GET /api/admin/users`（Bearer JWT 的用户列表）

阶段二/三会按约定接入 Axios；阶段五/六之前需要把后端 admin 鉴权补齐为 JWT，否则前端的 `Bearer token` 会 401。

### 部署前必须注意的两件事

1. **`yoji.zhdstudy.cyou` 当前未备案**。服务器在大陆阿里云，80/443 会被备案拦截（`Server: Beaver` / `Non-compliance ICP Filing`），后台静态站点也不能可靠地部署在这个域名上。正式部署前需要换已备案域名，或把后端/前端迁到境外/香港服务器。
2. **HTTPS 页面不能直接请求 `http://120.24.171.99`**，浏览器会按混合内容（Mixed Content）拦截。阶段七推荐在 Nginx 里把 `https://后台域名/api/` 反向代理到 `http://127.0.0.1:3000`，前端用同源 `/api`，既没有跨域也没有混合内容。

## 后续阶段

- [ ] 阶段二：Axios 实例 + Token 拦截器 + 401 跳转
- [ ] 阶段三：登录页 + 路由守卫
- [ ] 阶段四：Sidebar + Admin Layout
- [ ] 阶段五：Dashboard（SWR + Recharts）
- [ ] 阶段六：用户管理（Table + 搜索 + 删除）
- [ ] 阶段七：宝塔静态部署 + 反向代理 / 跨域方案
