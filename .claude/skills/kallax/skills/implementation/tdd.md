# TDD 技能 (测试驱动开发)

## 技能定义
测试驱动开发实践能力，通过先写测试再实现的方式保证代码质量。

## 适用场景
- 新功能开发
- Bug修复
- 重构
- API实现

## 执行流程

### Red-Green-Refactor 循环

```
1. Red: 写一个失败的测试
   - 明确需求
   - 定义预期行为
   - 测试应该失败

2. Green: 写最少的代码让测试通过
   - 只关注让测试通过
   - 不要过度设计
   - 代码可以不完美

3. Refactor: 重构代码
   - 消除重复
   - 改善设计
   - 保持测试通过
```

## 输出格式
```markdown
## TDD 实践记录

### 需求
[功能需求描述]

### 测试用例设计

#### 用例1: 正常场景
```typescript
describe('calculateTotal', () => {
  it('should calculate total for items', () => {
    const items = [
      { price: 100, quantity: 2 },
      { price: 50, quantity: 1 }
    ];
    
    expect(calculateTotal(items)).toBe(250);
  });
});
```

#### 用例2: 边界场景
```typescript
it('should return 0 for empty array', () => {
  expect(calculateTotal([])).toBe(0);
});
```

#### 用例3: 异常场景
```typescript
it('should throw for negative quantity', () => {
  const items = [{ price: 100, quantity: -1 }];
  
  expect(() => calculateTotal(items)).toThrow('Invalid quantity');
});
```

### 实现

#### 第一轮: 基本实现
```typescript
// Red: 测试失败
// Green: 最小实现
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

#### 第二轮: 处理边界
```typescript
function calculateTotal(items: Item[]): number {
  if (!items.length) return 0;
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

#### 第三轮: 添加验证
```typescript
function calculateTotal(items: Item[]): number {
  if (!items.length) return 0;
  
  for (const item of items) {
    if (item.quantity < 0) {
      throw new Error('Invalid quantity');
    }
  }
  
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

### 重构
```typescript
// 提取验证逻辑
function validateItems(items: Item[]): void {
  for (const item of items) {
    if (item.quantity < 0) {
      throw new Error('Invalid quantity');
    }
  }
}

function calculateTotal(items: Item[]): number {
  if (!items.length) return 0;
  validateItems(items);
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

### 测试覆盖
| 场景 | 覆盖 | 通过 |
|------|------|------|
| 正常计算 | ✓ | ✓ |
| 空数组 | ✓ | ✓ |
| 负数量 | ✓ | ✓ |
```

## TDD 原则

### 三原则
1. 只在测试失败时写新代码
2. 只写让测试刚好通过的代码
3. 每次只写一个测试

### 测试设计原则
- **FIRST**: Fast, Independent, Repeatable, Self-validating, Timely
- **Arrange-Act-Assert**: 准备、执行、断言
- **Given-When-Then**: 给定、当、那么

### 什么值得测试
| 场景 | 优先级 |
|------|--------|
| 核心业务逻辑 | 高 |
| 边界条件 | 高 |
| 错误处理 | 中 |
| 集成点 | 中 |
| UI细节 | 低 |
