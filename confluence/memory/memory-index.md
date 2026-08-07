# KALLAX Knowledge Base Index

> 知识库入口 | 更新时间: 2024-01-01

---

## 快速导航

### 📚 核心文档
- [术语表](glossary/terms.md) - KALLAX 专用术语定义
- `../docs/architecture/FRAMEWORK.md` - 系统设计白皮书

### 🎯 模式 (Patterns)
- [并行隔离策略](patterns/isolation-strategy.md) - Worktree + File Scope
- `patterns/error-propagation.md` - Result 链式处理
- `patterns/resource-management.md` - TTL + LRU + 连接池
- `patterns/degradation-strategy.md` - 三级架构降级

### 🔬 研究 (Research)
- [架构经验教训](research/architecture-lessons-learned.md) - 问题分析与改进
- [Agent 防幻觉机制](research/anti-hallucination.md) - Fact-Forcing 验证

### 📝 决策 (Decisions)
- `../decisions/adr-001-naming.md`
- `../decisions/adr-002-isolation.md`
- `../decisions/adr-003-error-handling.md`

---

## 按场景查找

### 我要开始一个新任务
1. 阅读 `../../template/docs/PERFORMER-RULES.md`
2. 检查 `../jira/schemas/ticket-schema.md#file-scope-规则-kallax-新增`
3. 运行 `kallax task:claim TASK-NNN`

### 我需要审核 PR
1. 阅读 `../../template/docs/GATE-REVIEW-PROTOCOL.md`
2. 执行 5-Level 验证
3. 运行 `kallax verify:output TASK-NNN`

### 我遇到了并行冲突
1. 阅读 [并行隔离策略](patterns/isolation-strategy.md)
2. 检查 File Scope 重叠: `kallax isolation:check`
3. 协调 Conductor 重新分配范围

### 我的 Agent 报告完成但没有产出
1. 阅读 [Agent 防幻觉机制](research/anti-hallucination.md)
2. 确认使用 foreground 模式
3. 手动验证: `ls`, `git show`, `npm test`

---

## 文档索引

```
confluence/
├── memory/
│   ├── memory-index.md          # 本文件
│   ├── glossary/
│   │   └── terms.md             # 术语表
│   ├── patterns/                # 架构模式
│   │   ├── isolation-strategy.md
│   │   ├── error-propagation.md
│   │   ├── resource-management.md
│   │   └── degradation-strategy.md
│   └── research/                # 研究笔记
│       ├── architecture-lessons-learned.md
│       └── anti-hallucination.md
├── architecture/                # 系统设计
├── decisions/                   # ADR 决策记录
├── requirements/                # 需求文档
└── audit/                       # 审计记录
```

---

## 贡献指南

### 添加新文档
1. 确定分类 (patterns/research/decisions)
2. 使用标准模板
3. 更新本索引文件
4. 提交 PR

### 文档模板
```markdown
# 文档标题

> 简短描述 | 作者: xxx | 更新: YYYY-MM-DD

## 背景
[问题/需求描述]

## 方案
[解决方案]

## 实施
[代码示例/配置]

## 参考
[相关文档链接]
```
