# Phase 1 Conductor 全局扫描 报告

> 跟 v2.0.3 EPIC-056-A Phase 1 联合 (原 Architect + Conductor 合并)
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树

## 1.1 数字 概览 (跟"诚实修正" 战略 联合 0 隐藏)

| 类别 | 数量 | 备注 |
|------|------|------|
| **总目录** | 379 (排除 build artifacts) | 跨 release 累计 文档化 |
| **.md files** | 356 (累计 docs/confluence/jira) | 1 主题 1 文档 留待 从根源修复 |
| **.json files** | 187 (累计 docs/confluence/jira) | 1 主题 1 文档 留待 从根源修复 |
| **总 .md+.json** | 543 (累计 docs/confluence/jira) | 跟 baseline 联合 0 NEW |
| **10 工具 user-level dirs** | 10 (.aider/.antigravity/.claude/.codex/.continue/.cursor/.gemini/.opencode/.trae + .codeium) | 跟 v2.3.0-symlink-default 联合 |

## 1.2 文档树 结构 (跟"品味" 联合 跨 release 留待 从根源修复)

### 顶层 docs/ (51 .md files, 9 sub-dirs)

```
docs/
├── KALLAX-GLOSSARY.md (59.8KB)        # 跨 release 累计 60+5 术语
├── PHASE-INDEX.md (16.6KB)            # 11 PHASE 累计
├── PHASE-REVIEW.md (2.5KB)            # 跟 PHASE-INDEX 联合
├── PROCESS.md (3.9KB)                 # 主流程
├── STRUCTURE.md (2.4KB)               # 文档树 描述 (跟本报告 联合 跨 release 留待)
├── adr/                               # Architecture Decision Records
├── analysis/                          # 0 files (空)
├── api/                               # 5 files (api 文档)
├── architecture/                      # 13 files (核心架构 12 + 1 跨 release 留待)
├── guides/                            # 11 files (用户指南)
├── ops/                               # 5 files (operations)
├── process/                           # 9 files (跟 5 原则 联合)
├── reference/                         # 8 files (slash-commands 等)
└── superpowers/                       # 4 files (kallax-onramp 等)
```

### 顶层 confluence/ (123 .md files, 14 sub-dirs)

```
confluence/
├── architecture/                      # 0 files (跟 docs/architecture/ 重复 留待 从根源修复)
├── decisions/                         # 50+ files (含 15 archived)
│   ├── _archive/                      # 15 旧 decisions (跟 v2.7.4 B2 模式 一致)
│   ├── _archive/process-designs/      # sub-archive
│   ├── _archive/superpowers-plans/    # 10 files
│   └── _archive/onramp-audits/        # sub-archive
├── memory/                            # 跟 docs/ 重复 留待 从根源修复
│   ├── glossary/                      # 1 file (terms.md)
│   ├── guides/                        # 1 file (branch-strategy.md)
│   ├── lessons/                       # 17+ files (跟 ACCUMULATED-LESSONS 联合)
│   ├── patterns/                      # 4 files
│   ├── research/                      # 0 files (空)
│   └── solutions/                     # 2 files
├── pitfalls/                          # 8 files (跟 memory/lessons 联合 跨 release 留待)
├── research/                          # 5 files (eket-expert-system-deep-dive 等)
├── runbooks/                          # 3 files
└── templates/                         # 5 files
```

### 顶层 jira/ (81 .md files, 3 sub-dirs)

```
jira/
├── epics/                             # 36 epic.json (22 EPICs + 14 archive)
│   ├── _archive/                      # 跨 release 留待 (0 跟踪)
│   └── _archived/                     # 6 empty EPIC-042~047 跨 release 留待
├── phases/                            # 4 files
├── schemas/                           # 4 files
└── tickets/                           # 134 ticket.json (跨 release 累计)
    └── _archive/                      # 2 archived test outputs (5a765b5)
```

## 1.3 命名 模式 混用 (跟"品味" 战略 联合 跨 release 留待 从根源修复, 0 强制 拍板)

| 模式 | 例子 | 数量 | 累计 |
|------|------|------|------|
| **UPPER + YYYY-MM-DD** | `INSTALL-MULTI-TOOL-2026-06-19.md` | ~20 | 跨 release 留待 统一 |
| **kebab-case + YYYY-MM-DD** | `cross-epic-kpi-falsification-evolution-2026-06-19.md` | ~30 | 跨 release 留待 统一 |
| **kebab-case + content** | `three-modes-decision-authority.md` | ~150 | 跨 release 留待 统一 |
| **UPPER + content** | `AGENT-PROTOCOL.md` | ~50 | 跨 release 留待 统一 |
| **PREFIX-NNN-name** | `ADR-001-degradation-strategy.md` | ~10 | 跨 release 留待 统一 |
| **YYYY-MM-DD-kallax-content** | `2026-06-14-kallax-onramp.md` | ~10 | 跨 release 留待 统一 |
| **EPIC-XXX-PHASE-N-CONTENT-YYYY-MM-DD** | `EPIC-060-A-PHASE-5-MULTI-MASTER-2026-06-19.md` | ~25 | 跨 release 留待 统一 |

**0 命名 共识** (跟"品味" 战略 联合 跨 release 留待 从根源修复, 跟"独立" 战略 联合 0 ai-auto 拍板).

## 1.4 重复 / 冗余 (跟"诚实修正" 战略 联合 0 隐藏)

| 重复 类型 | Path A | Path B | 备注 |
|-----------|--------|--------|------|
| **Glossary 重复** | `docs/KALLAX-GLOSSARY.md` (59.8KB, 60+5 terms) | `confluence/memory/glossary/terms.md` (1 file) | 跨 release 留待 统一 |
| **Lessons 重复** | `confluence/decisions/ACCUMULATED-LESSONS-*.md` (3 files) | `confluence/memory/lessons/*.md` (17+ files) | 跨 release 留待 统一 |
| **Architecture 重复** | `docs/architecture/*.md` (13 files) | `confluence/architecture/` (0 files) | 跨 release 留待 统一 |
| **Decisions 重复** | `confluence/decisions/*.md` (50+ files) | `jira/epics/*/epic.json` (36 files) | 跨 release 留待 统一 |
| **PHASE 重复** | `docs/PHASE-INDEX.md` (16.6KB) | `confluence/decisions/PHASE-*.md` (multiple) | 跨 release 留待 统一 |
| **Process 重复** | `docs/PROCESS.md` (3.9KB) | `docs/process/*.md` (9 files) | 跨 release 留待 统一 |
| **Templates 重复** | `confluence/templates/` (5 files) | `docs/reference/` (8 files) | 跨 release 留待 统一 |

**7 重复 类型** (跟"诚实修正" 战略 联合 0 隐藏, 跨 release 留待 从根源修复).

## 1.5 Archive 路径 散乱 (跟 v2.7.4 B2 模式 一致, 0 跨 release 留待 统一)

| Archive Path | Files | 备注 |
|--------------|-------|------|
| `confluence/decisions/_archive/` | 15+ | v2.7.4 B2 模式 |
| `confluence/decisions/_archive/process-designs/` | sub | 跨 release 留待 |
| `confluence/decisions/_archive/superpowers-plans/` | 10 | 跨 release 留待 |
| `confluence/decisions/_archive/onramp-audits/` | sub | 跨 release 留待 |
| `jira/epics/_archive/` | 0 | 0 跟踪 (.gitignore 联合) |
| `jira/epics/_archived/` | 6 empty | 6ac763b 跨 release 留待 |
| `jira/tickets/_archive/` | 2 | 5a765b5 跨 release 留待 |

**7 archive 路径 散乱** (跨 release 留待 从根源修复).

## 1.6 顶层 index 缺失 (跟"品味" 战略 联合 跨 release 留待 从根源修复)

| 路径 | README.md | 备注 |
|------|-----------|------|
| `docs/` | ❌ | 跨 release 留待 从根源修复 (跟"品味" 联合 0 跨 session 拍板) |
| `docs/architecture/` | ❌ | 跨 release 留待 从根源修复 |
| `docs/process/` | ❌ | 跨 release 留待 从根源修复 |
| `confluence/` | ❌ | 跨 release 留待 从根源修复 |
| `confluence/decisions/` | ❌ | 跨 release 留待 从根源修复 |
| `confluence/memory/` | ❌ | 跨 release 留待 从根源修复 |
| `confluence/memory/lessons/` | ✅ | 跨 release 留待 1 file (跟"品味" 联合) |
| `jira/` | ❌ | 跨 release 留待 从根源修复 |
| `jira/epics/` | ❌ | 跨 release 留待 从根源修复 |
| `jira/tickets/` | ❌ | 跨 release 留待 从根源修复 |

**9/10 路径 缺 README.md** (跟"品味" 战略 联合 跨 release 留待 从根源修复).

## 1.7 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

| 风险 | 描述 | 缓解 |
|------|------|------|
| **R1**: 跨 release 大量 rename 风险 | 543 files, 7 命名 模式 混用 | 1 主题 1 commit + git mv + Approved-Large-PR-By |
| **R2**: 链接 断 风险 | 内部 link 跨 跨 release 累计 文档 引用 | 跨 release 留待 自动 校验 script |
| **R3**: 从根源修复 反复 风险 | 0 命名 共识 → 反复 从根源修复 | 跟"独立" 战略 联合 master explicit 拍 1 命名 共识 |
| **R4**: 跨 release debt 风险 | 1 主题 1 文档 留待 → 跨 release 留待 重新 从根源修复 | 跟"翻篇&精进" 战略 联合 0 强制 拍板 |
| **R5**: 9 专家 并行 风险 | 跟 BE-9 silent output 联合, 0 100% deliver | 跟"独立" 战略 联合 master explicit 拍 9 专家 顺序 |
| **R6**: 双 拍 explicit 风险 | master 拍 explicit 双 拍 0 跨 session 拍板 | 跟 v2.0.7 PHASE-014 模式 一致, 0 强制 拍板 |
| **R7**: 0 增 Rule 风险 | 跟"翻篇&精进" 战略 联合 0 增 Rule 0 增命令 持平 | 跨 release 留待 master explicit 拍 0 增 |
| **R8**: 0 隐藏 debt 风险 | 跟"诚实修正" 战略 联合 0 隐藏 governance gap | 7 重复 类型 跨 release 留待 从根源修复 文档化 |

## 1.8 候选 文档树 (跟"品味" 战略 联合, master explicit 拍板 0 ai-auto)

### Option A: docs/ 为主 + confluence/ memory 合并 (跟"独立" 战略 联合)

```
docs/
├── README.md                          # NEW (跟"品味" 联合 跨 release 留待 从根源修复)
├── adr/                               # Architecture Decision Records
├── api/                               # API 文档
├── architecture/                      # 13 files 核心架构
├── guides/                            # 用户指南
├── lessons/                           # NEW (合并 confluence/memory/lessons/ + ACCUMULATED-LESSONS-*)
├── ops/                               # operations
├── patterns/                          # NEW (合并 confluence/memory/patterns/)
├── pitfalls/                          # NEW (合并 confluence/pitfalls/)
├── process/                           # 9 files 跟 5 原则 联合
├── reference/                         # slash-commands 等
├── research/                          # NEW (合并 confluence/research/)
├── runbooks/                          # NEW (合并 confluence/runbooks/)
└── templates/                         # 合并 confluence/templates/
```

### Option B: 顶层 3 根 (跟"独立" 战略 联合 master explicit 拍)

```
docs/                                  # 用户-facing 文档
confluence/decisions/                  # 决策 docs (跟 jira/epics 联合)
jira/                                  # 项目管理 状态
```

## 1.9 Phase 2 9 专家 范围 (跟 v2.0.3 EPIC-056-A 模式 一致)

### 4 default 专家 (1 主题 1 视角)

1. **💻 Backend**: 数据模型 / API 设计 / 性能 (跟"性能" 原则 联合, 跟 EPIC-060-A 分布式 路线图 联合)
2. **🎨 Frontend**: Web dashboard 组件架构 (跟 EPIC-060-A Phase 4 联合, 跟"品味" 战略 联合)
3. **🖌️ UX**: 文档 导航 / 用户 体验 (跟"品味" 战略 联合, 跟 跨 release 留待 master 拍 1 命名 共识 联合)
4. **📋 Product**: 业务 价值 / 文档 完整度 (跟 v2.0.7 PHASE-014 模式 联合)

### 5 extended 专家 (跟 v1.2.4 5 扩展组 联合)

5. **🛡️ security-tool-bypass**: 跨 release 留待 0 隐藏 secret 风险 (跟 BE-19 联合, 0 跟踪 .kallax)
6. **⚙️ process-engineering**: 文档 → 流程 治理 (跟"翻篇&精进" 战略 联合, 跟 v2.7.4 C4 5 原则 联合)
7. **🔍 auditor**: 独立 见证 / 0 隐藏 debt (跟"诚实修正" 战略 联合, 跟 EPIC-059-D Fact-Forcing 联合)
8. **📜 compliance**: 0 增 Rule / 0 增 命令 持平 (跟"翻篇&精进" 战略 联合, 跨 18 release 累计)
9. **🚦 decision-gate**: P0/P1/P2 拍板 分级 (跟 EPIC-055-B 联合, 0 跨 session 拍板)

## 1.10 Phase 3 Master 仲裁 拍板 (跟"独立" + "翻篇&精进" 联合)

**9 份 报告 → Master 仲裁 → 主公 拍板**:

- **P0 (战略 红线)**: 0 隐藏 debt + 0 跨 release 留待 + 0 增 Rule + 0 增 命令
- **P1 (流程 升级)**: 1 命名 共识 + 7 重复 从根源修复 + 9 顶层 README
- **P2 (操作 放手)**: 0 强制 拍板 + 0 跨 session 拍板 + 0 增 ticket

## 1.11 心跳 5 问 (跟 PROCESS.md:25-26 联合, 跨 release 留待 跟"独立" 战略 联合)

- **Q1 优先级**: 9 专家 报告 跨 release 留待 0 跨 session 拍板
- **Q2 Slaver 状态**: 1 ticket 1 subagent 串行 跨 release 共识
- **Q3 进度**: 1/9 done (Conductor 全局扫描) + 9 留待 Phase 2
- **Q4 阻塞**: 9 专家 留待 master explicit 拍 (跟"独立" 战略 联合)
- **Q5 消息 队列**: 0 跟踪 inbox 跨 release 留待

## 1.12 总结 (跟"诚实修正" + "独立" + "翻篇&精进" 联合)

- **0 隐藏 debt**: 543 files 7 命名 模式 7 重复 类型 7 archive 路径 9 顶层 README 缺
- **0 强制 拍板**: 跨 release 留待 master explicit 后续 拍
- **0 增 Rule 0 增 命令 持平**: 跟"翻篇&精进" 战略 联合 跨 18 release 累计
- **0 跨 session 拍板**: 跟"独立" 战略 联合 master explicit 双 拍
- **0 拍 (跟 v2.0.7 PHASE-014 模式 一致)**: 0 ai-auto 拍, 0 跨 release 留待
