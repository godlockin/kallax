#!/usr/bin/env bash
# tests/verify/claim-evidence-test.sh — EPIC-117-A
# 验证 check-claim-evidence 扫 confluence/decisions/** 里的 X/Y PASS 数字
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
HOOK="$REPO/scripts/hooks/check-claim-evidence.sh"
PASS=0
FAIL=0

run_case() {
  local name="$1" file="$2" content="$3" expected="$4"
  local tmpdir; tmpdir="$(mktemp -d)"
  ( cd "$tmpdir" && git init -q && git config user.email t@t && git config user.name t \
    && mkdir -p "$(dirname "$file")" && printf '%s\n' "$content" > "$file" \
    && git add "$file" \
    && actual_exit=0 && bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
    if [[ "$actual_exit" == "$expected" ]]; then
      echo "PASS: $name (exit=$actual_exit)"
    else
      echo "FAIL: $name (want=$expected got=$actual_exit)"
      exit 1
    fi
  ) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
  rm -rf "$tmpdir"
}

# Case 1: decisions 文档含 X/Y PASS 无 raw_output → FAIL (exit 1)
run_case "decisions-numeric-no-evidence" \
  "confluence/decisions/EPIC-999-fake.md" \
  "# fake\n\nTests: 25/25 PASS. 生产级." \
  1

# Case 2: decisions 文档含 X/Y PASS + raw_output → PASS (exit 0)
run_case "decisions-numeric-with-evidence" \
  "confluence/decisions/EPIC-999-real.md" \
  "# real\n\nTests: 25/25 PASS.\nraw_output: /tmp/vitest-run.log" \
  0

# Case 3: decisions 无数字 → PASS
run_case "decisions-no-numeric" \
  "confluence/decisions/EPIC-999-plain.md" \
  "# plain\n\n只是普通决策记录, 无数字断言" \
  0

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
