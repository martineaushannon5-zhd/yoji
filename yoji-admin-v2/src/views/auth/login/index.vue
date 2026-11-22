<!-- Yoji 管理后台登录 -->
<template>
  <div class="yoji-login">
    <section class="brand">
      <!-- 动态背景：漂移光斑 + 旋转圆环 -->
      <div class="blobs" aria-hidden="true">
        <span class="blob blob-a"></span>
        <span class="blob blob-b"></span>
        <span class="blob blob-c"></span>
      </div>
      <div class="ring ring-a" aria-hidden="true"></div>
      <div class="ring ring-b" aria-hidden="true"></div>

      <div class="brand-inner">
        <div class="brand-top rise d0">
          <img class="brand-logo" src="@imgs/common/logo.png" alt="Yoji" />
          <span class="brand-name">Yoji</span>
        </div>

        <h1 class="rise d1">把每个单词<br />变成一次真实的进步</h1>
        <p class="brand-sub rise d3">
          Yoji 背单词 App 的运营后台。词库、视频、用户与学习数据，在这里一次管好。
        </p>

        <ul class="brand-points">
          <li class="rise d4"><span>01</span>词库与视频可视化维护，内容上线不再等发版</li>
          <li class="rise d5"><span>02</span>学习进度、连续打卡与活跃趋势一屏可见</li>
          <li class="rise d6"><span>03</span>关键操作全量留痕，问题可以追到人</li>
        </ul>

        <div class="brand-foot rise d7">Yoji · 要记单词</div>
      </div>

      <!-- 漂浮的单词卡片 -->
      <div class="word-card float" aria-hidden="true">
        <span class="word-en">serendipity</span>
        <span class="word-zh">n. 意外收获的美好</span>
        <span class="word-bar"><i></i></span>
      </div>
    </section>

    <section class="panel">
      <div class="form-wrap rise d2">
        <h2>欢迎回来</h2>
        <p class="panel-sub">使用管理员账号登录控制台</p>

        <ElForm ref="formRef" :model="form" :rules="rules" size="large" @keyup.enter="handleSubmit">
          <ElFormItem prop="account">
            <ElInput v-model.trim="form.account" placeholder="管理员账号" autocomplete="username">
              <template #prefix><ArtSvgIcon icon="ri:user-3-line" /></template>
            </ElInput>
          </ElFormItem>
          <ElFormItem prop="password">
            <ElInput
              v-model.trim="form.password"
              type="password"
              placeholder="密码"
              autocomplete="current-password"
              show-password
            >
              <template #prefix><ArtSvgIcon icon="ri:lock-2-line" /></template>
            </ElInput>
          </ElFormItem>

          <ElButton class="submit" type="primary" :loading="loading" @click="handleSubmit">
            <span class="submit-text">登录控制台</span>
          </ElButton>
        </ElForm>

        <p class="tip">仅限管理员访问 · 登录状态 12 小时内有效</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue'
  import { useRouter, useRoute } from 'vue-router'
  import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
  import { fetchLogin } from '@/api/auth'
  import { useUserStore } from '@/store/modules/user'

  defineOptions({ name: 'Login' })

  const router = useRouter()
  const route = useRoute()
  const userStore = useUserStore()

  const formRef = ref<FormInstance>()
  const loading = ref(false)
  const form = reactive({ account: '', password: '' })

  const rules: FormRules = {
    account: [{ required: true, message: '请输入管理员账号', trigger: 'blur' }],
    password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
  }

  async function handleSubmit() {
    if (!formRef.value || loading.value) return
    const valid = await formRef.value.validate().catch(() => false)
    if (!valid) return

    loading.value = true
    try {
      const result = await fetchLogin({ userName: form.account, password: form.password })
      if (!result?.token) throw new Error('登录失败：未返回 token')

      localStorage.setItem('yoji_admin_account', result.account || form.account)
      userStore.setToken(result.token)
      userStore.setUserInfo({
        userId: 1,
        userName: result.account || form.account,
        roles: ['R_SUPER'],
        buttons: [],
        email: '',
        avatar: ''
      })
      userStore.setLoginStatus(true)

      ElMessage.success(`欢迎回来，${result.account || form.account}`)
      const redirect = (route.query.redirect as string) || '/dashboard'
      router.replace(redirect)
    } catch (error) {
      const message = error instanceof Error ? error.message : '登录失败，请稍后重试'
      ElMessage.error(message)
    } finally {
      loading.value = false
    }
  }
</script>

<style scoped lang="scss">
  $ink: #322c24;
  $muted: #7b7061;
  $cream: #f6f0e4;
  $terracotta: #c96442;
  $terracotta-deep: #b4563a;
  $ease-out: cubic-bezier(0.22, 1, 0.36, 1);

  .yoji-login {
    display: grid;
    grid-template-columns: 1.05fr 0.95fr;
    width: 100%;
    height: 100vh;
    overflow: hidden;
    color: $ink;
    background: $cream;
  }

  /* ---------- 入场动画 ---------- */
  .rise {
    opacity: 0;
    animation: rise 0.7s $ease-out var(--d, 0ms) forwards;
  }

  .d0 {
    --d: 0ms;
  }

  .d1 {
    --d: 80ms;
  }

  .d2 {
    --d: 120ms;
  }

  .d3 {
    --d: 160ms;
  }

  .d4 {
    --d: 240ms;
  }

  .d5 {
    --d: 320ms;
  }

  .d6 {
    --d: 400ms;
  }

  .d7 {
    --d: 480ms;
  }

  @keyframes rise {
    from {
      opacity: 0;
      transform: translateY(18px);
    }

    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .float {
    animation: float 7s ease-in-out infinite;
  }

  @keyframes float {
    0%,
    100% {
      transform: translateY(0) rotate(-1.5deg);
    }

    50% {
      transform: translateY(-14px) rotate(1deg);
    }
  }

  /* ---------- 左侧品牌区 ---------- */
  .brand {
    position: relative;
    display: flex;
    align-items: center;
    padding: 64px 72px;
    overflow: hidden;
    background:
      radial-gradient(900px 520px at 12% 8%, rgb(201 100 66 / 22%), transparent 62%),
      radial-gradient(720px 420px at 88% 96%, rgb(120 140 110 / 18%), transparent 60%),
      linear-gradient(150deg, #fbf6ec 0%, #f1e7d6 52%, #e8ddc9 100%);
  }

  /* 漂移光斑 */
  .blobs {
    position: absolute;
    inset: 0;
    pointer-events: none;
    filter: blur(40px);
  }

  .blob {
    position: absolute;
    border-radius: 50%;
    opacity: 0.55;
    will-change: transform;
  }

  .blob-a {
    top: -120px;
    left: -80px;
    width: 420px;
    height: 420px;
    background: rgb(201 100 66 / 28%);
    animation: drift-a 16s ease-in-out infinite;
  }

  .blob-b {
    right: -140px;
    bottom: -120px;
    width: 460px;
    height: 460px;
    background: rgb(120 150 110 / 26%);
    animation: drift-b 20s ease-in-out infinite;
  }

  .blob-c {
    top: 38%;
    left: 46%;
    width: 240px;
    height: 240px;
    background: rgb(233 180 120 / 30%);
    animation: drift-c 13s ease-in-out infinite;
  }

  @keyframes drift-a {
    0%,
    100% {
      transform: translate(0, 0) scale(1);
    }

    50% {
      transform: translate(60px, 40px) scale(1.12);
    }
  }

  @keyframes drift-b {
    0%,
    100% {
      transform: translate(0, 0) scale(1);
    }

    50% {
      transform: translate(-70px, -30px) scale(0.92);
    }
  }

  @keyframes drift-c {
    0%,
    100% {
      transform: translate(0, 0);
    }

    33% {
      transform: translate(-40px, 30px);
    }

    66% {
      transform: translate(30px, -40px);
    }
  }

  /* 旋转圆环 */
  .ring {
    position: absolute;
    pointer-events: none;
    border: 1px solid rgb(201 100 66 / 22%);
    border-radius: 50%;
  }

  .ring-a {
    right: -120px;
    bottom: -140px;
    width: 420px;
    height: 420px;
    animation: spin 60s linear infinite;
  }

  .ring-b {
    right: 40px;
    bottom: 60px;
    width: 180px;
    height: 180px;
    border-color: rgb(201 100 66 / 30%);
    border-style: dashed;
    animation: spin 40s linear infinite reverse;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .brand-inner {
    position: relative;
    z-index: 1;
    max-width: 520px;
  }

  .brand-top {
    display: flex;
    gap: 12px;
    align-items: center;
    margin-bottom: 64px;
  }

  .brand-logo {
    width: 44px;
    height: 44px;
    object-fit: contain;
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 6px 18px rgb(80 60 40 / 12%);
    transition: transform 0.4s $ease-out;

    &:hover {
      transform: rotate(-8deg) scale(1.06);
    }
  }

  .brand-name {
    font-size: 22px;
    font-weight: 600;
    letter-spacing: 0.04em;
  }

  h1 {
    margin: 0 0 20px;
    font-family: 'Songti SC', 'Noto Serif SC', Georgia, serif;
    font-size: 44px;
    font-weight: 600;
    line-height: 1.24;
    letter-spacing: 0.01em;
  }

  .brand-sub {
    max-width: 430px;
    margin: 0 0 36px;
    font-size: 15px;
    line-height: 1.8;
    color: $muted;
  }

  .brand-points {
    padding: 0;
    margin: 0;
    list-style: none;

    li {
      display: flex;
      gap: 14px;
      align-items: baseline;
      padding: 12px 8px;
      margin: 0 -8px;
      font-size: 14px;
      color: #5c5246;
      border-top: 1px solid rgb(90 74 58 / 12%);
      border-radius: 8px;
      transition:
        background-color 0.3s,
        transform 0.3s $ease-out;

      &:hover {
        background: rgb(201 100 66 / 7%);
        transform: translateX(6px);
      }

      span {
        font-family: Georgia, serif;
        font-size: 12px;
        color: $terracotta;
      }
    }
  }

  /* 单词卡片 */
  .word-card {
    position: absolute;
    top: 120px;
    right: 56px;
    z-index: 2;
    display: flex;
    flex-direction: column;
    gap: 6px;
    width: 220px;
    padding: 18px 20px;
    background: rgb(255 253 248 / 85%);
    backdrop-filter: blur(6px);
    border: 1px solid rgb(201 100 66 / 18%);
    border-radius: 16px;
    box-shadow: 0 18px 40px rgb(80 60 40 / 12%);
  }

  .word-en {
    font-family: Georgia, serif;
    font-size: 22px;
    color: $ink;
  }

  .word-zh {
    font-size: 13px;
    color: $muted;
  }

  .word-bar {
    position: relative;
    height: 4px;
    margin-top: 8px;
    overflow: hidden;
    background: rgb(201 100 66 / 15%);
    border-radius: 999px;

    i {
      position: absolute;
      inset: 0;
      width: 0;
      background: $terracotta;
      border-radius: inherit;
      animation: fill 4.5s $ease-out infinite;
    }
  }

  @keyframes fill {
    0% {
      width: 0;
    }

    70%,
    100% {
      width: 100%;
    }
  }

  .brand-foot {
    margin-top: 72px;
    font-size: 12px;
    color: rgb(90 74 58 / 55%);
    text-transform: uppercase;
    letter-spacing: 0.18em;
  }

  /* ---------- 右侧表单区 ---------- */
  .panel {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px;
    overflow: hidden;
    background: #fffdf8;
  }

  .form-wrap {
    position: relative;
    z-index: 1;
    width: 100%;
    max-width: 380px;
  }

  h2 {
    margin: 0 0 8px;
    font-family: 'Songti SC', 'Noto Serif SC', Georgia, serif;
    font-size: 30px;
    font-weight: 600;
  }

  .panel-sub {
    margin: 0 0 32px;
    font-size: 14px;
    color: $muted;
  }

  /* 输入框：聚焦时柔和光晕 */
  :deep(.el-form-item) {
    margin-bottom: 20px;
  }

  :deep(.el-input__wrapper) {
    height: 46px;
    background: #faf6ee;
    border-radius: 10px;
    box-shadow: 0 0 0 1px #e7ddcd inset;
    transition:
      box-shadow 0.3s,
      background-color 0.3s;

    &:hover {
      background: #fbf8f1;
      box-shadow: 0 0 0 1px #d9ccb6 inset;
    }
  }

  :deep(.el-input__wrapper.is-focus) {
    background: #fffdf8;
    box-shadow:
      0 0 0 1px $terracotta inset,
      0 0 0 4px rgb(201 100 66 / 12%);
  }

  /* 登录按钮：悬停上浮 + 光泽扫过 */
  .submit {
    position: relative;
    width: 100%;
    height: 46px;
    margin-top: 8px;
    overflow: hidden;
    font-size: 15px;
    letter-spacing: 0.06em;
    background: $terracotta;
    border-color: $terracotta;
    transition:
      transform 0.25s $ease-out,
      box-shadow 0.25s,
      background-color 0.25s;

    &::after {
      position: absolute;
      top: 0;
      left: -60%;
      width: 40%;
      height: 100%;
      pointer-events: none;
      content: '';
      background: linear-gradient(100deg, transparent, rgb(255 255 255 / 35%), transparent);
      transform: skewX(-20deg);
    }

    &:hover:not(.is-disabled),
    &:focus-visible:not(.is-disabled) {
      background: $terracotta-deep;
      border-color: $terracotta-deep;
      box-shadow: 0 10px 24px rgb(201 100 66 / 32%);
      transform: translateY(-2px);

      &::after {
        animation: shine 0.9s $ease-out;
      }
    }

    &:active:not(.is-disabled) {
      transform: translateY(0);
    }
  }

  @keyframes shine {
    to {
      left: 120%;
    }
  }

  .tip {
    margin-top: 28px;
    font-size: 12px;
    color: #a3978a;
    text-align: center;
  }

  /* ---------- 响应式 ---------- */
  @media (width <= 1100px) {
    .word-card {
      display: none;
    }
  }

  @media (width <= 960px) {
    .yoji-login {
      grid-template-columns: 1fr;
    }

    .brand {
      display: none;
    }
  }

  /* 尊重系统“减少动态效果”设置 */
  @media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
      transition-duration: 0.01ms !important;
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
    }

    .rise {
      opacity: 1;
    }
  }
</style>
