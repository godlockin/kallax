# EPIC-253 — docs 复用率 metric + root ticket 漏扫 bug

**Status**: in_progress → done
**Priority**: P1
**Type**: bugfix
**Estimated**: 3h
**Phase**: PHASE-023

## 起因

retrospective-batch-8 L14 记录 `cross_epic_reuse_rate` 对 docs-only EPIC 常年 0% / NO_DATA. 调查发现 2 个问题, 一个是真 bug (意外发现), 一个是设计缺口.

## Bug A (真 bug, 意外发现)

`collect_filescope_for_epic` 只扫 sub-ticket glob:

```bash
for ticket_dir in "${JIRA_TICKETS_DIR}/EPIC-${epic_num}-"*/; do
```

漏了 root ticket `EPIC-XXX/`. 所有 root-ticket 形态的 EPIC (EPIC-251/159/174 等) file_scope 都收集不到 → `total_files=0` → NO_DATA.

`collect_filescope_all_except` 的排除判断同样只匹配 sub 形态:

```bash
case "$base" in
  "EPIC-${epic_num}-"*) continue ;;   # 漏 "EPIC-${epic_num}"
esac
```

导致目标 EPIC 自己的文件泄漏进 others 集合, overlap 计算偏高.

### Rule 34 复现

```
bash scripts/metrics/sprint-metrics.sh --epic EPIC-251 --format json | grep -A5 cross_epic_reuse_rate
```

修复前:
```
      "metric": "cross_epic_reuse_rate",
      "epic": "EPIC-251",
      "reuse_pct": 0,
      "target": 60,
      "status": "NO_DATA",
      "overlap_count": 0,
```

`EPIC-251/ticket.json` 明确有 `file_scope.includes` 2 项, 但 metric 报 NO_DATA.

修复后:
```
| cross_epic_reuse_rate | 0% (0/2 files) | >= 60% | FAIL |
| cross_epic_docs_reuse_rate | 0% (0/1 docs) | >= 40% | FAIL |
```

status 从 NO_DATA 变 FAIL, total_files 从 0 变 2.

## Gap B (设计缺口)

即便修好 bug A, docs-only EPIC 的 file_scope 多为一次性路径 (`jira/tickets/EPIC-XXX/`), 复用率天然低, 60% 阈值不适用.

## 修复

| # | 改动 | 说明 |
|---|---|---|
| 1 | `collect_filescope_for_epic` 加 root 路径 | 同 `compute_mis_dispatch_binding_rate:571` 的 root+sub 双路径写法 |
| 2 | `collect_filescope_all_except` 排除判断加 root 形态 | `"EPIC-${n}"\|"EPIC-${n}-"*` |
| 3 | 新 `compute_cross_epic_docs_reuse_rate` | `DOCS_PATH_PATTERN` 过滤, 阈值 40% |
| 4 | `format_json_metrics` 加 m2b | metrics 数组第 3 位 |
| 5 | `format_markdown_metrics` 加 docs 行 | Summary 表 |
| 6 | CLAUDE.md §3.2 Rule 36 加指标 2b | 199 行 |

### DOCS_PATH_PATTERN

```
^(CLAUDE\.md|README|CHANGELOG\.md|\.claude/rules/|confluence/|docs/|jira/tickets/|tests/integration/.*\.sh$)|\.md$
```

## 验证结果

| AC | 状态 | raw output |
|---|---|---|
| AC1 root ticket 被扫到 | PASS | Case 2: `root ticket EPIC-901 file_scope collected (got '3')` |
| AC2 sub-ticket 无 regression | PASS | Case 3: `sub-ticket EPIC-902-A file_scope collected (got '3')` |
| AC3 排除 root + sub | PASS | Case 4: `EPIC-901 own file excluded` |
| AC4 只算 docs, 排除 .ts | PASS | Case 5: `docs file count excludes .ts (got '2')` |
| AC5 阈值判定 | PASS | Case 6: `full overlap >= 40 target → PASS` |
| AC6 无 docs → NO_DATA | PASS | Case 7: `no docs → NO_DATA` |
| AC7 2 formatter 集成 | PASS | Case 8: JSON m2b + Markdown docs 行 |
| AC8 test ≥8 case | PASS | 15 case |
| AC9 实测区分度 | PASS | EPIC-174: 总复用 33% FAIL, docs 复用 42% PASS |
| AC10 CLAUDE.md ≤ 200 行 | PASS | `wc -l CLAUDE.md` → 199 |
| AC11 0 改 immutable, 0 增 Rule | PASS | `scripts/verify/` 不在 diff; 指标 2b 是 Rule 36 副指标 |
| AC12 4-branch flow | 进行中 | PR-1 → testing → main → miao |

## 实测区分度 (AC9 核心价值)

| EPIC | 总复用率 | docs 复用率 | 说明 |
|---|---|---|---|
| EPIC-159 | 33% FAIL | 33% FAIL | docs 全是自己的路径 |
| EPIC-174 | 33% FAIL | **42% PASS** | docs 复用达标, 总复用被 .sh 拉低 |
| EPIC-171 | 33% FAIL | 33% FAIL | 同 159 |

docs metric 给了 docs-only EPIC 区分度 — 之前全是 NO_DATA / 0%.

## 联动

- Rule 36 (本 ticket 补指标 #2 副指标)
- EPIC-023-C (北极星源头)
- EPIC-157 (root+sub 双路径写法参考)
- retrospective-batch-8 L14 (docs 复用盲点)
- EPIC-252 (同 Sprint 前序)
- Rule 34 (独立复现)
