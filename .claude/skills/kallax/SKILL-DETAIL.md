# KALLAX Skills 详细文档

## 概述

KALLAX Skills 是一个多专家协作系统，通过模拟专业团队协作来提升复杂任务的解决质量。

## 核心理念

### Expert Panel 设计原则

1. **专业分工**: 每个专家专注特定领域
2. **并行思考**: 多视角同时分析问题
3. **协调整合**: Conductor 汇总形成统一决策
4. **按需扩展**: 可动态引入扩展专家

## 命令详解

### /kallax-panel

启动完整专家评审面板。

**语法**:
```
/kallax-panel [topic] [--experts <list>] [--depth <level>]
```

**参数**:
- `topic`: 讨论主题 (可选，默认从上下文推断)
- `--experts`: 自定义专家组合 (默认: architect,backend,frontend,ux,product)
- `--depth`: 分析深度 (quick/standard/deep，默认: standard)

**执行流程**:

```
┌─────────────────────────────────────────────────────────┐
│                    Phase 1: 架构师先行                    │
├─────────────────────────────────────────────────────────┤
│  🏗️ Architect                                           │
│  - 全局扫描代码库                                         │
│  - 识别关键约束和依赖                                      │
│  - 输出: 架构上下文报告                                    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                   Phase 2: 并行分析                      │
├─────────────────────────────────────────────────────────┤
│  💻 Backend    │  🎨 Frontend  │  🖌️ UX    │  📋 Product │
│  - API 设计    │  - 组件规划   │  - 体验   │  - 需求     │
│  - 数据模型    │  - 状态管理   │  - 流程   │  - 优先级   │
│  - 性能考量    │  - 性能优化   │  - 可用性 │  - ROI      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                  Phase 3: 汇总决策                       │
├─────────────────────────────────────────────────────────┤
│  🎼 Conductor                                           │
│  - 整合各专家意见                                         │
│  - 解决冲突和权衡                                         │
│  - 输出: 统一实施方案                                     │
└─────────────────────────────────────────────────────────┘
```

**输出格式**:

```markdown
## Expert Panel 评审报告

### 主题
[讨论主题]

### 架构上下文 (Architect)
[架构师的全局分析]

### 专家意见

#### 💻 Backend
[后端专家意见]

#### 🎨 Frontend
[前端专家意见]

#### 🖌️ UX
[UX 专家意见]

#### 📋 Product
[产品专家意见]

### 综合决策 (Conductor)

#### 推荐方案
[最终推荐]

#### 实施路径
1. [步骤1]
2. [步骤2]
...

#### 风险与缓解
| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| ... | ... | ... | ... |

#### 后续行动
- [ ] [Action Item 1]
- [ ] [Action Item 2]
```

---

### /kallax-expert

召唤单个专家进行分析。

**语法**:
```
/kallax-expert <role> [context] [--output <format>]
```

**参数**:
- `role`: 专家角色 (见 SKILL.md 列表)
- `context`: 上下文信息 (可选)
- `--output`: 输出格式 (markdown/json/brief，默认: markdown)

**核心专家详解**:

#### 🏗️ Architect (架构师)

**触发场景**:
- 系统设计评审
- 技术选型决策
- 性能/扩展性分析
- 依赖关系梳理

**输出内容**:
- 架构图 (Mermaid)
- 组件依赖分析
- 技术栈推荐
- 风险评估

#### 💻 Backend (后端工程师)

**触发场景**:
- API 设计
- 数据模型设计
- 后端性能优化
- 安全性考量

**输出内容**:
- API 规范 (OpenAPI)
- 数据模型 (ERD)
- 实现方案
- 测试策略

#### 🎨 Frontend (前端工程师)

**触发场景**:
- 组件设计
- 状态管理方案
- 前端性能优化
- 构建配置

**输出内容**:
- 组件树
- 状态流图
- 实现方案
- 性能指标

#### 🖌️ UX (UX 研究员)

**触发场景**:
- 用户流程设计
- 交互模式评审
- 可用性分析
- 信息架构

**输出内容**:
- 用户旅程图
- 线框图建议
- 交互规范
- 可访问性检查

#### 📋 Product (产品经理)

**触发场景**:
- 需求分析
- 优先级排序
- 验收标准定义
- ROI 评估

**输出内容**:
- PRD 大纲
- 用户故事
- 验收标准
- 发布计划

---

### /kallax-skill

执行特定技能。

**语法**:
```
/kallax-skill <name> [target] [--params <json>]
```

**参数**:
- `name`: 技能名称
- `target`: 目标文件/目录 (可选)
- `--params`: 额外参数 (JSON 格式)

**技能详解**:

#### code-analysis
静态代码分析，识别问题和改进点。

```
/kallax-skill code-analysis src/ --params '{"depth": "deep", "focus": ["security", "performance"]}'
```

#### requirements-analysis
需求分析，提取用户故事和验收标准。

```
/kallax-skill requirements-analysis "用户需要能够..." --params '{"format": "agile"}'
```

#### tdd
测试驱动开发引导。

```
/kallax-skill tdd "实现用户认证功能"
```

#### prompt-engineering
提示词工程优化。

```
/kallax-skill prompt-engineering "当前提示词内容"
```

---

### /kallax-list

列出所有可用资源。

**语法**:
```
/kallax-list [--category <cat>] [--format <fmt>]
```

**输出示例**:

```
KALLAX 可用资源

专家 (55)
├── 核心专家 (5)
│   ├── architect - 系统架构、技术选型
│   ├── backend - 后端实现、API 设计
│   ├── frontend - 前端实现、组件设计
│   ├── ux - 用户体验、交互设计
│   └── product - 产品规划、需求分析
└── 扩展专家 (50)
    ├── AI/ML (6)
    ├── Business (5)
    ├── Consulting (3)
    ...

技能 (16)
├── Algorithm (1)
├── Analysis (2)
├── Data (1)
...
```

---

## 高级用法

### 自定义专家组合

```
/kallax-panel "微服务拆分" --experts architect,backend,devops,sre
```

### 深度分析模式

```
/kallax-panel "安全架构评审" --depth deep
```

### 链式调用

```bash
# 先分析，再实施
/kallax-expert architect "评审当前设计"
/kallax-skill code-analysis src/
/kallax-skill refactoring "基于分析结果重构"
```

### 与其他工具集成

```bash
# 结合 Git 工作流
/kallax-panel "PR #123 架构变更评审"

# 结合 CI/CD
/kallax-skill ci-cd "优化构建流程"
```

---

## 最佳实践

### 1. 选择合适的粒度

| 任务类型 | 推荐方式 |
|----------|----------|
| 新产品/新 EPIC | `/kallax-panel` |
| 单一领域问题 | `/kallax-expert` |
| 具体技术任务 | `/kallax-skill` |
| 简单修复 | 直接执行 |

### 2. 提供充分上下文

```bash
# ❌ 上下文不足
/kallax-panel

# ✅ 上下文充分
/kallax-panel "设计实时消息系统，需支持10万并发，消息持久化，已有 PostgreSQL 和 Redis"
```

### 3. 迭代式使用

```bash
# 第一轮: 粗粒度分析
/kallax-panel "用户系统设计" --depth quick

# 第二轮: 针对性深入
/kallax-expert security "认证模块安全评审"
```

### 4. 记录决策

专家评审的输出可直接作为 ADR (Architecture Decision Record) 的基础。

---

## 故障排除

### 专家意见冲突

当专家意见产生冲突时，Conductor 会:
1. 明确列出冲突点
2. 分析各方理由
3. 基于项目约束给出建议
4. 标记需人工决策的事项

### 分析超时

对于大型代码库:
```bash
# 限制分析范围
/kallax-skill code-analysis src/core/ --params '{"maxFiles": 100}'

# 使用快速模式
/kallax-panel "问题" --depth quick
```

### 缺少领域专家

如果需要的专家不在列表中:
```bash
# 使用最接近的专家
/kallax-expert mgmt "项目管理问题"

# 或请求添加新专家
# (提交 PR 到 experts/extended/)
```
