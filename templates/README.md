# CLAUDE.md 模板 / CLAUDE.md Templates

> **kallax 框架** — 按需加载 + 模板化
> **核心思想**:`CLAUDE.md` 永远加载,所以要精简;详细规则按需 Read

## 📦 模板列表 / Template List

| 模板 | 行数 | 大小 | 适用场景 |
|------|------|------|---------|
| `CLAUDE.md.minimal` | 63 | ~3KB | 个人项目 / 探索性任务 / Token 敏感 |
| `CLAUDE.md.standard` | 97 | ~5KB | 团队项目 / 生产代码 |
| `CLAUDE.md.full` | 138 | ~7KB | 高级用户 / 复杂项目 / 多角色协作 |

**对比**:

```
┌──────────┬─────────┬──────────┬────────┬────────────┐
│ 模板     │ 核心原则 │ 规则摘要 │ 实战场景 │ 角色规则  │
├──────────┼─────────┼──────────┼────────┼────────────┤
│ minimal  │ ✓       │          │        │            │
│ standard │ ✓       │ ✓        │        │            │
│ full     │ ✓       │ ✓        │ ✓      │ ✓          │
└──────────┴─────────┴──────────┴────────┴────────────┘
```

## 🔄 选择指南 / Selection Guide

```
你只需要写 1-2 行代码吗?
├─ 是 → minimal(63 行)
└─ 否 ↓
    你是单独开发吗?
    ├─ 是 → minimal(63 行)
    └─ 否 ↓
        你是团队项目吗?
        ├─ 是 → standard(97 行)
        └─ 否 → full(138 行,多角色)
```

## 🚀 用法 / Usage

### 自动选择(setup.sh 默认)

```bash
bash scripts/setup.sh --release v1.0.0
# 默认装 minimal + rules/ 详细规则(按需 Read)
```

### 手动指定模板

```bash
bash scripts/setup.sh --template standard
bash scripts/setup.sh --template full
```

### 查看模板

```bash
ls templates/
cat templates/CLAUDE.md.minimal    # 63 行
cat templates/CLAUDE.md.standard   # 97 行
cat templates/CLAUDE.md.full       # 138 行
```

## 🏗️ 自定义模板

模板就是普通 Markdown,你可以:

```bash
# 复制 minimal 作基础
cp templates/CLAUDE.md.minimal templates/CLAUDE.md.myteam

# 编辑加团队特定规则
vim templates/CLAUDE.md.myteam

# 用你的模板
bash scripts/setup.sh --template myteam
```

## 📐 模板设计原则 / Design Principles

1. **永远加载的必须精简**:MINIMAL 63 行适合永远加载
2. **详情按需 Read**:`rules/cli-rule.md` 等不永远加载,需要时 Read
3. **自动加载机制**:Claude Code 按 cwd 自动加载 `CLAUDE.md`
4. **大小合理**:每个模板 < 200 行,避免 context 浪费
5. **可演进**:模板随项目演进,不锁定

## 🔗 配套规则(在 rules/)

部署模板后,会自动创建以下规则文件:

```
~/.claude/rules/
├── cli-rule.md              CLI 执行规范(60+ 行)
├── token-economy.md         Token 精简策略(80+ 行)
└── commit-message.md        Commit 规范(待加)
```

**大模型按需 Read**:做长命令前 Read `cli-rule.md`,写 commit 前 Read `commit-message.md`。

## 📊 Token 节省

| 模板 | 永远加载 | 按需加载 | 总节省 |
|------|---------|---------|--------|
| minimal | 63 行 | ~200 行 | **70%** |
| standard | 97 行 | ~150 行 | 50% |
| full | 138 行 | ~50 行 | 20% |
| (无模板) | 800 行+ | 0 | 0% |

**对比**:`~/.claude/CLAUDE.md` 当前 700+ 行,**任何模板都减 80%+**。

## 📋 完整文件清单

```
kallax/
├── templates/
│   ├── CLAUDE.md.minimal       # 63 行
│   ├── CLAUDE.md.standard      # 97 行
│   ├── CLAUDE.md.full          # 138 行
│   └── README.md               # 本文件
└── scripts/
    └── cli-rule                # 支持 --template
```

---

**Maintained by**:kallax framework
**Last updated**:2026-07-05