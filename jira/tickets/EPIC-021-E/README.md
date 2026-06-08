# EPIC-021-E: check-skill-anatomy.sh KALLAX 专属 6+ 项校验

## 需求

写一个 anatomy check 脚本, 借 EKET `check-skill-anatomy.sh` 思路, 但 KALLAX 多 7 项语义校验. 跑通所有 7 文件 = CI 门禁.

## 接受标准 (AC)

详见 `ticket.json`. 8 条 AC.

## 6+ 项 KALLAX 专属校验

| # | 校验项 | 借自 EKET | KALLAX 改动 |
|---|---|---|---|
| 1 | 7 节存在性 (mantras/personality/background/thinking_framework/analysis_focus/output_format/Common Rationalizations) | ✅ EKET 有 | 不变 |
| 2 | 额外 5 节 (When to Use / When NOT to Use / Process / Red Flags / Verification) | ❌ EKET 分散在 body | KALLAX 强制独立 ## 标题 |
| 3 | `rationalizations_count: N` 数字 = 实际 `## Common Rationalizations` 表格行数 | ❌ EKET 缺, 自己承认 | KALLAX 自动化 |
| 4 | `worktree_role: <master\|conductor\|performer>` 合法枚举 | ❌ EKET 缺 | KALLAX 独家 |
| 5 | `review_group: <A\|B\|AB>` 合法枚举 | ❌ EKET 缺 | KALLAX 独家 |
| 6 | `tickets_served: []` 是 JSON 数组 (可空, 但必须是数组) | ❌ EKET 缺 | KALLAX 独家 |
| 7 | `version: X.Y.Z` 符合 semver (regex `^\d+\.\d+\.\d+$`) | ❌ EKET 缺, 自己承认 | KALLAX 独家 |
| 8 | `output_format` YAML 多行字符串含 4 节标题 (亮点/风险/建议/P0 阻塞条件) | ❌ EKET 缺 | KALLAX 独家 |
| 9 | `Fact-Forcing Compliance` 节含 4 个 checkbox (L1-L4) | ❌ EKET 缺 | KALLAX 独家 |
| 10 | `id: kallax.<role>.001` 命名规范 (regex `^kallax\.\w+\.\d{3}$`) | ❌ EKET 有但格式不同 | KALLAX 调整 |

**实际 10 项校验** (比 6+ 多 4 项)

## 脚本模板

```bash
#!/usr/bin/env bash
# scripts/check-skill-anatomy.sh
# KALLAX 专属 persona anatomy 校验
# 借 EKET check-skill-anatomy.sh 思路, KALLAX 多 7 项语义校验

set -euo pipefail

QUIET=false
[ "${1:-}" = "--quiet" ] && { QUIET=true; shift; }

if [ $# -lt 1 ]; then
  echo "Usage: $0 [--quiet] <file.md> | <dir>/*.md"
  exit 2
fi

FAIL_COUNT=0
TOTAL=0

for file in "$@"; do
  TOTAL=$((TOTAL + 1))
  errors=()

  # 校验 1: 7 节存在性
  for section in "mantras" "personality" "background" "thinking_framework" "analysis_focus" "output_format" "Common Rationalizations"; do
    grep -q "^## $section\$" "$file" || errors+=("Missing section: ## $section")
  done

  # 校验 2: 额外 5 节
  for section in "When to Use" "When NOT to Use" "Process" "Red Flags" "Verification"; do
    grep -q "^## $section\$" "$file" || errors+=("Missing section: ## $section")
  done

  # 校验 3: rationalizations_count 同步
  declared=$(awk '/^rationalizations_count:/{print $2}' "$file" | tr -d '"' | head -1)
  actual=$(awk '/^## Common Rationalizations$/,/^## /' "$file" | grep -c '^|.*`.*`')
  if [ -n "$declared" ] && [ "$declared" != "$actual" ]; then
    errors+=("rationalizations_count mismatch: declared=$declared actual=$actual")
  fi

  # 校验 4: worktree_role 合法
  role=$(awk '/^worktree_role:/{print $2}' "$file" | head -1)
  case "$role" in
    master|conductor|performer) ;;
    *) errors+=("worktree_role invalid: $role (must be master|conductor|performer)") ;;
  esac

  # 校验 5: review_group 合法
  group=$(awk '/^review_group:/{print $2}' "$file" | head -1)
  case "$group" in
    A|B|AB) ;;
    *) errors+=("review_group invalid: $group (must be A|B|AB)") ;;
  esac

  # 校验 6: tickets_served 数组
  if ! grep -q "^tickets_served: \[\]" "$file" && ! grep -q "^tickets_served: \[" "$file"; then
    errors+=("tickets_served must be a JSON array")
  fi

  # 校验 7: version semver
  version=$(awk '/^version:/{print $2}' "$file" | head -1)
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    errors+=("version not semver: $version")
  fi

  # 校验 8: output_format 4 节
  if ! awk '/^output_format: \|/,/^[a-z]+:/' "$file" | grep -qE '## (亮点|风险|建议|P0 阻塞条件)'; then
    errors+=("output_format missing 4 sections (亮点/风险/建议/P0 阻塞条件)")
  fi

  # 校验 9: Fact-Forcing Compliance 4 checkbox
  if ! awk '/^## Fact-Forcing Compliance/,/^## /' "$file" | grep -qE '^\- \[ \] L[1-4]_'; then
    errors+=("Fact-Forcing Compliance missing 4-level checkboxes")
  fi

  # 校验 10: id 命名规范
  id=$(awk '/^id:/{print $2}' "$file" | head -1)
  if ! echo "$id" | grep -qE '^kallax\.[a-z]+\.[0-9]{3}$'; then
    errors+=("id invalid: $id (must match kallax.<role>.NNN)")
  fi

  # 报告
  if [ ${#errors[@]} -gt 0 ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    [ "$QUIET" = false ] && {
      echo "❌ $file"
      for err in "${errors[@]}"; do
        echo "   - $err"
      done
    }
  else
    [ "$QUIET" = false ] && echo "✅ $file"
  fi
done

[ "$QUIET" = false ] && echo ""
[ "$QUIET" = false ] && echo "Summary: $((TOTAL - FAIL_COUNT))/$TOTAL pass"

exit $FAIL_COUNT
```

## 用法

```bash
# 单文件
bash scripts/check-skill-anatomy.sh .kallax/experts/default/architect.md

# 批量
bash scripts/check-skill-anatomy.sh .kallax/experts/default/*.md

# 静默 (pre-commit hook 用)
bash scripts/check-skill-anatomy.sh --quiet .kallax/experts/default/*.md
```

## 文件范围

1 个 NEW 文件:
- `scripts/check-skill-anatomy.sh`

## ⚠️ 阻塞说明

**blocked_by EPIC-021-A**: A 创建 7 文件, E 才能校验它们. E 完成后 A 验证 (re-run check) 才能 close.

## 预估工时

0.6 小时 (脚本 0.4h + 调试 0.2h, 需跑 10 项校验)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 10 项全跑通, 错误信息清晰 (文件名+原因)
- **B 组 (Attack)**: 找校验本身是否可绕过 (e.g. frontmatter 多行字符串内嵌 `## mantras` 但实际不存在 — 攻击面), 找 regex 是否漏边界情况 (e.g. `tickets_served: [EPIC-001, EPIC-002]` vs `tickets_served: []`)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |
