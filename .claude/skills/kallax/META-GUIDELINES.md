# KALLAX Skills 元指南

## 设计哲学

### 为什么需要多专家系统？

单一视角的局限性:
- 开发者容易忽略 UX 问题
- 产品经**: 专家间相互校验，避免盲点
- **专业性**: 每个领域有专业深度
- **可追溯**: 决策过程透明可回顾

### 核心设计原则

#### 1. 按需召唤 (Invoke on Demand)

不是所有任务都需要专家评审:

```
任务复杂度    建议方式
────────────────────────────
简单 bug     直接修复
单文件改动    简单评审
新功能       单专家咨询
新模块       专家面板
新系统       深度面板
```

#### 2. 最小必要 (Minimal Necessary)

- 不召唤不需要的专家
- 不执行不需要的分析
- 不输出不需要的内容

#### 3. 协作优先 (Collaboration First)

专家不是孤立工作的:
- Architect 的输出是其他专家的输入
- 专家间可以相互质疑和补充
- Conductor 负责整合和仲裁

#### 4. 可执行导向 (Actionable Output)

输出必须可执行:
- 有清晰的 Action Items
- 有具体的实施步骤
- 有明确的验收标准

---

## 使用指南

### 何时使用 Expert Panel

✅ **适合场景**:
- 新 EPIC / 新产品规划
- 架构变更 / 重大重构
- 技术选型决策
- 跨团队协作需求
- 复杂问题分析
- 用户明确要求

❌ **不适合场景**:
- 简单 bug 修复
- 文档更新
- 依赖升级
- 代码格式化
- 已有明确方案的任务

### 选择正确的命令

```
需求明确度              推荐命令
────────────────────────────────────────
完全不清楚             /kallax-panel
大致方向清楚           /kallax-expert
具体任务清楚           /kallax-skill
非常清楚               直接执行
```

### 专家选择指南

| 问题类型 | 推荐专家 |
|----------|----------|
| "怎么设计这个系统？" | architect |
| "API 应该怎么定义？" | backend |
| "组件怎么拆分？" | frontend |
| "用户流程是否合理？" | ux |
| "这个需求合理吗？" | product |
| "怎么保证安全？" | security |
| "怎么提升性能？" | performance |
| "怎么部署？" | devops, sre |
| "数据怎么存？" | database |
| "AI 怎么集成？" | aiml |

### 上下文提供最佳实践

**好的上下文**:
```
/kallax-panel "设计订单系统"
- 日均订单量: 100万
- 技术栈: Node.js + PostgreSQL
- 约束: 需与现有用户系统集成
- 关注点: 高可用、数据一致性
```

**差的上下文**:
```
/kalltend, UX, Product] → Conductor
```

适用于大多数场景。

### 技术主导模式 (Tech-Led)

```
Architect → [Backend, Frontend, DevOps, Security] → Conductor
```

适用于技术重点项目。

### 产品主导模式 (Product-Led)

```
Product → [UX, Frontend, Backend, Growth] → Conductor
```

适用于用户体验重点项目。

### 数据主导模式 (Data-Led)

```
Architect → [Data-Analyst, BigData, Backend, MLOps] → Conductor
```

适用于数据密集型项目。

### 安全主导模式 (Security-Led)

```
Security → [Architect, Backend, DevOps, Compliance] → Conductor
```

适用于安全敏感项目。

---

## 输出解读

### 置信度标记

专家意见会带有置信度:

- **HIGH**: 专家对此建议有高度信心
- **MEDIUM**: 有一定把握，但存在不确定性
- **LOW**: 需要更多信息或存在显著不确定性

### 冲突标记

当专家意见冲突时:

```markdown
⚠️ 冲突点: API 设计风格

Backend: 推荐 REST
- 理由: 团队熟悉，生态成熟

Frontend: 偏好 GraphQL
- 理由: 减少过度获取，灵活查询

Conductor 建议:
考虑到团队现状，建议 REST + 特定场景使用 GraphQL
```

### 风险等级

| 等级 | 含义 | 行动 |
|------|------|------|
| 🔴 HIGH | 严重风险，可能导致项目失败 | 必须解决后才能继续 |
| 🟡 MEDIUM | 中等风险，可能影响质量或进度 | 应该解决，可以延后 |
| 🟢 LOW | 低风险，小问题 | 可以接受，有空再改 |

---

## 与现有工作流集成

### Git 工作流

```bash
# PR 评审时
/kallax-expert architect "评审 PR #123 的架构变更"

# 合并前检查
/kallax-skill code-analysis --params '{"compare": "main..feature"}'
```

### CI/CD 集成

```yaml
# .github/workflows/expert-review.yml
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'src/core/**'

jobs:
  expert-review:
    runs-on: ubuntu-latest
    steps:
      - uses: kallax/expert-review@v1
        with:
          experts: architect,security
          depth: standard
```

### 文档生成

专家评审输出可直接转换为:
- ADR (Architecture Decision Record)
- PRD (Product Requirements Document)
- 技术方案文档
- 测试计划

---

## 扩展专家系统

### 添加新专家

1. 在 `experts/extended/<category>/` 创建 `<name>.md`
2. 遵循专家模板格式
3. 更新 SKILL.md 索引
4. 提交 PR

### 添加新技能

1. 在 `skills/<category>/` 创建 `<name>.md`
2. 定义触发条件和执行流程
3. 更新 SKILL.md 索引
4. 提交 PR

### 自定义专家组合

可以在项目级别定义常用组合:

```yaml
# .kallax/config.yml
expert_panels:
  security_review:
    experts: [architect, security, backend, devops]
    depth: deep
  
  quick_review:
    experts: [architect, backend]
    depth: quick
```

---

## 常见问题

### Q: 专家评审会增加多少时间？

A: 取决于深度:
- quick: +2-5 分钟
- standard: +5-15 分钟
- deep: +15-30 分钟

但节省的返工时间通常远超投入。

### Q: 专家意见可以忽略吗？

A: 可以，但建议:
1. 记录忽略的原因
2. 评估潜在风险
3. 设置后续检查点

### Q: 如何处理专家意见冲突？

A: 
1. 首先理解各方立场
2. 考虑项目约束和优先级
3. 寻找折中方案
4. 必要时升级决策

### Q: 可以只用部分专家吗？

A: 可以，使用 `--experts` 参数:
```
/kallax-panel "问题" --experts architect,backend
```

### Q: 输出太长怎么办？

A: 使用简要模式:
```
/kallax-expert architect "问题" --output brief
```

---

## 版本历史

### v1.0.0 (2024-01)
- 初始版本
- 5 核心专家
- 50+ 扩展专家
- 16 技能模块
