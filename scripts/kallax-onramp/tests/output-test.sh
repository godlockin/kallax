#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SCRIPT_DIR}/../lib/output.sh"
TEST_PROJECT="/tmp/onramp-test-$$"

mkdir -p "${TEST_PROJECT}"
echo "test" > "${TEST_PROJECT}/README.md"

# Test 1: L1 输出
result=$(bash "${OUTPUT}" '{"choice":"A","experts":["architect"]}' '{"summoned":[{"role":"architect","skill_path":"/x"}]}' "${TEST_PROJECT}")
echo "${result}" | jq -e '.output_path' > /dev/null
[[ -f "$(echo "${result}" | jq -r '.output_path')" ]]

# Test 2: L2 输出
result=$(bash "${OUTPUT}" '{"choice":"B","experts":["architect","backend"]}' '{"summoned":[{"role":"architect","skill_path":"/x"}]}' "${TEST_PROJECT}")
[[ -f "$(echo "${result}" | jq -r '.output_path')" ]]

# Test 3: L3 输出 (含 3 件套)
result=$(bash "${OUTPUT}" '{"choice":"C","experts":["architect","security-tool-bypass"]}' '{"summoned":[{"role":"architect","skill_path":"/x"},{"role":"security-tool-bypass","skill_path":"/y"}]}' "${TEST_PROJECT}")
output_file=$(echo "${result}" | jq -r '.output_path')
[[ -f "${output_file}" ]]
grep -q "亮点" "${output_file}"
grep -q "缺点" "${output_file}"
grep -q "隐患" "${output_file}"

# Test 4: audit log 写入
audit_log="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/logs/onramp-$(date +%Y-%m-%d).jsonl"
[[ -f "${audit_log}" ]]

# Cleanup
rm -rf "${TEST_PROJECT}"
echo "output-test PASS"