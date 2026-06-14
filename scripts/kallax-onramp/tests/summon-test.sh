#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUMMON="${SCRIPT_DIR}/../lib/summon.sh"

# Test 1: 1 Architect (L1)
result=$(bash "${SUMMON}" '{"choice":"A","experts":["architect"]}')
echo "${result}" | jq -e '(.summoned | length) == 1' > /dev/null
echo "${result}" | jq -e '.summoned[0].role == "architect"' > /dev/null
echo "${result}" | jq -e '.summoned[0].skill_path' > /dev/null

# Test 2: 5 default (L2)
result=$(bash "${SUMMON}" '{"choice":"B","experts":["architect","backend","frontend","ux","product"]}')
echo "${result}" | jq -e '(.summoned | length) == 5' > /dev/null

# Test 3: 5+5 = 10 (L3)
result=$(bash "${SUMMON}" '{"choice":"C","experts":["architect","backend","frontend","ux","product","security-tool-bypass","process-engineering-self-verify","auditor-independent-witness","compliance-rule-merge","decision-gate-complex-only"]}')
echo "${result}" | jq -e '(.summoned | length) == 10' > /dev/null

# Test 4: 缺专家 → 降级 (不重试)
result=$(bash "${SUMMON}" '{"choice":"B","experts":["nonexistent-expert"]}')
echo "${result}" | jq -e '(.summoned | length) == 0' > /dev/null
echo "${result}" | jq -e '.warnings | length > 0' > /dev/null

echo "summon-test PASS"