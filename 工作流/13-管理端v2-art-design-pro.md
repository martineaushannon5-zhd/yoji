# 13 - 管理端 v2：用 art-design-pro 重构

> 2026-11-20。目标：把原来的 Next.js 静态导出后台换成成熟的后台模板，补齐布局、主题、表格、图表与交互细节，同时保留 Yoji 的品牌、Y 图标与 Claude 暖色系。

## 1. 为什么换

旧后台（`yoji-admin/`，Next.js 14 + Electron）功能齐，但界面是手写的：侧边栏、标签页、面包屑、主题切换、表格空态都要自己维护，成熟度不够。`Daymychen/art-design-pro`（MIT）自带这些能力，且是 Vue 3 + Vite，构建更快、Electron 打包更简单。

旧后台代码保留在 `yoji-admin/`，新后台在 **`yoji-admin-v2/`**，互不影响；线上已切到 v2。

## 2. 技术栈与关键目录

- Vue 3.5 + Vite 7 + TypeScript 5.6 + Element Plus 2.11 + Pinia 3 + vue-router 4.5 + ECharts 6。
- 业务代码集中在：
  - `src/api/yoji.ts`：全部后端接口、类型、`mediaUrl()`、`uploadForm()`、`putToOss()`。
  - `src/views/yoji/{dashboard,users,videos,wordbooks,audit}/index.vue`：五个业务页。
  - `src/router/modules/yoji.ts`：五个路由，`src/router/modules/index.ts` 只导出它们，模板示例菜单不再注册。
  - `src/assets/styles/yoji-theme.scss`：Claude 暖色覆盖（`src/main.ts` 引入）。
  - `electron/main.cjs`：`app://` 自定义协议加载 `dist/`，不用 electron-serve。
  - `build/icon.png`：由 App 的 `appIcon.png`（512×512）复制而来，electron-builder 自动转 ico。

## 3. 后端契约适配

| 项 | 模板默认 | 本项目 |
| --- | --- | --- |
| 响应结构 | `{ code, msg, data }`，成功 200 | `{ code, message, data }`，成功 **0** |
| 鉴权头 | `Authorization: <token>` | `Authorization: Bearer <jwt>` |
| 登录 | `POST /api/auth/login` | `POST /api/admin/login`，body `{ account, password }` |
| 用户信息 | `GET /api/user/info` | 不请求，登录后从 `localStorage.yoji_admin_account` 构造 |
| 上传 | 模板示例 | 本地 multipart `/admin/videos/upload`；OSS 模式先 `/admin/media/sign` 再直传 |

`src/utils/http/index.ts` 已改：baseURL 固定 `https://yoji.zhdstudy.cyou/api`，成功码 0，错误 toast 取 `message || msg`，401 清 token 回登录页。

## 4. 品牌与主题

- 主色 `#C96442`（陶土），背景 `#F5F1E8`（奶油），卡片 `#FFFDF8`，正文 `#3F3A33`；`systemMainColor` 同时给了 7 个色阶，Element Plus 自动生成 `--el-color-primary`。
- `src/assets/images/common/logo.webp` 由 `entry/src/main/resources/base/media/appIcon.png` 转 256×256 webp（2.4KB），登录页与侧边栏共用。
- `index.html`：标题 `Yoji 管理后台`、描述、`/favicon.png`（App 图标），首屏底色改奶油色，避免刷新白闪。
- 登录页是左右分栏：左侧品牌叙事，右侧账号密码；文案“把每个单词变成一次真实的进步”。

## 5. 页面

| 路由 | 内容 |
| --- | --- |
| `/dashboard` | 4 张统计卡（注册/今日活跃/学习单词/视频）、14 天活跃与新增折线、最近操作、快捷入口 |
| `/users` | 搜索、导出 CSV、学习进度条、连续打卡、删除（二次确认）、分页 10/20/50 |
| `/videos` | 存储模式标签（OSS 直传/本地）、封面、排序、上下架、编辑、上传对话框（本地或 OSS 两条路径，带进度） |
| `/wordbooks` | 词库统计、上架开关、来源、预览前 50 词、上传 `.txt/.json`、删除 |
| `/audit` | 动作筛选、操作人搜索、动作徽章、分页 20/50/100 |

## 6. 构建与打包

```bash
cd yoji-admin-v2
npx -y pnpm@9.15.0 install --frozen-lockfile --registry=https://registry.npmmirror.com
npm run build                     # vue-tsc + vite build → dist/
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ \
  npx electron-builder --project "<绝对路径>"
```

踩过的坑：

1. **pnpm 不跑 postinstall**：`node_modules/electron/dist` 缺失，需在 `node_modules/electron` 里执行 `ELECTRON_MIRROR=... node install.js`。
2. **NSIS 路径超长**：`app-builder-lib@26.18.0_...\templates\nsis\include\StdUtils.nsh` 长 261 字符 > 260，报 `!include: could not open file`。把 electron-builder 装到短路径 `C:\eb`，再用 `npx electron-builder --project <绝对路径>`。
3. **asar 189MB**：模板的 30 个运行时依赖（vue、element-plus、echarts、xlsx…）被 electron-builder 当作生产依赖打进去。静态导出其实不需要，全部移到 `devDependencies`、`dependencies` 置空后，asar 8.7MB、安装包 141.9MB → **116.5MB**。
4. **默认 Electron 图标**：`build.win.icon = "build/icon.png"`（512×512）即可，electron-builder 自动转 ico，日志不再提示 `default Electron icon is used`。
5. **`app://` 下路由不切换**：模板 `art-page-content` 用 `<Transition mode="out-in">` 包 `RouterView`，在 Electron 窗口里过渡不结束，面包屑变了但页面内容停在上一个。去掉 Transition 包裹后正常（`src/components/core/layouts/art-page-content/index.vue`）。
6. **头像 404**：用户头像存的是 `/media/avatars/...` 相对路径，在 `app://` 下会拼成 `app://-/media/...`。统一走 `mediaUrl()` 拼 `API_ORIGIN`。

## 7. 验证

- 本地：`vite`（3106）+ headless Chrome CDP：登录跳转、五页行数（11 用户 / 6 视频 / 9 词库 43,775 词 / 审计）、无 console error、无横向溢出。
- 打包版：`app://-/` 登录后五页同上，`app://` 下 API 跨域正常；头像 11 张全部加载。
- 线上：`https://yoji.zhdstudy.cyou/` 登录 hans/123456 → 仪表盘、用户 11、视频 6、词库 9/43,775、审计 18，无报错。

## 8. 部署

```bash
tar czf /tmp/yoji-admin-v2-dist.tgz -C dist .
scp /tmp/yoji-admin-v2-dist.tgz root@120.24.171.99:/tmp/
ssh root@120.24.171.99
  tar czf /root/backups/yoji-admin-before-v2-$(date +%Y%m%d%H%M%S).tgz -C /www/wwwroot/yoji-admin .
  rm -rf /www/wwwroot/yoji-admin/*
  tar xzf /tmp/yoji-admin-v2-dist.tgz -C /www/wwwroot/yoji-admin
  chown -R www:www /www/wwwroot/yoji-admin
```

Nginx 无需改（root 仍是 `/www/wwwroot/yoji-admin`，`/api/` 仍反代 3000）。回滚：解压 `yoji-admin-before-v2-*.tgz` 覆盖即可。

## 9. 异常页、系统管理、版本计划、帮助中心

第一版上线后补齐的“成熟度”模块：

- **异常页**：403 / 404 / 500 改为中文文案，按钮统一“回到仪表盘”；404 仍是 `/:pathMatch(.*)*` 兜底，未登录时先跳登录再回目标页。
- **系统管理**（`/system`）：后端新增 `GET /api/admin/system`（`server/src/routes/adminPanel.js`），返回服务版本、Node 版本、环境、启动时间、运行时长、数据库与媒体占用、存储模式（local/oss）、桶名、内容规模与审计条数。前端四张指标卡 + 内容规模 + 环境检查（API/数据库/媒体/词库）+ 运行位置，排查问题时可直接复制路径。
- **版本计划**（`/roadmap`）：v1.0 → v1.4 时间线，支持“全部 / 已完成 / 未完成”筛选；未完成项写明下一步（词库逐词编辑、拖拽排序、离线、HDS、自动更新）。
- **帮助中心**（`/help`）：入口含“下载 App”（`https://yoji.zhdstudy.cyou/app/`）；8 条真实 FAQ（词库上传、上架不生效、封面裂图、登录过期、CSV 导出、审计范围、桌面端不热更新等），带关键词过滤；四个入口（Swagger、接口索引、仓库、版本计划）；底部“维护者备忘”列出 `revert-media-urls.mjs`、`pm2 restart` 等命令。
- 菜单从 5 项扩到 8 项；版本号统一为 **1.3.0**（`server/package.json`、`yoji-admin-v2/package.json`、OpenAPI `info.version`）。

验证：线上逐页 CDP 检查（system / roadmap / help / 404），打包版同样验证；`/admin/system` 返回 `version 1.3.0`、Node v24.22.0、数据库 6.5MB、媒体 654MB、词库 8/9 本 43,775 词。

重新打包：`dist-release4/Yoji Admin Setup 1.3.0.exe` 116,628,891 B、`app.asar` 8,881,800 B；换统一 App 图标并加下载入口后为 `dist-release6`：安装包 **116,667,508 B**、`app.asar` **9,003,447 B**；安装版登录后 system / videos / wordbooks 均正常。

## 10. 已知限制

- 模板示例页（`src/views/examples/**` 等）仍参与构建，主 chunk 1.4MB（gzip 464KB）；后续可按需删除。
- 桌面端未做自动更新与代码签名；安装包未签，SmartScreen 会提示。
- 词库仍只能整本上传覆盖，可视化逐词编辑未做。
- `/api` 索引排除文档自身端点，显示 36 条；OpenAPI 实际 33 path / 39 operation。