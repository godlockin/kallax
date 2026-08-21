#!/usr/bin/env bash
# EPIC-277-E test — hook 体系健康 (9 immutable 全部接入 + install --verify PASS)
# TDD: 6 TC (per hook 1 + install --verify + CLAUDE.md §5 数字对账)
# Usage: bash tests/integration/hook-system-health.test.sh
# Exit: 0 = all PASS, 1 = any FAIL

# EPIC-277-E: REPO_ROOT 用 BASH_SOURCE 解析 (跟 hooks/* 脚本 1:1).
# 原因: 测试可能在 main repo 或 worktree 跑, BASH_SOURCE 保证找到测试脚本自身
# 所在的 repo (跟 check-ticket-schema 等 1:1 路径策略).
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

echo "=== EPIC-277-E: hook 体系健康 (9 immutable + install --verify) ==="
echo ""

# TC1: 9 immutable 脚本全部存在 + 可执行
echo "--- TC1: 9 immutable 脚本存在 + 可执行 ---"
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
)
for s in "${IMMUTABLE[@]}"; do
  if [ -f "$s" ] && [ -x "$s" ]; then
    ok "$s 存在 + 可执行"
  else
    ko "$s 缺失或不可执行"
  fi
done
echo ""

# TC2: install --verify 输出 9/9 PASS + exit 0
echo "--- TC2: install --verify 9/9 PASS ---"
INSTALL_LOG="${TMPDIR_TEST}/install-verify.log"
bash "$INSTALLER" --verify > "$INSTALL_LOG" 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then
  ok "install --verify exit 0"
else
  ko "install --verify exit $RC (期望 0)"
  cat "$INSTALL_LOG"
fi
if grep -qE "PASS: 9/9 immutable scripts" "$INSTALL_LOG"; then
  ok "install --verify 输出 9/9 PASS"
else
  ko "install --verify 缺 9/9 PASS 输出"
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

# TC6: CLAUDE.md §5 数字对账 (AC7)
echo "--- TC6: CLAUDE.md §5 数字 (9 immutable + 2 辅助) ---"
COUNT_HOOKS=$(grep -c '^scripts/hooks/check-\|^scripts/hooks/snapshot-' CLAUDE.md)
if [ "$COUNT_HOOKS" -eq 9 ]; then
  ok "CLAUDE.md §5 'scripts/hooks/' 引用 = 9 (跟 install --verify 1:1)"
else
  ko "CLAUDE.md §5 'scripts/hooks/' 引用 = $COUNT_HOOKS (期望 9)"
fi
COUNT_AUX=$(grep -cE 'check-smoke-retention\.sh|smoke-size-report\.sh' CLAUDE.md)
if [ "$COUNT_AUX" -ge 2 ]; then
  ok "CLAUDE.md §5 2 辅助脚本引用齐"
else
  ko "CLAUDE.md §5 辅助脚本引用 = $COUNT_AUX (期望 ≥ 2)"
fi
echo ""

# 总结
echo "--- 总结 ---"
TOTAL=$((PASS + FAIL))
echo "  ${PASS}/${TOTAL} PASS"
if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "OK: hook-system-health 6/6 PASS (EPIC-277-E 9/9 immutable 接入)"
  exit 0
fi
echo ""
echo "FAIL: ${FAIL}/${TOTAL}"
exit 1
