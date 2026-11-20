<!-- Yoji 仪表盘 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">YOJI · OVERVIEW</p>
        <h1>运营概览</h1>
        <p class="sub">背单词 App 的用户、学习与内容数据</p>
      </div>
      <div class="head-actions">
        <ElButton text @click="loadAll" :loading="loading">
          <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
        </ElButton>
        <ElButton type="primary" @click="router.push('/videos')">
          <ArtSvgIcon icon="ri:upload-cloud-2-line" class="mr-1" />上传内容
        </ElButton>
      </div>
    </header>

    <section class="stat-grid">
      <article v-for="item in cards" :key="item.label" class="stat-card">
        <div class="stat-icon"><ArtSvgIcon :icon="item.icon" /></div>
        <div class="stat-body">
          <span class="stat-label">{{ item.label }}</span>
          <strong class="stat-value">{{ item.value }}</strong>
          <span class="stat-foot">{{ item.foot }}</span>
        </div>
      </article>
    </section>

    <section class="content-grid">
      <ElCard class="panel-card chart-card" shadow="never">
        <template #header>
          <div class="card-head">
            <div>
              <h3>近 14 天学习活跃</h3>
              <p>按中国时区统计的日活与新增用户</p>
            </div>
            <span class="legend"><i class="dot active" />活跃 <i class="dot new" />新增</span>
          </div>
        </template>
        <ArtLineChart
          :data="trendSeries"
          :x-axis-data="trendLabels"
          height="320px"
          :show-area-color="true"
          :colors="['#C96442', '#8C9A7B']"
        />
      </ElCard>

      <ElCard class="panel-card audit-card" shadow="never">
        <template #header>
          <div class="card-head">
            <div>
              <h3>最近操作</h3>
              <p>登录、上传、删除与导出都会留痕</p>
            </div>
            <ElButton text size="small" @click="router.push('/audit')">全部</ElButton>
          </div>
        </template>

        <ul v-if="recentLogs.length" class="log-list">
          <li v-for="log in recentLogs" :key="log.id">
            <span class="log-action">{{ actionText(log.action) }}</span>
            <div class="log-main">
              <p>{{ log.detail || log.target || '—' }}</p>
              <span>{{ log.account }} · {{ formatTime(log.createdAt) }}</span>
            </div>
          </li>
        </ul>
        <ElEmpty v-else description="暂无操作记录" :image-size="80" />
      </ElCard>
    </section>

    <section class="quick-grid">
      <button class="quick-item" @click="router.push('/wordbooks')">
        <ArtSvgIcon icon="ri:book-2-line" />
        <div>
          <strong>维护词库</strong>
          <span>上线新词书、调整显示顺序</span>
        </div>
        <ArtSvgIcon icon="ri:arrow-right-line" class="quick-arrow" />
      </button>
      <button class="quick-item" @click="router.push('/users')">
        <ArtSvgIcon icon="ri:user-3-line" />
        <div>
          <strong>查看用户</strong>
          <span>学习进度、打卡与导出</span>
        </div>
        <ArtSvgIcon icon="ri:arrow-right-line" class="quick-arrow" />
      </button>
      <button class="quick-item" @click="router.push('/videos')">
        <ArtSvgIcon icon="ri:video-line" />
        <div>
          <strong>管理视频</strong>
          <span>封面、排序与上下架</span>
        </div>
        <ArtSvgIcon icon="ri:arrow-right-line" class="quick-arrow" />
      </button>
    </section>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, ref } from 'vue'
  import { useRouter } from 'vue-router'
  import { fetchAudit, fetchStats, type AuditRow, type StatsResult } from '@/api/yoji'

  defineOptions({ name: 'Dashboard' })

  const router = useRouter()
  const loading = ref(false)
  const stats = ref<StatsResult | null>(null)
  const recentLogs = ref<AuditRow[]>([])

  const cards = computed(() => {
    const s = stats.value
    return [
      {
        label: '注册用户',
        value: s ? String(s.totalUsers) : '—',
        foot: s ? `近 7 天新增 ${s.newUsers7d}` : '累计注册',
        icon: 'ri:group-line'
      },
      {
        label: '今日活跃',
        value: s ? String(s.todayActive) : '—',
        foot: s ? `覆盖率 ${percent(s.todayActive, s.totalUsers)}%` : '今天有学习行为',
        icon: 'ri:flashlight-line'
      },
      {
        label: '学习单词',
        value: s ? s.totalWords.toLocaleString() : '—',
        foot: s ? `已掌握 ${s.masteredWords.toLocaleString()}` : '掌握 + 学习中',
        icon: 'ri:book-open-line'
      },
      {
        label: '视频内容',
        value: s ? String(s.totalVideos) : '—',
        foot: '已上架视频',
        icon: 'ri:video-line'
      }
    ]
  })

  const trendLabels = computed(() => stats.value?.trend.map((item) => item.label) || [])
  const trendSeries = computed(() => {
    const trend = stats.value?.trend || []
    return [
      { name: '活跃用户', data: trend.map((item) => item.activeUsers) },
      { name: '新增用户', data: trend.map((item) => item.newUsers) }
    ]
  })

  function percent(value: number, total: number) {
    if (!total) return 0
    return Math.round((value / total) * 100)
  }

  const ACTION_TEXT: Record<string, string> = {
    'admin.login': '登录',
    'admin.login.failed': '登录失败',
    'user.delete': '删除用户',
    'user.export': '导出用户',
    'video.upload': '上传视频',
    'video.create': '新增视频',
    'video.update': '更新视频',
    'video.delete': '删除视频',
    'wordbook.upload': '上传词库',
    'wordbook.update': '更新词库',
    'wordbook.delete': '删除词库'
  }

  function actionText(action: string) {
    return ACTION_TEXT[action] || action
  }

  function formatTime(value: string) {
    if (!value) return ''
    return value.replace('T', ' ').slice(5, 16)
  }

  async function loadAll() {
    loading.value = true
    try {
      const [statsData, auditData] = await Promise.all([
        fetchStats(),
        fetchAudit({ page: 1, pageSize: 6 })
      ])
      stats.value = statsData
      recentLogs.value = auditData.logs || []
    } finally {
      loading.value = false
    }
  }

  onMounted(loadAll)
</script>

<style scoped lang="scss">
  .yoji-page {
    padding: 4px 2px 24px;
  }

  .page-head {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 22px;
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
    font-size: 30px;
    font-weight: 600;
    color: var(--art-gray-900);
  }

  .sub {
    margin: 8px 0 0;
    font-size: 13px;
    color: var(--art-gray-500);
  }

  .head-actions {
    display: flex;
    gap: 8px;
  }

  .stat-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin-bottom: 16px;
  }

  .stat-card {
    display: flex;
    gap: 14px;
    align-items: flex-start;
    padding: 20px;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .stat-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    color: #c96442;
    background: #f8ece4;
    border-radius: 10px;
  }

  .stat-body {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .stat-label {
    font-size: 12px;
    color: var(--art-gray-500);
  }

  .stat-value {
    font-family: Georgia, serif;
    font-size: 28px;
    font-weight: 600;
    line-height: 1.2;
  }

  .stat-foot {
    font-size: 12px;
    color: var(--art-gray-400);
  }

  .content-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.55fr) minmax(0, 1fr);
    gap: 14px;
    margin-bottom: 16px;
  }

  .panel-card {
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .card-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;

    h3 {
      margin: 0;
      font-size: 15px;
      font-weight: 600;
    }

    p {
      margin: 4px 0 0;
      font-size: 12px;
      color: var(--art-gray-400);
    }
  }

  .legend {
    display: flex;
    gap: 12px;
    align-items: center;
    font-size: 12px;
    color: var(--art-gray-500);
  }

  .dot {
    display: inline-block;
    width: 7px;
    height: 7px;
    margin-right: 5px;
    border-radius: 50%;

    &.active {
      background: #c96442;
    }

    &.new {
      background: #8c9a7b;
    }
  }

  .log-list {
    padding: 0;
    margin: 0;
    list-style: none;

    li {
      display: flex;
      gap: 12px;
      align-items: flex-start;
      padding: 10px 0;
      border-bottom: 1px dashed var(--default-border);

      &:last-child {
        border-bottom: 0;
      }
    }
  }

  .log-action {
    flex: none;
    padding: 2px 8px;
    font-size: 11px;
    color: #a8553a;
    background: #f8ece4;
    border-radius: 999px;
  }

  .log-main {
    min-width: 0;

    p {
      margin: 0;
      overflow: hidden;
      font-size: 13px;
      color: var(--art-gray-800);
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    span {
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  .quick-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
  }

  .quick-item {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 16px 18px;
    text-align: left;
    cursor: pointer;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
    transition: all 0.2s ease;

    &:hover {
      border-color: rgba(201, 100, 66, 0.4);
      box-shadow: 0 8px 20px rgba(80, 60, 40, 0.06);
    }

    > i {
      font-size: 20px;
      color: #c96442;
    }

    div {
      display: flex;
      flex: 1;
      flex-direction: column;
      gap: 3px;

      strong {
        font-size: 14px;
        color: var(--art-gray-800);
      }

      span {
        font-size: 12px;
        color: var(--art-gray-400);
      }
    }
  }

  .quick-arrow {
    color: var(--art-gray-300);
  }

  @media (max-width: 1100px) {
    .stat-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .content-grid,
    .quick-grid {
      grid-template-columns: 1fr;
    }
  }
</style>