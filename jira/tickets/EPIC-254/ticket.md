# EPIC-254 — 全仓清 grep -c 输出污染 + Rule 3 catch

**Status**: in_progress → done
**Priority**: P1
**Type**: bugfix
**Estimated**: 2h
**Phase**: PHASE-024

## 根因

`grep -c` 无匹配时**已输出 "0"** 且返回 1。写 `|| echo N` 会再追加一个值:

```bash
BAD=$(echo "no match" | grep -c "xyz" 2>/dev/null || echo 0)
# BAD = "0\n0"  (两行!)
[ "$BAD" -gt 0 ]   # → rc=2, integer expression expected
```

修法 `|| true` (只吞退出码不追加输出) + `${VAR:-0}` 兜底。

## 发现路径

规划下阶段时跑 `bash scripts/scan-dead-code.sh`,看到:

```
scripts/scan-dead-code.sh: line 123: [: 0
0: integer expression expected
```

顺着扫全仓。

## 两轮扫描 (首轮漏了带引号写法)

| 轮次 | 正则 | 找到 |
|---|---|---|
| 首轮 | `\|\| echo 0` (无引号) | 12 处 |
| 二轮 | 发现 test 报 23 处残留 → 加 `\|\| echo "0"` (带引号) | +20 处 |

**教训**:扫描正则要覆盖 shell 的引号变体。首轮报"11 处全修完"是不准确的。

## 危害分级

| 文件 | 处数 | 危害 |
|---|---|---|
| `merge-validator.sh` | 4 | **最高** — `FAILED` 污染时 `[ -gt 0 ]` 失效,CI 失败可能不拦 (fail-open) |
| `dashboard-metrics.sh` | 4 | `"0\n0"` 传给 `bc` 算术报错 |
| `scan-dead-code.sh` | 1 | 每次跑打错误行,噪声掩盖真问题 |
| `verify/level-2.sh` | 1 | 5-Level Verify L2 test 计数 |
| `parallel-dispatch.sh` | 1 | ticket 计数判断 |
| 其余 22 处 | 22 | 读 CLAUDE.md 数 Rule (必有 `### N.` 所以不触发,属潜在坑) |

## 附带修复

`node/src/core/worktree-manager.ts:51` catch 补 `:unknown` (CLAUDE.md Rule 3,scan Stage 1 长期 WARN)。

## 验证结果

| AC | 状态 | raw output |
|---|---|---|
| AC1 全仓 0 残留 | PASS | test Case 3 → `0 occurrences` (排除说明注释) |
| AC2 15 文件语法 | PASS | test Case 5 → `0 syntax errors` |
| AC3 merge-validator 安全模式 | PASS | test Case 6 → 双 PASS (`\|\| true` + `${VAR:-0}`) |
| AC4 scan-dead-code 无错误行 | PASS | `bash scripts/scan-dead-code.sh` → `3/3 阶段 PASS`,无 line 123 报错 |
| AC5 Rule 3 catch | PASS | test Case 8 → 双 PASS |
| AC6 test ≥8 case | PASS | **12 passed, 0 failed** |
| AC7 根因锚定 | PASS | Case 1 (len 3 vs len 1) + Case 2 (rc=2 vs rc=1) |
| AC8 0 改 immutable | PASS | `level-2.sh` 不在 9 immutable 清单 (清单是 `check-*.sh`) |
| AC9 4-branch | 进行中 | PR-1 → testing → main → miao |

## 同类坑第 6 次

| # | EPIC | 坑 |
|---|---|---|
| 1 | EPIC-232 | `jq` exit 2 + `set -e` |
| 2 | EPIC-245 | `check-ticket-schema` exit 3 + `set -e` |
| 3 | EPIC-248 | `((x++))` 返回旧值 |
| 4 | EPIC-249 | `\|\| echo 0` 追加输出 (首次发现) |
| 5 | EPIC-254 | 同上,全仓清 32 处 |
| 6 | (本 EPIC 写 test 时) | `set -e` 开了没关,Case 3 的 grep 无匹配直接终止脚本 |

第 6 次是我写这个 test 时自己犯的 — 跟被修的 bug 同一家族。

**共同教训**:bash 退出码 + `set -e` 组合是主要 bug 来源。写 `$(cmd || fallback)` 前先确认 cmd 无匹配时是否已有输出。

## 联动

- EPIC-249 (首次发现该模式)
- EPIC-248/232/245 (同类退出码坑)
- CLAUDE.md Rule 3 (catch `:unknown`)
- EPIC-131/132 (scan-dead-code sentinel)
- Rule 34 (独立复现)
