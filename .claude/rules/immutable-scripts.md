---
paths:
  - CLAUDE.md
  - scripts/verify/*.sh
  - scripts/hooks/*.sh
---

# Immutable Scripts 数字对齐 (EPIC-223, 主公 2026-08-08 拍板)

> **Path-scoped rule**: 只在 CLAUDE.md 或 verify/hooks 脚本修改时加载 (跟 EPIC-159 + EPIC-209 lazy load 联合).

## 1. 为什么需要这份文档

CLAUDE.md §5 历史上出现过 **4 个互不一致的数字**:

| 位置 | 数字 | 判定 |
|------|------|------|
| §5 标题 "4 不可更改 法律" | 4 | ❌ 历史遗留 (从 4 个时代起未更新) |
| §5 P0-7 注 "5 个 immutable scripts" | 5 | ✅ 正确 |
| §5 表格行数 | 7 | ⚠️ 混装了 5 immutable + 2 smoke 辅助 |
| SKILL.md AUTO-PERMS "5 verify + 1 hook = 6" | 6 | ❌ verify 实际是 4 个, 不是 5 个 |

**根因**: 表格把 immutable (fail-closed, 改动需主公亲自) 跟辅助脚本 (可迭代) 混在一起, 导致 "数几行" 得出的数字跟 "真正 immutable 数" 不一致.

## 2. 统一口径 (EPIC-223 后)

### 5 immutable (fail-closed, 改动需主公亲自批准)

| # | Script | Path | 退出码契约 |
|---|--------|------|-----------|
| 1 | `check-decorative-claim.sh` | `scripts/verify/` | 0=PASS, 1=FAIL |
| 2 | `check-narrative.sh` | `scripts/verify/` | 0=PASS, 1=FAIL |
| 3 | `check-fail-closed.sh` | `scripts/verify/` | 0=PASS, 1=FAIL |
| 4 | `check-self-heal.sh` | `scripts/verify/` | 0=PASS, 1=FAIL |
| 5 | `check-claim-evidence.sh` | `scripts/hooks/` | 0=PASS, 1=FAIL (仅扫 staged) |

**4 verify + 1 hook = 5**. 禁止 print FAIL + exit 0 (fail-open).

### 2 辅助 (非 immutable, 可迭代)

| # | Script | Path | 职责 |
|---|--------|------|------|
| 1 | `check-smoke-retention.sh` | `scripts/` | EPIC-174, smoke >=500 行检测 |
| 2 | `smoke-size-report.sh` | `scripts/audit/` | EPIC-174, smoke 状态报告 |

### 不算 immutable 的独立 sentinel

| Script | 为什么不算 |
|--------|-----------|
| `scan-dead-code.sh` | 退出码三态 (0/1/2=BLOCKED-env), 跟 immutable 二态契约不同 (P0-7 治理) |

### 待接入 (落地但未接 hook/CI, 不计入数字)

| Script | EPIC | 状态 |
|--------|------|------|
| `snapshot-claude-md.sh` | EPIC-219 | 已 merge, `.githooks`/`.github` 0 引用 |
| `check-disclaimer.sh` | EPIC-220 | 已 merge, `.githooks`/`.github` 0 引用 |
| `check-ticket-schema.sh` | EPIC-223 | 本 EPIC 新增, 待接入 |

**接入后数字变化**: 5 → 8 immutable. **接入前不登记** — 声称存在但不运行 = 形式化治理, 正是 CLAUDE.md §2 禁止的假 PASS 同型症状.

## 3. 改数字的强制流程

任何 immutable 数量变化 (5 → N) 必须**同时**改 3 处, 缺一处即数字漂移:

1. `CLAUDE.md` §5 标题 + 表格分区
2. `.claude/skills/kallax/SKILL.md` 9 类破坏性操作 #8
3. 本文件 §2 表格

**验证**: `git grep -n "immutable" CLAUDE.md .claude/skills/kallax/SKILL.md .claude/rules/immutable-scripts.md` 三处数字必须一致.

## 4. 联动

- Rule 5 (DRY): 数字单一真相来源在本文件, CLAUDE.md + SKILL.md 引用
- EPIC-069-D (check-claim-evidence 源头)
- EPIC-131/132 (strict tsconfig + gate-paint 防御)
- EPIC-174 (smoke retention 2 辅助脚本)
- EPIC-219 / EPIC-220 / EPIC-223 (待接入 3 脚本)
- P0-7 治理 (v3.32.1 路径澄清 + scan-dead-code 三态)