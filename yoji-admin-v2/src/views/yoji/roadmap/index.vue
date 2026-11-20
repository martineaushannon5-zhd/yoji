<!-- Yoji 版本计划 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">ROADMAP</p>
        <h1>版本计划</h1>
        <p class="sub">已经交付了什么、正在做什么、下一步往哪走</p>
      </div>
      <div class="head-actions">
        <ElRadioGroup v-model="filter" size="small">
          <ElRadioButton value="all">全部</ElRadioButton>
          <ElRadioButton value="done">已完成</ElRadioButton>
          <ElRadioButton value="planned">未完成</ElRadioButton>
        </ElRadioGroup>
      </div>
    </header>

    <ol class="timeline">
      <li v-for="release in visible" :key="release.version" :class="['release', release.status]">
        <div class="marker" />
        <div class="release-card">
          <div class="release-head">
            <div>
              <h2>v{{ release.version }}</h2>
              <p>{{ release.title }}</p>
            </div>
            <div class="release-meta">
              <ElTag :type="statusType(release.status)" size="small" effect="light">
                {{ statusText(release.status) }}
              </ElTag>
              <span>{{ release.date }}</span>
            </div>
          </div>
          <ul>
            <li v-for="item in release.items" :key="item">
              <ArtSvgIcon :icon="release.status === 'done' ? 'ri:check-line' : 'ri:time-line'" />
              {{ item }}
            </li>
          </ul>
        </div>
      </li>
    </ol>

    <ElCard class="panel-card note" shadow="never">
      <div class="note-body">
        <div>
          <h3>想要的功能没在列表里？</h3>
          <p>在帮助中心查看提交方式，或在日常使用中记录下最影响效率的那一步。</p>
        </div>
        <ElButton type="primary" @click="goHelp">去帮助中心</ElButton>
      </div>
    </ElCard>
  </div>
</template>

<script setup lang="ts">
  import { computed, ref } from 'vue'
  import { useRouter } from 'vue-router'

  defineOptions({ name: 'YojiRoadmap' })

  type Status = 'done' | 'doing' | 'planned'

  interface Release {
    version: string
    date: string
    title: string
    status: Status
    items: string[]
  }

  const router = useRouter()
  const filter = ref<'all' | 'done' | 'planned'>('all')

  const releases: Release[] = [
    {
      version: '1.3.0',
      date: '2026-11',
      title: '管理端 v2',
      status: 'doing',
      items: [
        '用 art-design-pro 重构后台，五个业务页 + 系统管理 / 版本计划 / 帮助中心',
        'Claude 暖色主题、Y 图标与统一品牌',
        '异常页（403 / 404 / 500）与全局兜底',
        'Electron 安装包体积优化（asar 189MB → 8.7MB）'
      ]
    },
    {
      version: '1.2.0',
      date: '2026-11',
      title: '学习闭环',
      status: 'done',
      items: [
        '错词本：答错自动收录，支持手动标记已掌握',
        '6 级间隔复习（1 / 2 / 4 / 7 / 15 / 30 天）',
        '跨端同步白名单扩展，错词与复习进度上云不丢',
        '首页沉浸式：状态栏透明 + 底部手势条避让'
      ]
    },
    {
      version: '1.1.0',
      date: '2026-11',
      title: '运营后台',
      status: 'done',
      items: [
        '仪表盘、用户、视频、词库、审计五个模块',
        '用户 CSV 导出、操作审计留痕、统一错误码',
        'OpenAPI 文档（38+ 接口）与 Swagger UI',
        '视频直传 OSS 与存量迁移脚本、Nginx 回滚预案'
      ]
    },
    {
      version: '1.0.0',
      date: '2026-10',
      title: '基础版',
      status: 'done',
      items: [
        '鸿蒙 App：登录、词库选择、学习卡片、视频播放',
        'Node + SQLite 后端：用户、进度、视频、词库接口',
        'Windows 管理端：视频与词库的基础增删改查'
      ]
    },
    {
      version: '1.4.0',
      date: '规划中',
      title: '内容与体验',
      status: 'planned',
      items: [
        '词库逐词编辑（现在只能整本覆盖）',
        '视频拖拽排序与批量上下架',
        'App 离线缓存与断网续学',
        'HDS 系统组件迁移（需把 min API 提到 20）',
        '桌面端自动更新与代码签名'
      ]
    }
  ]

  const visible = computed(() => {
    if (filter.value === 'all') return releases
    if (filter.value === 'done') return releases.filter((item) => item.status === 'done')
    return releases.filter((item) => item.status !== 'done')
  })

  const statusText = (status: Status) =>
    ({ done: '已完成', doing: '进行中', planned: '计划中' })[status]

  const statusType = (status: Status) =>
    ({ done: 'success', doing: 'warning', planned: 'info' })[status] as 'success' | 'warning' | 'info'

  function goHelp() {
    router.push('/help')
  }
</script>

<style scoped lang="scss">
  .yoji-page {
    padding: 4px 2px 24px;
  }

  .page-head {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
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

  .timeline {
    position: relative;
    margin: 0 0 16px;
    padding: 4px 0 0 22px;
    list-style: none;

    &::before {
      position: absolute;
      top: 10px;
      bottom: 10px;
      left: 6px;
      width: 1px;
      content: '';
      background: var(--art-card-border);
    }
  }

  .release {
    position: relative;
    margin-bottom: 14px;

    .marker {
      position: absolute;
      top: 22px;
      left: -20px;
      width: 9px;
      height: 9px;
      background: var(--default-box-color);
      border: 2px solid #c96442;
      border-radius: 50%;
    }

    &.planned .marker {
      border-color: var(--art-gray-300);
    }

    &.doing .marker {
      box-shadow: 0 0 0 4px rgb(201 100 66 / 15%);
    }
  }

  .release-card {
    padding: 16px 18px;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .release-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 8px;

    h2 {
      margin: 0;
      font-family: Georgia, serif;
      font-size: 18px;
    }

    p {
      margin: 2px 0 0;
      font-size: 12px;
      color: var(--art-gray-500);
    }
  }

  .release-meta {
    display: flex;
    align-items: center;
    gap: 10px;

    span {
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  ul {
    margin: 0;
    padding: 0;
    list-style: none;

    li {
      display: flex;
      gap: 8px;
      align-items: flex-start;
      padding: 4px 0;
      font-size: 13px;
      color: var(--art-gray-700);
    }

    svg {
      flex: 0 0 auto;
      margin-top: 3px;
      color: #8c9a7b;
    }
  }

  .panel-card {
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .note-body {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;

    h3 {
      margin: 0 0 4px;
      font-size: 14px;
    }

    p {
      margin: 0;
      font-size: 12px;
      color: var(--art-gray-500);
    }
  }
</style>