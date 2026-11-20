<!-- Yoji 审计日志 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">AUDIT</p>
        <h1>审计日志</h1>
        <p class="sub">登录、上传、删除与导出，每一步都有记录</p>
      </div>
      <ElButton text @click="load">
        <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
      </ElButton>
    </header>

    <ElCard class="panel-card" shadow="never">
      <div class="filters">
        <ElSelect v-model="action" placeholder="全部动作" clearable class="w-180" @change="handleSearch">
          <ElOption label="登录" value="admin.login" />
          <ElOption label="登录失败" value="admin.login.failed" />
          <ElOption label="用户操作" value="user" />
          <ElOption label="视频操作" value="video" />
          <ElOption label="词库操作" value="wordbook" />
        </ElSelect>

        <ElInput
          v-model="account"
          placeholder="操作人账号"
          clearable
          class="w-220"
          @keyup.enter="handleSearch"
          @clear="handleSearch"
        >
          <template #prefix><ArtSvgIcon icon="ri:user-search-line" /></template>
        </ElInput>

        <ElButton type="primary" @click="handleSearch">查询</ElButton>
        <span class="total">共 {{ total }} 条</span>
      </div>

      <ElTable :data="logs" v-loading="loading" stripe>
        <ElTableColumn label="时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
        </ElTableColumn>

        <ElTableColumn label="操作人" width="130" prop="account" />

        <ElTableColumn label="动作" width="150">
          <template #default="{ row }">
            <ElTag size="small" effect="light" :type="tagType(row.action)">{{ actionText(row.action) }}</ElTag>
          </template>
        </ElTableColumn>

        <ElTableColumn label="对象" min-width="140" prop="target" />

        <ElTableColumn label="详情" min-width="220">
          <template #default="{ row }">{{ row.detail || '—' }}</template>
        </ElTableColumn>

        <ElTableColumn label="IP" width="140" prop="ip" />
      </ElTable>

      <div class="pager">
        <ElPagination
          v-model:current-page="page"
          v-model:page-size="pageSize"
          :total="total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next"
          background
          @size-change="handleSizeChange"
          @current-change="load"
        />
      </div>
    </ElCard>
  </div>
</template>

<script setup lang="ts">
  import { onMounted, ref } from 'vue'
  import { fetchAudit, type AuditRow } from '@/api/yoji'

  defineOptions({ name: 'Audit' })

  const loading = ref(false)
  const logs = ref<AuditRow[]>([])
  const total = ref(0)
  const page = ref(1)
  const pageSize = ref(20)
  const action = ref('')
  const account = ref('')

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

  function actionText(value: string) {
    return ACTION_TEXT[value] || value
  }

  function tagType(value: string) {
    if (value.endsWith('.failed') || value.endsWith('.delete')) return 'danger'
    if (value.endsWith('.upload') || value.endsWith('.create')) return 'success'
    if (value.startsWith('admin.login')) return 'info'
    return 'warning'
  }

  function formatTime(value: string) {
    return value ? value.replace('T', ' ').slice(0, 19) : '—'
  }

  async function load() {
    loading.value = true
    try {
      const data = await fetchAudit({
        page: page.value,
        pageSize: pageSize.value,
        action: action.value || undefined,
        account: account.value.trim() || undefined
      })
      logs.value = data.logs || []
      total.value = data.total || 0
    } finally {
      loading.value = false
    }
  }

  function handleSearch() {
    page.value = 1
    load()
  }

  function handleSizeChange() {
    page.value = 1
    load()
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
    margin-bottom: 20px;
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

  .panel-card {
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .filters {
    display: flex;
    gap: 10px;
    align-items: center;
    margin-bottom: 16px;
  }

  .w-180 {
    width: 180px;
  }

  .w-220 {
    width: 220px;
  }

  .total {
    margin-left: auto;
    font-size: 12px;
    color: var(--art-gray-400);
  }

  .pager {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }
</style>