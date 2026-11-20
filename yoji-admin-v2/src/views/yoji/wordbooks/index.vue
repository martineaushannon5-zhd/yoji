<!-- Yoji 词库管理 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">WORDBOOKS</p>
        <h1>词库管理</h1>
        <p class="sub">上传 .txt / .json 词表，控制 App 中的显示与排序</p>
      </div>
      <div class="head-actions">
        <ElButton @click="load">
          <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
        </ElButton>
        <ElButton type="primary" @click="openUpload">
          <ArtSvgIcon icon="ri:upload-cloud-2-line" class="mr-1" />上传词库
        </ElButton>
      </div>
    </header>

    <section class="summary">
      <div><span>词库</span><strong>{{ books.length }}</strong></div>
      <div><span>总词条</span><strong>{{ totalWords.toLocaleString() }}</strong></div>
      <div><span>已上架</span><strong>{{ visibleCount }}</strong></div>
    </section>

    <ElCard class="panel-card" shadow="never">
      <ElTable :data="books" v-loading="loading" stripe>
        <ElTableColumn label="词库" min-width="240">
          <template #default="{ row }">
            <div class="book-cell">
              <div class="book-cover"><ArtSvgIcon icon="ri:book-2-line" /></div>
              <div>
                <p>{{ row.name }}</p>
                <span>{{ row.subtitle || row.description || row.id }}</span>
              </div>
            </div>
          </template>
        </ElTableColumn>

        <ElTableColumn label="ID" width="120" prop="id" />

        <ElTableColumn label="词条" width="100">
          <template #default="{ row }">{{ row.wordCount }} 词</template>
        </ElTableColumn>

        <ElTableColumn label="排序" width="90">
          <template #default="{ row }">{{ row.sortOrder }}</template>
        </ElTableColumn>

        <ElTableColumn label="上架" width="90">
          <template #default="{ row }">
            <ElSwitch
              :model-value="row.visible"
              size="small"
              @change="(value: string | number | boolean) => toggleVisible(row as WordBookRow, Boolean(value))"
            />
          </template>
        </ElTableColumn>

        <ElTableColumn label="来源" min-width="140">
          <template #default="{ row }">
            <span class="source">{{ row.source || '—' }}</span>
          </template>
        </ElTableColumn>

        <ElTableColumn label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <ElButton link type="primary" @click="openPreview(row)">预览</ElButton>
            <ElButton link type="danger" @click="handleDelete(row as WordBookRow)">删除</ElButton>
          </template>
        </ElTableColumn>
      </ElTable>

      <ElEmpty v-if="!loading && !books.length" description="还没有词库" />
    </ElCard>

    <ElDialog v-model="uploadVisible" title="上传词库" width="520px">
      <ElForm label-position="top">
        <ElFormItem label="词表文件" required>
          <input ref="fileInput" type="file" accept=".txt,.json" @change="onFilePick" />
          <span class="hint">单个 .txt 或 .json，≤8MB；同名 id 会整本替换</span>
        </ElFormItem>
        <ElFormItem label="名称">
          <ElInput v-model="uploadForm.name" placeholder="例如：雅思核心词汇" maxlength="80" />
        </ElFormItem>
        <div class="form-row">
          <ElFormItem label="ID（可选）">
            <ElInput v-model="uploadForm.id" placeholder="小写字母/数字/_-" />
          </ElFormItem>
          <ElFormItem label="排序">
            <ElInputNumber v-model="uploadForm.sortOrder" :min="0" :controls="false" style="width: 100%" />
          </ElFormItem>
        </div>
        <ElFormItem label="上架">
          <ElSwitch v-model="uploadForm.visible" />
        </ElFormItem>
        <ElProgress v-if="progress > 0 && progress < 100" :percentage="progress" :stroke-width="6" />
      </ElForm>
      <template #footer>
        <ElButton @click="uploadVisible = false">取消</ElButton>
        <ElButton type="primary" :loading="uploading" @click="handleUpload">上传</ElButton>
      </template>
    </ElDialog>

    <ElDialog v-model="previewVisible" :title="previewTitle" width="640px">
      <ElTable :data="previewWords" max-height="460" size="small">
        <ElTableColumn prop="word" label="单词" width="150" />
        <ElTableColumn prop="phonetic" label="音标" width="150" />
        <ElTableColumn prop="meaning" label="释义" />
      </ElTable>
      <div class="preview-foot">仅展示前 {{ previewWords.length }} 个词条</div>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, reactive, ref } from 'vue'
  import { ElMessage, ElMessageBox } from 'element-plus'
  import request from '@/utils/http'
  import {
    deleteWordbook,
    fetchWordbooks,
    updateWordbook,
    uploadForm as uploadMultipart,
    type WordBookRow
  } from '@/api/yoji'

  defineOptions({ name: 'Wordbooks' })

  interface PreviewWord {
    id: string
    word: string
    phonetic?: string
    meaning?: string
  }

  const loading = ref(false)
  const uploading = ref(false)
  const uploadVisible = ref(false)
  const previewVisible = ref(false)
  const books = ref<WordBookRow[]>([])
  const progress = ref(0)
  const file = ref<File | null>(null)
  const previewTitle = ref('')
  const previewWords = ref<PreviewWord[]>([])

  const uploadFormState = reactive({
    name: '',
    id: '',
    sortOrder: 0,
    visible: true
  })
  const uploadForm = uploadFormState

  const totalWords = computed(() => books.value.reduce((sum, book) => sum + (book.wordCount || 0), 0))
  const visibleCount = computed(() => books.value.filter((book) => book.visible).length)

  async function load() {
    loading.value = true
    try {
      const data = await fetchWordbooks()
      books.value = data.books || []
    } finally {
      loading.value = false
    }
  }

  function openUpload() {
    Object.assign(uploadForm, {
      name: '',
      id: '',
      sortOrder: books.value.length + 1,
      visible: true
    })
    file.value = null
    progress.value = 0
    uploadVisible.value = true
  }

  function onFilePick(event: Event) {
    const input = event.target as HTMLInputElement
    file.value = input.files?.[0] || null
  }

  async function handleUpload() {
    if (!file.value) return ElMessage.warning('请选择词表文件')
    uploading.value = true
    progress.value = 0
    try {
      const data = new FormData()
      data.append('file', file.value)
      if (uploadForm.name.trim()) data.append('name', uploadForm.name.trim())
      if (uploadForm.id.trim()) data.append('id', uploadForm.id.trim().toLowerCase())
      data.append('sortOrder', String(uploadForm.sortOrder))
      data.append('visible', String(uploadForm.visible))

      await uploadFormData(data)
      ElMessage.success('词库已上传')
      uploadVisible.value = false
      load()
    } catch (error) {
      ElMessage.error(error instanceof Error ? error.message : '上传失败')
    } finally {
      uploading.value = false
    }
  }

  async function uploadFormData(data: FormData) {
    return uploadMultipart('/admin/wordbooks/upload', data, (p) => (progress.value = p))
  }

  async function toggleVisible(row: WordBookRow, value: boolean) {
    await updateWordbook(row.id, { visible: value })
    row.visible = value
    ElMessage.success(value ? '已上架' : '已下架')
  }

  async function openPreview(row: WordBookRow) {
    previewTitle.value = `${row.name} · 预览`
    previewWords.value = []
    previewVisible.value = true
    const book = await request.get<{ words: PreviewWord[] }>({ url: `/admin/wordbooks/${row.id}` })
    previewWords.value = (book.words || []).slice(0, 50)
  }

  async function handleDelete(row: WordBookRow) {
    const confirmed = await ElMessageBox.confirm(`确定删除词库「${row.name}」？`, '删除词库', {
      type: 'warning',
      confirmButtonText: '删除',
      cancelButtonText: '取消'
    }).catch(() => false)
    if (!confirmed) return
    await deleteWordbook(row.id)
    ElMessage.success('已删除')
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

  .summary {
    display: flex;
    gap: 40px;
    padding: 16px 20px;
    margin-bottom: 14px;
    background: var(--default-box-color);
    border: 1px solid var(--art-card-border);
    border-radius: 14px;

    div {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    span {
      font-size: 12px;
      color: var(--art-gray-400);
    }

    strong {
      font-family: Georgia, serif;
      font-size: 22px;
      color: var(--art-gray-900);
    }
  }

  .panel-card {
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .book-cell {
    display: flex;
    gap: 12px;
    align-items: center;
  }

  .book-cover {
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    width: 38px;
    height: 46px;
    color: #b07050;
    background: #f6ecdf;
    border-radius: 7px;
  }

  .book-cell p {
    margin: 0 0 3px;
    font-size: 13px;
    font-weight: 500;
  }

  .book-cell span {
    display: block;
    max-width: 380px;
    overflow: hidden;
    font-size: 12px;
    color: var(--art-gray-400);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .source {
    font-size: 12px;
    color: var(--art-gray-500);
  }

  .hint {
    display: block;
    margin-top: 4px;
    font-size: 11px;
    color: var(--art-gray-400);
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .preview-foot {
    margin-top: 10px;
    font-size: 12px;
    color: var(--art-gray-400);
    text-align: right;
  }
</style>