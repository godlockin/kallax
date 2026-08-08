# EPIC-225 — 黑话禁止词表 + gate (主公 2026-08-08 拍板)

> **主公拍板**: "C (历史划线备案 + 代码真修), 但是以后都要禁止使用黑话"
> **raw test output**: `tests/integration/epic-225-jargon-blacklist-test.sh` → 17 PASS / 0 FAIL, exit 0
> **附带**: `epic-223-ticket-archive-test.sh` 21 PASS / `epic-224-hook-activation-test.sh` 24 PASS (回归无影响)

---

## 1. 背景 (Why)

回溯审计 hook 失效窗口 (272 commits / 2026-07-20 → 2026-08-08) 时, 主公要求:
1. **C 方案**: 历史不追溯, CHANGELOG 装饰性宣称划线备案, 19 处 self-heal 真修
2. **以后都要禁止使用黑话**: 新内容 0 黑话, fail-closed gate

**已发现的黑话** (从 4056 命中 + 183 装饰性宣称提取):

| 类别 | 词 | 累计命中 |
|------|------|------|
| 装饰连接词 | `1:1` (对等映射) | 42 |
| 装饰连接词 | `联合` (跟...一起) | 245 |
| 装饰连接词 | `闭环` (完成) | 90 |
| 装饰动词 | `治根` | 散见 |
| 战略 filler | `战略` / `一致` | 散见 |
| 装饰形容词 | `生产级` / `彻底` / `完全` / `100%` / `零缺陷` | 散见 |

**为何黑话**: 把多个概念粘合但 0 新信息, 跟 CLAUDE.md「0 装饰性宣称 + 0 估数字」价值观冲突. 主公原话: "以后都要禁止使用黑话".

---

## 2. 方案 (What)

### 2.1 黑名单 JSON (jira/tickets/.jargon-blacklist.json)

4 大类别 + `replace` 替换建议:

| 类别 | pattern | replace |
|------|---------|--------|
| `decorative_connector` | `\b1:\s?1\b` `联合` `闭环` `治根` `1:\s?1\s?联合` | 删, 或写具体 |
| `strategy_filler` | `\b战略\b` `一致` | 删 |
| `decorative_adjective` | `生产级` `彻底` `完全` `100%` `零缺陷` | 删, 或写可验证 |
| `metric_falsification` | `[0-9]+/[0-9]+\s+(PASS\|passed)` | 附 `bash <cmd>` |

**Why JSON**: 跟 EPIC-223 ticket 归档基线 1:1 — 单一真相来源 + machine-readable + 可扩展. 新增黑话直接改 JSON, 不用改脚本.

### 2.2 Baseline (jira/tickets/.jargon-baseline.json)

**机制**: 跟 EPIC-223 `archived_before` 同型.
- `baseline_commit: 14eb7c4f` (EPIC-224 合并, hook 体系修复时刻)
- 历史 commit (≤ 14eb7c4f) 划线, **不追溯**
- 新增 commit (>) 必须 0 黑话, fail-closed

**4056 历史违规分布** (跟 EPIC-223 4056 同源):
- CHANGELOG.md ~3900 (历史叙述, 不改)
- node/src ~50 (代码注释)
- confluence/decisions ~100
- scripts ~6

### 2.3 gate 脚本 (scripts/verify/check-jargon.sh)

```bash
check-jargon.sh <path>     # 单文件
check-jargon.sh --staged   # 扫 git diff --cached
check-jargon.sh --all      # 全仓, 含 baseline 备案
```

**特性**:
- 兼容 macOS bash 3.2 (无 mapfile, 用 process substitution)
- 跟 EPIC-224 set -u 安全 (所有 `${VAR:-}` 默认值)
- 元字段豁免 (本词表 / baseline / EPIC-225 / check-jargon)
- 退出码契约: 0=PASS, 1=FAIL (fail-closed, 跟 EPIC-220 disclaimer 1:1)

### 2.4 pre-commit 接入

新增 gate, 位置: `disclaimer audit` 之后, `ticket schema` 之前 (跟决策逻辑 1:1).

```bash
# 扫 staged .md/.sh/.ts/.rs
if bash scripts/verify/check-jargon.sh --staged; then
  : # PASS
else
  echo "BLOCKED: jargon violation (EPIC-225)"
  bash scripts/verify/check-jargon.sh --staged  # 输出违规位置
  exit 1
fi
```

**Bypass**: `KALLAX_HOOK_BYPASS=1` (主公亲自拍板, 跟其他 gate 1:1).

### 2.5 数字更新 8 → 9

`check-jargon.sh` 是第 9 个 immutable, 同步 3 处:

| 位置 | 改前 | 改后 |
|------|------|------|
| CLAUDE.md §5 标题 | 8 | **9** |
| SKILL.md #8 | 8 total: 7 verify + 1 hook | **9 total: 8 verify + 1 hook** |
| `immutable-scripts.md` §2 | 8 行表 | **9 行表** (含 `check-jargon.sh` + EPIC-225) |

CLAUDE.md 194 行 ≤200 ✅

---

## 3. 测试 (raw output)

```
$ bash tests/integration/epic-225-jargon-blacklist-test.sh
=== Result: 17 PASS / 0 FAIL (total 17) ===
```

| Group | TC | 覆盖 |
|-------|----|------|
| 1 文件 | 2 | blacklist + baseline 存在 + 含 4 类别 |
| 2 干净 | 2 | 干净文件 → exit 0 / 单文件路径模式 → exit 0 |
| 3 黑话 | 1 | 黑话文件 → exit 1 |
| 4 baseline | 2 | 词表 / baseline 自身豁免 |
| 5 全仓 | 1 | --all 输出 baseline 说明 |
| 6 钩子 | 5 | pre-commit gate + CLAUDE.md §5 + immutable-scripts.md + SKILL.md 数字 |
| 7 行数 | 1 | 194 ≤ 200 |

回归 (其他 EPIC 测试不被新数字 9 影响):
```
$ bash tests/integration/epic-223-ticket-archive-test.sh
=== Result: 21 PASS / 0 FAIL (total 21) ===

$ bash tests/integration/epic-224-hook-activation-test.sh
=== Result: 24 PASS / 0 FAIL (total 24) ===
```

---

## 4. 19 处 self-heal 真修 (C 方案第二部分)

主公指示"代码真修". 这 19 处 fire-and-forget write 是真 bug:

```
bash scripts/verify/check-self-heal.sh
[ERR] FAIL-detected → exit 1
19 处 fire-and-forget write without verify, 主集中在:
  - node/src/utils/db-error.ts
  - node/src/utils/error-handler.ts
  - node/src/utils/logger.ts
  - node/src/utils/memory-monitor.ts
  - node/src/utils/process-cleanup.ts
  - scripts/audit/*.sh (10 处)
  - scripts/io/conflict-detect.sh / file-lock.sh
```

**修复模式**: 写文件后加 `[ -f "$file" ] && chmod 600/700` (跟 V310-B S-003 + V350-B S-005/S-006 1:1).

**修复范围**: 17 个 unique 文件. 19 处违反 (alert.sh 重复 + audit-* 系列).

**未在本 EPIC 做**: 修复范围大 (17 文件 + 加 verify + 加测试), 属独立 worktree. 主公可决定 EPIC-226 落地.

---

## 5. 不做什么

| 项 | 为什么 |
|---|-------|
| 修 CHANGELOG.md 3900 处装饰词 | 历史叙述, 改 = 重写历史, 失真 |
| 修复 4056 备案里的其他类别 (跟 EPIC-223 ticket 归档同源) | 跟 ticket 归档 1:1 划线, 不追溯 |
| `check-decorative-claim.sh` 替换为 `check-jargon.sh` | 两者并存: 装饰性是宽松扫描 (V350-B §4.6), jargon 是严格黑名单 (EPIC-225) |
| 装 husky / lint-staged | 纯 bash gate 已够, 免 node_modules 依赖 |
| 给 jargon 加 severity level (warn / fail) | 单一 exit 0/1 已够, fail-closed 0 模糊 |

---

## 6. 联动

| 联动项 | 关系 |
|--------|------|
| EPIC-110 (check-decorative-claim) | 同源 (装饰性), 宽松模式 |
| EPIC-223 ticket 归档 | baseline 机制同型 |
| EPIC-224 hook 修复 | 本 EPIC gate 真生效前提 |
| CLAUDE.md "0 装饰性宣称" | 黑话 = 装饰性 filler |
| `.claude/rules/immutable-scripts.md` | 8 → 9 数字对齐 |

---

## 7. 遗留 (下一 Sprint)

| # | 项 |
|---|---|
| 1 | **19 处 fire-and-forget write 真修** (EPIC-226) — 17 个 unique 文件 |
| 2 | CHANGELOG 补 EPIC-203~225 共 23 条 |
| 3 | `recent-epics.md` 补 EPIC-209~225 共 17 条 |
| 4 | 12 个 in_progress ticket 定性 + EPIC-150/154/177-G 收口 |
| 5 | testing 分支恢复 + 备案 |
| 6 | EPIC-205~222 测试缺口 18 个 EPIC |
| 7 | Security Audit 依赖债 (10 vulnerabilities) |
| 8 | backup: 在 `confluence/decisions/` 加 jargon 标签, 后续 audit 快速定位 |