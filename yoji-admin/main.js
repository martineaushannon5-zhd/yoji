const { app, BrowserWindow, Menu, net, protocol } = require("electron");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

// 自定义协议：app://-/ 映射到打包后的 out 静态目录
const SCHEME = "app";
const HOST = "-";
const ROOT = path.join(app.getAppPath(), "out");

// 必须在 app ready 之前注册协议权限
protocol.registerSchemesAsPrivileged([
  {
    scheme: SCHEME,
    privileges: {
      standard: true,
      secure: true,
      allowServiceWorkers: true,
      supportFetchAPI: true,
      corsEnabled: true,
      stream: true,
      codeCache: true,
    },
  },
]);

// 把目录解析到 index.html（/login/ -> /login/index.html）
async function resolveFile(target) {
  try {
    const stat = await fs.stat(target);
    if (stat.isFile()) {
      return target;
    }
    if (stat.isDirectory()) {
      return resolveFile(path.join(target, "index.html"));
    }
  } catch {
    // 文件不存在，交给调用方处理
  }
  return null;
}

// 用 protocol.handle 代替 electron-serve：
// 1. 少一个运行时依赖，打包后不会出现 Cannot find module 'electron-serve'
// 2. 逻辑与 electron-serve 一致：目录 -> index.html、越界拦截、找不到回退首页
function registerProtocol() {
  protocol.handle(SCHEME, async (request) => {
    const { pathname } = new URL(request.url);

    let decoded;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      return new Response(null, { status: 400, statusText: "Bad Request" });
    }

    const filePath = path.join(ROOT, decoded);
    const relative = path.relative(ROOT, filePath);

    // 防止 ../ 目录穿越，只能访问 out 内部
    if (relative.startsWith("..") || path.isAbsolute(relative)) {
      return new Response(null, { status: 404, statusText: "Not Found" });
    }

    const finalPath = await resolveFile(filePath);
    const ext = path.extname(filePath);

    // 带扩展名却找不到的文件直接 404，避免把 .js 请求回退成 html
    if (!finalPath && ext && ext !== ".html" && ext !== ".asar") {
      return new Response(null, { status: 404, statusText: "Not Found" });
    }

    // 无扩展名的路由（如 /login）回退到首页，交给前端路由处理
    const target = finalPath || path.join(ROOT, "index.html");
    return net.fetch(pathToFileURL(target).toString());
  });
}

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    backgroundColor: "#0f172a",
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      // 可以在此处添加 preload.js 以暴露特定的 Electron API
    },
  });

  // 隐藏默认菜单栏
  Menu.setApplicationMenu(null);

  if (process.env.NODE_ENV === "development") {
    // 开发环境下，直接加载 Next.js 的本地服务器
    mainWindow.loadURL("http://localhost:3000");
    // mainWindow.webContents.openDevTools();
  } else {
    // 生产环境下，加载打包好的 out 目录（app://-/）
    mainWindow.loadURL(`${SCHEME}://${HOST}/`);
  }

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  registerProtocol();
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});