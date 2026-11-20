<!-- Yoji 视频管理 -->
<template>
  <div class="yoji-page">
    <header class="page-head">
      <div>
        <p class="eyebrow">VIDEOS</p>
        <h1>视频管理</h1>
        <p class="sub">上传、排序与上下架，封面和视频地址都在这维护</p>
      </div>
      <div class="head-actions">
        <span class="storage-tag" :class="storage?.mode === 'oss' ? 'oss' : 'local'">
          {{ storage?.mode === 'oss' ? 'OSS 直传' : '本地存储' }}
        </span>
        <ElButton @click="load">
          <ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新
        </ElButton>
        <ElButton type="primary" @click="openCreate">
          <ArtSvgIcon icon="ri:upload-cloud-2-line" class="mr-1" />上传视频
        </ElButton>
      </div>
    </header>

    <ElCard class="panel-card" shadow="never">
      <ElTable :data="videos" v-loading="loading" stripe>
        <ElTableColumn label="视频" min-width="300">
          <template #default="{ row }">
            <div class="video-cell">
              <div class="thumb">
                <img v-if="row.thumbUrl" :src="mediaUrl(row.thumbUrl)" alt="" />
                <ArtSvgIcon v-else icon="ri:video-line" />
              </div>
              <div class="meta">
                <p>{{ row.title }}</p>
                <span>{{ row.description || '暂无简介' }}</span>
              </div>
            </div>
          </template>
        </ElTableColumn>

        <ElTableColumn label="日期" width="120" prop="date" />

        <ElTableColumn label="排序" width="80">
          <template #default="{ row }">{{ row.sortOrder }}</template>
        </ElTableColumn>

        <ElTableColumn label="状态" width="90">
          <template #default="{ row }">
            <ElTag :type="row.visible ? 'success' : 'info'" effect="light" size="small">
              {{ row.visible ? '已上架' : '已下架' }}
            </ElTag>
          </template>
        </ElTableColumn>

        <ElTableColumn label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <ElButton link type="primary" @click="openEdit(row)">编辑</ElButton>
            <ElButton link type="danger" @click="handleDelete(row as VideoRow)">删除</ElButton>
          </template>
        </ElTableColumn>
      </ElTable>

      <ElEmpty v-if="!loading && !videos.length" description="还没有视频，先上传第一个" />
    </ElCard>

    <ElDialog v-model="dialogVisible" :title="editing ? '编辑视频' : '上传视频'" width="560px">
      <ElForm label-width="86px" label-position="top">
        <ElFormItem label="标题" required>
          <ElInput v-model="form.title" maxlength="100" show-word-limit placeholder="例如：焦虑的时候，大脑发生了什么" />
        </ElFormItem>

        <div class="form-row">
          <ElFormItem label="发布日期" required>
            <ElDatePicker v-model="form.date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
          </ElFormItem>
          <ElFormItem label="排序">
            <ElInputNumber v-model="form.sortOrder" :min="0" :controls="false" style="width: 100%" />
          </ElFormItem>
        </div>

        <ElFormItem label="简介">
          <ElInput v-model="form.description" type="textarea" :rows="2" maxlength="500" show-word-limit />
        </ElFormItem>

        <template v-if="!editing">
          <ElFormItem label="视频文件" required>
            <input ref="videoInput" type="file" accept="video/mp4,video/webm,video/x-m4v" @change="onVideoPick" />
            <span class="hint">支持 mp4 / webm / m4v，最大 900MB</span>
          </ElFormItem>
          <ElFormItem label="封面图">
            <input ref="coverInput" type="file" accept="image/png,image/jpeg,image/webp" @change="onCoverPick" />
            <span class="hint">可选，png / jpg / webp，最大 5MB</span>
          </ElFormItem>
        </template>

        <ElFormItem v-if="editing" label="视频地址">
          <ElInput v-model="form.videoUrl" placeholder="相对路径或 https:// 绝对地址" />
        </ElFormItem>
        <ElFormItem v-if="editing" label="封面地址">
          <ElInput v-model="form.thumbUrl" placeholder="相对路径或 https:// 绝对地址" />
        </ElFormItem>

        <ElFormItem label="上架状态">
          <ElSwitch v-model="form.visible" active-text="上架" inactive-text="下架" />
        </ElFormItem>

        <ElProgress v-if="progress > 0 && progress < 100" :percentage="progress" :stroke-width="6" />
      </ElForm>
      <template #footer>
        <ElButton @click="dialogVisible = false">取消</ElButton>
        <ElButton type="primary" :loading="saving" @click="handleSubmit">
          {{ editing ? '保存修改' : '开始上传' }}
        </ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
  import { onMounted, reactive, ref } from 'vue'
  import { ElMessage, ElMessageBox } from 'element-plus'
  import {
    API_ORIGIN,
    createVideo,
    deleteVideo,
    fetchStorage,
    fetchVideos,
    putToOss,
    signMedia,
    updateVideo,
    uploadForm,
    type StorageInfo,
    type VideoRow
  } from '@/api/yoji'

  defineOptions({ name: 'Videos' })

  const loading = ref(false)
  const saving = ref(false)
  const videos = ref<VideoRow[]>([])
  const storage = ref<StorageInfo | null>(null)
  const dialogVisible = ref(false)
  const editing = ref<VideoRow | null>(null)
  const progress = ref(0)
  const videoFile = ref<File | null>(null)
  const coverFile = ref<File | null>(null)

  const form = reactive({
    title: '',
    date: new Date().toISOString().slice(0, 10),
    description: '',
    sortOrder: 0,
    visible: true,
    videoUrl: '',
    thumbUrl: ''
  })

  function mediaUrl(url: string) {
    if (!url) return ''
    if (/^https?:\/\//i.test(url)) return url
    return `${API_ORIGIN}${url}`
  }

  async function load() {
    loading.value = true
    try {
      const [videoData, storageData] = await Promise.all([
        fetchVideos(),
        fetchStorage().catch(() => null)
      ])
      videos.value = videoData.videos || []
      storage.value = storageData
    } finally {
      loading.value = false
    }
  }

  function openCreate() {
    editing.value = null
    Object.assign(form, {
      title: '',
      date: new Date().toISOString().slice(0, 10),
      description: '',
      sortOrder: videos.value.length + 1,
      visible: true,
      videoUrl: '',
      thumbUrl: ''
    })
    videoFile.value = null
    coverFile.value = null
    progress.value = 0
    dialogVisible.value = true
  }

  function openEdit(row: VideoRow) {
    editing.value = row
    Object.assign(form, {
      title: row.title,
      date: row.date,
      description: row.description,
      sortOrder: row.sortOrder,
      visible: row.visible,
      videoUrl: row.videoUrl,
      thumbUrl: row.thumbUrl
    })
    dialogVisible.value = true
  }

  function onVideoPick(event: Event) {
    const input = event.target as HTMLInputElement
    videoFile.value = input.files?.[0] || null
  }

  function onCoverPick(event: Event) {
    const input = event.target as HTMLInputElement
    coverFile.value = input.files?.[0] || null
  }

  async function submitLocal() {
    const formData = new FormData()
    formData.append('title', form.title)
    formData.append('date', form.date)
    formData.append('description', form.description)
    formData.append('sortOrder', String(form.sortOrder))
    formData.append('visible', String(form.visible))
    if (videoFile.value) formData.append('video', videoFile.value)
    if (coverFile.value) formData.append('cover', coverFile.value)
    await uploadForm('/admin/videos/upload', formData, (p) => (progress.value = p))
  }

  async function submitOss() {
    if (!videoFile.value) throw new Error('请选择视频文件')
    const videoTicket = await signMedia({ kind: 'video', filename: videoFile.value.name })
    await putToOss(videoTicket, videoFile.value, (p) => (progress.value = Math.round(p * 0.9)))

    let thumbUrl = ''
    if (coverFile.value) {
      const thumbTicket = await signMedia({ kind: 'thumb', filename: coverFile.value.name })
      await putToOss(thumbTicket, coverFile.value, (p) => (progress.value = 90 + Math.round(p * 0.1)))
      thumbUrl = thumbTicket.publicUrl
    }

    await createVideo({
      title: form.title,
      date: form.date,
      description: form.description,
      sortOrder: form.sortOrder,
      visible: form.visible,
      videoUrl: videoTicket.publicUrl,
      thumbUrl,
      duration: 0
    })
  }

  async function handleSubmit() {
    if (!form.title.trim()) return ElMessage.warning('请填写标题')
    if (!form.date) return ElMessage.warning('请选择发布日期')

    saving.value = true
    progress.value = 0
    try {
      if (editing.value) {
        await updateVideo(editing.value.id, {
          title: form.title,
          date: form.date,
          description: form.description,
          sortOrder: form.sortOrder,
          visible: form.visible,
          videoUrl: form.videoUrl,
          thumbUrl: form.thumbUrl
        })
        ElMessage.success('视频已更新')
      } else if (storage.value?.mode === 'oss') {
        await submitOss()
        ElMessage.success('已直传 OSS 并上架')
      } else {
        await submitLocal()
        ElMessage.success('视频已上传')
      }
      progress.value = 100
      dialogVisible.value = false
      load()
    } catch (error) {
      ElMessage.error(error instanceof Error ? error.message : '操作失败')
    } finally {
      saving.value = false
    }
  }

  async function handleDelete(row: VideoRow) {
    const confirmed = await ElMessageBox.confirm(`确定删除「${row.title}」？`, '删除视频', {
      type: 'warning',
      confirmButtonText: '删除',
      cancelButtonText: '取消'
    }).catch(() => false)
    if (!confirmed) return
    await deleteVideo(row.id)
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

  .head-actions {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .storage-tag {
    padding: 3px 9px;
    font-size: 11px;
    border-radius: 999px;

    &.oss {
      color: #3f6b52;
      background: #e6f0e8;
    }

    &.local {
      color: #8a6a3f;
      background: #f6ecdd;
    }
  }

  .panel-card {
    border: 1px solid var(--art-card-border);
    border-radius: 14px;
  }

  .video-cell {
    display: flex;
    gap: 12px;
    align-items: center;
  }

  .thumb {
    display: flex;
    flex: none;
    align-items: center;
    justify-content: center;
    width: 96px;
    height: 54px;
    overflow: hidden;
    color: var(--art-gray-300);
    background: #f2eadf;
    border-radius: 8px;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  .meta {
    min-width: 0;

    p {
      margin: 0 0 3px;
      overflow: hidden;
      font-size: 13px;
      font-weight: 500;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    span {
      display: block;
      max-width: 420px;
      overflow: hidden;
      font-size: 12px;
      color: var(--art-gray-400);
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .hint {
    display: block;
    margin-top: 4px;
    font-size: 11px;
    color: var(--art-gray-400);
  }
</style>