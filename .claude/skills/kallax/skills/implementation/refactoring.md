# 重构技能

## 技能定义
系统性改善代码结构而不改变外部行为的能力。

## 适用场景
- 代码质量改进
- 技术债务清理
- 设计模式应用
- 性能优化准备

## 执行流程

### 1. 评估阶段
- 识别代码坏味道
- 评估重构风险
- 确定重构范围

### 2. 准备阶段
- 确保测试覆盖
- 设置回滚机制
- 小步前进计划

### 3. 执行阶段
- 单一职责重构
- 持续运行测试
- 频繁提交

### 4. 验证阶段
- 功能验证
- 性能对比
- 代码审查

## 输出格式
```markdown
## 重构计划

### 现状分析

#### 代码坏味道
| 问题 | 位置 | 严重程度 |
|------|------|----------|
| 过长函数 | OrderService.process() | 高 |
| 重复代码 | utils/*.ts | 中 |
| 过度耦合 | UserController | 高 |

#### 复杂度分析
| 文件 | 圈复杂度 | 建议 |
|------|----------|------|
| OrderService.ts | 25 | 拆分函数 |
| PaymentHandler.ts | 18 | 状态模式 |

### 重构目标
- 降低核心模块复杂度
- 消除重复代码
- 提高可测试性

### 重构步骤

#### Step 1: 提取函数
**Before**
```typescript
class OrderService {
  process(order: Order) {
    // 100行混杂逻辑
    // 验证
    if (!order.items.length) throw new Error('Empty');
    // 计算
    let total = 0;
    for (const item of order.items) {
      total += item.price * item.quantity;
    }
    // 保存
    this.db.save(order);
    // 通知
    this.email.send(order.user, 'Order created');
  }
}
```

**After**
```typescript
class OrderService {
  process(order: Order) {
    this.validate(order);
    const total = this.calculateTotal(order);
    this.save(order, total);
    this.notify(order);
  }

  private validate(order: Order) {
    if (!order.items.length) {
      throw new Error('Empty order');
    }
  }

  private calculateTotal(order: Order): number {
    return order.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    );
  }

  private save(order: Order, total: number) {
    order.total = total;
    this.db.save(order);
  }

  private notify(order: Order) {
    this.email.send(order.user, 'Order created');
  }
}
```

#### Step 2: 引入策略模式
[后续重构步骤...]

### 风险评估
| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 功能回归 | 中 | 高 | 完善测试 |
| 性能下降 | 低 | 中 | 性能测试 |

### 验证检查
- [ ] 所有测试通过
- [ ] 代码覆盖率不降
- [ ] 复杂度指标改善
- [ ] 性能指标不降
```

## 常见重构模式

### 提取方法 (Extract Method)
将代码片段提取为独立方法

### 内联方法 (Inline Method)
将简单方法内容合并到调用处

### 提取类 (Extract Class)
将部分职责提取到新类

### 引入参数对象 (Introduce Parameter Object)
将多个参数封装为对象

### 用多态替代条件 (Replace Conditional with Polymorphism)
用策略模式替代复杂条件

## 代码坏味道速查

| 坏味道 | 识别 | 重构方法 |
|--------|------|----------|
| 过长函数 | >20行 | 提取方法 |
| 过长参数列表 | >3个 | 参数对象 |
| 重复代码 | 相似逻辑 | 提取方法/类 |
| 过大类 | 多职责 | 提取类 |
| 发散式变化 | 一改多 | 提取类 |
| 霰弹式修改 | 改一处动多处 | 移动方法 |
