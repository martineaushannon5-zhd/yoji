<!-- Yoji 用户管理 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">USERS</p>
        <h1>用户管理</h1>
        <p class="sub">查看学习进度、打卡情况，支持搜索与导出</p>
      </div>
      <div class="head-actions">
        <ElButton :loading="exporting" @click="handleExport">
          <ArtSvgIcon icon="ri:download-2-line" class="mr-1" />导出 CSV
        </ElButton>
        <ElButton text @click="load">
          <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
        </ElButton>
      </div>
    </header>

    <ElCard class="panel-card" shadow="never">
      <div class="filters">
        <ElInput
          v-model="search"
          placeholder="搜索账号或昵称"
          clearable
          class="search-input"
          @keyup.enter="handleSearch"
          @clear="handleSearch"
        >
          <template #prefix><ArtSvgIcon icon="ri:search-line" /></template>
        </ElInput>
        <ElButton type="primary" @click="handleSearch">搜索</ElButton>
        <span class="total">共 {{ total }} 位用户</span>
      </div>

      <ElTable :data="rows" v-loading="loading" stripe class="user-table">
        <ElTableColumn label="用户" min-width="200">
          <template #default="{ row }">
            <div class="user-cell">
              <ElAvatar :size="34" :src="mediaUrl(row.avatar)">
                {{ (row.nickname || row.account || '?').slice(0, 1) }}
              </ElAvatar>
              <div>
                <p class="name">{{ row.nickname || row.account }}</p>
                <span class="account">@{{ row.account }}</span>
              </div>
            </div>
          </template>
        </ElTableColumn>

        <ElTableColumn label="学习进度" min-width="180">
          <template #default="{ row }">
            <div class="progress-cell">
              <div class="progress-bar">
                <i :style="{ width: progressPercent(row as UserRow) + '%' }" />
              </div>
              <span>{{ row.mastered }} 掌握 / {{ row.learning }} 学习中</span>
            </div>
          </template>
        </ElTableColumn>

        <ElTableColumn label="连续打卡" width="110">
          <template #default="{ row }">
            <span class="streak">{{ row.streak }} 天</span>
          </template>
        </ElTableColumn>

        <ElTableColumn label="最近学习" width="130">
          <template #default="{ row }">{{ row.lastLearnDate || '—' }}</template>
        </ElTableColumn>

        <ElTableColumn label="注册时间" width="120">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
        </ElTableColumn>

        <ElTableColumn label="操作" width="90" fixed="right">
          <template #default="{ row }">
            <ElButton link type="danger" @click="handleDelete(row as UserRow)">删除</ElButton>
          </template>
        </ElTableColumn>
      </ElTable>

      <div class="pager">
        <ElPagination
          v-model:current-page="page"
          v-model:page-size="pageSize"
          :total="total"
          :page-sizes="[10, 20, 50]"
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
  import { ElMessage, ElMessageBox } from 'element-plus'
  import { deleteUser, exportUsersCsv, fetchUsers, mediaUrl, type UserRow } from '@/api/yoji'

  defineOptions({ name: 'Users' })

  const loading = ref(false)
  const exporting = ref(false)
  const search = ref('')
  const rows = ref<UserRow[]>([])
  const total = ref(0)
  const page = ref(1)
  const pageSize = ref(20)

  function progressPercent(row: UserRow) {
    const sum = row.mastered + row.learning
    if (!sum) return 0
    return Math.round((row.mastered / sum) * 100)
  }

  function formatDate(value: string) {
    return value ? value.slice(0, 10) : '—'
  }

  async function load() {
    loading.value = true
    try {
      const data = await fetchUsers({
        search: search.value.trim() || undefined,
        page: page.value,
        pageSize: pageSize.value
      })
      rows.value = data.users || []
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

  async function handleDelete(row: UserRow) {
    const confirmed = await ElMessageBox.confirm(
      `确定删除用户「${row.nickname || row.account}」？该操作不可恢复。`,
      '删除用户',
      { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' }
    ).catch(() => false)
    if (!confirmed) return

    await deleteUser(row.id)
    ElMessage.success('已删除用户')
    load()
  }

  async function handleExport() {
    exporting.value = true
    try {
      const blob = await exportUsersCsv(search.value.trim())
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `yoji-users-${new Date().toISOString().slice(0, 10)}.csv`
      link.click()
      URL.revokeObjectURL(url)
      ElMessage.success('CSV 已开始下载')
    } catch (error) {
      ElMessage.error(error instanceof Error ? error.message : '导出失败')
    } finally {
      exporting.value = false
    }
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
    color: var(--art-gray-900);
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

  .search-input {
    max-width: 320px;
  }

  .total {
    margin-left: auto;
    font-size: 12px;
    color: var(--art-gray-400);
  }

  .user-cell {
    display: flex;
    gap: 10px;
    align-items: center;
  }

  .name {
    margin: 0;
    font-size: 13px;
    font-weight: 500;
    color: var(--art-gray-800);
  }

  .account {
    font-size: 11px;
    color: var(--art-gray-400);
  }

  .progress-cell {
    display: flex;
    flex-direction: column;
    gap: 5px;
    font-size: 11px;
    color: var(--art-gray-400);
  }

  .progress-bar {
    width: 100%;
    height: 5px;
    overflow: hidden;
    background: #efe7db;
    border-radius: 999px;

    i {
      display: block;
      height: 100%;
      background: linear-gradient(90deg, #c96442, #d98b6a);
      border-radius: 999px;
    }
  }

  .streak {
    font-family: Georgia, serif;
    color: #b07050;
  }

  .pager {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }
</style>