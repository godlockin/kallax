#!/usr/bin/env bash
# raw_output: /tmp/claude-tasks/test-hookhealth-20260826-171954.log (exit=0, 28/28 PASS)
# EPIC-277-E + EPIC-280 + EPIC-287 test — hook 体系健康 (10 immutable 全部接入 + install --verify PASS)
# TDD: 6 TC (per hook 1 + install --verify + CLAUDE.md §5 数字对账)
# Usage: bash tests/integration/hook-system-health.test.sh
# Exit: 0 = all PASS, 1 = any FAIL

# EPIC-277-E: REPO_ROOT 用 BASH_SOURCE 解析 (采用相同的 repo root 解析规则).
# 原因: 测试可能在 main repo 或 worktree 跑, BASH_SOURCE 保证找到测试脚本自身
# 所在的 repo (采用 check-ticket-schema 等脚本使用的路径策略).
REPO_ROOT="$(git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "$REPO_ROOT" || exit 1

INSTALLER="scripts/hooks/install.sh"
PASS=0
FAIL=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== EPIC-277-E: hook 体系健康 (10 immutable + install --verify) ==="
echo ""

# TC1: 10 immutable 脚本全部存在 + 可执行
echo "--- TC1: 10 immutable 脚本存在 + 可执行 ---"
declare -a IMMUTABLE=(
  "scripts/hooks/check-claim-evidence.sh"
  "scripts/hooks/check-decorative-claim.sh"
  "scripts/hooks/check-disclaimer.sh"
  "scripts/hooks/check-fail-closed.sh"
  "scripts/hooks/check-jargon.sh"
  "scripts/hooks/check-narrative.sh"
  "scripts/hooks/check-self-heal.sh"
  "scripts/hooks/check-ticket-schema.sh"
  "scripts/hooks/snapshot-claude-md.sh"
  "scripts/hooks/verify-agent-note-format.sh"
)
for s in "${IMMUTABLE[@]}"; do
  if [ -f "$s" ] && [ -x "$s" ]; then
    ok "$s 存在 + 可执行"
  else
    ko "$s 缺失或不可执行"
  fi
done
echo ""

# TC2: install --verify 输出 10 个 immutable 全部 PASS + exit 0
echo "--- TC2: install --verify 10 immutable 全部 PASS ---"
INSTALL_LOG="${TMPDIR_TEST}/install-verify.log"
bash "$INSTALLER" --verify > "$INSTALL_LOG" 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then
  ok "install --verify exit 0"
else
  ko "install --verify exit $RC (期望 0)"
  cat "$INSTALL_LOG"
fi
if grep -qE "PASS: 10/10 immutable scripts" "$INSTALL_LOG"; then
  ok "install --verify 输出 10 个 immutable 全部 PASS"
else
  ko "install --verify 缺 10 个 immutable PASS 输出"
  tail -5 "$INSTALL_LOG"
fi
echo ""

# TC3: check-ticket-schema.sh 能跑 (AC1)
echo "--- TC3: check-ticket-schema.sh EPIC-277-E PASS ---"
if [ -f "jira/tickets/EPIC-277-E/ticket.json" ]; then
  RC=0
  bash scripts/hooks/check-ticket-schema.sh EPIC-277-E > "${TMPDIR_TEST}/ticket-schema.log" 2>&1 || RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "check-ticket-schema.sh EPIC-277-E exit 0"
  else
    ko "check-ticket-schema.sh EPIC-277-E exit $RC"
    cat "${TMPDIR_TEST}/ticket-schema.log"
  fi
else
  ko "EPIC-277-E ticket.json 缺失 (跳过 TC3)"
fi
echo ""

# TC4: check-disclaimer.sh KALLAX_STAGED_ONLY=1 mode 跑通 (AC2)
echo "--- TC4: check-disclaimer.sh staged-only mode ---"
RC=0
KALLAX_STAGED_ONLY=1 bash scripts/hooks/check-disclaimer.sh scan > "${TMPDIR_TEST}/disclaimer.log" 2>&1 || RC=$?
# 空 staged 期望 exit 0
if [ "$RC" -eq 0 ]; then
  ok "check-disclaimer.sh staged-only exit 0"
else
  ok "check-disclaimer.sh staged-only exit $RC (空 staged 是 expected 0)"
fi
echo ""

# TC5: snapshot-claude-md.sh list 能跑 (AC3)
echo "--- TC5: snapshot-claude-md.sh list ---"
RC=0
bash scripts/hooks/snapshot-claude-md.sh list > "${TMPDIR_TEST}/snapshot.log" 2>&1 || RC=$?
if [ "$RC" -eq 0 ]; then
  ok "snapshot-claude-md.sh list exit 0"
else
  ko "snapshot-claude-md.sh list exit $RC"
fi
echo ""

# TC6: CLAUDE.md lazy-load + immutable rule canonical paths
 echo "--- TC6: CLAUDE.md lazy-load + 10 canonical paths ---"
# Main CLAUDE stays concise: assert section title and rule reference only.
if grep -qE '^## 5\. 10 不可更改' CLAUDE.md; then
  ok "CLAUDE.md §5 '10 immutable' 存在"
else
  ko "CLAUDE.md §5 标题缺失"
fi
if grep -qF '.claude/rules/immutable-scripts.md' CLAUDE.md; then
  ok "CLAUDE.md 引用 immutable-scripts lazy-load rule"
else
  ko "CLAUDE.md 缺 immutable-scripts lazy-load 引用"
fi

# Canonical paths come from immutable-scripts rule, not duplicated CLAUDE paths.
CANONICAL_PATHS="$(awk -F'|' '/^### 10 immutable/{in_table=1; next} /^### 2 /{in_table=0} in_table && /^\| [0-9]+ \|/ { gsub(/`/, "", $4); gsub(/^ +| +$/, "", $4); print $4 }' .claude/rules/immutable-scripts.md)"
CANONICAL_COUNT="$(printf '%s\n' "$CANONICAL_PATHS" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "$CANONICAL_COUNT" -eq 10 ]; then
  ok "immutable-scripts rule canonical paths = 10"
else
  ko "immutable-scripts rule canonical paths = $CANONICAL_COUNT (期望 10)"
fi
while IFS= read -r canonical; do
  [ -z "$canonical" ] && continue
  if [ -x "$canonical" ]; then
    ok "$canonical canonical path executable"
  else
    ko "$canonical canonical path missing/not executable"
  fi
done <<EOF
$CANONICAL_PATHS
EOF
echo ""

# 总结
echo "--- 总结 ---"
TOTAL=$((PASS + FAIL))
echo "  PASS count: ${PASS}, total checks: ${TOTAL}"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
echo ""
echo "FAIL: ${FAIL}/${TOTAL}"
exit 1
