const { app, BrowserWindow, Menu, net, protocol } = require('electron')
const fs = require('node:fs/promises')
const path = require('node:path')
const { pathToFileURL } = require('node:url')

// 自定义协议：app://-/ 映射到打包后的 dist 静态目录
const SCHEME = 'app'
const HOST = '-'
const ROOT = path.join(app.getAppPath(), 'dist')

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
      codeCache: true
    }
  }
])

// 把目录解析到 index.html（/login/ -> /login/index.html）
async function resolveFile(target) {
  try {
    const stat = await fs.stat(target)
    if (stat.isFile()) return target
    if (stat.isDirectory()) return resolveFile(path.join(target, 'index.html'))
  } catch {
    // 文件不存在，交给调用方处理
  }
  return null
}

// 目录 -> index.html、越界拦截、带扩展名缺失 404、其余回退首页
function registerProtocol() {
  protocol.handle(SCHEME, async (request) => {
    const { pathname } = new URL(request.url)

    let decoded
    try {
      decoded = decodeURIComponent(pathname)
    } catch {
      return new Response(null, { status: 400, statusText: 'Bad Request' })
    }

    const filePath = path.join(ROOT, decoded)
    const relative = path.relative(ROOT, filePath)
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      return new Response(null, { status: 404, statusText: 'Not Found' })
    }

    const finalPath = await resolveFile(filePath)
    const ext = path.extname(filePath)
    if (!finalPath && ext && ext !== '.html' && ext !== '.asar') {
      return new Response(null, { status: 404, statusText: 'Not Found' })
    }

    const target = finalPath || path.join(ROOT, 'index.html')
    return net.fetch(pathToFileURL(target).toString())
  })
}

let mainWindow

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 980,
    minHeight: 640,
    backgroundColor: '#f5f1e8',
    title: 'Yoji 管理后台',
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  Menu.setApplicationMenu(null)

  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:3006')
  } else {
    mainWindow.loadURL(`${SCHEME}://${HOST}/`)
  }

  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

app.whenReady().then(() => {
  registerProtocol()
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})