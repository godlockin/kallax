#!/bin/bash
# expert-match-injection.sh — Test SQL injection prevention in expert-match.sh
# Tests REQUIREMENT validation (Issue 2) + L1/L2 query escape (Issue 2)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MATCH_SCRIPT="$REPO_ROOT/scripts/expert-match.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=== expert-match.sh SQL Injection Tests ==="
echo ""

# Test 1: Single quote injection in requirement
echo -n "Test 1: Single quote in requirement... "
if bash "$MATCH_SCRIPT" "安全测试' DROP TABLE" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC} (accepted dangerous input)"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 2: Semicolon injection
echo -n "Test 2: Semicolon in requirement... "
if bash "$MATCH_SCRIPT" "API; rm -rf /" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 3: Double dash (SQL comment)
echo -n "Test 3: Double dash in requirement... "
if bash "$MATCH_SCRIPT" "API-- comment" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 4: Backslash
echo -n "Test 4: Backslash in requirement... "
if bash "$MATCH_SCRIPT" "API\\path" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 5: Newline injection
echo -n "Test 5: Newline in requirement... "
if bash "$MATCH_SCRIPT" $'API\nDROP' >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 6: Double quote
echo -n "Test 6: Double quote in requirement... "
if bash "$MATCH_SCRIPT" 'API"x' >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
else
  echo -e "${GREEN}PASS${NC} (rejected)"
  ((PASS++))
fi

# Test 7: Valid Chinese input should work (regression check)
echo -n "Test 7: Valid Chinese input (数据库)... "
if bash "$MATCH_SCRIPT" "数据库" >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC} (matched)"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC} (rejected valid input)"
  ((FAIL++))
fi

# Test 8: Valid English input should work
echo -n "Test 8: Valid English input (API)... "
if bash "$MATCH_SCRIPT" "API" >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC} (matched)"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC} (rejected valid input)"
  ((FAIL++))
fi

# Test 9: Pure Chinese with no special chars
echo -n "Test 9: Pure Chinese (架构设计)... "
if bash "$MATCH_SCRIPT" "架构设计" >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC} (matched)"
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
