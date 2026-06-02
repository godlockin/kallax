# Performer 设计规则

> KALLAX 设计工作专项规范 v1.0

---

## 1. 设计流程

### 1.1 标准流程

```
┌─────────────────┐
│  1. 需求理解    │
│  阅读 Ticket    │
│  确认 AC        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. 技术调研    │
│  查询知识库     │
│  评估方案       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. 方案设计    │
│  写设计文档     │
│  画架构图       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. 设计评审    │
│  Conductor 审核 │
│  专家组评审     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  5. 开始实现    │
└─────────────────┘
```

### 1.2 设计文档模板

```markdown
# 设计文档: [功能名称]

## 1. 背景
[为什么需要这个功能]

## 2. 目标
- 目标 1
- 目标 2
- 非目标: [明确不做什么]

## 3. 方案设计

### 3.1 整体架构
[架构图]

### 3.2 核心流程
[流程图]

### 3.3 数据模型
[ER 图或类型定义]

### 3.4 API 设计
[接口定义]

## 4. 技术选型
| 组件 | 选型 | 理由 |
|-----|-----|-----|
| ... | ... | ... |

## 5. 风险评估
| 风险 | 影响 | 缓解措施 |
|-----|-----|---------|
| ... | ... | ... |

## 6. 里程碑
| 阶段 | 内容 | 预估时间 |
|-----|-----|---------|
| ... | ... | ... |
```

---

## 2. 架构设计原则

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (Controllers, API Handlers, CLI Commands)                  │
│                                                              │
│  职责: 接收请求, 参数验证, 调用服务, 返回响应               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (Services, Use Cases)                                       │
│                                                              │
│  职责: 业务逻辑编排, 事务管理, 领域对象协调                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  (Entities, Value Objects, Domain Services)                  │
│                                                              │
│  职责: 核心业务规则, 领域模型, 业务验证                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  (Repositories, External Services, Database)                 │
│                                                              │
│  职责: 数据持久化, 外部服务集成, 技术实现                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 依赖方向

```typescript
// ❌ 禁止 - 上层依赖下层实现
class UserController {
  constructor() {
    this.repository = new PostgresUserRepository();  // 直接依赖实现
  }
}

// ✅ 正确 - 依赖抽象
interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<User>;
}

class UserController {
  constructor(private userService: UserService) {}  // 依赖抽象
}

class UserService {
  constructor(private repository: UserRepository) {}  // 依赖接口
}

// 在组装层注入具体实现
const repository = new PostgresUserRepository(db);
const service = new UserService(repository);
const controller = new UserController(service);
```

### 2.3 禁止跨层调用

```typescript
// ❌ 禁止 - Controller 直接访问 Repository
class UserController {
  async getUser(id: string) {
    return await userRepository.findById(id);  // 跳过 Service 层
  }
}

// ❌ 禁止 - Controller 直接访问数据库
class UserController {
  async getUser(id: string) {
    return await db.query('SELECT * FROM users WHERE id = ?', [id]);
  }
}

// ✅ 正确 - 通过 Service 层
class UserController {
  constructor(private userService: UserService) {}
  
  async getUser(id: string) {
    return await this.userService.findById(id);
  }
}
```

---

## 3. API 设计

### 3.1 RESTful 规范

```typescript
// 资源命名 - 使用复数名词
GET    /api/tasks         // 列表
POST   /api/tasks         // 创建
GET    /api/tasks/:id     // 获取单个
PUT    /api/tasks/:id     // 完整更新
PATCH  /api/tasks/:id     // 部分更新
DELETE /api/tasks/:id     // 删除

// 子资源
GET    /api/tasks/:id/comments    // 任务的评论
POST   /api/tasks/:id/comments    // 添加评论

// 动作 (非 CRUD 操作)
POST   /api/tasks/:id/claim       // 领取任务
POST   /api/tasks/:id/complete    // 完成任务
```

### 3.2 请求/响应格式

```typescript
// 请求体
interface CreateTaskRequest {
  title: string;
  description?: string;
  priority: 'P0' | 'P1' | 'P2' | 'P3';
  assignee?: string;
}

// 成功响应
interface SuccessResponse<T> {
  success: true;
  data: T;
  meta?: {
    total?: number;
    page?: number;
    pageSize?: number;
  };
}

// 错误响应
interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: Record<string, string[]>;
  };
}

// 示例
// 成功
{
  "success": true,
  "data": {
    "id": "task-123",
    "title": "Implement login",
    "status": "ready"
  }
}

// 错误
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request",
    "details": {
      "title": ["Title is required"],
      "priority": ["Invalid priority value"]
    }
  }
}
```

### 3.3 状态码使用

```typescript
// 成功
200 OK              // 成功 (GET, PUT, PATCH, DELETE)
201 Created         // 创建成功 (POST)
204 No Content      // 删除成功,无返回体

// 客户端错误
400 Bad Request     // 请求格式错误
401 Unauthorized    // 未认证
403 Forbidden       // 无权限
404 Not Found       // 资源不存在
409 Conflict        // 资源冲突 (如重复创建)
422 Unprocessable   // 业务验证失败

// 服务器错误
500 Internal Error  // 服务器内部错误
502 Bad Gateway     // 上游服务错误
503 Unavailable     // 服务不可用
```

---

## 4. 数据库设计

### 4.1 命名规范

```sql
-- 表名: 复数,snake_case
CREATE TABLE tasks (
  -- 字段名: snake_case
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- 外键: 表名单数_id
  performer_id UUID REFERENCES performers(id),
  
  -- 枚举字段
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  priority VARCHAR(10) NOT NULL DEFAULT 'P2'
);

-- 索引名: idx_表名_字段名
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_performer_id ON tasks(performer_id);

-- 唯一约束: uq_表名_字段名
CREATE UNIQUE INDEX uq_tasks_title_epic ON tasks(title, epic_id);
```

### 4.2 必要字段

```sql
-- 每个表必须有
CREATE TABLE example (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  -- 主键
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- 创建时间
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- 更新时间
  
  -- 可选但推荐
  created_by UUID REFERENCES users(id),  -- 创建人
  updated_by UUID REFERENCES users(id),  -- 更新人
  deleted_at TIMESTAMP WITH TIME ZONE,   -- 软删除时间
  version INTEGER DEFAULT 1              -- 乐观锁版本
);
```

### 4.3 Migration 规范

```sql
-- 文件名: 20240115143022_create_tasks.sql
-- 格式: YYYYMMDDHHMMSS_description.sql

-- UP: 应用变更
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL
);

-- DOWN: 回滚变更 (在同一文件或单独的 down 文件)
DROP TABLE tasks;
```

---

## 5. 安全设计

### 5.1 认证设计

```typescript
// JWT Token 结构
interface JWTPayload {
  sub: string;       // 用户 ID
  email: string;     // 邮箱
  roles: string[];   // 角色列表
  iat: number;       // 签发时间
  exp: number;       // 过期时间
}

// Token 过期策略
const ACCESS_TOKEN_EXPIRY = '15m';   // 访问令牌: 15 分钟
const REFRESH_TOKEN_EXPIRY = '7d';   // 刷新令牌: 7 天

// 刷新流程
// 1. Access Token 过期
// 2. 使用 Refresh Token 获取新的 Access Token
// 3. Refresh Token 只能使用一次 (rotation)
```

### 5.2 授权设计

```typescript
// 基于角色的访问控制 (RBAC)
const permissions = {
  admin: ['*'],  // 所有权限
  conductor: [
    'task:read',
    'task:create',
    'task:assign',
    'task:review',
    'pr:merge'
  ],
  performer: [
    'task:read',
    'task:claim',
    'task:complete',
    'pr:create'
  ]
};

// 中间件检查
function requirePermission(permission: string) {
  return (req, res, next) => {
    const user = req.user;
    const userPermissions = permissions[user.role];
    
    if (!userPermissions.includes('*') && !userPermissions.includes(permission)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    next();
  };
}

// 使用
router.post('/tasks/:id/claim', 
  requirePermission('task:claim'),
  taskController.claim
);
```

### 5.3 输入验证

```typescript
// 使用 Zod 进行验证
import { z } from 'zod';

const CreateTaskSchema = z.object({
  title: z.string()
    .min(1, 'Title is required')
    .max(255, 'Title too long'),
  description: z.string()
    .max(10000)
    .optional(),
  priority: z.enum(['P0', 'P1', 'P2', 'P3']),
  assignee: z.string().uuid().optional()
});

// 在 Controller 中使用
async function createTask(req: Request, res: Response) {
  const validation = CreateTaskSchema.safeParse(req.body);
  
  if (!validation.success) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        details: validation.error.flatten().fieldErrors
      }
    });
  }
  
  const task = await taskService.create(validation.data);
  return res.status(201).json({ success: true, data: task });
}
```

---

## 6. 可扩展性设计

### 6.1 配置驱动

```typescript
// ❌ 禁止硬编码
const MAX_RETRIES = 3;
const TIMEOUT = 30000;

// ✅ 使用配置
interface Config {
  maxRetries: number;
  timeout: number;
  cacheSize: number;
}

const config = loadConfig();  // 从环境变量或配置文件加载
```

### 6.2 策略模式

```typescript
// 定义策略接口
interface NotificationStrategy {
  send(message: Message): Promise<void>;
}

// 实现具体策略
class EmailStrategy implements NotificationStrategy {
  async send(message: Message): Promise<void> {
    await emailService.send(message);
  }
}

class SlackStrategy implements NotificationStrategy {
  async send(message: Message): Promise<void> {
    await slackClient.post(message);
  }
}

// 使用策略
class NotificationService {
  constructor(private strategies: NotificationStrategy[]) {}
  
  async notify(message: Message): Promise<void> {
    await Promise.all(
      this.strategies.map(s => s.send(message))
    );
  }
}

// 组装 - 可以动态添加/移除策略
const service = new NotificationService([
  new EmailStrategy(),
  new SlackStrategy()
]);
```

### 6.3 事件驱动

```typescript
// 定义事件
interface DomainEvent {
  type: string;
  timestamp: Date;
  payload: unknown;
}

interface TaskCreatedEvent extends DomainEvent {
  type: 'task.created';
  payload: {
    taskId: string;
    title: string;
    createdBy: string;
  };
}

// 事件发布
class TaskService {
  constructor(private eventBus: EventBus) {}
  
  async create(data: CreateTaskInput): Promise<Task> {
    const task = await this.repository.save(data);
    
    // 发布事件 - 解耦后续处理
    await this.eventBus.publish<TaskCreatedEvent>({
      type: 'task.created',
      timestamp: new Date(),
      payload: {
        taskId: task.id,
        title: task.title,
        createdBy: data.createdBy
      }
    });
    
    return task;
  }
}

// 事件订阅 - 可以独立添加处理器
eventBus.subscribe('task.created', async (event: TaskCreatedEvent) => {
  await notificationService.notifyTaskCreated(event.payload);
});

eventBus.subscribe('task.created', async (event: TaskCreatedEvent) => {
  await analyticsService.trackTaskCreated(event.payload);
});
```

---

## 7. 文档规范

### 7.1 代码注释

```typescript
/**
 * 领取任务
 * 
 * @description 将任务状态从 ready 变为 in_progress,
 * 并分配给指定的 Performer。会创建独立的 worktree。
 * 
 * @param taskId - 任务 ID
 * @param performerId - Performer ID
 * @returns 领取成功的任务,或错误
 * 
 * @throws {TaskNotFoundError} 任务不存在
 * @throws {TaskNotReadyError} 任务状态不是 ready
 * @throws {PerformerBusyError} Performer 已达到最大并发任务数
 * 
 * @example
 * const result = await taskService.claim('task-123', 'performer-456');
 * if (result.isOk()) {
 *   console.log('Task claimed:', result.value.id);
 * }
 */
async function claimTask(
  taskId: string,
  performerId: string
): Promise<Result<Task, TaskError>> {
  // ...
}
```

### 7.2 ADR (架构决策记录)

```markdown
# ADR-001: 选择 PostgreSQL 作为主数据库

## 状态
已接受

## 背景
需要选择一个关系型数据库用于存储任务、用户等核心数据。

## 考虑的选项
1. PostgreSQL
2. MySQL
3. SQLite

## 决策
选择 PostgreSQL

## 理由
- 更好的 JSON 支持 (JSONB)
- 更强的并发处理能力
- 更丰富的数据类型
- 团队已有 PostgreSQL 经验

## 后果
- 正面: 更灵活的查询能力
- 负面: 运维复杂度略高于 SQLite
```

---

## 8. 检查清单

### 设计评审检查

- [ ] 架构图清晰
- [ ] 依赖方向正确
- [ ] API 设计符合规范
- [ ] 数据模型合理
- [ ] 安全性已考虑
- [ ] 可扩展性已考虑
- [ ] 风险已评估
- [ ] 文档完整

---

## 参考

- [Performer 规则](PERFORMER-RULES.md)
- [代码规则](PERFORMER-RULES-CODE.md)
- [反模式集合](ANTI-PATTERNS.md)
