// OpenAPI 3 描述文件：给 /api/docs 的 Swagger UI 使用，也可直接给 Apifox / Postman 导入。
// 只描述对外契约，不参与业务逻辑；新增路由时记得同步这里（server/test/openapi.test.mjs 会校验路径覆盖）。

const bearer = [{ bearerAuth: [] }];

const errorSchema = {
  type: 'object',
  properties: {
    code: { type: 'integer', example: 404 },
    message: { type: 'string', example: '接口不存在' },
    data: { nullable: true, example: null }
  }
};

const errorResponse = (description) => ({
  description,
  content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } }
});

const jsonBody = (schema, example) => ({
  required: true,
  content: { 'application/json': { schema, ...(example ? { example } : {}) } }
});

export const openapi = {
  openapi: '3.0.3',
  info: {
    title: 'Yoji API',
    version: '1.3.0',
    description: [
      'Yoji 背单词 App 与 Yoji Admin 后台使用的 HTTP 接口。',
      '',
      '约定：',
      '- 统一响应体 `{ code, message, data }`，`code === 0` 表示成功；',
      '- 需要登录的接口使用 `Authorization: Bearer <token>`；',
      '- App 用户 token 与管理员 token 是两套，不能混用；',
      '- 管理端接口统一挂在 `/api/admin` 下。'
    ].join('\n')
  },
  servers: [
    { url: 'https://yoji.zhdstudy.cyou', description: '线上环境' },
    { url: 'http://127.0.0.1:3001', description: '本地开发' }
  ],
  tags: [
    { name: 'Auth', description: 'App 用户注册、登录、资料' },
    { name: 'Progress', description: '学习进度同步' },
    { name: 'Videos', description: '视频学习列表' },
    { name: 'Wordbooks', description: '词库与词条' },
    { name: 'Admin', description: '管理后台（需要管理员 token）' },
    { name: 'System', description: '健康检查与文档' }
  ],
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }
    },
    schemas: {
      Error: errorSchema,
      User: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          username: { type: 'string' },
          nickname: { type: 'string' },
          avatar: { type: 'string', nullable: true },
          createdAt: { type: 'string', format: 'date-time' }
        }
      },
      Video: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          description: { type: 'string' },
          videoUrl: { type: 'string' },
          thumbUrl: { type: 'string', nullable: true },
          date: { type: 'string', example: '2025-01-01' },
          sortOrder: { type: 'integer' },
          visible: { type: 'boolean' }
        }
      },
      Wordbook: {
        type: 'object',
        properties: {
          id: { type: 'string', example: 'cet4' },
          name: { type: 'string', example: 'CET4' },
          count: { type: 'integer', example: 4538 },
          updatedAt: { type: 'string', format: 'date-time' }
        }
      }
    }
  },
  paths: {
    '/healthz': {
      get: {
        tags: ['System'],
        summary: '健康检查',
        responses: { 200: { description: '服务存活' } }
      }
    },
    '/api': {
      get: {
        tags: ['System'],
        summary: '接口索引',
        description: '返回版本、文档地址与按分组列出的接口清单。',
        responses: { 200: { description: '索引 JSON' } }
      }
    },
    '/api/openapi.json': {
      get: {
        tags: ['System'],
        summary: 'OpenAPI 描述',
        responses: { 200: { description: 'OpenAPI 3 文档' } }
      }
    },
    '/api/docs': {
      get: {
        tags: ['System'],
        summary: 'Swagger UI',
        responses: { 200: { description: 'HTML 文档页' } }
      }
    },

    '/api/auth/register': {
      post: {
        tags: ['Auth'],
        summary: '注册 App 用户',
        requestBody: jsonBody({
          type: 'object',
          required: ['username', 'password'],
          properties: {
            username: { type: 'string', minLength: 2, maxLength: 32 },
            password: { type: 'string', minLength: 6, maxLength: 64 },
            nickname: { type: 'string', maxLength: 32 }
          }
        }),
        responses: {
          200: { description: '注册成功，返回 token 与用户信息' },
          400: errorResponse('参数不合法'),
          409: errorResponse('用户名已存在')
        }
      }
    },
    '/api/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'App 用户登录',
        requestBody: jsonBody({
          type: 'object',
          required: ['username', 'password'],
          properties: {
            username: { type: 'string' },
            password: { type: 'string' }
          }
        }),
        responses: {
          200: { description: '登录成功，返回 token 与用户信息' },
          401: errorResponse('账号或密码错误')
        }
      }
    },
    '/api/auth/me': {
      get: {
        tags: ['Auth'],
        summary: '当前用户资料',
        security: bearer,
        responses: { 200: { description: '用户信息' }, 401: errorResponse('未登录') }
      },
      patch: {
        tags: ['Auth'],
        summary: '修改昵称等资料',
        security: bearer,
        requestBody: jsonBody({
          type: 'object',
          properties: { nickname: { type: 'string', maxLength: 32 } }
        }),
        responses: { 200: { description: '更新后的用户信息' }, 401: errorResponse('未登录') }
      }
    },
    '/api/auth/avatar': {
      post: {
        tags: ['Auth'],
        summary: '上传头像',
        security: bearer,
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                required: ['file'],
                properties: { file: { type: 'string', format: 'binary' } }
              }
            }
          }
        },
        responses: { 200: { description: '头像地址' }, 400: errorResponse('文件不合法') }
      }
    },
    '/api/auth/logout': {
      post: {
        tags: ['Auth'],
        summary: '退出登录',
        security: bearer,
        responses: { 200: { description: '已退出' } }
      }
    },

    '/api/progress': {
      get: {
        tags: ['Progress'],
        summary: '读取学习进度',
        security: bearer,
        responses: { 200: { description: '进度对象' }, 401: errorResponse('未登录') }
      },
      put: {
        tags: ['Progress'],
        summary: '覆盖写入学习进度',
        security: bearer,
        requestBody: jsonBody({
          type: 'object',
          properties: {
            learned: { type: 'array', items: { type: 'string' } },
            favorites: { type: 'array', items: { type: 'string' } },
            currentBook: { type: 'string' }
          }
        }),
        responses: { 200: { description: '保存后的进度' } }
      }
    },
    '/api/progress/sync': {
      post: {
        tags: ['Progress'],
        summary: '合并同步学习进度',
        security: bearer,
        description: '按时间戳合并客户端与服务端进度，返回合并结果。',
        requestBody: jsonBody({
          type: 'object',
          properties: {
            updatedAt: { type: 'integer' },
            learned: { type: 'array', items: { type: 'string' } }
          }
        }),
        responses: { 200: { description: '合并后的进度' } }
      }
    },

    '/api/videos': {
      get: {
        tags: ['Videos'],
        summary: '视频列表（仅显示中的）',
        responses: { 200: { description: '视频数组' } }
      }
    },
    '/api/videos/{id}': {
      get: {
        tags: ['Videos'],
        summary: '视频详情',
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '视频对象' }, 404: errorResponse('不存在') }
      }
    },

    '/api/wordbooks': {
      get: {
        tags: ['Wordbooks'],
        summary: '词库列表（含单词数）',
        responses: { 200: { description: '词库数组' } }
      }
    },
    '/api/wordbooks/full': {
      get: {
        tags: ['Wordbooks'],
        summary: '全部词库与词条',
        description: '体积较大（约 5–6MB），App 启动时拉取一次后缓存。',
        responses: { 200: { description: '词库 + 词条' } }
      }
    },
    '/api/wordbooks/{id}': {
      get: {
        tags: ['Wordbooks'],
        summary: '单个词库详情',
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '词库与词条' }, 404: errorResponse('不存在') }
      }
    },

    '/api/admin/login': {
      post: {
        tags: ['Admin'],
        summary: '管理员登录',
        requestBody: jsonBody({
          type: 'object',
          required: ['username', 'password'],
          properties: {
            username: { type: 'string', example: 'zhd' },
            password: { type: 'string', example: '123456' }
          }
        }),
        responses: { 200: { description: '管理员 token' }, 401: errorResponse('账号或密码错误') }
      }
    },
    '/api/admin/ping': {
      get: {
        tags: ['Admin'],
        summary: '校验管理员 token',
        security: bearer,
        responses: { 200: { description: 'ok' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/stats': {
      get: {
        tags: ['Admin'],
        summary: '后台概览统计',
        security: bearer,
        responses: { 200: { description: '用户数、视频数、学习趋势等' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/system': {
      get: {
        tags: ['Admin'],
        summary: '系统信息（版本/运行时/数据库/媒体/存储）',
        security: bearer,
        responses: { 200: { description: '服务版本、Node 版本、运行时长、数据库与媒体占用、存储模式' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/users': {
      get: {
        tags: ['Admin'],
        summary: '用户列表',
        security: bearer,
        parameters: [
          { name: 'page', in: 'query', schema: { type: 'integer', default: 1 } },
          { name: 'pageSize', in: 'query', schema: { type: 'integer', default: 10, maximum: 50 } },
          { name: 'search', in: 'query', schema: { type: 'string' }, description: '按账号或昵称模糊搜索' }
        ],
        responses: { 200: { description: '用户分页' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/users/export.csv': {
      get: {
        tags: ['Admin'],
        summary: '导出用户 CSV',
        description: '返回带 BOM 的 CSV 文件，Excel 打开中文不乱码，可直接用于备份或分析。',
        security: bearer,
        parameters: [
          { name: 'search', in: 'query', schema: { type: 'string' }, description: '与列表一致的搜索条件' }
        ],
        responses: {
          200: { description: 'CSV 文件', content: { 'text/csv': { schema: { type: 'string' } } } },
          401: errorResponse('未授权')
        }
      }
    },
    '/api/admin/audit': {
      get: {
        tags: ['Admin'],
        summary: '后台审计日志',
        description: '登录、删除用户、视频与词表的增删改都会记录一条；按 id 倒序返回。',
        security: bearer,
        parameters: [
          { name: 'page', in: 'query', schema: { type: 'integer', default: 1 } },
          { name: 'pageSize', in: 'query', schema: { type: 'integer', default: 20, maximum: 100 } },
          {
            name: 'action',
            in: 'query',
            schema: { type: 'string', enum: ['admin', 'user', 'video', 'wordbook'] },
            description: '按动作前缀筛选'
          },
          { name: 'account', in: 'query', schema: { type: 'string' }, description: '按操作人模糊筛选' }
        ],
        responses: { 200: { description: '审计日志分页' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/users/{id}': {
      delete: {
        tags: ['Admin'],
        summary: '删除用户',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '已删除' }, 404: errorResponse('不存在') }
      }
    },
    '/api/admin/storage': {
      get: {
        tags: ['Admin'],
        summary: '当前媒体存储模式',
        description: 'mode=oss 时前端走浏览器直传 OSS；mode=local 时仍上传到服务器磁盘。',
        security: bearer,
        responses: { 200: { description: '存储模式' }, 401: errorResponse('未授权') }
      }
    },
    '/api/admin/media/sign': {
      post: {
        tags: ['Admin'],
        summary: '获取 OSS 直传签名',
        description: '返回 policy / signature / key / publicUrl，浏览器在有效期内直接 POST 到 OSS。',
        security: bearer,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['kind', 'filename'],
                properties: {
                  kind: { type: 'string', enum: ['video', 'thumb'] },
                  filename: { type: 'string', example: 'lesson-01.mp4' }
                }
              }
            }
          }
        },
        responses: {
          200: { description: '签名与目标地址' },
          400: errorResponse('扩展名不支持'),
          409: errorResponse('OSS 未配置')
        }
      }
    },
    '/api/admin/videos': {
      get: {
        tags: ['Admin'],
        summary: '视频列表（含隐藏）',
        security: bearer,
        responses: { 200: { description: '视频数组' } }
      },
      post: {
        tags: ['Admin'],
        summary: '新增视频（JSON，引用已有地址）',
        security: bearer,
        requestBody: jsonBody({
          type: 'object',
          required: ['title', 'videoUrl'],
          properties: {
            title: { type: 'string' },
            description: { type: 'string' },
            videoUrl: { type: 'string' },
            thumbUrl: { type: 'string' },
            date: { type: 'string', example: '2025-01-01' },
            sortOrder: { type: 'integer' },
            visible: { type: 'boolean' }
          }
        }),
        responses: { 200: { description: '新建的视频' }, 400: errorResponse('参数不合法') }
      }
    },
    '/api/admin/videos/upload': {
      post: {
        tags: ['Admin'],
        summary: '上传视频文件（≤900MB）',
        security: bearer,
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                required: ['file'],
                properties: {
                  file: { type: 'string', format: 'binary' },
                  title: { type: 'string' },
                  thumb: { type: 'string', format: 'binary' }
                }
              }
            }
          }
        },
        responses: { 200: { description: '上传结果与视频记录' }, 413: errorResponse('文件过大') }
      }
    },
    '/api/admin/videos/scan': {
      post: {
        tags: ['Admin'],
        summary: '扫描 media 目录补录视频',
        security: bearer,
        responses: { 200: { description: '扫描结果' } }
      }
    },
    '/api/admin/videos/{id}': {
      patch: {
        tags: ['Admin'],
        summary: '修改视频',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: jsonBody({ type: 'object', properties: { title: { type: 'string' }, visible: { type: 'boolean' } } }),
        responses: { 200: { description: '更新后的视频' }, 404: errorResponse('不存在') }
      },
      delete: {
        tags: ['Admin'],
        summary: '删除视频',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '已删除' }, 404: errorResponse('不存在') }
      }
    },
    '/api/admin/wordbooks': {
      get: {
        tags: ['Admin'],
        summary: '词库列表（后台）',
        security: bearer,
        responses: { 200: { description: '词库数组' } }
      }
    },
    '/api/admin/wordbooks/upload': {
      post: {
        tags: ['Admin'],
        summary: '上传词库（.txt / .json，≤8MB）',
        security: bearer,
        description: '按 id 整本替换。.txt 每行 `word [音标] 释义`；.json 可带 example/exampleCn。',
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                required: ['file'],
                properties: { file: { type: 'string', format: 'binary' } }
              }
            }
          }
        },
        responses: { 200: { description: '导入结果' }, 400: errorResponse('只支持 .txt 或 .json 词表') }
      }
    },
    '/api/admin/wordbooks/sync': {
      post: {
        tags: ['Admin'],
        summary: '从官方节点同步全部词库',
        security: bearer,
        description:
          '自部署实例初始化用。默认拉取 `OFFICIAL_WORDBOOKS_URL`（官方 `/api/wordbooks/full`），' +
          '按 id 整本覆盖写入本地库；拒绝内网地址，单次上限 40MB。',
        requestBody: jsonBody({
          type: 'object',
          properties: {
            url: { type: 'string', description: '可选，自定义可信实例的 /api/wordbooks/full 地址' }
          }
        }),
        responses: {
          200: { description: '同步结果（imported / skipped / totalWords / elapsedMs）' },
          400: errorResponse('地址不合法或指向内网'),
          502: errorResponse('拉取失败或返回格式不正确')
        }
      }
    },
    '/api/admin/wordbooks/{id}': {
      get: {
        tags: ['Admin'],
        summary: '词库详情（含词条预览）',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '词库详情' } }
      },
      patch: {
        tags: ['Admin'],
        summary: '修改词库名称 / 排序',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: jsonBody({ type: 'object', properties: { name: { type: 'string' } } }),
        responses: { 200: { description: '更新后的词库' } }
      },
      delete: {
        tags: ['Admin'],
        summary: '删除词库',
        security: bearer,
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: '已删除' } }
      }
    }
  }
};

export const docsHtml = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Yoji API 文档</title>
<link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
<style>
  body { margin: 0; background: #fafafa; }
  .topbar { display: none; }
  .offline { max-width: 720px; margin: 48px auto; padding: 24px; font: 15px/1.7 system-ui, sans-serif; color: #333; background: #fff; border: 1px solid #e5e5e5; border-radius: 12px; }
  .offline code { background: #f2f2f2; padding: 2px 6px; border-radius: 4px; }
</style>
</head>
<body>
<div id="swagger-ui"></div>
<div id="offline" class="offline" hidden>
  <h3>Swagger UI 需要外网 CDN</h3>
  <p>当前环境加载不到 <code>unpkg.com</code>，可以直接访问 <a href="/api/openapi.json">/api/openapi.json</a>，把它导入 Apifox / Postman，或使用任意 OpenAPI 查看器打开。</p>
</div>
<script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" onerror="document.getElementById('offline').hidden=false"></script>
<script>
  if (window.SwaggerUIBundle) {
    window.ui = SwaggerUIBundle({
      url: '/api/openapi.json',
      dom_id: '#swagger-ui',
      deepLinking: true,
      displayRequestDuration: true,
      defaultModelsExpandDepth: 0,
      tryItOutEnabled: true
    });
  }
</script>
</body>
</html>`;