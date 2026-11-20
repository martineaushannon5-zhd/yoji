import { AppRouteRecord } from '@/types/router'

/** Yoji 管理端菜单：仪表盘 / 内容 / 系统 / 帮助 */
export const yojiRoutes: AppRouteRecord[] = [
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: '/yoji/dashboard',
    meta: {
      title: '仪表盘',
      icon: 'ri:pie-chart-line',
      fixedTab: true,
      affix: true
    }
  },
  {
    path: '/users',
    name: 'Users',
    component: '/yoji/users',
    meta: {
      title: '用户管理',
      icon: 'ri:user-3-line',
      keepAlive: true
    }
  },
  {
    path: '/videos',
    name: 'Videos',
    component: '/yoji/videos',
    meta: {
      title: '视频管理',
      icon: 'ri:video-line',
      keepAlive: true
    }
  },
  {
    path: '/wordbooks',
    name: 'Wordbooks',
    component: '/yoji/wordbooks',
    meta: {
      title: '词库管理',
      icon: 'ri:book-2-line',
      keepAlive: true
    }
  },
  {
    path: '/audit',
    name: 'Audit',
    component: '/yoji/audit',
    meta: {
      title: '审计日志',
      icon: 'ri:file-list-3-line',
      keepAlive: true
    }
  },
  {
    path: '/system',
    name: 'System',
    component: '/yoji/system',
    meta: {
      title: '系统管理',
      icon: 'ri:settings-3-line',
      keepAlive: true
    }
  },
  {
    path: '/roadmap',
    name: 'Roadmap',
    component: '/yoji/roadmap',
    meta: {
      title: '版本计划',
      icon: 'ri:route-line'
    }
  },
  {
    path: '/help',
    name: 'Help',
    component: '/yoji/help',
    meta: {
      title: '帮助中心',
      icon: 'ri:question-line'
    }
  }
]