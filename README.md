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

- 远程仓库：<https://github.com/martineaushannon5-zhd/yoji.git>
- 主开发分支：`integration/v1.2.0-backend`

```bash
git clone https://github.com/martineaushannon5-zhd/yoji.git
git checkout integration/v1.2.0-backend
```