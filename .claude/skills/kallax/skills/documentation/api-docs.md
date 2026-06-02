# API文档技能

## 技能定义
编写API参考文档的能力，包括OpenAPI规范和文档生成。

## 适用场景
- REST API文档
- GraphQL文档
- SDK文档
- 接口规范

## 执行流程

### 1. API分析
- 端点识别
- 参数定义
- 响应格式

### 2. 规范编写
- OpenAPI规范
- 示例数据
- 错误码定义

### 3. 文档生成
- 工具选择
- 样式定制
- 交互功能

### 4. 维护更新
- 版本管理
- 变更日志
- 废弃策略

## 输出格式
```markdown
## API 文档

### 概述
**Base URL**: `https://api.example.com/v1`
**认证**: Bearer Token

### 认证

所有请求需要在 Header 中包含:
```
Authorization: Bearer <token>
```

### 端点

#### 用户

##### 获取用户列表
```
GET /users
```

**Query Parameters**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | integer | 否 | 页码，默认1 |
| limit | integer | 否 | 每页数量，默认20 |
| status | string | 否 | 筛选状态 |

**请求示例**
```bash
curl -X GET "https://api.example.com/v1/users?page=1&limit=10" \
  -H "Authorization: Bearer <token>"
```

**响应**
```json
{
  "data": [
    {
      "id": "usr_123",
      "email": "user@example.com",
      "name": "User Name",
      "status": "active",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 100,
    "totalPages": 10
  }
}
```

##### 创建用户
```
POST /users
```

**Request Body**
```json
{
  "email": "user@example.com",
  "name": "User Name",
  "role": "user"
}
```

**字段说明**
| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| email | string | 是 | 邮箱地址 |
| name | string | 是 | 用户名称 |
| role | string | 否 | 角色，默认user |

**响应**: `201 Created`
```json
{
  "id": "usr_456",
  "email": "user@example.com",
  "name": "User Name",
  "role": "user",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### 错误处理

**错误响应格式**
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": {}
  }
}
```

**通用错误码**
| 状态码 | 错误码 | 说明 |
|--------|--------|------|
| 400 | INVALID_REQUEST | 请求格式错误 |
| 401 | UNAUTHORIZED | 未认证 |
| 403 | FORBIDDEN | 无权限 |
| 404 | NOT_FOUND | 资源不存在 |
| 429 | RATE_LIMITED | 请求过频 |
| 500 | INTERNAL_ERROR | 服务器错误 |

### 速率限制
- 限制: 1000 请求/分钟
- Header: `X-RateLimit-Remaining`

### 版本控制
- 当前版本: v1
- 废弃通知: Header `X-API-Deprecated`

### SDK
- [JavaScript SDK](link)
- [Python SDK](link)
- [Go SDK](link)
```

## OpenAPI 规范

```yaml
openapi: 3.0.3
info:
  title: Example API
  version: 1.0.0
paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserList'
components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
        email:
          type: string
```
