# Performer 代码规则

> KALLAX 代码编写专项规范 v1.0

---

## 1. 类型安全

### 1.1 禁止 any 类型

```typescript
// ❌ 禁止
function process(data: any): any {
  return data.value;
}

// ✅ 正确
function process(data: unknown): Result<ProcessedData, ProcessError> {
  if (!isValidData(data)) {
    return err(ProcessError.invalidInput(data));
  }
  return ok(transform(data as ValidData));
}
```

### 1.2 禁止 @ts-ignore

```typescript
// ❌ 禁止
// @ts-ignore
const result = incompatibleOperation();

// ✅ 正确 - 修复类型问题
const result = (value as unknown as TargetType);
// 或使用类型守卫
if (isTargetType(value)) {
  const result = value;
}
```

### 1.3 严格空值检查

```typescript
// ❌ 禁止
function getUser(id: string) {
  const user = users.find(u => u.id === id);
  return user.name;  // 可能为 undefined
}

// ✅ 正确
function getUser(id: string): string | null {
  const user = users.find(u => u.id === id);
  return user?.name ?? null;
}
```

---

## 2. 错误处理

### 2.1 TypeScript 模式

```typescript
import { Result, ok, err } from 'neverthrow';

// 定义错误类型
class KallaxError extends Error {
  constructor(
    public code: string,
    message: string,
    public context?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'KallaxError';
  }
}

// 使用 Result 模式
async function claimTask(taskId: string): Promise<Result<Task, KallaxError>> {
  const task = await findTask(taskId);
  
  if (!task) {
    return err(new KallaxError(
      'TASK_NOT_FOUND',
      `Task ${taskId} not found`,
      { taskId }
    ));
  }
  
  if (task.status !== 'ready') {
    return err(new KallaxError(
      'TASK_NOT_READY',
      `Task ${taskId} is not ready for claiming`,
      { taskId, currentStatus: task.status }
    ));
  }
  
  return ok(task);
}
```

### 2.2 Rust 模式

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum KallaxError {
    #[error("task {id} not found")]
    TaskNotFound { id: String },
    
    #[error("task {id} is not ready, current status: {status}")]
    TaskNotReady { id: String, status: String },
    
    #[error("operation failed: {context}")]
    Operation { 
        context: String,
        #[source]
        source: Box<dyn std::error::Error + Send + Sync>,
    },
}

fn claim_task(task_id: &str) -> Result<Task, KallaxError> {
    let task = find_task(task_id)
        .ok_or(KallaxError::TaskNotFound { id: task_id.to_string() })?;
    
    if task.status != "ready" {
        return Err(KallaxError::TaskNotReady {
            id: task_id.to_string(),
            status: task.status.clone(),
        });
    }
    
    Ok(task)
}
```

### 2.3 禁止静默 Catch

```typescript
// ❌ 禁止
try {
  await riskyOperation();
} catch (e) {
  // 静默忽略
}

// ❌ 禁止
try {
  await riskyOperation();
} catch (e) {
  console.log(e);  // 仅打印
}

// ✅ 正确
try {
  await riskyOperation();
} catch (e: unknown) {
  logger.error({ 
    error: e,
    context: 'risky_operation'
  }, 'Operation failed');
  
  // 重新抛出或返回错误
  throw new KallaxError('OPERATION_FAILED', 'Risky operation failed', { cause: e });
}
```

---

## 3. 命名规范

### 3.1 变量命名

```typescript
// ❌ 禁止 Magic Number
if (timeout > 30000) { }
const limit = 100;

// ✅ 正确
const TIMEOUT_MS = 30000;
const MAX_ITEMS = 100;

if (timeout > TIMEOUT_MS) { }
const limit = MAX_ITEMS;
```

### 3.2 函数命名

```typescript
// ❌ 禁止 - 不清晰的命名
function process(data) { }
function doSomething() { }
function handle(event) { }

// ✅ 正确 - 清晰表达意图
function validateUserInput(input: UserInput): ValidationResult { }
function calculateTotalPrice(items: CartItem[]): number { }
function handleLoginSubmit(event: FormEvent): void { }
```

### 3.3 布尔变量命名

```typescript
// ❌ 禁止
const active = true;
const visibility = false;

// ✅ 正确
const isActive = true;
const isVisible = false;
const hasPermission = true;
const canEdit = false;
```

---

## 4. 代码结构

### 4.1 函数职责单一

```typescript
// ❌ 禁止 - 一个函数做太多事
async function processOrder(order: Order) {
  // 验证
  if (!order.items.length) throw new Error();
  
  // 计算价格
  const total = order.items.reduce((sum, item) => sum + item.price, 0);
  
  // 保存到数据库
  await db.orders.insert({ ...order, total });
  
  // 发送邮件
  await sendEmail(order.customer, '订单确认');
  
  // 发送短信
  await sendSMS(order.customer, '订单确认');
}

// ✅ 正确 - 职责分离
async function processOrder(order: Order): Promise<Result<Order, OrderError>> {
  const validationResult = validateOrder(order);
  if (validationResult.isErr()) {
    return err(validationResult.error);
  }
  
  const total = calculateOrderTotal(order);
  const savedOrder = await orderRepository.save({ ...order, total });
  
  await notificationService.sendOrderConfirmation(savedOrder);
  
  return ok(savedOrder);
}

function validateOrder(order: Order): Result<void, ValidationError> { }
function calculateOrderTotal(order: Order): number { }
```

### 4.2 禁止复制粘贴

```typescript
// ❌ 禁止 - 重复代码
function handleUserClick() {
  validate();
  process();
  notify();
}

function handleAdminClick() {
  validate();
  process();
  notify();
}

// ✅ 正确 - 提取公共逻辑
function handleClick(role: Role) {
  validate();
  process();
  notify(role);
}
```

### 4.3 禁止注释掉的代码

```typescript
// ❌ 禁止
// function oldImplementation() {
//   return something;
// }

// ✅ 正确
// 直接删除不需要的代码
// 使用 Git 历史追溯旧实现
```

---

## 5. 日志规范

### 5.1 使用结构化日志

```typescript
// ❌ 禁止
console.log('Task claimed:', taskId);
console.error('Error:', e);
console.log(`User ${userId} logged in`);

// ✅ 正确
logger.info({ taskId, performerId }, 'task claimed');
logger.error({ error: e, context: 'login' }, 'authentication failed');
logger.info({ userId, loginTime: Date.now() }, 'user logged in');
```

### 5.2 日志级别使用

```typescript
// ERROR: 需要立即处理的问题
logger.error({ error, orderId }, 'payment processing failed');

// WARN: 可能有问题但不阻断
logger.warn({ userId, attempts }, 'multiple login failures');

// INFO: 关键业务事件
logger.info({ taskId, status }, 'task status changed');

// DEBUG: 调试信息
logger.debug({ request, response }, 'api call completed');
```

---

## 6. 资源管理

### 6.1 缓存必须有 TTL

```typescript
// ❌ 禁止
const cache = new Map<string, Data>();
cache.set(key, value);  // 永不过期

// ✅ 正确
import { LRUCache } from 'lru-cache';

const cache = new LRUCache<string, Data>({
  max: 1000,           // 最大条目数
  ttl: 5 * 60 * 1000,  // 5 分钟过期
  updateAgeOnGet: true,
  dispose: (value, key) => {
    logger.debug({ key }, 'cache entry disposed');
  }
});
```

### 6.2 连接池管理

```typescript
// ✅ 正确
import { createPool } from 'generic-pool';

const pool = createPool({
  create: () => createConnection(),
  destroy: (conn) => conn.close(),
}, {
  max: 10,
  min: 2,
  acquireTimeoutMillis: 30000,
  idleTimeoutMillis: 30000,
  evictionRunIntervalMillis: 1000,
});

// 使用
const conn = await pool.acquire();
try {
  await conn.query(...);
} finally {
  await pool.release(conn);
}
```

### 6.3 重试有上限

```typescript
// ❌ 禁止
while (true) {
  try {
    await operation();
    break;
  } catch (e) {
    await sleep(1000);
  }
}

// ✅ 正确
const MAX_RETRIES = 3;

async function withRetry<T>(
  fn: () => Promise<T>,
  options: { maxRetries?: number; baseDelay?: number } = {}
): Promise<T> {
  const { maxRetries = MAX_RETRIES, baseDelay = 1000 } = options;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (e) {
      if (attempt === maxRetries - 1) {
        throw e;
      }
      const delay = baseDelay * Math.pow(2, attempt);
      await sleep(delay);
    }
  }
  throw new Error('Unreachable');
}
```

---

## 7. 导入导出

### 7.1 导入顺序

```typescript
// 1. Node.js 内置模块
import path from 'path';
import fs from 'fs';

// 2. 第三方模块
import { z } from 'zod';
import { LRUCache } from 'lru-cache';

// 3. 项目内部模块 (绝对路径)
import { KallaxError } from '@/core/errors';
import { logger } from '@/core/logger';

// 4. 相对路径模块
import { TaskService } from './services/task';
import type { Task, TaskStatus } from './types';
```

### 7.2 导出规范

```typescript
// ✅ 命名导出 (推荐)
export function claimTask() { }
export class TaskService { }
export type Task = { };

// ✅ 在文件末尾统一导出
export { claimTask, TaskService };
export type { Task, TaskStatus };

// ❌ 避免默认导出 (除非必要)
export default function() { }
```

---

## 8. 检查清单

### 提交前检查

```bash
# 类型检查
npm run type-check

# Lint 检查
npm run lint

# 测试
npm test

# 无 any 检查
grep -r ": any" src/ && exit 1

# 无 console.log 检查
grep -r "console.log" src/ && exit 1
```

### 代码审查清单

- [ ] 无 `any` 类型
- [ ] 无 `@ts-ignore`
- [ ] 无 `console.log`
- [ ] 无空 catch 块
- [ ] 无 magic number
- [ ] 无注释掉的代码
- [ ] 缓存有 TTL
- [ ] 重试有上限
- [ ] 函数职责单一
- [ ] 命名清晰

---

## 参考

- [Performer 规则](PERFORMER-RULES.md)
- [测试规则](PERFORMER-RULES-TEST.md)
- [反模式集合](ANTI-PATTERNS.md)
