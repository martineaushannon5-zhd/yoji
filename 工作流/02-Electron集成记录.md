# 工作流 02：Electron 与 Next.js 集成

## 1. 最初的方案与坑

第一版（Gemini 生成）用了 `electron-serve` 加载静态导出的 `out` 目录：

```js
const serve = require("electron-serve");
const loadURL = serve({ directory: "out" });
```

开发时能跑，打包安装后直接报：

```
A JavaScript error occurred in the main process
Uncaught Exception: Error: Cannot find module 'electron-serve'
Require stack: ...\resources\app.asar
```

原因有两个：

1. `electron-serve@3.0.1` 是 **ESM** 包（`"type": "module"`），而主进程是 CommonJS，`require()` 本身就不稳；
2. 它被放在 `devDependencies` 里，electron-builder 打包时只收生产依赖，**根本没进 `app.asar`**，安装后自然找不到。

同时第一版把 `next`、`react`、`recharts` 等全部当成生产依赖打进了 asar：`app.asar` 有 **151MB**、包含 **17,785 个 node_modules 文件**，安装包 169MB，安装和启动都慢。

## 2. 改造方案：去掉 electron-serve，用内置 protocol

静态导出（`output: "export"`）的页面只依赖浏览器 API，运行时**不需要任何 node_modules**。所以直接删掉 `electron-serve`，用 Electron 自带的 `protocol.handle` 把 `app://` 映射到 `out` 目录：

```js
// main.js
const { net, protocol } = require("electron");
const ROOT = path.join(app.getAppPath(), "out");
const SCHEME = "app";
const HOST = "-";

protocol.registerSchemesAsPrivileged([
  { scheme: SCHEME, privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true, codeCache: true } },
]);

protocol.handle(SCHEME, async (request) => {
  const { pathname } = new URL(request.url);
  const filePath = path.join(ROOT, decodeURIComponent(pathname));
  // path.relative 防 ../ 穿越
  // 目录 -> index.html；带扩展名找不到 -> 404；无扩展名 -> 回退 index.html
  return net.fetch(pathToFileURL(target).toString());
});
```

生产环境 `mainWindow.loadURL("app://-/")`，开发环境仍然 `http://localhost:3000`。逻辑与 electron-serve 对齐：目录解析到 `index.html`、越界返回 404、带扩展名的静态资源找不到时 404（避免把 `.js` 回退成 HTML）、前端路由回退首页。

## 3. package.json 的关键调整

- 移除 `electron-serve`；
- 把 `next/react/recharts/axios/...` 全部移到 `devDependencies`（它们只在 `next build` 时用到，产物是静态文件）；
- `build.files` 只保留 `out/**/*`、`main.js`、`package.json`，electron-builder 不再打包 node_modules；
- `asar: true`、`compression: "maximum"`、`electronLanguages: ["zh-CN", "en-US"]`（只留中文和英文语言包）；
- NSIS 配置：`oneClick: true`、`perMachine: false`（装到用户目录，不需要管理员）、创建桌面/开始菜单快捷方式。

效果：`app.asar` 从 **151MB 降到 1.88MB**，安装包从 **169MB 降到约 112MB**，解压后从 631MB 降到约 311MB（其中大部分是 Electron 运行时本身）。

## 4. 开发与构建命令

```bash
npm run dev            # 只跑 Next.js（浏览器调试）
npm run electron:dev   # Next.js + Electron 联调（NODE_ENV=development）
npm run electron:start # 用已构建的 out 直接起 Electron（不打包）
npm run electron:build # 构建静态页面 + 打 Windows 安装包
```

`electron:build` 里已经固定了 `NEXT_PUBLIC_API_ORIGIN=https://yoji.zhdstudy.cyou`，桌面端直接请求线上 API，不需要本地起后端。

## 5. 经验

- 主进程依赖必须放 `dependencies`，否则打包后 `Cannot find module`；但静态站点场景更好的做法是**一个运行依赖都不要**。
- electron-serve 这类“小工具”并不值得为它引入 ESM/CJS 兼容问题，`protocol.handle` 十几行就能替代。
- 打包体积的大头通常是 node_modules，不是 Electron 本身；先看 `app.asar` 里装了什么。