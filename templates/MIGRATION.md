# CLAUDE.md 迁移指南 / Migration Guide

> **核心原则**:**模板是 ADDITIVE(增量式),不是 REPLACE(替换)**
> 直接覆盖 683 行的 `~/.claude/CLAUDE.md` 会**灾难性丢失**全局功能。

---

## ⚠️ 危险警告

```
❌ 不要直接:cp templates/CLAUDE.md.minimal ~/.claude/CLAUDE.md
   (会丢 600+ 行全局规则:Immutable Eight / Knowledge Base / RTK 等)
```

**`~/.claude/CLAUDE.md` 当前包含 12+ 个章节,跨多个项目、多个工作流,每个章节都有价值。**

---

## ✅ 安全迁移方案(3 步)

### Step 1:备份

```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup-$(date +%Y%m%d-%H%M%S)
# 备份示例:/Users/chenchen/.claude/CLAUDE.md.backup-20260705-150000
```

### Step 2:分层(`rules/` 目录)

不要直接覆盖 `~/.claude/CLAUDE.md`,**把大段详情搬到 `~/.claude/rules/`**:

```bash
mkdir -p ~/.claude/rules

# 把每个章节搬成独立文件
# (用 Read 看,然后 Write 新位置,或用 Edit 段切)
```

**目标结构**:
```
~/.claude/
├── CLAUDE.md           # 永远加载,精简版(< 200 行)
└── rules/              # 大模型按需 Read
    ├── typescript-principles.md    # 原 Immutable Eight + Checklist
    ├── anti-patterns.md            # 原 Anti-Patterns
    ├── knowledge-base.md           # 原 Knowledge Base
    ├── advanced-patterns.md        # 原 Advanced Patterns
    ├── rtk.md                      # 原 RTK
    ├── memory-lessons.md           # 原 Memory & Lessons
    ├── ultraskills-fallback.md     # 原 Skill Fallback
    ├── cli-rule.md                 # CLI 详细
    └── token-economy.md            # Token 详细
```

**`~/.claude/CLAUDE.md` 精简后只剩**:
```markdown
# CLAUDE.md (精简版)

## 🎯 核心原则
(5 条最核心)

## 📚 规则文件(按需加载)
| 文件 | 何时 Read |
|------|----------|
| rules/typescript-principles.md | TypeScript 项目时 |
| rules/cli-rule.md | 跑长命令前 |
| rules/token-economy.md | cat / find / grep 前 |
| ... |

## ⚙️ 4 层防护
(Hook + Verify + CLI + Setup)
```

### Step 3:大模型按需加载

Claude Code 的行为:
- 进入项目根目录 → 自动加载 `~/.claude/CLAUDE.md` + 项目根 `CLAUDE.md`
- 大模型**按需 Read** `rules/*.md`(只读需要的)

**优点**:
- 永远加载的内容 < 200 行(从 683 行降到 ~150)
- 详情按需(大模型只在需要时 Read)
- 模块化:每个项目根 `CLAUDE.md` 引用需要的 rules/

---

## 🛠️ 自动化脚本(kallax migrate-claude-md)

`scripts/migrate-claude-md.sh`(待实现):

```bash
bash scripts/migrate-claude-md.sh --dry-run   # 预览
bash scripts/migrate-claude-md.sh --apply     # 执行
bash scripts/migrate-claude-md.sh --rollback # 回滚
```

行为:
1. 自动备份原 `CLAUDE.md`
2. 检测现有章节(用 grep)
3. 把每个章节拆成独立文件 `rules/<section>.md`
4. 替换 `CLAUDE.md` 为精简版(保留核心 + 引用)

**示例**:
```bash
# before
~/.claude/CLAUDE.md (683 行)

# after
~/.claude/CLAUDE.md (150 行)
~/.claude/rules/
├── typescript-principles.md (185 行)
├── anti-patterns.md         (49 行)
├── knowledge-base.md        (56 行)
├── advanced-patterns.md     (45 行)
├── rtk.md                   (18 行)
├── memory-lessons.md        (16 行)
├── ultraskills-fallback.md  (20 行)
├── cli-rule.md              (151 行)
└── token-economy.md         (70 行)
```

---

## 📐 迁移原则

### 1. **永远加载 vs 按需加载**

| 类别 | 大小 | 加载时机 | 章节 |
|------|------|----------|------|
| **永远加载** | < 200 行 | 每次会话 | Communication Style + 核心原则 + 4 层防护速查 + 规则索引 |
| **按需加载** | 50-200 行/文件 | 大模型按需 Read | Immutable Eight / Anti-Patterns / RTK / CLI Rule / Token Economy 等 |

### 2. **保留全局功能**

迁移**不能丢**:
- Immutable Eight(TS 编码 8 原则)— 即使现在不写 TS,未来要用
- Knowledge Base(74 个经验文件)— 全局查
- RTK(60-90% token 节省)— dev 工作流
- Auto-Evolution / Memory / Changelog — 文档保留

### 3. **保留但降级**

- Changelog(完整) → 移到 `~/.claude/CHANGELOG.md`(大模型按需 Read)
- Skill Fallback → 移到 `rules/ultraskills-fallback.md`

---

## 🎯 不同迁移路径

### 路径 A:保守(推荐)

**只**迁移最近 2 个新增章节(CLI Rule + Token Economy),其他保留:

```bash
# 1. 把 CLI Rule 和 Token Economy 详细搬到 ~/.claude/rules/
mkdir -p ~/.claude/rules
# (手动 Edit 段切)

# 2. CLAUDE.md 用 references 替换大段
# Edit:把 CLI Rule 详细段换成 "see ~/.claude/rules/cli-rule.md"

# 3. 验证
bash ~/.claude/verify-rule.sh verify
```

**风险**:低(只切 2 段)
**收益**:永远加载的内容减 ~200 行

### 路径 B:激进

**全部分层**:把 12 个章节都搬到 `rules/`。

```bash
# 用脚本自动切
bash scripts/migrate-claude-md.sh --apply
```

**风险**:中(章节切错会丢内容,但有备份)
**收益**:永远加载内容减 ~500 行(从 683 到 ~150)

### 路径 C:零迁移(原状)

**不动** `~/.claude/CLAUDE.md`,只在新项目用模板:

```bash
# 新项目根 CLAUDE.md 用 minimal 模板
cp templates/CLAUDE.md.minimal /new-project/CLAUDE.md
```

**风险**:零
**收益**:新项目干净,旧项目不变

---

## 📊 Token 节省预估

| 路径 | 永远加载 | 按需加载 | 总节省 |
|------|---------|---------|--------|
| 不迁移(当前) | 683 行 | 0 | 0% |
| 路径 A(只切 2 段) | ~480 行 | ~220 行 | 30% |
| 路径 B(全切) | ~150 行 | ~550 行 | 78% |
| 路径 C(新项目) | 63 行 | 0 | 仅新项目 |

---

## 🔗 关联

- `templates/CLAUDE.md.minimal` — 永远加载的精简模板
- `templates/CLAUDE.md.standard` — 中间档
- `templates/CLAUDE.md.full` — 完整档(仍 < 150 行)
- `scripts/migrate-claude-md.sh` — 迁移脚本(待实现)
- `kallax/docs/cli-rule.md` — CLI Rule 完整参考

---

**Maintained by**:kallax framework
**Last updated**:2026-07-05
**Status**:文档,迁移脚本待实现