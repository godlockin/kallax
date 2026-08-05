# EPIC-174 Smoke Retention Policy — Decision Record

**日期**: 2026-08-05
**拍板**: 主公 Phase 5 D
**来源**: loopx AGENTS.md Smoke Retention Policy

## Context

KALLAX 测试套件中 smoke 测试存在膨胀问题。当 smoke 测试超过 500 行时，它失去了"快速冒烟"的特性，变成了另一个 integration test。

主公 2026-08-05 Phase 5 D 拍板借鉴 loopx AGENTS.md Smoke Retention Policy 5 条规则。

## 5 条规则 (跟 loopx 1:1)

| Rule | 内容 | 示例 |
|------|------|------|
| 1 | 保留 shipped CLI/runtime behavior | `kallax --version`, `kallax init` |
| 2 | 保留 reusable control-plane contract | state.json schema, ticket.json 字段 |
| 3 | 保留 public/private boundary enforcement | `--help` 输出, `KALLAX_*` env prefix |
| 4 | 保留 regression that stranded automation | CI failure ticket 关联测试 |
| 5 | >=500 行 smoke 拆 / aggregate 替代 | 拆分或迁移到 integration/ |

## Pre-existing CI debt

对于已存在的 >500 行 smoke 测试 (如 CI debt)，处理方式:

1. **登记**: 记录到 `scripts/audit/smoke-size-report.sh` 报告
2. **不阻塞**: 不强制拆分 (避免破坏现有 CI)
3. **逐步治理**: 后续 EPIC 逐步拆分

## 实现

| 文件 | 类型 | 职责 |
|------|------|------|
| `docs/process/smoke-retention-policy.md` | 新 | 5 条规则详化 (≥80 行) |
| `scripts/check-smoke-retention.sh` | 新 | scanner (exit 0/1/2) |
| `scripts/audit/smoke-size-report.sh` | 新 | 报告 |
| `tests/integration/smoke-retention.test.sh` | 新 | ≥5 case 测试 |

## 退出码契约 (跟 EPIC-131/132 1:1)

| Code | 含义 |
|------|------|
| 0 | PASS - 所有 smoke 测试 <= 阈值 |
| 1 | FAIL - 存在 >= 阈值 的 smoke 测试 |
| 2 | BLOCKED-env - 环境问题 |

## 兼容性

- 0 改 source code
- 0 增 Rule
- 0 增 immutable script
- 跟 EPIC-131/132 scan-dead-code 退出码 1:1 兼容

## 验证

```bash
# Scanner
bash scripts/check-smoke-retention.sh

# Report
bash scripts/audit/smoke-size-report.sh

# Tests
bash tests/integration/smoke-retention.test.sh
```

## Raw Output

```
# smoke-size-report.sh
$ bash scripts/audit/smoke-size-report.sh
==============================================
KALLAX Smoke Size Report
Generated: 2026-08-05
Threshold: 500 lines
==============================================

FILE                                           LINES      STATUS     VALUE
----------------------------------------------
EPIC-113-A-session-dual-write-smoke.sh            77        ok    cli-behavior
----------------------------------------------
TOTAL                                             77           0        1

[INFO] All smoke tests within threshold
```

## 结论

EPIC-174 完成，smoke retention policy 建立，后续新 smoke 测试需遵循 5 条规则。
