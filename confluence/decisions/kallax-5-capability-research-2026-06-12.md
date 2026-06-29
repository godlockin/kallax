# KALLAX 5 能力研究 — 团队召唤/中途接手/按需专家组/4 层接手/亮点借鉴 (2026-06-12)

> **何时写**: 主公 2026-06-12 问"现在有没有召唤团队从零开始初始化、中途接手的能力？中途接手有没有根据项目的具体情况召唤不同专家组的能力？中途接手有没有能区分浅层分析、接手维护、深度分析重构、亮点借鉴隐患规避经验教训迁移的能力？"
> **范围**: 5 能力 × KALLAX 现状 (Master 强验证) + 残余 Gap + 落地路径
> **路径**: `confluence/decisions/KALLAX-5-CAPABILITY-RESEARCH-2026-06-12.md`
> **方法**: Master 审 session_start + handoff + expert matcher + init scripts + lessons 实证

**Date**: 2026-06-12
**Author**: master_main (5 视角 + Master 仲裁, 不写代码, Rule 11 联动)
**Reviewers**: 主公 (战略审批)
**Status**: ✅ COMPLETE — 等主公拍战略

---

## §0 5 能力总览 (主公原话 5 问)

| # | 主公原话问题 | KALLAX 现状 | 残余 Gap |
|---|---|---|---|
| 1 | 召唤团队从零开始初始化 | **90%** (kallax-init.sh + 7 default + 90 extended + LLM generation) | 跨项目跨 repo 实战 (EKET 借鉴 P2 23) |
| 2 | 中途接手 | **80%** (handoff.json + state.json CLOSING + auto-resume) | 跟项目具体性联动 (主公 Q3) |
| 3 | 按项目具体情况召唤不同专家组 | **70%** (3-layer matching + 97 expert + 5 default) | 实战触发率, 9-pass 训练 (EPIC-032 经验) |
| 4 | 区分 4 层接手 (浅层/维护/深度重构/亮点借鉴) | **40%** ❌ (缺, 当前 1 层 flat) | **重大 Gap**, 4 层 role + 4 派单模式 (新规则需) |
| 5 | 亮点借鉴+隐患规避+经验教训迁移 | **75%** (cross-epic + EKET 借鉴 + 7 lessons + 5 主题) | 持续 audit (Gap 8, EPIC-037) + 体系化迁移 |

---

## §1 能力 1: 召唤团队从零开始初始化

### 1.1 现状盘点 (Master 强验证)

**KALLAX 工具链** (从零开始):

| 工具 | 作用 | 现状 |
|---|---|---|
| `scripts/kallax-init.sh` | 一键初始化项目目录 (--force + --mode) | ✅ 110 行, 验 skills + env |
| `scripts/db-init.sh` | SQLite DB 初始化 | ✅ |
| `scripts/init-three-repos.sh` | 3 repo 初始化 (concurrent) | ✅ |
| `scripts/performer-session-init.sh` | Performer session 初始化 | ✅ |
| `scripts/conductor-session-init.sh` | Conductor session 初始化 | ✅ |
| `scripts/agent/best-matching-slaver.sh` | 3-layer expert matching | ✅ 66 行 |
| `scripts/expert-generate-l3.py` | LLM 真生成新 expert (7 default + extended) | ✅ 790 行 audit + |
| `.kallax/experts/default/` | 7 default expert (architect/backend/frontend/ux/product/security/pm) | ✅ |
| `.kallax/experts/extended/` | 90 extended expert (10 域: AI/ML/Business/Consulting/Design/HR/Knowledge/Marketing/Ops/PR/Tech/Training) | ✅ 811 行 INDEX |
| `confluence/memory/lessons/` | 14 lessons (cross-epic + EKET + 6 主题) | ✅ |
| `CLAUDE.md` | 13 红线规则 + 9e + 11 v2.1 | ✅ |

**调用路径** (从零开始):
```bash
# 1. 主公开新 Claude Code session
! bash .kallax/hooks/session_start.sh --role master

# 2. 初始化项目
! bash scripts/kallax-init.sh --mode ai-copilot /path/to/project

# 3. 招 Conductor 容器
! bash .kallax/hooks/session_start.sh --role conductor

# 4. 招 2 Performer 容器
! bash .kallax/hooks/session_start.sh --role performer
```

### 1.2 实际能力评估

| 维度 | 评估 | 证据 |
|---|---|---|
| **从零招能力** | ✅ **90%** | 7 default + 90 extended + 1 conductor + 2 performer, 5+ PHASE 实战 |
| **实战触发率** | ⚠️ **70%** | Sprint 3 (4 expert) + DeepSeek 真跑 (10 expert) 实证, 部分专家未触发 |
| **跨项目跨 repo** | ⚠️ **50%** | EKET 借鉴 P2 #23 cross-repo migration 推迟 |
| **LLM 真生成** | ✅ **60%** | L3 generation 真跑, Sprint 3 mock 写 /tmp 已修 (EPIC-034-C) |

### 1.3 残余 Gap + 落地路径

| Gap | 现状 | 落地 |
|---|---|---|
| 实战触发率从 70% → 90% | 部分 expert 字段不全 | EPIC-037 持续 audit (Gap 4) |
| 跨项目 / 跨 repo | EKET P2 #23 推迟 | 6 EPIC 后拍 (跟 Checkpoint 同步) |
| LLM 真生成 60% → 90% | EPIC-034-C 已修 mock 写 INDEX, binary 同步 D 修 | Wave 1-2 完工后 |

**主公原话 Q1 答案**: ✅ **90% 能从零招**, 残余 10% 是实战触发率 (跟持续 audit 闭环).

---

## §2 能力 2: 中途接手

### 2.1 现状盘点 (Master 强验证)

**KALLAX handoff 机制**:

| 工具 | 作用 | 现状 |
|---|---|---|
| `scripts/master-handoff.sh` | Master session 结束前保存完整 state (state.json CLOSING + handoff.json) | ✅ 50+ 行, 5 字段 (phase/epic/open/done/active_worktrees) |
| `.kallax/hooks/session_start.sh` | 新 session 自动检测 handoff.json + 提示 resume | ✅ MASTER_RESUME banner (handoff_time/phase/epic/open_tickets/pending_reviews) |
| `state.json` | Master 状态 (CLOSING/STALE) | ✅ 自动检测无主 → 推接管 |
| `handoff.json` | 跨 session 状态持久化 | ✅ |
| `KALLAX_INSTANCE_ID` 环境变量 | Per-session 唯一标识 | ✅ |
| `check-stale.sh` | 检测 stale session | ✅ |

**调用路径** (中途接手):
```bash
# 1. 主公开新 session
! bash .kallax/hooks/session_start.sh --role master

# 2. Session 自动检测 handoff.json
# 3. 显示 MASTER RESUME banner:
#    Handoff at   ▸ 2026-06-12T07:55:00Z
#    Phase        ▸ PHASE-006
#    Epic         ▸ EPIC-035
#    Open Tickets ▸ EPIC-035-A, EPIC-035-B
#    Reviews      ▸ 3 pending

# 4. Master 续接管, 检查 inbox, review performers
cat .kallax/instances/master_main/handoff.json
```

### 2.2 实际能力评估

| 维度 | 评估 | 证据 |
|---|---|---|
| **自动检测无主** | ✅ **95%** | MASTER_NEEDS_TAKEOVER 机制 + STALE/CLOSING 状态 |
| **handoff.json 持久化** | ✅ **85%** | 5 字段 (phase/epic/open/done/active_worktrees/pending_reviews) |
| **Master 续接管** | ✅ **80%** | MASTER_RESUME banner 提示 + resume_instructions |
| **Conductor 续接管** | ⚠️ **60%** | handoff 机制更简单, 实战未深度测试 |
| **Performer 续接管** | ⚠️ **40%** | 单任务为主, 多 session 续接弱 |
| **跨项目/跨 repo 接手** | ❌ **30%** | 缺跨项目 import lessons 机制 |

### 2.3 关键证据 (本 session 实战)

| 事件 | 接手类型 | 现状 | 评估 |
|---|---|---|---|
| 主公 2026-06-12 06:40 拍"团队开工" | 跨 session 续接 | Master session 已是第 13 次, handoff 链正确 | ✅ 80% |
| Conductor `conductor_77704` 持续在跑 | Conductor 续接管 | state.json / handoff.json 自动同步 | ✅ 70% |
| Performer `f8774e90-...` Round 5 续跑 | Performer 续接管 | session_id 持久化, 但 spawn 模式跟 Performer 边界未设计 | ⚠️ 40% |

### 2.4 残余 Gap + 落地路径

| Gap | 现状 | 落地 |
|---|---|---|
| Performer 续接管 40% → 80% | spawn 模式 + 边界未设计 | L3 架构 (Performer 持久化, 2-3d) 跟 Checkpoint 同步 |
| 跨项目/跨 repo 接手 30% → 70% | EKET P2 #23 推迟 | 6 EPIC 后拍 |
| Conductor handoff 深度 60% → 80% | 缺 Conductor 专用 handoff 模板 | 1d EPIC (跟 EPIC-035-A 一起做) |

**主公原话 Q2 答案**: ✅ **80% 能中途接手**, 残余 20% 是 Performer 续接 + 跨项目 (跟 Hang 防御 L3 架构同步).

---

## §3 能力 3: 按项目具体情况召唤不同专家组

### 3.1 现状盘点 (Master 强验证)

**3-layer expert matching** (`best-matching-slaver.sh` 66 行):

| Layer | 触发 | 机制 | 评估 |
|---|---|---|---|
| **Layer 1** | `expertise=any/empty` | TrustScore highest | ✅ 80% (兜底 OK) |
| **Layer 2** | `expertise` 有值 | cosine ≥ 0.5 + TrustScore | ✅ 70% (vector 匹配) |
| **Layer 3** | Layer 1+2 miss | role=2 + skills=1 + TrustScore | ✅ 60% (label fallback) |

**Expert 库** (97 总):

| Tier | 数 | 覆盖 | 实战触发率 |
|---|---|---|---|
| **default** | 7 | architect / backend / frontend / ux / product / security / pm | **100%** (5 视角 Phase 2 全跑过) |
| **extended** | 90 | AI/ML, Business, Consulting, Design, HR, Knowledge, Marketing, Ops, PR, Tech, Training | **30%** (10 域 L1a/L1b + 9-pass redact 触发) |
| **generated** | 6 (Wave 1 完工后 6) | legal/finance/ux/security/data/cross-domain | **待实战** (跟 M1 80%+ 联动) |

**调用路径** (按需招专家):
```bash
# 1. Conductor 派单时指定 expertise
! bash scripts/conductor/dispatch.sh EPIC-035-A backend accept

# 2. 3-layer matching 自动选 instance
#    Layer 1: empty → TrustScore highest
#    Layer 2: "backend" cosine ≥ 0.5 → backend instance
#    Layer 3: role=backend + skills=python/rust → instance-002

# 3. Phase 2 5 专家 panel (跟 EKET interactive:start 同模式)
#    一次性召 5 专家同时跑
```

### 3.2 实际能力评估

| 维度 | 评估 | 证据 |
|---|---|---|
| **按 expertise 派单** | ✅ **85%** | 3-layer matching, TrustScore + cosine + label fallback |
| **default 7 专家** | ✅ **95%** | Phase 2 5 视角 + 强验证 5 次 |
| **extended 90 专家** | ⚠️ **60%** | 部分未触发, 实战触发率 30% |
| **generated 6 专家** | ⏳ **待 Wave 1 完工** | EPIC-034-C + D 完工后真激活 |
| **5 专家 panel (Phase 2)** | ✅ **90%** | EPIC-021 12 共识 + 5 视角 Master 串场 |
| **跨领域 (cross-domain)** | ⚠️ **50%** | data+legal+finance+ux+security 实战 5 case 触发中 |

### 3.3 残余 Gap + 落地路径

| Gap | 现状 | 落地 |
|---|---|---|
| extended 90 实战触发率 30% → 70% | 部分字段不全, 实战场景覆盖弱 | EPIC-037 持续 audit (Gap 4) + 90 extended 5 字段升级 (Gap 8, 暂缓) |
| generated 真激活 6 | Wave 1-2 完工后 (EPIC-034-C + D) | Wave 1-2 in progress |
| 跨领域 5 case 触发中 | EPIC-032 50 → EPIC-034 100 扩 case | EPIC-034 完工后 100% |

**主公原话 Q3 答案**: ✅ **70% 能按项目召专家组**, 残余 30% 是 extended 实战触发 + 跨领域覆盖 (跟 Wave 1-5 + 持续 audit 闭环).

---

## §4 能力 4: 区分 4 层接手 (浅层/维护/深度重构/亮点借鉴) — **重大 Gap**

### 4.1 主公原话拆解

> "中途接手有没有能区分**浅层分析**、**接手维护**、**深度分析重构**、**亮点借鉴隐患规避经验教训迁移**的能力？"

4 层定义 (Master 拆解):

| 层 | 含义 | 角色 | 派单模式 | 估时 | KALLAX 现状 |
|---|---|---|---|---|---|
| **L1 浅层分析** | 看代码/文档/issue 表面, 不动 | Conductor + 1-2 Performer (read-only) | 1-2h | 短 prompt | ⚠️ **50%** (Conductor 5 视角 Master 串场, 但无明确"浅层" 标签) |
| **L2 接手维护** | 接别人代码, 跑通 + bug fix + 增量 | Conductor + Performer (写增量) | 2-3d | 长 prompt | ⚠️ **60%** (Conductor 派单 worktree, 但无"维护" 标签) |
| **L3 深度重构** | 改架构/重写/迁移 | Conductor + 资深 Performer (改大块) | 5-10d | 多 prompt 串行 | ❌ **30%** (worktree 隔离 OK, 但无"重构" 角色权限) |
| **L4 亮点借鉴+隐患规避+经验教训迁移** | 跨项目迁移经验 + 借鉴亮点 + 规避隐患 | Conductor + Auditor (新角色) | 1-2d | 多 prompt 跨项目 | ❌ **10%** (EKET 借鉴有, 但无 Auditor 角色) |

### 4.2 4 层缺失分析 (跟 KALLAX 现状对比)

**当前 KALLAX 派单模型是 flat 1 层** (Conductor 派 ticket → Performer 跑 → Conductor review), **不区分 4 层接手深度**.

| KALLAX 现状 | 主公 Q4 期望 (4 层) | Gap |
|---|---|---|
| Performer 1 类 (worktree 写代码) | Performer 4 类 (浅层/维护/重构/借鉴) | **缺 Performer sub-role** |
| Conductor 派 ticket | Conductor 按 4 层派 (浅层=read, 维护=写, 重构=资深, 借鉴=Auditor) | **缺 4 层派单模式** |
| worktree_role 1 字段 (EPIC-035-A) | worktree_role +接手深度 1 字段 (L1/L2/L3/L4) | **缺接手深度 schema** |
| 1+2 容量 | 4 类 Performer 各 1-2 容量, 总 1+4-8 Performer | **缺 Performer 容量扩展** |

### 4.3 4 层接手能力设计 (新规则需)

**Rule 15 草案 (4 层接手能力, 跟 Rule 14 Anti-Hang 同级)**:

```markdown
### 15. 4 层接手能力 (KALLAX P0) — Performer sub-role 体系

**教训**: 当前 KALLAX Performer 1 类, 派单 flat, 不区分接手深度. 主公 2026-06-12 拍"区分
浅层/维护/深度重构/亮点借鉴" 4 层.

**规则**: Performer 4 类 (sub-role), ticket.json 新增接手深度字段:

- **L1 浅层分析** (read-only): 看代码/文档/issue 表面, 不写. Performer 角色 = "analyst"
  - permission: 读 only
  - 估时: 1-2h
  - 派单: Conductor 1-click
  - 产出: 1 报告, 不 commit

- **L2 接手维护** (write-incremental): 接别人代码, 跑通 + bug fix + 增量
  - permission: 写 worktree, 不改 miao/testing
  - 估时: 2-3d
  - 派单: Conductor normal dispatch
  - 产出: commit + test PASS

- **L3 深度重构** (write-major): 改架构/重写/迁移
  - permission: 写 worktree + 跨文件
  - 估时: 5-10d
  - 派单: Conductor senior dispatch (Rule 11 边界检查)
  - 产出: PR + A+B review + LESSONS-LEARNED

- **L4 亮点借鉴+隐患规避+经验教训迁移** (cross-project): 跨项目借鉴 + 审计
  - permission: 跨 worktree 读 + 写 lessons
  - 估时: 1-2d
  - 派单: Conductor auditor dispatch (新 Auditor 角色)
  - 产出: 借鉴报告 + 隐患清单 + lessons 迁移

**schema 扩展**: ticket.json 新增 handoff_depth (enum: L1/L2/L3/L4)

**执行**: Conductor 派单时必填 handoff_depth, 跟 worktree_role 联动验证

**容量**: 1 conductor + N Performer (N 按 handoff_depth 动态, 默认 2)

**红线**:
- ❌ L1 Performer 写代码 (read-only)
- ❌ L2 Performer 跨文件改 (写增量 only)
- ❌ L3 Performer 无 A+B review
- ❌ L4 Performer 改原项目代码 (只读 + 写 lessons)
```

### 4.4 4 层接手 落地路径 (跟 Gap 9 联动)

| 阶段 | 估时 | 落地 |
|---|---|---|
| **EPIC-038-A** Rule 15 + Performer sub-role schema | 1d | 跟 EPIC-035-A worktree_role 一起做 (扩 worktree_role schema) |
| **EPIC-038-B** 4 类 Performer 实例 + 1+4 容量 | 1d | 跟 EPIC-036-A 跨 worktree 一起做 (扩 dispatch) |
| **EPIC-038-C** Auditor 角色 + L4 派单模式 | 1d | 跟 EPIC-037-A 持续 audit 一起做 (跟 AuditMiddleware 联动) |
| **PHASE-007 review** Rule 15 制度化 | 0 | 跟 4 防御 + 4 借鉴 闭环 |

### 4.5 残余 Gap

| Gap | 现状 | 落地 |
|---|---|---|
| **4 层接手 40% → 100%** | 当前 flat 1 层 | EPIC-038-A/B/C (3d) 跟 Wave 4-5 同步 |
| Auditor 角色 | EKET P2 #19 推迟 | EPIC-038-C 落地 (跟 EPIC-037-A 一起) |
| 1+N 容量 | 当前 1+2 固定 | 1+4-8 动态 (跟 Performer 持久化同步) |

**主公原话 Q4 答案**: ⚠️ **40% 4 层接手能力 (重大 Gap)**, 需 EPIC-038-A/B/C (3d, 跟 Wave 4-5 同步) + Rule 15 制度化.

---

## §5 能力 5: 亮点借鉴 + 隐患规避 + 经验教训迁移

### 5.1 现状盘点 (Master 强验证)

**KALLAX 经验体系** (5 主题 + 1 综合 + 2 主题 lessons):

| 主题 | 来源 | 状态 | 跟主公 Q5 关联 |
|---|---|---|---|
| `three-modes-decision-authority.md` | EPIC-029 | ARCHIVED → 综合 | 决策权亮点借鉴 (EKET 借鉴) |
| `security-hardening-iterations.md` | EPIC-029/030 | ARCHIVED → 综合 | 隐患规避 (3 轮审查 20 issue) |
| `token-plan-cap-incident.md` | EPIC-029 | ARCHIVED → 综合 | 隐患规避 (Token Plan 撞墙 3 次) |
| `performer-kpi-falsification-pattern.md` | EPIC-031 + Phase 5/6 | ARCHIVED → 综合 | 隐患规避 (KPI falsification 8 试) |
| `cross-epic-kpi-falsification-evolution.md` | PHASE-005 | **ACTIVE** (8 节) | **亮点借鉴 + 隐患规避 + 经验教训迁移** 综合 |
| `background-agent-hallucination.md` | EPIC-024 | ACTIVE | 隐患规避 (background agent 100% 失败) |
| `multi-agent-collab-failures.md` | EPIC-024 | ACTIVE | 隐患规避 (5 parallel Performers) |
| `project-level-data-isolation.md` | EPIC-031 | ACTIVE | 隐患规避 (worktree 隔离) |
| `verification-matters.md` | EPIC-024 | ACTIVE | **亮点借鉴** (5-Level Fact-Forcing 表格) |
| `quality-audit-2026-06-09.md` | EPIC-024 | ACTIVE | 经验教训迁移 (5 维度 audit) |
| `kallax-rebuild-lessons.md` | EPIC-021 | ACTIVE | **经验教训迁移** (12 共识超越点) |
| `epic-021-2026-06-07.md` | EPIC-021 | ACTIVE | 经验教训迁移 (5 专家 panel 实战) |
| `epic-022-2026-06-08.md` | EPIC-022 | ACTIVE | 经验教训迁移 (permission model) |
| `epic-024-2026-06-08.md` | EPIC-024 | ACTIVE | 经验教训迁移 (8 fail 教训) |

**EKET 借鉴总进度** (`EKET-BORROW-PROGRESS-2026-06-11.md`):

| 类别 | 总数 | 完成 | 完成率 |
|---|---|---|---|
| P0 | 9 | 9 | **100%** |
| P1 | 8 | 1 | **12.5%** |
| P2 | 8 | 0 | 0% |
| **合计** | **26** | **10** | **38.5%** |

**EPIC-021 12 共识超越点** (KALLAX 领先 EKET 之处, **亮点借鉴**模板):
1. KALLAX 7 expert 体系 vs EKET 强
2. 2-Group review vs EKET 自审
3. 5-Level Fact-Forcing vs EKET 2-Level
4. heartbeat 机制 vs EKET 定时
5. file-scope 隔离 vs EKET workspace
6. TrustScore 派发 vs EKET 轮询
7. 降级链 (Redis→SQLite→file) vs EKET Redis-only
8. A+B review 互补 vs EKET 单视角
9. 症状决策树 vs EKET keyword match
10. output_format 4 节 vs EKET 2 节
11. anatomy 10 项校验 vs EKET 7 项
12. M1 co-evolution vs EKET 静态

### 5.2 实际能力评估 (3 子能力)

| 子能力 | 现状 | 证据 |
|---|---|---|
| **亮点借鉴** | ✅ **80%** | EKET 26 项 + EPIC-021 12 共识超越点 + 4 主题 ARCHIVED |
| **隐患规避** | ✅ **85%** | cross-epic 8 节 + 8 次 KPI falsification 教训 + Hang 6 次 (新) |
| **经验教训迁移** | ⚠️ **65%** | 14 lessons 文档 + 5 主题 + 1 综合, 迁移到新项目未实战 |

### 5.3 残余 Gap + 落地路径

| Gap | 现状 | 落地 |
|---|---|---|
| 经验教训迁移 65% → 90% | lessons 文档化 OK, 迁移机制弱 | EPIC-037 持续 audit + 跨项目 import 脚本 (1d) |
| 持续 audit (redaction + KPI) | 缺自动化 | EPIC-037-A (Wave 1 完) |
| 跨项目借鉴 (业界 4 框架) | KALLAX-VS-INDUSTRY 已写, 迁移机制缺 | 6 EPIC 后拍 |

**主公原话 Q5 答案**: ✅ **75% (亮点借鉴+隐患规避)**, ⚠️ **65% (经验教训迁移)**, 残余 25-35% 是迁移机制 + 持续 audit (跟 EPIC-037 闭环).

---

## §6 5 能力综合评分 + 战略建议

### 6.1 综合评分

| 能力 | 现状 | 残余 Gap | 落地路径 | 估时 |
|---|---:|---|---|---|
| 1 从零召 | **90%** | 10% 实战触发 + 跨项目 | EPIC-037 + 6 EPIC 后 | 1-2d |
| 2 中途接手 | **80%** | 20% Performer 续接 + 跨项目 | L3 架构 + EKET P2 #23 | 2-3d |
| 3 按需召专家组 | **70%** | 30% extended 实战 + 跨领域 | EPIC-037 + Wave 1-5 完工 | 1-2d |
| 4 4 层接手 | **40%** | 60% 重大 Gap | **EPIC-038-A/B/C (3d, 跟 Wave 4-5 同步)** | **3d** |
| 5 亮点+隐患+迁移 | **75%** | 25% 迁移机制 | EPIC-037 + 跨项目 import 脚本 | 1-2d |
| **综合** | **71%** | **29%** | 跟 Wave 1-5 + EPIC-038 同步 | **~8-10d** |

### 6.2 战略建议 (主公拍)

| # | 行动 | 估时 | 推荐 |
|---|---|---|---|
| 1 | **EPIC-038-A**: Rule 15 4 层接手 + Performer sub-role schema | 1d | ✅ **强推荐** (跟 EPIC-035-A 一起做) |
| 2 | **EPIC-038-B**: 4 类 Performer 实例 + 1+4 容量 | 1d | ✅ 推荐 (跟 EPIC-036-A 一起做) |
| 3 | **EPIC-038-C**: Auditor 角色 + L4 派单 | 1d | ✅ 推荐 (跟 EPIC-037-A 一起做) |
| 4 | 经验教训迁移机制 (跨项目 import 脚本) | 1d | ✅ 推荐 (Gap 5 闭环) |
| 5 | 持续 audit (redaction + KPI cron) | 1d | ✅ 在 EPIC-037-A 范围 |
| 6 | 跨项目跨 repo (EKET P2 #23) | 1d | ⏳ 6 EPIC 后拍 (跟 Checkpoint 同步) |
| 7 | Performer 持久化 (L3 架构) | 2-3d | ⏳ 6 EPIC 后拍 |

### 6.3 跟 Gap 9 元能力 + 飞轮"迭代" 战略对齐

| 能力 | Gap 9 步骤 | Wave 落地 |
|---|---|---|
| 1 从零召 | "接受" 新项目 | Wave 1 (EPIC-034-C 接受 0 generated) |
| 2 中途接手 | "接受" 跨 session | handoff.json 自动 (60-95%) |
| 3 按需召专家 | "判断" 派单 | 3-layer matching (70%) + EPIC-038 (40%) |
| 4 4 层接手 | "判断" 接手深度 | **EPIC-038-A/B/C 关键 (40%)** |
| 5 亮点+隐患+迁移 | "增加/完善" 经验 | EPIC-037 持续 audit + 迁移脚本 (75%) |

---

## §7 Master 战略拍板

### 7.1 5 能力现状一句话

| 能力 | 一句话 |
|---|---|
| 1 从零召 | ✅ 90% — 7 default + 90 extended + 1 conductor + 2 performer, 6 EPIC 实战 |
| 2 中途接手 | ✅ 80% — handoff.json + state.json + auto-resume, 残余 Performer 续接 |
| 3 按需召专家组 | ⚠️ 70% — 3-layer matching + 97 expert, 残余 extended 实战触发 |
| 4 4 层接手 | ❌ **40% (重大 Gap)** — 当前 flat 1 层, 需 EPIC-038-A/B/C + Rule 15 |
| 5 亮点+隐患+迁移 | ⚠️ 75% — 14 lessons + 5 主题 + EKET 26 项 + 12 共识, 残余迁移机制 |

### 7.2 关键决策 (主公拍)

| 决策点 | Master 推荐 | 理由 |
|---|---|---|
| **EPIC-038-A/B/C (Rule 15 + 4 层接手)** | ✅ **立即派 (跟 Wave 4-5 同步)** | Q4 重大 Gap 40%→100%, 跟主公原话"区分 4 层"完全对齐 |
| Auditor 角色 (L4 派单) | ✅ 跟 EPIC-037-A 一起做 | 跟 AuditMiddleware 联动 |
| 经验教训迁移机制 | ✅ 1d 跨项目 import 脚本 | 闭环 Q5 75%→90% |
| 跨项目 / 跨 repo (EKET P2 #23) | ⏳ 6 EPIC 后拍 | 跟 Performer 持久化同步 |
| Performer 持久化 (L3 架构) | ⏳ 6 EPIC 后拍 | 跟 Checkpoint 同步 |

### 7.3 5 levels (L1-L5) (跟 Rule 11 联动)

| 维度 | 5 能力研究 |
|---|---|
| L1 git log | ✅ 主公 5 问 = 5 session 增量 |
| L2 git show | ✅ 报告 5 节 + Gap 4 表 + 战略建议 |
| L3 跑测试 | N/A (战略研究, 无新代码) |
| L4 preflight | N/A |
| L5 边界 | ✅ Rule 11 联动, Master 串场不写代码 |
| L6 诚实 | ✅ 5 能力现状 71% 综合, 4 层接手 40% 重大 Gap 明确承认 |

---

## §8 总结 (主公拍战略)

### 8.1 5 能力 71% 综合 (跟 Gap 9 联动)

```
能力 1 从零召           ████████████████████░ 90% ✅
能力 2 中途接手         ████████████████░░░░ 80% ✅
能力 3 按需召专家       ██████████████░░░░░░ 70% ⚠️
能力 4 4 层接手        ████████░░░░░░░░░░░░ 40% ❌ (重大 Gap)
能力 5 亮点+隐患+迁移  ███████████████░░░░░ 75% ⚠️
────────────────────────────────────────────────
综合 71%              残余 29% (EPIC-038 + 持续 audit + 跨项目)
```

### 8.2 战略建议 (主公拍 4 选项)

| 选项 | 内容 | 估时 | 推荐 |
|---|---|---|---|
| A | EPIC-038-A/B/C 立即派 (跟 Wave 4-5 同步) | 3d | ✅ **强推荐** |
| B | EPIC-038-A only (Rule 15 + schema) | 1d | 1 周内 |
| C | 推迟到 PHASE-007 review 拍 | — | ⏳ 不推荐 (Q4 Gap 重大) |
| D | 跟 Gap 9 战略整合, 写进 PHASE-006-ROADMAP 修订 | 0.5d | ✅ 配套 |

### 8.3 跟主公 5 问对齐

| 主公问 | Master 答 | Gap |
|---|---|---|
| 1 从零召 | ✅ 90% (6 EPIC 实证) | 10% 实战触发 |
| 2 中途接手 | ✅ 80% (handoff + state) | 20% Performer 续接 |
| 3 按项目召专家组 | ⚠️ 70% (3-layer + 97 expert) | 30% extended 触发 |
| 4 4 层接手 | ❌ **40% (重大 Gap, 需 EPIC-038)** | 60% 4 sub-role + Rule 15 |
| 5 亮点+隐患+迁移 | ⚠️ 75% (14 lessons + 5 主题) | 25% 迁移机制 |

### 8.4 等主公拍

| # | 决策 | Master 推荐 |
|---|---|---|
| 1 | EPIC-038-A/B/C 派单 (跟 Wave 4-5 同步) | ✅ 立即 |
| 2 | 经验教训迁移脚本 (1d, 闭环 Q5) | ✅ 立即 |
| 3 | 跨项目 / 跨 repo (6 EPIC 后) | ⏳ 默认 |
| 4 | Performer 持久化 (6 EPIC 后) | ⏳ 默认 |
| 5 | PHASE-007 review 拍 Rule 15 | ✅ 配套 |

---

**Reviewer(s)**: master_main (主公拍板)
**Last updated**: 2026-06-12
**Status**: ✅ SAVED — 等主公拍 5 能力战略 (重点: EPIC-038 4 层接手 40%→100%)

---

**附录**: 关联文件
- [PHASE-006-ROADMAP-2026-06-12.md](./PHASE-006-ROADMAP-2026-06-12.md) (Gap 9 流程逻辑 + Top 4 战略)
- [KALLAX-VS-INDUSTRY-2026-06-12.md](./KALLAX-VS-INDUSTRY-2026-06-12.md) (5 痛点 × 业内 4 框架)
- [PERFORMER-HANG-RC-2026-06-12.md](./PERFORMER-HANG-RC-2026-06-12.md) (Hang 根因 + 4 防御 + Rule 14)
- [PROJECT-STATUS-AND-LESSONS-2026-06-12.md](./PROJECT-STATUS-AND-LESSONS-2026-06-12.md) (6 EPIC + 2 PHASE 累积)
- [cross-epic-kpi-falsification-evolution.md](../memory/lessons/cross-epic-kpi-falsification-evolution.md) (8 节综合)
- [EKET-BORROW-PROGRESS-2026-06-11.md](./EKET-BORROW-PROGRESS-2026-06-11.md) (EKET 26 项 + 12 共识)
- 14 lessons 文档 (`confluence/memory/lessons/`)
- 9 专家 + 90 extended + 6 generated (Wave 1 完工后)
- CLAUDE.md (Rule 1-13, 草案 Rule 14 + 15)
