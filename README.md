# Yoji.（要记单词）

一个面向英语单词学习的一体化项目，由**鸿蒙 App 本体、后台服务、Windows 桌面端**三个端组成：

| 端 | 形态 | 技术栈 | 目录 |
| --- | --- | --- | --- |
| 鸿蒙 App | HarmonyOS 手机应用 | ArkTS / ArkUI（Stage 模型，DevEco Studio） | `entry/`、`AppScope/` |
| 后台服务 | Linux 云服务器上的 HTTP API + 静态媒体 | Node.js 24、Express、SQLite（`node:sqlite`）、JWT、Nginx | `server/` |
| Windows 桌面端 | Electron 管理后台（NSIS 安装包） | Next.js 14 静态导出、TypeScript、Tailwind、Shadcn UI、Electron、electron-builder | `yoji-admin/` |

三端关系：App 通过 HTTPS 调用后台的 `/api/*` 完成注册登录、学习进度同步、词库与视频拉取；Windows 桌面端是同一套后台的运营入口，调用 `/api/admin/*` 管理用户、词库、视频和数据大盘。

## 一、鸿蒙 App 本体

「Yoji.（要记单词）」的 HarmonyOS 客户端，承担全部学习交互：

- 启动页、登录/注册、首页学习入口
- 词库选择与单词学习（学习页、单词列表）
- 学习视频列表、播放与收藏
- 学习日历、连续打卡天数
- 个人资料（头像、昵称、性别、生日）、收藏、自定义单词
- 登录后通过 `CloudSync` 把整份学习进度快照上传/合并到后台，多设备取并集，换账号自动隔离
- 后台不可用时使用内置词表兜底，不阻塞本地学习

构建方式：用 DevEco Studio 打开项目根目录，或执行根目录的 `build.bat` / `hvigorw assembleHap`。

主要目录：

```
entry/src/main/ets/
├─ pages/        SplashPage、LoginPage、Index、LearnPage、BookListPage、
│                WordListPage、CalendarPage、FavoritePage、FavoriteVideoPage、
│                VideoPlayPage、ProfileEditPage、AboutPage
├─ view/         各页面拆分的 UI 组件
├─ store/        全局状态、进度与账号隔离
├─ model/        数据模型
├─ common/       Config、Api、CloudSync 等网络与同步封装
└─ entryability/ 应用入口
```

## 二、后台服务（server）

给 App 和桌面端共用的账号与数据服务，目标是一台 2 核 2G / Ubuntu 22.04 服务器即可运行：

- Node.js 24 单进程，常驻内存约 60–100 MB
- SQLite 单文件数据库，无需 MySQL / Redis
- bcrypt 密码哈希；JWT（30 天）+ `token_version`，退出登录即时失效
- 学习进度快照按设备做并集合并，不互相覆盖
- 视频只在库里存链接，mp4 由 Nginx 直接读磁盘并支持 Range 拖动
- 内置后台管理接口（登录、统计、用户、视频、词库）与一键部署脚本

快速开始：

```bash
cd server
npm install
npm run dev        # 本地启动 API
npm test           # 接口冒烟测试
```

生产部署（Ubuntu + Nginx + HTTPS + systemd）见 [`server/README.md`](server/README.md)；App 端接入细节见 [`docs/backend-integration.md`](docs/backend-integration.md)。

## 三、Windows 桌面端（yoji-admin）

基于 Next.js 14 静态导出的管理后台，再由 Electron 包成 Windows 桌面应用：

- 管理员登录、路由守卫、Sidebar / Header 骨架
- 数据大盘：用户数、今日活跃、掌握单词数、14 天趋势图
- 用户管理：搜索、分页、删除
- 视频管理：上传视频/封面、编辑、显示隐藏、删除
- 词库管理：查看、上传 `.txt` / `.json` 词表、预览、启用隐藏、删除

开发与打包：

```bash
cd yoji-admin
npm install
npm run dev             # 浏览器开发：http://localhost:3000
npm run electron:dev    # Electron + Next.js 联调
npm run electron:build  # 构建 Windows NSIS 安装包（输出到 dist-installer/）
```

接口地址由 `NEXT_PUBLIC_API_ORIGIN` 控制（静态导出在 build 时写死）。页面、接口依赖与设计令牌详见 [`yoji-admin/README.md`](yoji-admin/README.md)。

## 目录结构

```
.
├─ AppScope/            应用级配置（包名、版本、图标）
├─ entry/               鸿蒙 App 源码（ArkTS 页面、组件、状态、网络）
├─ server/              后台服务（Express + SQLite + 部署脚本）
├─ yoji-admin/          Windows 桌面端（Next.js 管理后台 + Electron）
├─ docs/                需求、设计、部署、对接与功能说明
├─ 工作流/              项目规划、Electron 集成、打包测试等过程记录
├─ build-profile.json5  HarmonyOS 构建配置
└─ build.bat            Windows 下构建 HAP 的快捷脚本
```

## 换电脑 / 新环境：一条命令恢复

三端连接的**线上地址**本来就写在代码或已提交的 env 里，不需要每次重配：

| 端 | 位置 | 值 |
| --- | --- | --- |
| 鸿蒙 App | [`entry/src/main/ets/common/Config.ets`](entry/src/main/ets/common/Config.ets) 第 7 行 | `http://120.24.171.99` |
| 管理端（开发） | [`yoji-admin/lib/axios.ts`](yoji-admin/lib/axios.ts) 第 6–9 行读 `NEXT_PUBLIC_API_ORIGIN`，`.env.development` 已提交 | 线上 IP |
| 管理端（生产） | `yoji-admin/.env.production` 已提交，值为空 | 同源 `/api`，由 Nginx 反代 |
| 管理端 v2 | [`yoji-admin-v2/src/utils/http/index.ts`](yoji-admin-v2/src/utils/http/index.ts) 第 42 行 | `https://yoji.zhdstudy.cyou/api` |

真正**不在仓库里、clone 不会带走**的是机器级配置，所以新电脑要跑一次：

```powershell
.\setup.cmd                                        # 恢复双推 + 生成 server/.env + 装依赖
.\setup.cmd -GithubProxy http://127.0.0.1:10090    # 顺便写 GitHub 代理（按本机代理端口改）
.\setup.cmd -SkipInstall                           # 只修 git 配置，不装依赖
```

[`scripts/bootstrap.ps1`](scripts/bootstrap.ps1) 可重复执行，做的事：

| 步骤 | 说明 |
| --- | --- |
| 远程仓库 | `origin` fetch 指 GitHub，push 同时写 GitHub + Gitee；缺 `gitee` 远程则补上（`.git/config` 不在仓库里，这是换电脑必丢的一项） |
| 代理 | 传 `-GithubProxy` 时写入全局 `http.https://github.com.proxy`；已存在则保留 |
| 本地 env | 没有 `server/.env` 时生成开发配置，后台账号固定为 `admin` / `dev-admin-token` |
| 依赖 | `server`、`yoji-admin`、`yoji-admin-v2` 缺 `node_modules` 时执行 `npm install` |

换电脑后仍躲不掉的只有登录本身：Git 凭据（Windows 凭据管理器，第一次 push 时输入一次）和管理后台登录（token 存在浏览器 localStorage，换机器/换浏览器要重新登录一次）。

## 部署（2026-11-16 更新）

线上入口：<https://yoji.zhdstudy.cyou>，App 与管理端共用同一域名；API 走同域 `/api`，静态媒体走 `/media`。

| 项 | 值 |
| --- | --- |
| 服务器 | 阿里云深圳 ECS，2 核 2G，公网 `120.24.171.99` |
| Node | `/www/server/nodejs/v24.22.0/bin/node` |
| 后端进程 | PM2 `yoji_project`，代码在 `/www/wwwroot/yoji/server` |
| 管理端静态站 | `/www/wwwroot/yoji-admin`（Next.js `out/`） |
| Nginx 站点 | `/www/server/panel/vhost/nginx/node_yoji_project.conf` |
| 反向代理 | `location /api/` → `http://127.0.0.1:3000`（3000 不对外开放） |
| 视频 | 阿里云 OSS 深圳 Bucket，后台直传；`GET /api/admin/storage` 可查当前模式 |
| 备份 | `/root/backups` |

本次后端新增：

- OpenAPI 文档：`GET /api/openapi.json`、`GET /api/docs`，`GET /api` 返回分组索引
- 管理端审计日志（`/audit`）与用户 CSV 导出（UTF-8 BOM）
- 错词本 / 间隔复习（SRS）快照字段
- OSS 直传签名接口，视频不再占用服务器磁盘

日常发布顺序：server 先 `npm test` → 备份 → 覆盖 `src/` → `pm2 restart yoji_project`；admin 用 `NEXT_PUBLIC_API_ORIGIN=https://yoji.zhdstudy.cyou npm run build` 后覆盖静态目录。完整命令、验证结果、回滚方式和 `/api` 301 修复见 [`工作流/11-部署与运维记录.md`](工作流/11-部署与运维记录.md)。

## 文档

| 文档 | 内容 |
| --- | --- |
| [`docs/Yoji_需求分析文档.docx`](docs/Yoji_需求分析文档.docx) | 需求分析 |
| [`docs/Yoji_详细页面设计文档.docx`](docs/Yoji_详细页面设计文档.docx) | 详细页面设计 |
| [`docs/backend-integration.md`](docs/backend-integration.md) | App 与后台联调说明 |
| [`docs/api-modules-and-troubleshooting.md`](docs/api-modules-and-troubleshooting.md) | 接口模块与排障 |
| [`docs/deploy-admin-baota.md`](docs/deploy-admin-baota.md) | 管理后台线上部署 |
| [`server/README.md`](server/README.md) | 后台部署、接口与运维 |
| [`yoji-admin/README.md`](yoji-admin/README.md) | 桌面端页面、接口与打包 |
| [`工作流/`](工作流) | 各阶段工作流记录 |

## 仓库

- 远程仓库（`origin` 配置双推，`git push` 一次同步两边）：
  - GitHub：<https://github.com/martineaushannon5-zhd/yoji.git>
  - Gitee（老仓库）：<https://gitee.com/Liaohaoran1026/shixun-project>
- `gitee` 远程单独保留，便于拉取老仓库分支
- 主开发分支：`integration/v1.2.0-backend`

```bash
git clone https://github.com/martineaushannon5-zhd/yoji.git
git checkout integration/v1.2.0-backend
```