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

## 2. 统一口径 (EPIC-277-E 后: 9 immutable 全部在 scripts/hooks/)

### 9 immutable (fail-closed, 改动需主公亲自批准, 全部已接入 hook)

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

**退出码契约**: 0=PASS, 1=FAIL. 禁止 print FAIL + exit 0 (fail-open).
**例外**: `check-ticket-schema.sh` 有 exit 3 = ARCHIVED_SKIP (跟 EPIC-204 `DOCS_ONLY_SKIP` 同型, 表示"不适用"而非 PASS/FAIL). pre-commit 只拦 exit 1.
**#7 是 advisory**: `snapshot-claude-md.sh` 在 pre-commit 只提醒不阻塞 (改治理文件时提示打 snapshot), 不阻断 commit.

**EPIC-277-E 路径迁移**: 4 个原 verify/ 脚本 (check-decorative-claim / check-narrative / check-fail-closed / check-self-heal) 已 copy 到 scripts/hooks/ 作 canonical location.
- pre-commit 4-law loop 优先读 scripts/hooks/, fall back 到 scripts/verify/ (向后兼容).
- scripts/verify/ 副本保留 (audit 链完整 + backward-compat).
- install --verify 9/9 PASS (跟 CLAUDE.md §5 数字对齐).

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

### commit-msg gate (EPIC-221 config → EPIC-224 激活)

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