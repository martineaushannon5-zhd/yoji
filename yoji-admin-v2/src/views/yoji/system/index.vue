<!-- Yoji 系统管理 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">SYSTEM</p>
        <h1>系统管理</h1>
        <p class="sub">服务版本、运行环境、存储与内容规模，一处看清</p>
      </div>
      <div class="head-actions">
        <ElButton :loading="loading" @click="load">
          <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
        </ElButton>
        <ElButton type="primary" @click="openDocs">
          <ArtSvgIcon icon="ri:book-open-line" class="mr-1" />API 文档
        </ElButton>
      </div>
    </header>

    <section class="metrics">
      <div class="metric">
        <span>服务版本</span>
        <strong>v{{ info?.app.version || '—' }}</strong>
        <em>{{ info?.app.env === 'production' ? '生产环境' : '开发环境' }}</em>
      </div>
      <div class="metric">
        <span>Node 运行时</span>
        <strong>{{ info?.app.node || '—' }}</strong>
        <em>启动于 {{ formatTime(info?.app.startedAt) }}</em>
      </div>
      <div class="metric">
        <span>已运行</span>
        <strong>{{ uptime }}</strong>
        <em>无中断</em>
      </div>
      <div class="metric">
        <span>媒体存储</span>
        <strong>{{ info?.storage.mode === 'oss' ? 'OSS 直传' : '本地存储' }}</strong>
        <em>{{ info?.storage.bucket || '服务器磁盘' }}</em>
      </div>
    </section>

    <div class="grid">
      <ElCard class="panel-card" shadow="never">
        <template #header>
          <div class="card-head"><span>内容规模</span><small>实时统计</small></div>
        </template>
        <ul class="stat-list">
          <li><span>注册用户</span><b>{{ num(info?.content.users) }}</b></li>
          <li><span>词库（上架 / 全部）</span><b>{{ num(info?.content.visibleWordbooks) }} / {{ num(info?.content.wordbooks) }}</b></li>
          <li><span>词条总数</span><b>{{ num(info?.content.words) }}</b></li>
          <li><span>视频</span><b>{{ num(info?.content.videos) }}</b></li>
          <li><span>审计记录</span><b>{{ num(info?.content.auditLogs) }}</b></li>
        </ul>
      </ElCard>

      <ElCard class="panel-card" shadow="never">
        <template #header>
          <div class="card-head"><span>环境检查</span><small>部署后自检</small></div>
        </template>
        <ul class="check-list">
          <li v-for="item in checks" :key="item.label">
            <div>
              <p>{{ item.label }}</p>
              <span>{{ item.detail }}</span>
            </div>
            <ElTag :type="item.ok ? 'success' : 'warning'" size="small" effect="light">
              {{ item.ok ? '正常' : '注意' }}
            </ElTag>
          </li>
        </ul>
      </ElCard>
    </div>

    <ElCard class="panel-card storage-card" shadow="never">
      <template #header>
        <div class="card-head"><span>运行位置</span><small>排查问题时复制给对方</small></div>
      </template>
      <div class="kv"><span>数据库</span><code>{{ info?.database.file || '—' }}</code></div>
      <div class="kv"><span>数据库占用</span><code>{{ formatBytes(info?.database.bytes) }}</code></div>
      <div class="kv"><span>媒体目录</span><code>{{ info?.media.dir || '—' }}</code></div>
      <div class="kv"><span>媒体文件</span><code>{{ num(info?.media.files) }} 个 / {{ formatBytes(info?.media.bytes) }}</code></div>
      <div class="kv"><span>媒体公网前缀</span><code>{{ info?.storage.publicBase || '同域 /media' }}</code></div>
    </ElCard>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, ref } from 'vue'
  import { fetchSystem, type SystemInfo } from '@/api/yoji'

  defineOptions({ name: 'YojiSystem' })

  const loading = ref(false)
  const info = ref<SystemInfo>()

  const num = (value?: number) => (value === undefined ? '—' : value.toLocaleString())

  const formatBytes = (bytes?: number) => {
    if (!bytes) return '0 B'
    const units = ['B', 'KB', 'MB', 'GB']
    let value = bytes
    let index = 0
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024
      index += 1
    }
    return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`
  }

  const formatTime = (value?: string) => {
    if (!value) return '—'
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return '—'
    return date.toLocaleString('zh-CN', { hour12: false })
  }

  const uptime = computed(() => {
    const seconds = info.value?.app.uptimeSeconds || 0
    if (seconds < 60) return `${seconds} 秒`
    if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} 小时`
    return `${Math.floor(seconds / 86400)} 天`
  })

  const checks = computed(() => [
    {
      label: 'API 服务',
      detail: info.value ? '接口正常响应' : '尚未获取到服务信息',
      ok: Boolean(info.value)
    },
    {
      label: '数据库',
      detail: info.value?.database.bytes ? `可读，${formatBytes(info.value.database.bytes)}` : '文件不存在或为空',
      ok: Boolean(info.value?.database.bytes)
    },
    {
      label: '媒体存储',
      detail:
        info.value?.storage.mode === 'oss'
          ? `OSS：${info.value.storage.bucket}`
          : `本地目录 ${formatBytes(info.value?.media.bytes)}`,
      ok: Boolean(info.value)
    },
    {
      label: '词库数据',
      detail: info.value?.content.words ? `${info.value.content.words} 个词条可用` : '暂无词条',
      ok: Boolean(info.value?.content.words)
    }
  ])

  async function load() {
    loading.value = true
    try {
      info.value = await fetchSystem()
    } finally {
      loading.value = false
    }
  }

  function openDocs() {
    window.open('https://yoji.zhdstudy.cyou/api/docs', '_blank')
  }

  onMounted(load)
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

  .head-actions {
    display: flex;
    gap: 8px;
  }

  .metrics {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin-bottom: 14px;
  }

  .metric {
    padding: 16px 18px;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;

    span {
      font-size: 12px;
      color: var(--art-gray-400);
    }

    strong {
      display: block;
      margin: 6px 0 2px;
      font-family: Georgia, serif;
      font-size: 22px;
      color: var(--art-gray-900);
    }

    em {
      font-style: normal;
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 14px;
    margin-bottom: 14px;
  }

  .panel-card {
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
    color: var(--art-gray-900);

    small {
      font-weight: 400;
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  .stat-list {
    margin: 0;
    padding: 0;
    list-style: none;

    li {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 11px 0;
      border-bottom: 1px dashed var(--art-card-border);

      &:last-child {
        border-bottom: 0;
      }
    }

    span {
      font-size: 13px;
      color: var(--art-gray-500);
    }

    b {
      font-family: Georgia, serif;
      font-size: 17px;
      color: var(--art-gray-900);
    }
  }

  .check-list {
    margin: 0;
    padding: 0;
    list-style: none;

    li {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 0;
      border-bottom: 1px dashed var(--art-card-border);

      &:last-child {
        border-bottom: 0;
      }
    }

    p {
      margin: 0 0 2px;
      font-size: 13px;
      color: var(--art-gray-800);
    }

    span {
      font-size: 11px;
      color: var(--art-gray-400);
    }
  }

  .storage-card {
    .kv {
      display: flex;
      gap: 16px;
      padding: 9px 0;
      border-bottom: 1px dashed var(--art-card-border);

      &:last-child {
        border-bottom: 0;
      }

      span {
        flex: 0 0 110px;
        font-size: 12px;
        color: var(--art-gray-400);
      }

      code {
        font-size: 12px;
        color: var(--art-gray-800);
        word-break: break-all;
      }
    }
  }

  @media (max-width: 1100px) {
    .metrics {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .grid {
      grid-template-columns: 1fr;
    }
  }
</style>