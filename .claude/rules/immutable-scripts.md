---
paths:
  - CLAUDE.md
  - scripts/verify/*.sh
  - scripts/hooks/*.sh
---

# Immutable Scripts 数字对齐 (EPIC-223 + EPIC-224, 主公 2026-08-08 拍板)

> **Path-scoped rule**: 只在 CLAUDE.md 或 verify/hooks 脚本修改时加载 (跟 EPIC-159 + EPIC-209 lazy load 联合).

## 0. EPIC-224 关键发现: hook 体系曾整体失效

`git config core.hooksPath` 曾指向 `/tmp/kallax-fix-epic131/.githooks` — **已删除的临时目录**.

后果: **所有 pre-commit hook 从未运行**. 5 immutable scripts 存在于 repo 但一个都没触发过. 这不是"3 个死文件"问题, 是整套 gate 静默失效.

**防复发** (EPIC-224):
1. `scripts/hooks/install.sh` 检测并 unset 坏 `core.hooksPath`
2. `install.sh --verify` 只检查不改, exit 1 = 有问题
3. CI `hook-health` job 每次 PR 验证 (含 "installer 能否检出坏 hooksPath" 的负向测试)

**教训**: 脚本存在 ≠ 脚本生效. 治理 gate 必须有"验证 gate 本身在运行"的元检查.

## 1. 为什么需要这份文档

CLAUDE.md §5 历史上出现过 **4 个互不一致的数字**:

| 位置 | 数字 | 判定 |
|------|------|------|
| §5 标题 "4 不可更改 法律" | 4 | ❌ 历史遗留 (从 4 个时代起未更新) |
| §5 P0-7 注 "5 个 immutable scripts" | 5 | ✅ 当时正确 |
| §5 表格行数 | 7 | ⚠️ 混装了 5 immutable + 2 smoke 辅助 |
| SKILL.md AUTO-PERMS "5 verify + 1 hook = 6" | 6 | ❌ verify 实际是 4 个, 不是 5 个 |

**根因**: 表格把 immutable (fail-closed, 改动需主公亲自) 跟辅助脚本 (可迭代) 混在一起, 导致 "数几行" 得出的数字跟 "真正 immutable 数" 不一致.

## 2. 统一口径 (EPIC-280 后: 10 immutable)

### 10 immutable (fail-closed, 改动需主公亲自批准, 全部已接入 hook)

| # | Script | Canonical Path (EPIC-277-E) | hook 接入点 | EPIC |
|---|--------|------|------------|------|
| 1 | `check-decorative-claim.sh` | `scripts/hooks/check-decorative-claim.sh` | pre-commit (4-law loop) | EPIC-110 |
| 2 | `check-narrative.sh` | `scripts/hooks/check-narrative.sh` | pre-commit (4-law loop) | EPIC-110 |
| 3 | `check-fail-closed.sh` | `scripts/hooks/check-fail-closed.sh` | pre-commit (4-law loop) | EPIC-110 |
| 4 | `check-self-heal.sh` | `scripts/hooks/check-self-heal.sh` | pre-commit (4-law loop) | EPIC-110 |
| 5 | `check-claim-evidence.sh` | `scripts/hooks/check-claim-evidence.sh` | pre-commit (staged only) | EPIC-069-D |
| 6 | `check-disclaimer.sh` | `scripts/hooks/check-disclaimer.sh` | pre-commit (staged .md) | EPIC-220 → 224 |
| 7 | `snapshot-claude-md.sh` | `scripts/hooks/snapshot-claude-md.sh` | pre-commit (advisory, CLAUDE.md/rules) | EPIC-219 → 224 |
| 8 | `check-ticket-schema.sh` | `scripts/hooks/check-ticket-schema.sh` | pre-commit (staged ticket.json) | EPIC-223 → 224 |
| 9 | `check-jargon.sh` | `scripts/hooks/check-jargon.sh` | pre-commit (staged .md/.sh/.ts/.rs, 黑名单扫) | EPIC-225 |
| 10 | `verify-agent-note-format.sh` | `scripts/hooks/verify-agent-note-format.sh` | pre-commit (staged .md, Agent Note schema) | EPIC-280 |

**EPIC-280 admission (主公 2026-08-21 拍板 DSH Path A)**: 从 9 → 10. 验 staged .md 满足 Agent Note schema (path 闭集 / header 三行 / Status 闭集 / class 6 闭集 / ## Problem 段). 脚本最初放 `scripts/verify/` (沿用 check-jargon 命名), canonical path 走 EPIC-277-E 迁移到 `scripts/hooks/` (待 EPIC-280-PR 落地后做迁移, 跟 EPIC-225 同型).

**EPIC-286 单脚本统一 (主公 2026-08-22 拍板)**: 曾有 `scripts/verify/check-jargon.sh` (213 行) 跟 `scripts/hooks/check-jargon.sh` (179 行) 两份同名脚本行为分叉 — verify 版实现了 2 个豁免但不被任何 hook 调用, hooks 版被 pre-commit 调用但缺豁免 (`is_historical_file()` 是 dead code)。后果: blacklist `replace` 字段承诺"附命令引用即可写 X/Y PASS"、`_scope` 字段 + 主公 2026-08-11 拍板承诺"历史内容不追溯", 两个承诺都没兑现 → 贴 raw test output 撞 gate, 改老文档撞 gate → HOOK_BYPASS 用量常态化。
- 处理: 删 verify 版, 把 2 个豁免移植进 canonical (hooks 版)
- 豁免 1 (X/Y PASS): 命中 `[0-9]+/[0-9]+ (PASS|passed)` 时查 ±10 行窗口内是否有命令证据 (`` `bash|npx|cargo|npm|git|python3 ``/`$ cmd`/`exit=N`/`RC=N`), 有则豁免。裸数字仍 fail (v3.8.0 假 PASS 防线保留)
- 豁免 2 (历史文件, 逐行): 标记为历史文件（以 `jira/tickets/.jargon-baseline.json` 的 EPIC-225 `baseline_commit` 为界）后, **逐行**用 `git blame` 查 last_change_commit, 仅豁免 baseline 之前就存在的行。**修复 B 修 B5 反馈** (原"整文件按 first_commit 豁免"是 fail-open — 改老文件时新增违规词也全过)
- 元字段豁免 (META_EXEMPT): 不用 substring 通配 (B 修 B3 反馈 — 'jargon' 通配会误豁免任何含 'jargon' 字样的未来文件), 改精确 basename (`.jargon-blacklist.json` / `.jargon-baseline.json`) + 显式 path glob (`tests/integration/check-jargon-*` / `epic-225-jargon-*` / `epic-250-jargon-*` / `scripts/hooks/check-jargon.sh` / `confluence/decisions/EPIC-225*` / `jira/tickets/.jargon-*`)
- 例外范围: 仅 X/Y PASS 有窗口豁免, 装饰词 (`生产级`/`100%`/`彻底` 等) 无例外
- 验证: `bash tests/integration/check-jargon-exemption.test.sh` 应通过（含裸数字仍 fail / 窗口外不豁免 / 装饰词无例外反向 case）

**退出码契约**: 0=PASS, 1=FAIL. 禁止 print FAIL + exit 0 (fail-open).
**例外**: `check-ticket-schema.sh` 有 exit 3 = ARCHIVED_SKIP (跟 EPIC-204 `DOCS_ONLY_SKIP` 同型, 表示"不适用"而非 PASS/FAIL). pre-commit 只拦 exit 1.
**#7 是 advisory**: `snapshot-claude-md.sh` 在 pre-commit 只提醒不阻塞 (改治理文件时提示打 snapshot), 不阻断 commit.

**EPIC-277-E 路径迁移**: 4 个原 verify/ 脚本 (check-decorative-claim / check-narrative / check-fail-closed / check-self-heal) 已 copy 到 scripts/hooks/ 作 canonical location.
- pre-commit 4-law loop 优先读 scripts/hooks/, fall back 到 scripts/verify/ (向后兼容).
- scripts/verify/ 副本保留 (audit 链完整 + backward-compat).
- install --verify 10/10 PASS (跟 CLAUDE.md §5 数字对齐).

### 2 辅助 (非 immutable, 可迭代)

| # | Script | Path | 职责 |
|---|--------|------|------|
| 1 | `check-smoke-retention.sh` | `scripts/` | EPIC-174, smoke >=500 行检测 |
| 2 | `smoke-size-report.sh` | `scripts/audit/` | EPIC-174, smoke 状态报告 |

### 不算 immutable 的独立 sentinel

| Script | 为什么不算 |
|--------|-----------|
| `scan-dead-code.sh` | 退出码三态 (0/1/2=BLOCKED-env), 跟 immutable 二态契约不同 (P0-7 治理) |
| `check-doc-budgets.sh` | EPIC-279 (DSH Path C 借鉴), 跟 `check-smoke-retention.sh` 同级辅助, 改动只需 PR review 不需主公亲自 |

### EPIC-286 check-jargon semantic contract

Canonical `scripts/hooks/check-jargon.sh` owns both exemptions; `scripts/verify/check-jargon.sh` must not become a second behavior source:

- X/Y `PASS` is exempt only when a command/raw-exit reference appears within ±10 lines (`bash`, `npx`, `cargo`, `npm`, `git`, `python3`, `$ command`, `exit=N`, or `RC=N`). Bare numeric PASS remains blocked.
- Baseline exemption is line-level: use `git blame` against baseline commit. Existing pre-baseline lines may be exempt; newly added violating lines in an old file are not.
- Metadata exemptions use exact basenames and explicit paths only. Never exempt arbitrary files because their name contains `jargon`.
- Decorative claims remain blocked even when nearby command evidence exists.

Validation: `bash tests/integration/check-jargon-exemption.test.sh` covers positive and negative cases, including out-of-window evidence and modified historical files.



| 检查 | 来源 |
|------|------|
| DCO `Signed-off-by` trailer 必填 | `.github/dco.yml` 1:1 |
| Conventional Commits type | `commitlint.config.js` type-enum 1:1 |
| header ≤ 100 字符 | `commitlint.config.js` header-max-length 1:1 |

**实现**: `scripts/hooks/commit-msg` 纯 bash (不依赖 `npx commitlint`, 免 node_modules)。EPIC-221 只加了 `commitlint.config.js` 但没装 runner → config 是死文件, EPIC-224 补 runner.

## 3. 改数字的强制流程

任何 immutable 数量变化 (8 → N) 必须**同时**改 3 处, 缺一处即数字漂移:

1. `CLAUDE.md` §5 标题 + 清单
2. `.claude/skills/kallax/SKILL.md` 9 类破坏性操作 #8
3. 本文件 §2 表格

**新脚本登记前置条件** (EPIC-224 教训): 必须**先接入 hook 并验证生效**, 再登记进数字. 登记未接入的脚本 = 声称存在但不运行 = 形式化治理.

**验证**:
```bash
git grep -n "immutable" CLAUDE.md .claude/skills/kallax/SKILL.md .claude/rules/immutable-scripts.md
bash scripts/hooks/install.sh --verify   # exit 0 = hook 体系健康
```

## 4. 联动

- Rule 5 (DRY): 数字单一真相来源在本文件, CLAUDE.md + SKILL.md 引用
- EPIC-069-D (check-claim-evidence 源头)
- EPIC-110 (4-law 接进 pre-commit)
- EPIC-131/132 (strict tsconfig + gate-paint 防御)
- EPIC-174 (smoke retention 2 辅助脚本)
- EPIC-219 / EPIC-220 / EPIC-223 (3 脚本落地) → EPIC-224 (接入 hook)
- EPIC-221 (commitlint.config.js) → EPIC-224 (commit-msg runner)
- P0-7 治理 (v3.32.1 路径澄清 + scan-dead-code 三态)