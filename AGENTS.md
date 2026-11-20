# AGENTS.md — Yoji.（要记单词）

三端一体项目：**鸿蒙 App（ArkTS/ArkUI）** + **Node 24 后台（Express + `node:sqlite`）** + **Windows 管理端（Next.js 14 静态导出 + Electron）**。
远程仓库 `https://github.com/martineaushannon5-zhd/yoji.git`，主开发分支 `integration/v1.2.0-backend`。

## 命令

| 端 | 用途 | 命令（在对应目录） |
| --- | --- | --- |
| server | 启动 API | `cd server && npm run dev`（默认 `127.0.0.1:3000`，DB 在 `server/data/yoji.db`） |
| server | 测试 | `cd server && npm test`（`node --test test/api.test.mjs`，11 个用例，约 1s，用临时库） |
| server | 单用例 | `node --test --test-name-pattern "登录" test/api.test.mjs` |
| server | 种子/导入 | `npm run seed`、`npm run import-wordbooks`、`npm run sync-media` |
| yoji-admin | 开发 | `cd yoji-admin && npm run dev`（`http://localhost:3000`） |
| yoji-admin | 构建 | `npm run build` → 静态导出到 `out/` |
| yoji-admin | 检查 | `npm run lint`、`npx tsc --noEmit` |
| yoji-admin | 桌面端 | `npm run electron:dev`；打包 `npm run electron:build`（`NEXT_PUBLIC_API_ORIGIN` 在 build 时写死） |
| App | 构建 HAP | 根目录 `build.bat`（或 `hvigorw assembleHap`，需 DevEco Studio 的 node/hvigor/SDK） |

## 约定

- **server 是 ESM**（`"type": "module"`），用 `import`，不要写成 CommonJS。
- **App 是 ArkTS**：不用 `any`/`unknown`、不用动态属性访问；对象字面量先声明 interface；页面在 `entry/src/main/ets/pages/`，组件在 `view/`，状态在 `store/`，网络在 `common/Api.ets`。
- **yoji-admin 是纯静态导出**（`output: "export"`）：不能依赖服务端渲染/路由 handler；数据请求全部客户端 axios/SWR。
- 接口地址由 `NEXT_PUBLIC_API_ORIGIN` 控制，**build 时注入**，改地址必须重新 build。
- 词库接口：一次一个文件、仅 `.txt`/`.json`、≤8MB、需管理员 JWT；同名 id **整本替换**，不是追加。
- 数据库是单文件 SQLite；测试用临时库，不要拿 `server/data/yoji.db` 做实验。

## 工作纪律

- **当前工作区有未提交改动**（App 页面、server 路由等）。动手前先 `git status` 看清归属，不要 revert、不要擅自 commit 别人的改动。
- 修 bug 按 `bugfix` 技能：先复现（有失败用例）→ 定位根因 → 最小改动 → `npm test` / 相关命令验证 → 汇报根因/改动/验证/风险。
- 不提交 `.env`、密钥、`node_modules`、构建产物（`out/`、`dist-*`）。
- 项目排障记录在 `工作流/*.md`，动手前先查是否已有同类问题的结论。

## 禁止

- 不改 `oh-package-lock.json5`、`package-lock.json`、`pnpm-lock.yaml`（除非明确升级依赖并说明）。
- 不删除或跳过失败测试；不用 `--no-verify`。
- 不在 `entry/src/main/ets` 里引入 Node 内置模块或动态 `eval`（ArkTS 运行时不支持）。