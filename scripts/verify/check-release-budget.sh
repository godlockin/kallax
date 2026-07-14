#!/usr/bin/env bash
# scripts/verify/check-release-budget.sh — 每 release 砍 1 (EPIC-117-C)
#
# Anthropic Simplicity: "add complexity only when it demonstrably improves outcomes"
# KALLAX 反例: complexity via accretion, 只加不减
#
# 触发时机: release commit (CHANGELOG.md 修改 + tag pattern vX.Y.Z)
# 检查: 上一 tag → HEAD 的净增量 (rule / command / script), 期望 >= 1 项删除
#
# Exit:
#   0 = PASS (有删除记录) 或 not-release-commit (skip)
#   1 = FAIL (release 但 0 删除, warn)
#   2 = error

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# pre-commit skip (只在 release 节点跑, 走 CI 或手动)
if [[ "${KALLAX_PRE_COMMIT:-0}" == "1" ]]; then
    echo "WARN: check-release-budget skipped (pre-commit context, run at release tag)" >&2
    exit 0
fi

# 找上一 release tag
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [[ -z "$LAST_TAG" ]]; then
    echo "WARN: no previous tag, skip release-budget check" >&2
    exit 0
fi

RANGE="$LAST_TAG..HEAD"

# 统计 3 类净变化
count_delta() {
    local pattern="$1"
    # 新增行 (+) minus 删除行 (-) 匹配 pattern
    local added deleted
    added="$(git log "$RANGE" --pretty=format: --unified=0 -p 2>/dev/null | grep -cE "^\+[^+].*$pattern" || true)"
    deleted="$(git log "$RANGE" --pretty=format: --unified=0 -p 2>/dev/null | grep -cE "^-[^-].*$pattern" || true)"
    echo "$added $deleted"
}

echo "==================================="
echo "Release Budget Check (since $LAST_TAG)"
echo "==================================="

# 1. Rule count (CLAUDE.md `## Rule`)
read -r rule_added rule_deleted <<< "$(count_delta '^## Rule|^### Rule')"
# 2. Slash command count (SKILL.md `/kallax-`)
read -r cmd_added cmd_deleted <<< "$(count_delta '/kallax-[a-z]')"
# 3. Script count (scripts/**/*.sh new files)
scripts_added="$(git diff --name-status "$RANGE" 2>/dev/null | grep -cE '^A\s+scripts/.*\.sh$' || true)"
scripts_deleted="$(git diff --name-status "$RANGE" 2>/dev/null | grep -cE '^D\s+scripts/.*\.sh$' || true)"

net_rules=$((rule_added - rule_deleted))
net_cmds=$((cmd_added - cmd_deleted))
net_scripts=$((scripts_added - scripts_deleted))
total_deletes=$((rule_deleted + cmd_deleted + scripts_deleted))

printf "  Rules:    +%d  -%d  (net %+d)\n" "$rule_added" "$rule_deleted" "$net_rules"
printf "  Commands: +%d  -%d  (net %+d)\n" "$cmd_added" "$cmd_deleted" "$net_cmds"
printf "  Scripts:  +%d  -%d  (net %+d)\n" "$scripts_added" "$scripts_deleted" "$net_scripts"
printf "  Total deletions: %d\n" "$total_deletes"
echo ""

if [[ $total_deletes -ge 1 ]]; then
    echo "PASS: release contains at least 1 deletion (simplicity budget met)"
    exit 0
fi

echo "FAIL: 0 deletions since $LAST_TAG (complexity via accretion)"
echo ""
echo "Anthropic Simplicity principle: add complexity only when it demonstrably improves outcomes."
echo "This release added things but removed nothing. Answer before continuing:"
echo "  1. Can any existing rule/command/script be replaced or removed?"
echo "  2. Can duplicated concepts be merged?"
echo "  3. Emergency bypass: KALLAX_RELEASE_BUDGET_BYPASS=1 (require justification in release notes)"
[[ "${KALLAX_RELEASE_BUDGET_BYPASS:-0}" == "1" ]] && { echo "BYPASSED"; exit 0; }
exit 1
