#!/usr/bin/env bash
# scripts/check-skill-anatomy.sh
# KALLAX 专属 persona anatomy 校验 (v2 — 修复 A+B review 找出的 P1 bugs)
# 借 EKET check-skill-anatomy.sh 思路, KALLAX 多 7 项语义校验
#
# 修复历史:
# - v1 → v2: A-Forward 报 P1 (Check 3, Check 8) + B-Attack 报 HIGH (Check 7)
# - v2: 修复 output_format 在 frontmatter 内的 awk 切片问题

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

  # 提取 body 段 (frontmatter 之后, 避免 output_format 内的 ## 标题干扰)
  body_after_fm=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$file")
  fm_block=$(awk 'BEGIN{fm=0} /^---$/{fm++; if(fm==2) exit; next} fm==1{print}' "$file")

  # 校验 1: 6 节 body 存在性 (output_format 在 frontmatter, 由 Check 8 单独校验)
  for section in "mantras" "personality" "background" "thinking_framework" "analysis_focus" "Common Rationalizations"; do
    grep -q "^## $section\$" "$file" || errors+=("Missing section: ## $section")
  done

  # 校验 2: 额外 5 节
  for section in "When to Use" "When NOT to Use" "Process" "Red Flags" "Verification"; do
    grep -q "^## $section\$" "$file" || errors+=("Missing section: ## $section")
  done

  # 校验 3: rationalizations_count 同步 (支持 bullet 和 table 两种格式)
  declared=$(awk '/^rationalizations_count:/{print $2}' "$file" | tr -d '"' | head -1)
  # FIX: 用 state-based awk 避免 range pattern 跟字符类冲突
  section=$(echo "$body_after_fm" | awk '
    /^## Common Rationalizations$/ { in_sec=1; next }
    in_sec && /^## [A-Z]/ { in_sec=0; next }
    in_sec { print }
  ')
  actual_bullets=$(echo "$section" | grep -cE '^- "' || true)
  actual_table=$(echo "$section" | grep -cE '^\|.*`.*`' || true)
  if [ "$actual_bullets" -gt 0 ]; then
    actual="$actual_bullets"
  else
    actual="$actual_table"
  fi
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
    errors+=("tickets_served must be a JSON array (empty [] or non-empty [items])")
  fi

  # 校验 7: version semver (支持 -pre-release 和 +build metadata per semver.org)
  version=$(awk '/^version:/{print $2}' "$file" | head -1)
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$'; then
    errors+=("version not semver: $version (expected X.Y.Z or X.Y.Z-pre or X.Y.Z+build)")
  fi

  # 校验 8: output_format 4 节 (frontmatter 内的 YAML 多行字符串)
  if ! echo "$fm_block" | grep -qE '## (亮点|风险|建议|P0 阻塞条件)'; then
    errors+=("output_format missing 4 sections (亮点/风险/建议/P0 阻塞条件)")
  fi

  # 校验 9: Fact-Forcing Compliance 节 + 4 checkbox (L1-L4) — 必须含 4 个不同级别
  fact_block=$(echo "$body_after_fm" | awk '
    /^## Fact-Forcing Compliance/ { in_sec=1; next }
    in_sec && /^## [A-Z]/ { in_sec=0; next }
    in_sec { print }
  ')
  if [ -z "$fact_block" ]; then
    errors+=("Fact-Forcing Compliance section missing")
  else
    l1=$(echo "$fact_block" | grep -c 'L1_' || true)
    l2=$(echo "$fact_block" | grep -c 'L2_' || true)
    l3=$(echo "$fact_block" | grep -c 'L3_' || true)
    l4=$(echo "$fact_block" | grep -c 'L4_' || true)
    if [ "$l1" -eq 0 ] || [ "$l2" -eq 0 ] || [ "$l3" -eq 0 ] || [ "$l4" -eq 0 ]; then
      errors+=("Fact-Forcing Compliance missing 4 distinct levels (L1_/L2_/L3_/L4_)")
    fi
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

[ "$QUIET" = false ] && {
  echo ""
  echo "Summary: $((TOTAL - FAIL_COUNT))/$TOTAL pass"
}

exit $FAIL_COUNT
