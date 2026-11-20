---
name: yoji-dev
description: 在 Yoji.（要记单词）项目里开发、排障、验证时使用。覆盖鸿蒙 ArkTS App、Node/Express+SQLite 后台、Next.js/Electron 管理端三端的启动、测试、打包命令，以及词库上传、进度同步、视频访问等已踩过的坑。
---

# Yoji 三端开发速查

## 先判断改哪端

| 现象 | 先看 |
|---|---|
| 登录/同步/接口 4xx/5xx | `server/src/routes/*`、`server/src/auth.js` |
| 页面不显示新数据 | App 拉取时机（启动/手动刷新），未必是后端 bug |
| 管理端页面空白/接口跨域 | `yoji-admin/lib/axios.ts`、`NEXT_PUBLIC_API_ORIGIN` 是否 build 时注入 |
| 鸿蒙页面渲染/交互 | `entry/src/main/ets/pages/`、`view/`，ArkTS 类型限制 |

## server（Express + node:sqlite）

```bash
cd server
npm run dev                 # 127.0.0.1:3000，DB: data/yoji.db
npm test                    # 11 用例，临时库，约 1s
node --test --test-name-pattern "退出登录" test/api.test.mjs
```

- 本地手工验证：起服后 `curl -s -X POST localhost:3000/api/auth/register -H 'content-type: application/json' -d '{"username":"t1","password":"pass1234"}'`，拿 `token` 再打 `/api/auth/me`、`/api/progress`。
- 配置在 `server/src/config.js`：`PORT`、`DATA_DIR`、`MEDIA_DIR`、`JWT_SECRET`（生产必须 ≥32 字符）、`ADMIN_ACCOUNT`。**不要读/改 `.env`**，用 `.env.example` 了解键名。
- 管理员 token 12 小时过期，401 先怀疑过期而不是权限。
- 改 schema 要同步 `server/src/db.js` 的建表/迁移逻辑，并确认测试用临时库能建起来。

## yoji-admin（Next.js 静态导出 + Electron）

```bash
cd yoji-admin
npm run dev            # localhost:3000，与 server 默认端口冲突，需错开（server PORT=3100 或 next dev -p 3001）
npm run build          # 必须能过，产物 out/
npm run lint; npx tsc --noEmit
npm run electron:dev   # 联调
npm run electron:build # NSIS 安装包 → dist-release/
```

- `next.config.mjs`：`output: "export"` + `trailingSlash: true`，不能写 server actions / route handlers。
- `NEXT_PUBLIC_API_ORIGIN` 编进静态包，改接口地址后必须重新 build，改 `.env.local` 不重启 dev 也不生效。
- 打包走 npmmirror 镜像（脚本已设 `ELECTRON_MIRROR`），网络慢时别去掉。

## 鸿蒙 App（ArkTS）

```bat
build.bat    :: 需要 DevEco Studio（tools/node、jbr、sdk、hvigor）
```

- 目录：`pages/` 页面、`view/` 组件、`store/` 全局状态、`model/` 数据模型、`common/Api.ets` 网络。
- ArkTS 限制：禁 `any`/`unknown`/动态属性；接口返回先定义 interface 再 `as`；不能用 Node API。
- 真机/模拟器调试用 DevEco Studio 的 Log 面板或 `hdc hilog`；本仓库没有可命令行跑的单测，改完 UI 要说明在 DevEco 里怎么复现。
- 新增页面记得登记 `entry/src/main/resources/base/profile/main_pages.json`。

## 已踩过的坑（先查再动手）

1. **词库上传**：只收单个 `.txt`/`.json`、≤8MB、需管理员 JWT；zip/PDF/XLSX 直接被扩展名拦截。**同 id 整本替换**——只传一部分单词会"传一本少一本"。
2. **App 不刷新词书**：App 只在启动（`SplashPage`）或词书页手动刷新时拉 `/api/wordbooks/full`，后台传完不会推送。
3. **视频**：库里只存链接，mp4 由 Nginx 读磁盘（支持 Range）；迁移 OSS 的记录见 `工作流/09-视频迁移到OSS.md`。
4. **端口 3000**：server 与 `next dev` 默认都占 3000，同时开必须错开。
5. **`.txt` 词表**：解析出 `example`/`exampleCn` 为空，只有 JSON 能带例句；解析规则在 `server/src/wordlist-parse.js` 的 `WORD_RE`。

## 改完的验证清单

- server：`npm test` 全绿；新增接口补一个用例（照着 `server/test/api.test.mjs` 的写法）。
- admin：`npm run build` 通过 + 手动在 dev 里点一遍改动路径。
- app：`build.bat` 能出 HAP，或明确说明需要 DevEco 手工验证的步骤。
- 汇报按 `bugfix` 技能的四段：根因 / 改动 / 验证命令与结果 / 风险。