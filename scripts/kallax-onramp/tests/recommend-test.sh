#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOMMEND="${SCRIPT_DIR}/../lib/recommend.sh"

# Test 1: 高 ROI → C
SCAN='{"loc":50000,"files":300}'
PRE_ASSESS='{"roi":5,"research_value":"critical"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "C"' > /dev/null
echo "${result}" | jq -e '.expert_count == 10' > /dev/null

# Test 2: 中 ROI → B
PRE_ASSESS='{"roi":3,"research_value":"medium"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "B"' > /dev/null
echo "${result}" | jq -e '.expert_count >= 3 and .expert_count <= 5' > /dev/null

# Test 3: 低 ROI → A
PRE_ASSESS='{"roi":1,"research_value":"low"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "A"' > /dev/null
echo "${result}" | jq -e '.expert_count == 1' > /dev/null

# Test 4: pre-assess 缺失 → fallback
result=$(bash "${RECOMMEND}" "${SCAN}" "")
echo "${result}" | jq -e '.recommendation' > /dev/null

echo "recommend-test PASS"