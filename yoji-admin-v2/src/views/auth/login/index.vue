<!-- Yoji 管理后台登录 -->
<template>
  <div class="yoji-login">
    <section class="brand">
      <div class="brand-inner">
        <div class="brand-top">
          <img class="brand-logo" src="@imgs/common/logo.png" alt="Yoji" />
          <span class="brand-name">Yoji</span>
        </div>

        <h1>把每个单词<br />变成一次真实的进步</h1>
        <p class="brand-sub">
          Yoji 背单词 App 的运营后台。词库、视频、用户与学习数据，在这里一次管好。
        </p>

        <ul class="brand-points">
          <li><span>01</span>词库与视频可视化维护，内容上线不再等发版</li>
          <li><span>02</span>学习进度、连续打卡与活跃趋势一屏可见</li>
          <li><span>03</span>关键操作全量留痕，问题可以追到人</li>
        </ul>

        <div class="brand-foot">Yoji · 要记单词</div>
      </div>
    </section>

    <section class="panel">
      <div class="form-wrap">
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
            登录控制台
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

  .yoji-login {
    display: grid;
    grid-template-columns: 1.05fr 0.95fr;
    width: 100%;
    height: 100vh;
    overflow: hidden;
    background: $cream;
    color: $ink;
  }

  .brand {
    position: relative;
    display: flex;
    align-items: center;
    padding: 64px 72px;
    overflow: hidden;
    background:
      radial-gradient(900px 520px at 12% 8%, rgba(201, 100, 66, 0.22), transparent 62%),
      radial-gradient(720px 420px at 88% 96%, rgba(120, 140, 110, 0.18), transparent 60%),
      linear-gradient(150deg, #fbf6ec 0%, #f1e7d6 52%, #e8ddc9 100%);

    &::after {
      position: absolute;
      right: -120px;
      bottom: -140px;
      width: 420px;
      height: 420px;
      content: '';
      border: 1px solid rgba(201, 100, 66, 0.22);
      border-radius: 50%;
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
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 6px 18px rgba(80, 60, 40, 0.12);
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
      padding: 12px 0;
      font-size: 14px;
      color: #5c5246;
      border-top: 1px solid rgba(90, 74, 58, 0.12);

      span {
        font-family: Georgia, serif;
        font-size: 12px;
        color: $terracotta;
      }
    }
  }

  .brand-foot {
    margin-top: 72px;
    font-size: 12px;
    letter-spacing: 0.18em;
    color: rgba(90, 74, 58, 0.55);
    text-transform: uppercase;
  }

  .panel {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px;
    background: #fffdf8;
  }

  .form-wrap {
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

  .submit {
    width: 100%;
    height: 46px;
    margin-top: 8px;
    font-size: 15px;
    letter-spacing: 0.06em;
    background: $terracotta;
    border-color: $terracotta;

    &:hover,
    &:focus {
      background: #b4563a;
      border-color: #b4563a;
    }
  }

  .tip {
    margin-top: 28px;
    font-size: 12px;
    color: #a3978a;
    text-align: center;
  }

  :deep(.el-input__wrapper) {
    height: 46px;
    background: #faf6ee;
    border-radius: 10px;
    box-shadow: 0 0 0 1px #e7ddcd inset;
  }

  :deep(.el-input__wrapper.is-focus) {
    box-shadow: 0 0 0 1px $terracotta inset;
  }

  @media (max-width: 960px) {
    .yoji-login {
      grid-template-columns: 1fr;
    }

    .brand {
      display: none;
    }
  }
</style>