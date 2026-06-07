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
  actual=$(awk '/^## Common Rationalizations$/,/^## /' "$file" | grep -c '^|.*\`.*\`' || echo 0)
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

  # 校验 7: version semver
  version=$(awk '/^version:/{print $2}' "$file" | head -1)
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    errors+=("version not semver: $version (expected X.Y.Z)")
  fi

  # 校验 8: output_format 4 节
  if ! awk '/^output_format: \|/,/^[a-z]+:[^ ]/' "$file" | grep -qE '## (亮点|风险|建议|P0 阻塞条件)'; then
    errors+=("output_format missing 4 sections (亮点/风险/建议/P0 阻塞条件)")
  fi

  # 校验 9: Fact-Forcing Compliance 节
  if ! grep -q "^## Fact-Forcing Compliance" "$file"; then
    errors+=("Missing section: ## Fact-Forcing Compliance")
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
      echo "FAIL $file"
      for err in "${errors[@]}"; do
        echo "   - $err"
      done
    }
  else
    [ "$QUIET" = false ] && echo "PASS $file"
  fi
done

[ "$QUIET" = false ] && {
  echo ""
  echo "Summary: $((TOTAL - FAIL_COUNT))/$TOTAL pass"
}

exit $FAIL_COUNT