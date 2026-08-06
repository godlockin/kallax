#!/bin/bash
# EPIC-172 Public Coordination Assets Integration Test
# AC10: ≥6 case PASS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

echo "=== EPIC-172 Public Coordination Assets Test ==="
echo ""

# AC1: Lark group entrance exists
test_lark_entrace() {
  if [ -f "docs/community/lark-qr-placeholder.md" ]; then
    echo "[PASS] AC1: Lark group entrance exists"
    ((PASS++))
  else
    echo "[FAIL] AC1: Lark group entrance missing"
    ((FAIL++))
  fi
}

# AC2: WeChat group entrance exists
test_wechat_entrace() {
  if [ -f "docs/community/wechat-qr-placeholder.md" ]; then
    echo "[PASS] AC2: WeChat group entrance exists"
    ((PASS++))
  else
    echo "[FAIL] AC2: WeChat group entrance missing"
    ((FAIL++))
  fi
}

# AC3: Hosted frontstage web/index.html exists
test_web_index() {
  if [ -f "web/index.html" ]; then
    echo "[PASS] AC3: web/index.html exists"
    ((PASS++))
  else
    echo "[FAIL] AC3: web/index.html missing"
    ((FAIL++))
  fi
}

# AC4: Showcase gallery exists
test_showcase_gallery() {
  if [ -f "web/showcase/index.html" ]; then
    echo "[PASS] AC4: web/showcase/index.html exists"
    ((PASS++))
  else
    echo "[FAIL] AC4: web/showcase/index.html missing"
    ((FAIL++))
  fi
}

# AC5: Growth loop document exists
test_growth_loop() {
  if [ -f "docs/community/growth-loop.md" ]; then
    echo "[PASS] AC5: Growth loop document exists"
    ((PASS++))
  else
    echo "[FAIL] AC5: Growth loop document missing"
    ((FAIL++))
  fi
}

# AC6: confluence/research has ≥200 lines
test_confluence_research() {
  local file="confluence/research/kallax-growth-loop-2026-08-05.md"
  if [ -f "$file" ]; then
    local lines=$(wc -l < "$file")
    if [ "$lines" -ge 200 ]; then
      echo "[PASS] AC6: confluence/research ≥200 lines (actual: $lines)"
      ((PASS++))
    else
      echo "[FAIL] AC6: confluence/research <200 lines (actual: $lines)"
      ((FAIL++))
    fi
  else
    echo "[FAIL] AC6: confluence/research file missing"
    ((FAIL++))
  fi
}

# AC7: ICP 4 types mentioned
test_icp_mentions() {
  local file="docs/community/growth-loop.md"
  if grep -q "ICP 1" "$file" && \
     grep -q "ICP 2" "$file" && \
     grep -q "ICP 3" "$file" && \
     grep -q "ICP 4" "$file"; then
    echo "[PASS] AC7: ICP 1-4 mentioned in growth-loop.md"
    ((PASS++))
  else
    echo "[FAIL] AC7: ICP types not properly mentioned"
    ((FAIL++))
  fi
}

# Run all tests
test_lark_entrace
test_wechat_entrace
test_web_index
test_showcase_gallery
test_growth_loop
test_confluence_research
test_icp_mentions

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "All tests PASSED"
  exit 0
else
  echo "Some tests FAILED"
  exit 1
fi
