# EPIC-204 docs-only metrics 适配 (2026-08-08)

> **Decision record**: sprint-metrics.sh 加 `--docs-only` flag, docs-only EPIC 显式跳过 4 北极星指标 + exit 3.
> **Author**: master | **Reviewer**: 主公 2026-08-08 拍板

## 1. 背景

Rule 36 (EPIC-194) Sprint 结束必跑 `scripts/metrics/sprint-metrics.sh` 4 指标, exit 2 (NO_DATA) 触发 ASK.

docs-only EPIC (EPIC-197/198/199/200/201/202-A/B/C/203) 0 ticket, 0 file_scope → 4 指标全 NO_DATA → 误触发 ASK, 跟 EPIC-198 docs-only PR CI exempt 矛盾.

## 2. Fix

**新 exit code 3: DOCS_ONLY_SKIP** (跟 0/1/2 契约 1:1 兼容).

**新 flag `--docs-only`**:
```bash
bash scripts/metrics/sprint-metrics.sh --epic EPIC-197 --docs-only
# exit 3, status=DOCS_ONLY_SKIP
```

**联动**:
- EPIC-198: docs-only PR CI exempt (源)
- EPIC-203 retrospective Item 2: docs-only EPIC NO_DATA 是设计, 非 bug
- Rule 36: Sprint 4 指标 (docs-only EPIC 显式 --docs-only 跳过, 不触发 ASK)
- EPIC-205 retrospective-routine: 季度整理会跑 EPIC-203/204 sprint-metrics, 自动用 --docs-only

## 3. 落地

- `scripts/metrics/sprint-metrics.sh` 加 `--docs-only` flag + exit 3 (跟 exit 0/1/2 契约 1:1)
- `tests/integration/epic-204-docs-only-metrics-test.sh` 8 TC (8/8 PASS)
- 0 改 Rule, 0 增 immutable script

## 4. 4-PR 流程

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-204-docs-only-metrics (worktree) | integration test 8/8 PASS |
| Step 2 | PR feature → testing | 8/8 PASS |
| Step 3 | testing → main | force-push |
| Step 4 | main → miao | ff merge |

## 5. Reviewer

- 主公 (拍板 docs-only 适配)
- master (执行)
- Rule 36 闭环 (Sprint 4 指标 docs-only EPIC 跳过)

## 6. Exit codes 契约 (更新)

| Exit | 含义 |
|------|------|
| 0 | All 4 metrics PASS |
| 1 | At least 1 metric FAIL or invalid args |
| 2 | NO_DATA on all metrics (data sources missing) |
| 3 | DOCS_ONLY_SKIP (--docs-only, docs-only EPIC, 跟 EPIC-198 1:1) |