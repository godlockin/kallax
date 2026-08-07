#!/usr/bin/env bash
# tests/integration/decision-cleanup-test.sh
# EPIC-196 cherry-pick: 验证 mcp-bridge + decision-cleanup-test 关键文件落地
set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== EPIC-196 cherry-pick verification ==="

# T1: mcp-bridge-backlog.md 存在 + 含关键内容
if [ -f "confluence/research/mcp-bridge-backlog.md" ] \
   && grep -q "MCP Bridge Backlog" "confluence/research/mcp-bridge-backlog.md"; then
  pass "T1 mcp-bridge-backlog.md 存在"
else
  fail "T1 mcp-bridge-backlog.md 缺失"
fi

# T2: 此测试脚本本身存在且可执行
if [ -x "tests/integration/decision-cleanup-test.sh" ]; then
  pass "T2 decision-cleanup-test.sh 存在且可执行"
else
  fail "T2 decision-cleanup-test.sh 缺失或不可执行"
fi

# T3: confluence/research/ 目录存在
if [ -d "confluence/research/" ]; then
  pass "T3 confluence/research/ 目录存在"
else
  fail "T3 confluence/research/ 缺失"
fi

# T4: index.md 存在且可读
if [ -f "confluence/decisions/index.md" ] && [ -s "confluence/decisions/index.md" ]; then
  pass "T4 index.md 存在且非空"
else
  fail "T4 index.md 缺失或空"
fi

# T5: EPIC-196 拍板记录 (本 cherry-pick 提交后写)
if [ -f "confluence/decisions/EPIC-196-cleanup-2026-08-07.md" ]; then
  pass "T5 EPIC-196 拍板记录存在"
else
  fail "T5 EPIC-196 拍板记录缺失"
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1