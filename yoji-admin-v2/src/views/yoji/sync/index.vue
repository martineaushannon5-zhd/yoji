<!-- Yoji 词库同步：从官方节点一键导入线上词库 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">DATA SYNC</p>
        <h1>词库同步</h1>
        <p class="sub">克隆源码自部署时，本地数据库是空的；点一下就能拿到线上的全部词库</p>
      </div>
    </header>

    <ElAlert type="info" :closable="false" show-icon class="tip">
      <template #title>为什么需要这一步？</template>
      <p class="tip-text">
        仓库里只自带少量内置词表，GitHub / Gitee 上的源码不含线上数据库。
        这个页面会从官方节点拉取全部词库并写入当前实例的 SQLite，App 刷新后即可看到。
      </p>
    </ElAlert>

    <ElCard class="panel-card" shadow="never">
      <template #header>
        <div class="card-head">
          <span>同步来源</span>
          <small>同名词库按 id 整本覆盖，不会追加</small>
        </div>
      </template>

      <div class="source-row">
        <ElInput v-model="sourceUrl" placeholder="https://yoji.zhdstudy.cyou/api/wordbooks/full" clearable>
          <template #prefix><ArtSvgIcon icon="ri:link" /></template>
        </ElInput>
        <ElButton type="primary" :loading="loading" @click="handleSync">
          {{ loading ? '正在同步…' : '从官方同步词库' }}
        </ElButton>
      </div>
      <p class="hint">
        默认地址是官方节点；也可以填其他可信实例的 <code>/api/wordbooks/full</code>。
        单次最多 40 MB，超时会自动中止。同步完成后到「词库管理」确认词条数，再到 App 下拉刷新。
      </p>
      <p class="hint">
        当前后台：<code>{{ API_ORIGIN }}</code> —— 词库会写进这个地址对应的服务器。
        如果你在自部署实例上操作，这里应该显示你自己的域名或 IP。
      </p>
    </ElCard>

    <ElCard v-if="result" class="panel-card" shadow="never">
      <template #header>
        <div class="card-head">
          <span>同步结果</span>
          <small>{{ result.totalBooks }} 本 · {{ result.totalWords.toLocaleString() }} 词 · 跳过 {{ result.skippedWords }} 条无释义 · {{ result.elapsedMs }} ms</small>
        </div>
      </template>
      <ElTable :data="result.imported" stripe>
        <ElTableColumn prop="id" label="ID" width="140" />
        <ElTableColumn prop="name" label="词库" min-width="200" />
        <ElTableColumn prop="words" label="词条数" width="120" align="right">
          <template #default="{ row }">{{ row.words.toLocaleString() }}</template>
        </ElTableColumn>
      </ElTable>
      <div v-if="result.skipped.length" class="skipped">
        <p>跳过 {{ result.skipped.length }} 本：</p>
        <ul>
          <li v-for="item in result.skipped" :key="item.id">{{ item.id }} — {{ item.reason }}</li>
        </ul>
      </div>
      <p class="hint">来源：{{ result.source }}</p>
    </ElCard>

    <ElCard class="panel-card" shadow="never">
      <template #header>
        <div class="card-head">
          <span>本地现状</span>
          <small>同步前可先对比</small>
        </div>
      </template>
      <div class="stats">
        <div class="stat">
          <span>词库</span>
          <b>{{ local.totalBooks }}</b>
        </div>
        <div class="stat">
          <span>词条</span>
          <b>{{ local.totalWords.toLocaleString() }}</b>
        </div>
        <div class="stat">
          <span>最近同步</span>
          <b class="time">{{ lastSync || '尚未同步' }}</b>
        </div>
      </div>
    </ElCard>
  </div>
</template>

<script setup lang="ts">
  import { onMounted, reactive, ref } from 'vue'
  import { ElMessage } from 'element-plus'
  import { API_ORIGIN, fetchWordbooks, syncWordbooks, type SyncResult } from '@/api/yoji'

  defineOptions({ name: 'YojiSync' })

  const loading = ref(false)
  const result = ref<SyncResult | null>(null)
  const lastSync = ref(localStorage.getItem('yoji_wordbook_sync_at') || '')
  const sourceUrl = ref(`${API_ORIGIN}/api/wordbooks/full`)
  const local = reactive({ totalBooks: 0, totalWords: 0 })

  async function loadLocal() {
    try {
      const data = await fetchWordbooks()
      local.totalBooks = data.books.length
      local.totalWords = data.books.reduce((sum, book) => sum + (book.wordCount || 0), 0)
    } catch {
      // 词库列表失败不阻断同步入口
    }
  }

  async function handleSync() {
    loading.value = true
    try {
      const data = await syncWordbooks(sourceUrl.value.trim() || undefined)
      result.value = data
      lastSync.value = new Date().toLocaleString()
      localStorage.setItem('yoji_wordbook_sync_at', lastSync.value)
      ElMessage.success(`已同步 ${data.totalBooks} 本词库、${data.totalWords.toLocaleString()} 个词条`)
      await loadLocal()
    } catch (error) {
      ElMessage.error(error instanceof Error ? error.message : '同步失败，请稍后重试')
    } finally {
      loading.value = false
    }
  }

  onMounted(loadLocal)
</script>

<style scoped>
  .tip {
    margin-bottom: 16px;
    border-radius: 12px;
  }
  .tip-text {
    margin: 4px 0 0;
    font-size: 13px;
    line-height: 1.8;
    color: #7a6f62;
  }
  .panel-card {
    margin-bottom: 16px;
    border-radius: 14px;
  }
  .card-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }
  .card-head small {
    color: #8a8177;
    font-size: 12px;
  }
  .source-row {
    display: flex;
    gap: 12px;
  }
  .source-row .el-input {
    flex: 1;
  }
  .hint {
    margin: 12px 0 0;
    font-size: 12.5px;
    line-height: 1.8;
    color: #8a8177;
  }
  .hint code {
    padding: 1px 6px;
    border-radius: 6px;
    background: #f1e9db;
  }
  .skipped {
    margin-top: 12px;
    font-size: 12.5px;
    color: #8a6a4f;
  }
  .skipped ul {
    margin: 6px 0 0;
    padding-left: 18px;
  }
  .stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
  }
  .stat {
    border: 1px solid #e7dfd2;
    border-radius: 12px;
    padding: 14px 16px;
    background: #fffdf8;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .stat span {
    font-size: 12px;
    color: #8a8177;
  }
  .stat b {
    font-size: 22px;
    font-weight: 600;
    color: #2f2a24;
  }
  .stat .time {
    font-size: 14px;
    font-weight: 500;
  }
  @media (max-width: 720px) {
    .source-row {
      flex-direction: column;
    }
    .stats {
      grid-template-columns: 1fr;
    }
  }
</style>