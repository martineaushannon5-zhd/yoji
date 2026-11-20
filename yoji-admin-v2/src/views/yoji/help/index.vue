<!-- Yoji 帮助中心 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">HELP CENTER</p>
        <h1>帮助中心</h1>
        <p class="sub">常见问题、常用入口和维护手册，先在这里找答案</p>
      </div>
      <ElInput v-model="keyword" class="search" placeholder="搜索问题，例如：词库、视频、登录" clearable>
        <template #prefix><ArtSvgIcon icon="ri:search-line" /></template>
      </ElInput>
    </header>

    <section class="links">
      <a v-for="link in links" :key="link.title" class="link-card" :href="link.href" target="_blank" rel="noreferrer">
        <ArtSvgIcon :icon="link.icon" class="link-icon" />
        <div>
          <p>{{ link.title }}</p>
          <span>{{ link.desc }}</span>
        </div>
        <ArtSvgIcon icon="ri:arrow-right-up-line" class="link-arrow" />
      </a>
    </section>

    <ElCard class="panel-card" shadow="never">
      <template #header>
        <div class="card-head"><span>常见问题</span><small>{{ filtered.length }} 条</small></div>
      </template>
      <ElCollapse v-model="opened" accordion>
        <ElCollapseItem v-for="faq in filtered" :key="faq.q" :name="faq.q">
          <template #title>
            <span class="faq-title">{{ faq.q }}</span>
          </template>
          <p class="faq-answer">{{ faq.a }}</p>
        </ElCollapseItem>
      </ElCollapse>
      <p v-if="!filtered.length" class="empty">没有匹配的问题，换个关键词试试。</p>
    </ElCard>

    <ElCard class="panel-card" shadow="never">
      <template #header>
        <div class="card-head"><span>维护者备忘</span><small>只在排查时用</small></div>
      </template>
      <ul class="ops-list">
        <li><b>看服务状态</b><span>系统管理页：版本、Node、数据库与媒体占用、存储模式</span></li>
        <li><b>看接口定义</b><span>打开 <code>/api/docs</code>（Swagger）或 <code>/api/openapi.json</code></span></li>
        <li><b>回滚媒体地址</b><span><code>node scripts/revert-media-urls.mjs data/yoji.db --from=&lt;前缀&gt; --to=/media --apply</code></span></li>
        <li><b>重启后端</b><span><code>pm2 restart yoji_project</code>，随后刷新本页确认版本与运行时长</span></li>
      </ul>
    </ElCard>
  </div>
</template>

<script setup lang="ts">
  import { computed, ref } from 'vue'

  defineOptions({ name: 'YojiHelp' })

  const keyword = ref('')
  const opened = ref('')

  const links = [
    {
      title: '下载 App',
      desc: '鸿蒙安装包与安装说明',
      href: 'https://yoji.zhdstudy.cyou/app/',
      icon: 'ri:smartphone-line'
    },
    {
      title: 'API 文档',
      desc: 'Swagger UI，可直接试接口',
      href: 'https://yoji.zhdstudy.cyou/api/docs',
      icon: 'ri:book-open-line'
    },
    {
      title: '接口索引',
      desc: '按模块分组的 JSON 索引',
      href: 'https://yoji.zhdstudy.cyou/api',
      icon: 'ri:list-check'
    },
    {
      title: '运维手册',
      desc: '部署、回滚、日常流程',
      href: 'https://github.com/martineaushannon5-zhd/yoji',
      icon: 'ri:tools-line'
    },
    {
      title: '版本计划',
      desc: '看接下来要做什么',
      href: '#/roadmap',
      icon: 'ri:route-line'
    }
  ]

  const faqs = [
    {
      q: '词库上传失败怎么办？',
      a: '一次只能传一个 .txt 或 .json 文件，大小不超过 8MB；zip、PDF、Excel 都会被拦下。同名 id 是整本替换而不是追加，确认好再传。传完到 App 的词库页下拉刷新。'
    },
    {
      q: '后台上架了词库，App 里为什么没有？',
      a: '先确认词库列表里的“上架”开关是打开的，再在 App 启动时或词库页点刷新。App 只在这些时机拉取 /api/wordbooks/full，不会后台自动同步。'
    },
    {
      q: '视频封面裂开、点开无法播放？',
      a: '先到系统管理看“媒体存储”是本地还是 OSS。如果是 OSS，可能是账号或桶被停用（会返回 403 UserDisable）；此时跑 revert-media-urls.mjs 把地址切回 /media，再 pm2 restart。本地模式则检查 Nginx 的 /media/ 是否可访问。'
    },
    {
      q: '管理员登录提示账号或密码错误？',
      a: '管理员账号来自服务器 .env 的 ADMIN_ACCOUNT 与 ADMIN_TOKEN（token 同时作为兼容密码）。改完 .env 需要 pm2 restart yoji_project 才生效。'
    },
    {
      q: '登录状态多久过期？',
      a: '管理端 JWT 默认 12 小时，过期后会自动回到登录页。普通用户 App 的 token 是 30 天。'
    },
    {
      q: '怎么导出用户数据？',
      a: '用户管理页右上角“导出 CSV”，会按当前搜索条件导出，带 BOM，Excel 打开中文不乱码。'
    },
    {
      q: '审计日志记录了哪些操作？',
      a: '管理员登录成功/失败、用户删除、CSV 导出、视频上传/新建/修改/删除、词库上传/修改/删除。每条记录操作人、对象、详情、IP 和时间。'
    },
    {
      q: '后台页面改了，桌面端为什么没变化？',
      a: '桌面端是静态导出后打进 asar 的，不会热更新。需要重新 npm run build + electron-builder，再安装新包。'
    }
  ]

  const filtered = computed(() => {
    const key = keyword.value.trim().toLowerCase()
    if (!key) return faqs
    return faqs.filter((item) => `${item.q} ${item.a}`.toLowerCase().includes(key))
  })
</script>

<style scoped lang="scss">
  .yoji-page {
    padding: 4px 2px 24px;
  }

  .page-head {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 18px;
  }

  .eyebrow {
    margin: 0 0 6px;
    font-size: 11px;
    letter-spacing: 0.22em;
    color: #b07050;
  }

  h1 {
    margin: 0;
    font-family: 'Songti SC', Georgia, serif;
    font-size: 28px;
    font-weight: 600;
  }

  .sub {
    margin: 8px 0 0;
    font-size: 13px;
    color: var(--art-gray-500);
  }

  .search {
    max-width: 300px;
  }

  .links {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin-bottom: 14px;
  }

  .link-card {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 14px 16px;
    color: inherit;
    text-decoration: none;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
    transition: border-color 0.2s;

    &:hover {
      border-color: #c96442;
    }

    p {
      margin: 0 0 2px;
      font-size: 13px;
      font-weight: 600;
    }

    span {
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  .link-icon {
    color: #c96442;
  }

  .link-arrow {
    margin-left: auto;
    color: var(--art-gray-300);
  }

  .panel-card {
    margin-bottom: 14px;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .card-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    font-size: 14px;
    font-weight: 600;

    small {
      font-size: 11px;
      font-weight: 400;
      color: var(--art-gray-400);
    }
  }

  .faq-title {
    font-size: 13px;
    color: var(--art-gray-800);
  }

  .faq-answer {
    margin: 0;
    font-size: 13px;
    line-height: 1.8;
    color: var(--art-gray-500);
  }

  .empty {
    padding: 24px 0;
    font-size: 13px;
    color: var(--art-gray-400);
    text-align: center;
  }

  .ops-list {
    margin: 0;
    padding: 0;
    list-style: none;

    li {
      display: flex;
      gap: 14px;
      padding: 8px 0;
      font-size: 13px;
      border-bottom: 1px dashed var(--art-card-border);

      &:last-child {
        border-bottom: 0;
      }
    }

    b {
      flex: 0 0 96px;
      color: var(--art-gray-800);
    }

    span {
      color: var(--art-gray-500);
      word-break: break-all;
    }

    code {
      padding: 1px 4px;
      font-size: 12px;
      background: rgb(63 58 51 / 6%);
      border-radius: 4px;
    }
  }

  @media (max-width: 1100px) {
    .links {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
</style>