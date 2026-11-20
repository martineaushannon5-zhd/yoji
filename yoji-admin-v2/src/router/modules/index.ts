import { AppRouteRecord } from '@/types/router'
import { yojiRoutes } from './yoji'

/**
 * 导出所有模块化路由
 * Yoji 管理端只保留业务菜单，模板自带的示例页面不再注册。
 */
export const routeModules: AppRouteRecord[] = [...yojiRoutes]