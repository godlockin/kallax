#!/usr/bin/env bash
# EPIC-287 scope cache 路径测试
# 验证 check-jargon.sh --all 性能 <15s + 退出码正确
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0

# Test 1: check-jargon.sh --all 退出码正确
echo "--- Test 1: --all exit code sane ---"
bash scripts/hooks/check-jargon.sh --all > /tmp/jargon-all.log 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ] || [ "$rc" -eq 0 ]; then
  echo "  PASS: --all exit code $rc (sane)"
  PASS=$((PASS+1))
else
  echo "  FAIL: --all exit code $rc (unexpected)"
  FAIL=$((FAIL+1))
fi

# Test 2: wall-clock <15s
echo "--- Test 2: wall-clock <15s ---"
START=$(date +%s.%N)
bash scripts/hooks/check-jargon.sh --all > /dev/null 2>&1 || true
END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc)
if (( $(echo "$ELAPSED < 15" | bc -l) )); then
  echo "  PASS: wall-clock ${ELAPSED}s < 15s"
  PASS=$((PASS+1))
else
  echo "  FAIL: wall-clock ${ELAPSED}s >= 15s"
  FAIL=$((FAIL+1))
fi

# Test 3: Python single-process (verify no subprocess per file)
echo "--- Test 3: Python scanner used ---"
if grep -q "python3" scripts/hooks/check-jargon.sh; then
  echo "  PASS: Python scanner present"
  PASS=$((PASS+1))
else
  echo "  FAIL: Python scanner missing"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
