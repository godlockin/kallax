#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTE="${SCRIPT_DIR}/../lib/route.sh"

# Test 1: 输入 A → 输出 A
result=$(echo "A" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "A"' > /dev/null

# Test 2: 输入 y → 输出推荐方案
result=$(echo "y" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "B"' > /dev/null

# Test 3: 输入 C → 进入自选模式 (mock 自选 reply "architect,security")
result=$(printf "C\narchitect,security\n" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "CUSTOM"' > /dev/null
echo "${result}" | jq -e '(.experts | length) == 2' > /dev/null

# Test 4: 输入 n → 输出 CANCEL
result=$(echo "n" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "CANCEL"' > /dev/null

echo "route-test PASS"