#!/bin/bash
# expert-list-injection.sh — Test SQL injection prevention in expert-list.sh
# Tests 5 attack vectors: ' ; -- \n

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIST_SCRIPT="$REPO_ROOT/scripts/expert-list.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=== expert-list.sh SQL Injection Tests ==="
echo ""

# Test 1: Single quote injection
echo -n "Test 1: Single quote in TIER... "
if bash "$LIST_SCRIPT" --tier "default'" 2>/dev/null; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 2: Semicolon injection (command chaining)
echo -n "Test 2: Semicolon in DOMAIN... "
if bash "$LIST_SCRIPT" --domain "test; DROP TABLE" 2>/dev/null; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 3: Double dash (SQL comment)
echo -n "Test 3: Double dash in TIER... "
if bash "$LIST_SCRIPT" --tier "default--" 2>/dev/null; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 4: Backslash injection
echo -n "Test 4: Backslash in DOMAIN... "
if bash "$LIST_SCRIPT" --domain "test\\" 2>/dev/null; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 5: Newline injection
echo -n "Test 5: Newline in TIER... "
if bash "$LIST_SCRIPT" --tier $'default\n' 2>/dev/null; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 6: Valid input should still work
echo -n "Test 6: Valid input (tier=default)... "
if bash "$LIST_SCRIPT" --tier "default" --count >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC} (accepted valid input)"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC} (rejected valid input)"
  ((FAIL++))
fi

# Test 7: Valid domain should work
echo -n "Test 7: Valid domain (domain=k8s)... "
if bash "$LIST_SCRIPT" --domain "k8s" --count >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC} (accepted valid input)"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC} (rejected valid input)"
  ((FAIL++))
fi

echo ""
echo "Results: $PASS/$((PASS+FAIL)) PASS"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAIL test(s) failed${NC}"
  exit 1
fi