# KALLAX 记忆分层 (Memory Layering) — L0-L4

> **EPIC-059-H** (2026-06-18) | 跟 eket `confluence/memory/` 多级记忆 模式 联合, 跟 `~/.claude/knowledge/core/patterns/knowledge-system.md` L0-L4 分层架构 联合
> **借方法论 不借代码** (跟 EPIC-059-A 9-hard-rules.md §1 联合) — 提取分层模式, 适配 KALLAX 实际目录结构
> **0 增 Rule, 0 重写** (跟 Rule 5 DRY 联合, 加分层标记不删已有 26 files)

---

## 1. 5 层定义 (5 Layer Definitions)

KALLAX 知识库按 5 层分层, 每层有明确的存储位置、生命周期、访问范围:

| Layer | 名称 | 存储位置 | 生命周期 | 访问范围 | 已存在 files |
|---|---|---|---|---|---|
| **L0** | 会话缓存 (Session Cache) | `.kallax/state/` | 瞬态 (session 级别) | 单 session | `state.json` / `instances.json` / `mode.lock` / `instances/` / `instance_config.yml` |
| **L1** | 项目经验 (Project Experience) | `confluence/decisions/` | 长期 (项目级) | 项目内所有 session | 26 files (PHASE-005 ~ PHASE-014 + ACCUMULATED-LESSONS × 2 + dispatch-checklist 等) |
| **L2** | 项目知识 (Project Knowledge) | `confluence/memory/lessons/` | 长期 (项目级) | 项目内所有 session | 17 files (EPIC-016 ~ EPIC-031 lessons + 主题 lessons) |
| **L3** | 全局模式 (Global Patterns) | `confluence/memory/patterns/` | 长期 (跨项目) | 跨项目复用 | 2 files (`isolation-strategy.md` / `rust-node-bridge.md`) |
| **L4** | 全局知识库 (Global Knowledge) | `confluence/memory/research/` | 长期 (跨项目) | 跨项目复用 | 2 files (`anti-hallucination.md` / `architecture-lessons-learned.md`) |

**目录对应** (跟"借方法论 不借代码" 联合):

| Layer | eket 借鉴 | ~/.claude/knowledge 借鉴 | KALLAX 落地 |
|---|---|---|---|
| L0 | session cache | ephemeral 缓存 | `.kallax/state/` (5 entries) |
| L1 | project logs | `decisions/` | `confluence/decisions/` (26 files) |
| L2 | project lessons | `lessons/` | `confluence/memory/lessons/` (17 files) |
| L3 | global patterns | `patterns/` | `confluence/memory/patterns/` (2 files) |
| L4 | global knowledge | `research/` | `confluence/memory/research/` (2 files) |

**辅助层** (不属 L0-L4 主分层, 但相关):
- `confluence/memory/solutions/` (2 files) — 跨项目 solution 库, 跟 L3 模式 联合
- `confluence/memory/guides/` (1 file: `branch-strategy.md`) — 跨项目 guide 库, 跟 L3 模式 联合
- `confluence/memory/glossary/terms.md` — 跨项目术语表, 跟 L4 知识库 联合
- `confluence/memory/architecture-decisions.md` — 跨项目 ADR summary, 跟 L1/L2 联合
- `confluence/memory/memory-index.md` — L0-L4 入口索引, 跟 L4 知识库 联合

---

## 2. 5 触发条件 (5 Trigger Conditions)

每层升级有明确的触发条件 (跟"诚实修正" 联合, 不模糊):

| 触发 # | 条件 | From → To | 典型场景 |
|---|---|---|---|
| **1** | 任务完成 (Performer 完工) | L0 → L1 | ticket claim → PR merge, session 状态写入 `confluence/decisions/` |
| **2** | EPIC 完成 (闭环) | L1 → L2 | EPIC 所有 ticket 完工 → EPIC lessons-learned 写入 `confluence/memory/lessons/` |
| **3** | 跨 release 累计 (复用 ≥ 3 次) | L2 → L3 | lessons 跨 ≥ 3 release 复用 → 升级为全局 pattern, 写入 `confluence/memory/patterns/` |
| **4** | PHASE review (战略级闭环) | L3 → L4 | PHASE-XXX-REVIEW → patterns 升级为全局 knowledge, 写入 `confluence/memory/research/` |
| **5** | 借鉴外部项目 (eket / industry) | L4 沉淀 | eket / industry 模式 → 落地 KALLAX 知识库, 写入 L1-L4 适配层 |

**触发判据** (跟"反讽" 治根 联合, 不模糊):
- 触发 1: `kallax task:merge` 成功 → 写入 `state.json` L0 状态 → 沉淀到 `confluence/decisions/<ticket>.md`
- 触发 2: EPIC 状态 = `closed` + 全部 ticket 完工 → 写 `confluence/memory/lessons/epic-{ID}-{date}.md`
- 触发 3: 同一 lessons 跨 ≥ 3 release 引用 → 评估升级, 写 `confluence/memory/patterns/{pattern-name}.md`
- 触发 4: PHASE-XXX-REVIEW.md 落地 + Master 拍板 → 关键 patterns 提取到 `confluence/memory/research/`
- 触发 5: 外部项目 (eket / industry) 借鉴 → `scripts/eket-lessons-import.sh` (已存在) → 落地到 L1-L4

---

## 3. 5 升级路径 (5 Promotion Paths)

每层升级有明确的执行命令 + 验证标准:

### Path 1: L0 → L1 (任务完成 → 项目经验)

```bash
# 触发: Performer 完工
kallax task:merge TASK-001
# 自动: state.json L0 状态 → confluence/decisions/TASK-001.md (L1 沉淀)
```

**验证**: `confluence/decisions/TASK-001.md` 存在 + `state.json` L0 清理

### Path 2: L1 → L2 (EPIC 完工 → 项目知识)

```bash
# 触发: EPIC 闭环
EPIC_ID=EPIC-031
test -f "confluence/memory/lessons/epic-${EPIC_ID,,}-$(date +%Y-%m-%d).md"
```

**验证**: `confluence/memory/lessons/epic-{ID}-{date}.md` 存在 + 引用 ≥ 5 L1 经验

### Path 3: L2 → L3 (跨 release 累计 → 全局模式)

```bash
# 触发: 同一 lessons 跨 ≥ 3 release 引用
grep -l "{pattern-keyword}" confluence/decisions/PHASE-*.md | wc -l  # >= 3
```

**验证**: 跨 ≥ 3 PHASE 引用 + Master 拍板 → `confluence/memory/patterns/{name}.md`

### Path 4: L3 → L4 (PHASE review → 全局知识库)

```bash
# 触发: PHASE-XXX-REVIEW 关键 patterns
test -f "confluence/decisions/PHASE-${PHASE}-REVIEW-${DATE}.md"
```

**验证**: PHASE review 落地 + research 文档创建 → `confluence/memory/research/{topic}.md`

### Path 5: L4 沉淀 (借鉴外部项目)

```bash
# 触发: 外部项目借鉴
bash scripts/eket-lessons-import.sh  # 已存在
```

**验证**: eket/industry 借鉴落地 → 写 L1 (decisions) + L3 (patterns) + L4 (research) 适配层

---

## 4. 反模式 / 边界 (跟"反讽" + "诚实修正" 联合)

### ❌ 反模式 1: 跨层写入 (skip layer)

- 模式: 直接写 L4 跳过 L1-L3 → **L0→L4 跨级 = 失序**
- 治根: 强制 L0→L1→L2→L3→L4 顺序, 跳级需 Master 拍板 (跟 PROCESS.md:25-26 联合)

### ❌ 反模式 2: 倒序沉淀 (reverse promotion)

- 模式: L4 → L3 倒序写 → **降级 = 反讽**
- 治根: scripts/memory-promote.sh 拒绝逆向 transition, exit 1

### ❌ 反模式 3: L0 长期累积 (cache bloating)

- 模式: `.kallax/state/` 累积 > 1GB → **L0 失活 = 反讽**
- 治根: L0 TTL = session 级别, session 退出清理 (跟 LRU 模式 联合)

### ❌ 反模式 4: L4 假沉淀 (fake global)

- 模式: 写 `confluence/memory/research/` 但缺跨 release 引用 → **空 L4 = 反讽**
- 治根: research 文档必含 ≥ 3 PHASE 引用, 否则不算 L4

### ❌ 反模式 5: 分层标记 跟 实际 失配 (label drift)

- 模式: 写 L3 (patterns/) 但内容是 L2 lessons → **标记 vs reality 失配**
- 治根: scripts/memory-promote.sh verify-all 强制检查目录 vs 内容一致性

---

## 5. 自动化工具 (跟"借方法论 不借代码" 联合)

**新增**: `scripts/memory-promote.sh` (跟 26 .sh wrapper 模式 一致)

**功能**:
- `verify-all` — 验证 5 层目录全部存在 → 5/5 PASS
- `promote <from> <to> <src> <dest>` — 升级 L_i → L_{i+1}, 拒绝跳级/逆序
- `check-layer <L0|L1|L2|L3|L4>` — 检查单层目录 + 内容

**测试**: `tests/integration/memory-l0-l4-test.sh` — 5 mock 场景, 5/5 PASS

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) + Rule 11 (Master 6 维) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../../CLAUDE.md)
**联合**: 跟 KALLAX-GLOSSARY §12.4 (EPIC-059-H 新增) 联合, 跟 eket `confluence/memory/` 模式 + `~/.claude/knowledge` L0-L4 架构 联合.

---

**维护者**: master (EPIC-059-H 拍板)
**最近更新**: 2026-06-18 (EPIC-059-H 落地)
**下次整理触发**: 跨 5+ EPIC 升级累计 / PHASE-016 启动
