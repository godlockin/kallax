# Performer 测试规则

> KALLAX 测试编写专项规范 v1.0

---

## 1. TDD 流程

### 1.1 红-绿-重构

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   红 (Red)   │ ───▶ │  绿 (Green) │ ───▶ │  重构      │
│  写失败测试  │      │ 写最小代码  │      │ (Refactor) │
└─────────────┘      └─────────────┘      └─────────────┘
       │                                          │
       └──────────────────────────────────────────┘
                    循环迭代
```

### 1.2 示例流程

```typescript
// Step 1: 红 - 写失败的测试
describe('calculateTotal', () => {
  it('should sum item prices', () => {
    const items = [{ price: 10 }, { price: 20 }];
    expect(calculateTotal(items)).toBe(30);  // 失败: calculateTotal 未定义
  });
});

// Step 2: 绿 - 写最小代码让测试通过
function calculateTotal(items: { price: number }[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Step 3: 重构 - 保持测试通过的情况下优化代码
function calculateTotal(items: ReadonlyArray<{ price: number }>): number {
  return items.reduce((sum, { price }) => sum + price, 0);
}
```

---

## 2. 测试类型

### 2.1 单元测试

**目的**: 测试单个函数/类的行为

```typescript
// ✅ 好的单元测试
describe('TaskValidator', () => {
  describe('validate', () => {
    it('should return error for empty title', () => {
      const task = { title: '', priority: 'P1' };
      const result = TaskValidator.validate(task);
      
      expect(result.isErr()).toBe(true);
      expect(result.error.code).toBe('EMPTY_TITLE');
    });
    
    it('should return ok for valid task', () => {
      const task = { title: 'Fix bug', priority: 'P1' };
      const result = TaskValidator.validate(task);
      
      expect(result.isOk()).toBe(true);
    });
  });
});
```

### 2.2 集成测试

**目的**: 测试多个组件协作

```typescript
// ✅ 好的集成测试 - 使用真实依赖
describe('TaskService Integration', () => {
  let db: TestDatabase;
  let service: TaskService;
  
  beforeAll(async () => {
    db = await createTestDatabase();
    service = new TaskService(db);
  });
  
  afterAll(async () => {
    await db.cleanup();
  });
  
  it('should create and retrieve task', async () => {
    const created = await service.create({ title: 'Test Task' });
    const retrieved = await service.findById(created.id);
    
    expect(retrieved).toEqual(created);
  });
});
```

### 2.3 E2E 测试

**目的**: 测试完整用户流程

```typescript
// ✅ 好的 E2E 测试
describe('User Login Flow', () => {
  it('should login and redirect to dashboard', async () => {
    await page.goto('/login');
    
    await page.fill('[data-testid=email]', 'user@example.com');
    await page.fill('[data-testid=password]', 'password123');
    await page.click('[data-testid=submit]');
    
    await page.waitForURL('/dashboard');
    expect(page.url()).toContain('/dashboard');
  });
});
```

---

## 3. 测试原则

### 3.1 禁止内联实现复制

```typescript
// ❌ 禁止 - 测试内联实现逻辑
test('should calculate total', () => {
  // 重新实现了被测代码的逻辑
  function localCalculate(items) {
    return items.reduce((sum, item) => sum + item.price, 0);
  }
  
  const items = [{ price: 10 }, { price: 20 }];
  expect(localCalculate(items)).toBe(30);
});

// ✅ 正确 - 导入被测代码
import { calculateTotal } from './calculator';

test('should calculate total', () => {
  const items = [{ price: 10 }, { price: 20 }];
  expect(calculateTotal(items)).toBe(30);
});
```

**设计原则**: 内联复制导致源码修改后测试仍通过,82个测试失效却绿灯

### 3.2 集成测试禁止 Mock

```typescript
// ❌ 禁止 - 集成测试使用 mock
describe('UserService Integration', () => {
  it('should create user', async () => {
    jest.mock('./database');  // 错误: mock 掉了真实依赖
    
    const user = await userService.create({ name: 'Test' });
    expect(user).toBeDefined();
  });
});

// ✅ 正确 - 集成测试使用真实依赖
describe('UserService Integration', () => {
  let db: TestDatabase;
  
  beforeAll(async () => {
    db = await createTestDatabase();
  });
  
  it('should create user', async () => {
    const service = new UserService(db);
    const user = await service.create({ name: 'Test' });
    
    // 验证真实数据库
    const found = await db.users.findById(user.id);
    expect(found).toEqual(user);
  });
});
```

### 3.3 依赖注入测试模式

```typescript
// ✅ 使用依赖注入便于测试
class TaskService {
  constructor(
    private repository: TaskRepository,
    private validator: TaskValidator,
    private notifier: Notifier
  ) {}
  
  async create(data: CreateTaskInput): Promise<Result<Task, Error>> {
    const validation = this.validator.validate(data);
    if (validation.isErr()) {
      return err(validation.error);
    }
    
    const task = await this.repository.save(data);
    await this.notifier.notify('task_created', task);
    
    return ok(task);
  }
}

// 测试时可以注入 fake 实现
describe('TaskService', () => {
  it('should validate before saving', async () => {
    const fakeRepo = new FakeTaskRepository();
    const fakeValidator = new FakeTaskValidator();
    const fakeNotifier = new FakeNotifier();
    
    fakeValidator.setResult(err(new ValidationError('Invalid')));
    
    const service = new TaskService(fakeRepo, fakeValidator, fakeNotifier);
    const result = await service.create({ title: '' });
    
    expect(result.isErr()).toBe(true);
    expect(fakeRepo.saveCallCount).toBe(0);  // 验证未调用 save
  });
});
```

---

## 4. 测试结构

### 4.1 AAA 模式

```typescript
// Arrange - Act - Assert
test('should claim available task', async () => {
  // Arrange: 准备测试数据和环境
  const task = await createTestTask({ status: 'ready' });
  const performer = await createTestPerformer();
  
  // Act: 执行被测操作
  const result = await taskService.claim(task.id, performer.id);
  
  // Assert: 验证结果
  expect(result.isOk()).toBe(true);
  expect(result.value.status).toBe('in_progress');
  expect(result.value.performerId).toBe(performer.id);
});
```

### 4.2 测试命名

```typescript
// ✅ 好的命名 - 描述行为和条件
describe('TaskService', () => {
  describe('claim', () => {
    it('should succeed when task is ready and performer is available', () => {});
    it('should fail when task is already claimed', () => {});
    it('should fail when performer has reached max concurrent tasks', () => {});
  });
});

// ❌ 不好的命名
describe('TaskService', () => {
  it('test1', () => {});
  it('works', () => {});
  it('claim task', () => {});
});
```

### 4.3 测试隔离

```typescript
// ✅ 每个测试独立,不依赖其他测试
describe('TaskRepository', () => {
  let db: TestDatabase;
  
  beforeEach(async () => {
    db = await createTestDatabase();  // 每个测试新数据库
  });
  
  afterEach(async () => {
    await db.cleanup();
  });
  
  it('test 1', async () => {
    // 使用独立的 db 实例
  });
  
  it('test 2', async () => {
    // 使用另一个独立的 db 实例
  });
});
```

---

## 5. 边界条件测试

### 5.1 必测边界

```typescript
describe('calculateDiscount', () => {
  // 边界值测试
  it('should return 0 discount for amount below threshold', () => {
    expect(calculateDiscount(99)).toBe(0);
  });
  
  it('should return discount at exact threshold', () => {
    expect(calculateDiscount(100)).toBe(10);
  });
  
  it('should return discount above threshold', () => {
    expect(calculateDiscount(101)).toBe(10);
  });
  
  // 异常输入测试
  it('should handle negative amount', () => {
    expect(calculateDiscount(-1)).toBe(0);
  });
  
  it('should handle zero amount', () => {
    expect(calculateDiscount(0)).toBe(0);
  });
  
  it('should handle very large amount', () => {
    expect(calculateDiscount(1_000_000)).toBe(100_000);
  });
});
```

### 5.2 错误路径测试

```typescript
describe('TaskService.claim', () => {
  // 正常路径
  it('should succeed with valid input', async () => {});
  
  // 错误路径 - 每种错误情况都要测
  it('should return TASK_NOT_FOUND for non-existent task', async () => {
    const result = await service.claim('non-existent', performerId);
    
    expect(result.isErr()).toBe(true);
    expect(result.error.code).toBe('TASK_NOT_FOUND');
  });
  
  it('should return TASK_ALREADY_CLAIMED when claimed by another', async () => {
    const task = await createTask({ status: 'in_progress' });
    const result = await service.claim(task.id, performerId);
    
    expect(result.isErr()).toBe(true);
    expect(result.error.code).toBe('TASK_ALREADY_CLAIMED');
  });
  
  it('should return PERFORMER_BUSY when at max capacity', async () => {
    await createTasksForPerformer(performerId, MAX_CONCURRENT);
    const task = await createTask({ status: 'ready' });
    const result = await service.claim(task.id, performerId);
    
    expect(result.isErr()).toBe(true);
    expect(result.error.code).toBe('PERFORMER_BUSY');
  });
});
```

---

## 6. 异步测试

### 6.1 正确处理 Promise

```typescript
// ✅ 正确 - 使用 async/await
it('should fetch user', async () => {
  const user = await userService.findById('123');
  expect(user).toBeDefined();
});

// ✅ 正确 - 返回 Promise
it('should fetch user', () => {
  return userService.findById('123').then(user => {
    expect(user).toBeDefined();
  });
});

// ❌ 错误 - 忘记 await
it('should fetch user', () => {
  userService.findById('123');  // 没有 await,测试会立即通过
  // 断言永远不会执行
});
```

### 6.2 超时处理

```typescript
// 设置测试超时
it('should complete within timeout', async () => {
  const result = await slowOperation();
  expect(result).toBeDefined();
}, 10000);  // 10 秒超时

// 测试超时行为
it('should timeout after 5 seconds', async () => {
  const promise = operationWithTimeout(100);  // 100ms 操作
  
  await expect(promise).resolves.toBeDefined();
});

it('should reject on timeout', async () => {
  const promise = operationWithTimeout(10000);  // 太慢
  
  await expect(promise).rejects.toThrow('Timeout');
}, 1000);
```

---

## 7. 覆盖率要求

### 7.1 最低要求

```yaml
coverage:
  statements: 80%
  branches: 75%
  functions: 80%
  lines: 80%
```

### 7.2 关键路径 100% 覆盖

```typescript
// 关键路径必须 100% 覆盖
// 例如: 支付流程、认证流程、数据持久化

describe('PaymentService', () => {
  // 所有分支都要测到
  it('should process valid payment', async () => {});
  it('should reject insufficient balance', async () => {});
  it('should reject expired card', async () => {});
  it('should retry on network error', async () => {});
  it('should fail after max retries', async () => {});
});
```

### 7.3 检查覆盖率

```bash
# 运行覆盖率报告
npm test -- --coverage

# CI 中强制覆盖率
npm test -- --coverage --coverageThreshold='{"global":{"branches":75,"functions":80,"lines":80}}'
```

---

## 8. 测试数据

### 8.1 使用 Factory 模式

```typescript
// ✅ 使用 factory 创建测试数据
const taskFactory = {
  build(overrides: Partial<Task> = {}): Task {
    return {
      id: `task-${Date.now()}`,
      title: 'Test Task',
      status: 'ready',
      priority: 'P2',
      createdAt: new Date(),
      ...overrides
    };
  },
  
  async create(overrides: Partial<Task> = {}): Promise<Task> {
    const task = this.build(overrides);
    return await db.tasks.insert(task);
  }
};

// 使用
const readyTask = await taskFactory.create({ status: 'ready' });
const urgentTask = await taskFactory.create({ priority: 'P0' });
```

### 8.2 清理测试数据

```typescript
// ✅ 每个测试后清理
afterEach(async () => {
  await db.tasks.deleteAll();
  await db.users.deleteAll();
});

// 或使用事务回滚
beforeEach(async () => {
  transaction = await db.beginTransaction();
});

afterEach(async () => {
  await transaction.rollback();
});
```

---

## 9. 检查清单

### 测试编写检查

- [ ] 使用 TDD 流程
- [ ] 测试名称清晰描述行为
- [ ] 覆盖所有边界条件
- [ ] 覆盖所有错误路径
- [ ] 测试相互隔离
- [ ] 无内联实现复制
- [ ] 集成测试使用真实依赖
- [ ] 异步正确处理
- [ ] 覆盖率达标

### CI 配置

```yaml
# .github/workflows/test.yml
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - run: npm ci
    - run: npm test -- --coverage
    - run: |
        COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
          echo "Coverage $COVERAGE% is below 80%"
          exit 1
        fi
```

---

## 参考

- [Performer 规则](PERFORMER-RULES.md)
- [代码规则](PERFORMER-RULES-CODE.md)
- [反模式集合](ANTI-PATTERNS.md)
