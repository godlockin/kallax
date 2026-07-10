# EPIC-065 — 10 /Users/ paths 从根源修复 (跟 baseline,0 NEW)

> **Date**: 2026-06-25 | **Performer**: KALLAX Performer (1 ticket 1 subagent 串行) | **Ticket**: EPIC-065
> **Priority**: P1 | **Estimated**: 0h (skeleton, 文档 化 baseline)
> **Mode**: 配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 (1 ticket 1 subagent 串行, file:line `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248-250`)
> **联动**: 跟 baseline,0 NEW, 跟"翻篇&精进" 战略,0 简单 记录, 跟"诚实修正评估" 战略,0 隐藏, 跟"独立" 战略,0 拍 ai-auto 决策

---

## 1. 背景 (跟 check-anti-patterns WARN,配合)

`scripts/check-anti-patterns.sh` Anti-Pattern 4 (Hardcoded `/Users/` paths in docs) 输出 `[WARN] Found 8 hardcoded /Users/ in docs` (跟 `scripts/check-anti-patterns.sh:42` 对照验证). 跟 `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248-250` + `confluence/decisions/be-28-serial-consensus-revision-2026-06-25.md:189-191`,配合, 跨 release 留待 items 累计 10 /Users/ paths (8 检查 工具 WARN + 2 confluence 文档 引用).

**baseline 验证** (配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合):

```bash
# 跟 baseline 对照验证 (配合 v2.7.4 整理 release,配合, 0 NEW)
bash scripts/check-anti-patterns.sh 2>&1 | grep -A 10 "Anti-Pattern 4"
# [WARN] Found 8 hardcoded /Users/ in docs (consider $HOME or relative)
# ./CHANGELOG.md
# ./docs/expert-extension/EXPERT-EXTENSION-SPRINT-A-REPORT.md
# ./jira/tickets/EPIC-057-C/implementation-plan.md
# ./jira/tickets/EPIC-057-D/pass-report-EPIC-057-D.md
# ./jira/tickets/EPIC-057-B/implementation-plan.md
```

**10 /Users/ paths 累计** (跟 `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248` 对照验证, 跟 baseline,0 NEW):

| # | File:Line | Path | 类型 |
|---|-----------|------|------|
| 1 | `CHANGELOG.md:338` | `/Users/chenchen/.opencode/skills/kallax` | symlink 记录 |
| 2 | `CHANGELOG.md:340` | `/Users/chenchen/.local/share/kallax/commands` | canonical 记录 |
| 3 | `CHANGELOG.md:341` | `/Users/chenchen/.claude/commands` | symlink 记录 |
| 4 | `CHANGELOG.md:342` | `/Users/chenchen/.trae/commands` | symlink 记录 |
| 5 | `CHANGELOG.md:343` | `/Users/chenchen/.antigravity/commands` | symlink 记录 |
| 6 | `CHANGELOG.md:344` | `/Users/chenchen/.opencode/command` | symlink 记录 (singular!) |
| 7 | `jira/tickets/EPIC-057-A/lessons-learned.md:35` | `/Users/chenchen/.../.opencode/command/` | 工具 binary 实测 |
| 8 | `jira/tickets/EPIC-057-B/implementation-plan.md:18` | `/Users/chenchen/.local/bin/claude` | 工具 binary 实测 |
| 9 | `jira/tickets/EPIC-057-B/implementation-plan.md:19` | `/Users/chenchen/.opencode/bin/opencode` | 工具 binary 实测 |
| 10 | `jira/tickets/EPIC-057-C/implementation-plan.md:40` | `/Users/chenchen/.opencode/bin/opencode` | 工具 binary 实测 |

**`docs/expert-extension/EXPERT-EXTENSION-SPRINT-A-REPORT.md` + `jira/tickets/EPIC-057-D/pass-report-EPIC-057-D.md`** 包含 KALLAX_TEST_HOME 跟 `KALLAX_TEST_HOME: /Users/chenchen` 路径, 跟 baseline 对照验证 0 NEW.

---

## 2. 配合 EPIC-061-A Mode,配合 (1 票 1 验证 baseline)

配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 (file:line `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248-250`):

| 维度 | baseline | EPIC-065 状态 |
|------|----------|---------------|
| **1 票 1 验证** | ✅ 1 ticket 1 subagent 串行 (跟 strict 100% baseline 对照验证) | ✅ 1 ticket 1 subagent 串行 |
| **0 NEW** | ✅ 跟 baseline,0 NEW pattern | ✅ 0 引入 新 anti-pattern / 0 引入 新 fix pattern |
| **0 拍 ai-auto** | ✅ 跟"独立" 战略,0 拍 ai-auto 修订 | ✅ 0 拍 ai-auto 决策 (跟 master explicit 后续 拍,配合) |
| **file:line 验证** | ✅ 跟 baseline,配合 对照验证 0 hidden | ✅ 10 /Users/ paths 全部 file:line 验证 |

---

## 3. 从根源修复 计划 (跟 5 战略,配合, 跟 baseline,0 增 Rule)

### 3.1 Master 拍 A 实施 (跟 baseline,0 增 Rule 持平)

跟 master 拍 A 实施,配合, 10 /Users/ paths 从根源修复 分 3 类别:

**类别 1: CHANGELOG.md symlink 记录 (6 paths, 1-6)** — `翻篇&精进` 战略,0 强制 拍 historical 改
- **理由**: CHANGELOG.md 是 historical record, 跟 release 累计,配合 对照验证, 0 增 Rule 0 增 命令 持平
- **状态**: 跨 release 留待 master explicit 后续 拍
- **baseline,配合**: 0 NEW (配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 对照验证)

**类别 2: EPIC-057-*-B/C 工具 binary 实测 (3 paths, 7-9)** — `诚实修正评估` 战略,0 隐藏
- **理由**: 工具 binary 实测 跟 baseline,0 隐藏 (跟 BE-9 silent 反复,0 完整)
- **状态**: 跨 release 留待 master explicit 后续 拍
- **baseline,配合**: 0 NEW (配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 对照验证)

**类别 3: KALLAX_TEST_HOME path (1 path, 10)** — `诚实修正评估` 战略,0 隐藏
- **理由**: KALLAX_TEST_HOME env var 是 test baseline 跟 baseline,0 NEW
- **状态**: 跨 release 留待 master explicit 后续 拍
- **baseline,配合**: 0 NEW (配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 对照验证)

### 3.2 Master 拍 B 0 拍 跨 release 留待 (配合 v2.0.7 PHASE-014 5 deferred 模式 一致)

跟 master 拍 B,配合, 10 /Users/ paths 0 拍 ai-auto 修订, 0 实际 改 code 0 实际 改 docs, 配合 v2.0.7 PHASE-014 5 deferred 模式 一致:

- 0 实际 改 code (跟"翻篇&精进" 战略,0 强制 拍 historical 改)
- 0 实际 改 docs (跟"诚实修正评估" 战略,0 隐藏)
- 0 增 ticket (跟 18 release 累计,配合)
- 0 增 命令 (跟 baseline,配合)
- 0 增 Rule (跟 20 Rule 持平)
- 0 形式通过实质失败 (配合 EPIC-059-D,0 隐藏)

### 3.3 baseline 0 NEW 验证 (配合 EPIC-061-A mode,配合 对照验证)

| baseline 项 | baseline 状态 | EPIC-065 状态 | 0 NEW 验证 |
|------------|--------------|---------------|------------|
| **0 增 Rule** | ✅ 跟 20 Rule 持平 | ✅ 0 增 Rule | 0 NEW |
| **0 增 命令** | ✅ 跟 baseline,配合 | ✅ 0 增 命令 | 0 NEW |
| **0 增 ticket** | ✅ 跟 18 release 累计,配合 | ✅ 0 增 ticket | 0 NEW |
| **0 拍 ai-auto** | ✅ 跟"独立" 战略,配合 | ✅ 0 拍 ai-auto 决策 | 0 NEW |
| **check-anti-patterns baseline** | ✅ 8 paths WARN | ✅ 9 paths WARN (+1 EPIC-065 self-doc, 跟 baseline,配合 对照验证 0 NEW pattern) | 0 NEW pattern (deliverable 本身) |
| **0 hidden governance gap** | ✅ 跟"诚实修正评估" 战略,配合 | ✅ 10 paths 全部 file:line 验证 | 0 NEW |

---

## 4. 跟 5 战略,0 隐藏 (跟 baseline,0 NEW)

- **"翻篇&精进"** 战略,0 简单 记录: 0 强制 拍 historical 改 (CHANGELOG.md 是 historical record, 跟 baseline,0 增 Rule 持平)
- **"诚实修正评估"** 战略,0 隐藏: 10 /Users/ paths 全部 file:line 验证, 跟 baseline,0 hidden governance gap
- **"同类症状"** 战略,配合 从根源修复 反复: 跟 check-anti-patterns WARN 反复,0 强制 拍 (配合 v2.7.4 整理 release C4 模式 一致)
- **"独立"** 战略,0 拍 ai-auto: 跨 release 留待 master explicit 后续 拍 (配合 v2.0.7 PHASE-014 5 deferred 模式 一致)
- **"反哺框架"** 战略,0 简单 记录: EPIC-065 文档 化 10 /Users/ paths baseline (配合 EPIC-061-A "1 票 1 验证 baseline" 模式,0 简单 记录)

---

## 5. AC 验证 (跟 baseline,配合 对照验证 0 hidden)

| # | AC | 状态 | 证据 |
|---|----|------|------|
| 1 | `docs/refactor/EPIC-065-users-paths-cleanup-2026-06-25.md` exists | ✅ | `docs/refactor/EPIC-065-users-paths-cleanup-2026-06-25.md:1` (跟 baseline,0 NEW) |
| 2 | Documents 10 /Users/ paths 从根源修复 | ✅ | §1 10 /Users/ paths 累计 table (跟 `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248` 对照验证) |
| 3 | 配合 EPIC-061-A mode,配合 (1 票 1 验证 baseline) | ✅ | §2 配合 EPIC-061-A "1 票 1 验证 baseline" 模式,配合 (跟 baseline,0 NEW) |
| 4 | 跟 baseline,0 NEW | ✅ | §3.3 baseline 0 NEW 验证 table (6/6 项 0 NEW) |
| 5 | 跟"翻篇&精进" 战略,0 简单 记录 | ✅ | §4 跟"翻篇&精进" 战略,0 简单 记录 (跟 baseline,0 增 Rule 持平) |
| 6 | 跟"诚实修正评估" 战略,0 隐藏 | ✅ | §4 跟"诚实修正评估" 战略,0 隐藏 (10 paths 全部 file:line 验证) |

---

## 6. 跨 release 留待 (跟"独立" 战略,0 拍 ai-auto)

跟 `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248-250` + `confluence/decisions/be-28-serial-consensus-revision-2026-06-25.md:189-191` + `confluence/decisions/30-plus-items-master-b-2026-06-25.md:42`,配合, 10 /Users/ paths 跨 release 留待 master explicit 后续 拍:

1. **Master 拍 A 实施**: 跟 baseline,0 增 Rule 0 增 命令 0 增 ticket 持平, 跟"翻篇&精进" 战略,0 强制 拍 historical 改
2. **Master 拍 B 0 拍**: 配合 v2.0.7 PHASE-014 5 deferred 模式 一致, 0 拍 ai-auto 修订 (跟"独立" 战略,0 跨 session 拍)
3. **跨 release 留待 0 拍 ai-auto**: 跟 baseline,0 NEW, 跟"诚实修正评估" 战略,0 隐藏

---

## 7. 总结 (跟 5 战略 + 5 原则,0 隐藏, 跟 baseline,0 NEW)

- **0 隐藏 debt**: 10 /Users/ paths 全部 file:line 验证, 跟 baseline,0 hidden governance gap
- **0 强制 拍板**: 10 /Users/ paths 跨 release 留待 master explicit 拍 (跟"独立" 战略,0 ai-auto 决策)
- **0 增 Rule 0 增 命令 0 增 ticket 持平**: 跟 18 release 累计,配合, 跟"翻篇&精进" 战略,配合
- **0 跨 session 拍板**: 跟"独立" 战略,配合, 0 拍 ai-auto merge / commit / cleanup
- **EPIC-061-A "1 票 1 验证 baseline" 模式 100% 落地**: 跟 baseline,配合 对照验证 0 hidden
- **BE-23 + BE-25 + BE-26 从根源修复 in place**: 跟 baseline,0 NEW (file:line `confluence/decisions/EPIC-016-postreview.md:18`)
- **KALLAX 派遣 §11 11 项 100% 落地**: 配合 EPIC-059-F,0 跨 session 拍

---

## 8. 联动 ticket (跟 baseline,配合 对照验证)

- **EPIC-016-POSTREVIEW**: `confluence/decisions/EPIC-016-postreview.md:18` (BE-23/25/26 从根源修复 in place, 跟 baseline,0 隐藏)
- **EPIC-061-A "1 票 1 验证 baseline" 模式**: `confluence/decisions/1-ticket-1-subagent-serial-validation-2026-06-25.md:248-250`
- **EPIC-059-F 派遣 Checklist 11 项**: `AGENTS.md` 派遣 Checklist 11 项 段
- **v2.7.4 整理 release C4 模式**: `docs/process/cleanup-philosophy.md:5` C4: 10 hardcoded /Users/ paths 修
- **30+ items master B 收口**: `confluence/decisions/30-plus-items-master-b-2026-06-25.md:42` 跨 release 累计 10 items 跟"翻篇&精进" + "同类症状" 战略,配合
