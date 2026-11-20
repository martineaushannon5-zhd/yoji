import request from '@/utils/http'
import type { LoginResult } from './yoji'

/**
 * 管理端登录（Yoji 后端：POST /api/admin/login）
 * 模板的 LoginParams 使用 userName 字段，这里映射为后端的 account。
 */
export function fetchLogin(params: Api.Auth.LoginParams) {
  return request.post<LoginResult>({
    url: '/admin/login',
    params: { account: params.userName, password: params.password }
  })
}

/** 管理端没有单独的 user/info 接口，登录信息由本地保存的账号推导 */
export function fetchGetUserInfo() {
  const account = localStorage.getItem('yoji_admin_account') || 'admin'
  return Promise.resolve<Api.Auth.UserInfo>({
    userId: 1,
    userName: account,
    roles: ['R_SUPER'],
    buttons: [],
    email: '',
    avatar: ''
  })
}