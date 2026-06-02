# 反模式集合

> KALLAX 禁止的编码和协作模式 | 基于 KALLAX 教训

---

## 1. 错误处理反模式

### 1.1 静默 Catch

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
  console.log(e);  // 仅打印，不处理
}

// ✅ 正确
try {
  await riskyOperation();
} catch (e: unknown) {
  logger.error({ error: e }, 'operation failed');
  throw new KallaxError('OPERATION_FAILED', { cause: e });
}
```

**问题**: 隐藏错误，导致难以调试

### 1.2 Any 类型逃逸

```typescript
// ❌ 禁止
function process(data: any): any {
  return data.foo;
}

// ❌ 禁止
catch (e: any) {
  console.log(e.message);
}

// ✅ 正确
function process(data: unknown): Result<Data, Error> {
  if (!isValidData(data)) {
    return err(new ValidationError());
  }
  return ok(transform(data));
}

catch (e: unknown) {
  const error = e instanceof Error ? e : new Error(String(e));
  logger.error({ error }, 'caught error');
}
```

**问题**: 绕过类型检查，引入运行时错误

### 1.3 Panic 模式 (Rust)

```rust
// ❌ 禁止
let value = operation().expect("should not fail");
let value = operation().unwrap();
panic!("unexpected state");

// ✅ 正确
let value = operation()
    .map_err(|e| KallaxError::Operation { source: e })?;
```

**问题**: 生产环境崩溃，无法恢复

---

## 2. 资源管理反模式

### 2.1 无 TTL 缓存

```typescript
// ❌ 禁止
const cache = new Map<string, Data>();

cache.set(key, value);  // 永不过期

// ✅ 正确
const cache = new LRUCache<string, Data>({
  max: 1000,
  ttl: 5 * 60 * 1000,  // 5 分钟
});
```

**问题**: 内存泄漏，最终 OOM

### 2.2 无限重试

```typescript
// ❌ 禁止
while (true) {
  try {
    await operation();
    break;
  } catch (e) {
    await sleep(1000);  // 永远重试
  }
}

// ✅ 正确
const MAX_RETRIES = 3;
for (let i = 0; i < MAX_RETRIES; i++) {
  try {
    return await operation();
  } catch (e) {
    if (i === MAX_RETRIES - 1) throw e;
    await sleep(Math.pow(2, i) * 1000);  // 指数退避
  }
}
```

**问题**: 无法恢复时永远阻塞

### 2.3 静默降级

```typescript
// ❌ 禁止
try {
  config = await fetchRemoteConfig();
} catch (e) {
  config = DEFAULT_CONFIG;  // 静默降级
}

// ✅ 正确
try {
  config = await fetchRemoteConfig();
} catch (e) {
  logger.warn({ error: e }, 'remote config failed, using fallback');
  metrics.increment('kallax.config.fallback');
  config = DEFAULT_CONFIG;
}
```

**问题**: 无人知道系统已降级

---

## 3. 架构反模式

### 3.1 跨层调用

```typescript
// ❌ 禁止
class UserController {
  async getUser(id: string) {
    // Controller 直接访问数据库
    const user = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return user;
  }
}

// ✅ 正确
class UserController {
  constructor(private userService: UserService) {}
  
  async getUser(id: string) {
    return this.userService.findById(id);
  }
}

class UserService {
  constructor(private userRepository: UserRepository) {}
  
  async findById(id: string) {
    return this.userRepository.findById(id);
  }
}
```

**问题**: 违反分层架构，耦合严重

### 3.2 硬编码敏感信息

```typescript
// ❌ 禁止
const API_KEY = 'sk-1234567890abcdef';
const DB_PASSWORD = 'secret123';

// ✅ 正确
const API_KEY = process.env.API_KEY;
if (!API_KEY) {
  throw new Error('API_KEY environment variable required');
}
```

**问题**: 安全风险，泄露凭证

---

## 4. 并行协作反模式

### 4.1 无隔离并行

```
❌ 禁止:
Performer A 和 Performer B 同时修改 src/utils/helpers.ts

✅ 正确:
- 声明 file_scope 确保不重叠
- 使用 worktree 隔离
- kallax isolation:check 检查
```

**问题**: Git 冲突，阻塞 2-3 小时

### 4.2 后台模式幻觉

```
❌ 禁止:
使用 background 模式执行代码修改任务
Agent 报告"完成"但实际无修改

✅ 正确:
- 代码任务必须用 foreground 模式
- Conductor 必须运行 kallax verify:output 验证
```

**问题**: 虚假完成，浪费时间

### 4.3 自我审查

```
❌ 禁止:
Performer 自己 Approve 自己的 PR

✅ 正确:
- 必须由 Conductor 或其他 Performer 审查
```

**问题**: 缺乏第二视角，错误难以发现

---

## 5. 测试反模式

### 5.1 内联实现复制

```typescript
// ❌ 禁止 - 测试内联实现逻辑
test('should calculate total', () => {
  // 重新实现了被测代码的逻辑
  function calculateTotal(items) {
    return items.reduce((sum, item) => sum + item.price, 0);
  }
  
  expect(calculateTotal([{price: 10}])).toBe(10);
});

// ✅ 正确 - 导入被测代码
import { calculateTotal } from './calculator';

test('should calculate total', () => {
  expect(calculateTotal([{price: 10}])).toBe(10);
});
```

**问题**: 源码修改后测试仍通过，测试失效

### 5.2 Mock 集成测试

```typescript
// ❌ 禁止 - 集成测试使用 mock
test('user login integration', async () => {
  jest.mock('./database');
  const result = await login('user', 'pass');
  expect(result).toBe(true);
});

// ✅ 正确 - 集成测试使用真实依赖
test('user login integration', async () => {
  const db = await createTestDatabase();
  const result = await login('user', 'pass', db);
  expect(result).toBe(true);
});
```

**问题**: Mock 与真实行为不一致

---

## 6. Git 反模式

### 6.1 强制推送

```bash
# ❌ 禁止
git push --force origin main
git push --force origin feature/xxx  # 已有其他人基于此分支

# ✅ 正确
git push --force-with-lease origin feature/xxx  # 检查远程是否有新提交
```

**问题**: 覆盖他人工作

### 6.2 大型提交

```bash
# ❌ 禁止
git add -A
git commit -m "implement everything"

# ✅ 正确
git add src/components/Login.tsx
git commit -m "feat(auth): add login form component"

git add src/hooks/useAuth.ts
git commit -m "feat(auth): add useAuth hook"
```

**问题**: 难以 Review，难以回滚

---

## 7. 快速检查清单

### 代码审查时检查

- [ ] 无 `any` 类型
- [ ] 无 `@ts-ignore`
- [ ] 无 `expect()`/`unwrap()`
- [ ] 无 `console.log`
- [ ] 无空 catch 块
- [ ] 无 magic number
- [ ] 无注释掉的代码
- [ ] 无硬编码敏感信息
- [ ] 缓存有 TTL
- [ ] 重试有上限

### 协作时检查

- [ ] file_scope 已声明
- [ ] worktree 已创建
- [ ] 无范围重叠
- [ ] 非自我审查
- [ ] 验证已执行

---

## 参考

- [KALLAX 经验教训](../../confluence/memory/research/kallax-lessons-learned.md)
- [Conductor 规则](CONDUCTOR-RULES.md)
- [Performer 规则](PERFORMER-RULES.md)
