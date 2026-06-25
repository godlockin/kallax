#!/usr/bin/env bash
# EPIC-030-E: PR Size self-test fixture 回归
# 跟 Rule 8 (Rule of 500) 1:1 验证, 跟 EPIC-059-B 1:1 验证
# 跟 "翻篇&精进" 战略 联合 0 简单 记录 (借方法论 不借代码)
#
# Fixture runner — 调 scripts/check-pr-size.sh --self-test 验证 cases.json 全过
# 5 case 覆盖: small PR / empty PR / boundary 100 / boundary 500 / huge PR
#
# AC L1: scripts/check-pr-size.sh supports --self-test mode ✓
# AC L2: 跑每个 case 验证脚本输出符合预期 (WARN=100行, FAIL=500行), 真回归 ✓
# AC L3: bash + jq 合法, fixture 格式 JSON ✓
# AC L4: 跑 PASS, 覆盖 5+ case ✓
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/check-pr-size.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/pr-size/cases.json"

echo "=== EPIC-030-E: PR Size self-test fixture 回归 ==="
echo "  Script:   $SCRIPT"
echo "  Fixture:  $FIXTURE"
echo ""

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not installed"; exit 1; }
[[ -f "$SCRIPT" ]] || { echo "FAIL: $SCRIPT not found"; exit 1; }
[[ -f "$FIXTURE" ]] || { echo "FAIL: $FIXTURE not found"; exit 1; }

# AC #1: --self-test mode 存在 (declared in --help)
if ! bash "$SCRIPT" --help 2>&1 | grep -q -- "--self-test"; then
    echo "FAIL: --self-test mode not declared in --help"
    exit 1
fi

# Run self-test
echo "Running: bash $SCRIPT --self-test"
echo ""
if ! bash "$SCRIPT" --self-test; then
    echo ""
    echo "FAIL: check-pr-size.sh --self-test exited non-zero"
    exit 1
fi

# AC L4: 覆盖 5+ case (small / empty / boundary 100 / boundary 500 / huge)
TOTAL=$(jq 'length' "$FIXTURE")
if [[ "$TOTAL" -lt 5 ]]; then
    echo "FAIL: fixture has $TOTAL cases, need ≥5 (AC L4)"
    exit 1
fi

echo ""
echo "=== Fixture coverage: $TOTAL cases (≥5 required) ==="
echo ""
echo "PASS: pr-size-self-test.sh — all $TOTAL cases passed (跟 Rule 8 Rule of 500 1:1, EPIC-059-B 1:1 验证)"
