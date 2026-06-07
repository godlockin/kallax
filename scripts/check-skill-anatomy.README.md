# check-skill-anatomy.sh — KALLAX 10 项校验

## 用途

校验 KALLAX expert persona 文件 (`.kallax/experts/default/*.md`) 是否符合 KALLAX 规范. 借 EKET `check-skill-anatomy.sh` 思路, KALLAX 多 7 项语义校验.

## 用法

```bash
# 单文件
bash scripts/check-skill-anatomy.sh .kallax/experts/default/architect.md

# 批量
bash scripts/check-skill-anatomy.sh .kallax/experts/default/*.md

# 静默 (pre-commit hook 用, 只输出错误)
bash scripts/check-skill-anatomy.sh --quiet .kallax/experts/default/*.md
```

退出码: 0 = 全 PASS, N = 失败文件数.

## 10 项校验 + 修复历史

| # | 校验 | 借自 | KALLAX 改动 | 修复版本 |
|---|---|---|---|---|
| 1 | 7 节存在性 (mantras / personality / background / thinking_framework / analysis_focus / output_format / Common Rationalizations) | EKET | 不变 | v1 |
| 2 | 额外 5 节 (When to Use / NOT to Use / Process / Red Flags / Verification) | EKET 分散在 body | 强制独立 ## 标题 | v1 |
| 3 | `rationalizations_count: N` 数字 = 实际表格/行数 | ❌ EKET 缺, 自己承认缺 | KALLAX 自动化, 支持 bullet + table 双格式 | v2 (A-Forward 报 P1) |
| 4 | `worktree_role: <master\|conductor\|performer>` 合法枚举 | ❌ EKET 缺 | KALLAX 独家 | v1 |
| 5 | `review_group: <A\|B\|AB>` 合法枚举 | ❌ EKET 缺 | KALLAX 独家 | v1 |
| 6 | `tickets_served: []` 是 JSON 数组 (可空) | ❌ EKET 缺 | KALLAX 独家 | v1 |
| 7 | `version: X.Y.Z` 符合 semver (允许 `-pre` 和 `+build`) | ❌ EKET 缺 | KALLAX semver 严格 + pre-release | v2 (B-Attack 报 HIGH) |
| 8 | `output_format` YAML 多行字符串含 4 节标题 (亮点/风险/建议/P0 阻塞条件) | ❌ EKET 缺 | KALLAX 独家, awk 切片 | v2 (C-Attack 报 CRITICAL awk bug) |
| 9 | `Fact-Forcing Compliance` 节含 4 个不同级别 (L1_/L2_/L3_/L4_) | ❌ EKET 缺 | KALLAX 独家, 4-Level 不可降级 | v2 (B-Attack 报 HIGH) |
| 10 | `id: kallax.<role>.NNN` 命名规范 | ❌ EKET 格式不同 | KALLAX 调整 (角色小写, 3 位数字) | v1 |

## 集成

```bash
# pre-commit hook (建议)
git diff --cached --name-only | grep -E '\.kallax/experts/default/.*\.md$' | \
  xargs bash scripts/check-skill-anatomy.sh --quiet || {
    echo "❌ persona anatomy check failed"
    exit 1
  }
```

## 已知限制

1. **macOS etime 解析**: 不适用本脚本 (无 ps/etime 依赖)
2. **跨平台 regex**: 用 `grep -E` (BSD/GNU 兼容)
3. **YAML 解析**: 用 awk 切片而非 `python3 -c yaml`, 避免 Python 依赖
4. **rationalizations_count 双格式**: bullet (`- "text"`) 和 table (`| text |`); 优先 bullet 计数

## 修复历史

| Date | Reviewer | Fix |
|---|---|---|
| 2026-06-07 | A-Forward | Check 3: 移除 `\|\| echo 0`, 避免 "0\n0" 双输出 |
| 2026-06-07 | A-Forward | Check 8: `output_format: \|` → `output_format: [\|]`, 端 pattern `/^[a-z_]+:/` (允许 key: value 形式) |
| 2026-06-07 | A-Forward | Check 9: 升级为 4 个不同级别计数 (而非单个 regex) |
| 2026-06-07 | B-Attack | Check 7: semver regex 支持 `-pre` 和 `+build` (per semver.org) |
| 2026-06-07 | B-Attack (C review) | Check 8: awk pattern 修复 (避免 gawk illegal primary) |
