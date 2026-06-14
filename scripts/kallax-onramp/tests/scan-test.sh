#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"
SCAN="${SCRIPT_DIR}/../lib/scan.sh"

# Test 1: mini-kallax fixture
result=$(bash "${SCAN}" "${FIXTURES}/mini-kallax")
echo "${result}" | jq -e '.project' > /dev/null
echo "${result}" | jq -e '.loc >= 0' > /dev/null
echo "${result}" | jq -e '.files >= 0' > /dev/null
echo "${result}" | jq -e '.has_claude_md == false' > /dev/null
echo "${result}" | jq -e '.has_readme == true' > /dev/null

# Test 2: nonexistent path
set +e
bash "${SCAN}" "/nonexistent/path/that/does/not/exist" 2>/dev/null
exit_code=$?
set -e
if [[ ${exit_code} -ne 2 ]]; then
  echo "ERROR: scan.sh should exit 2 on missing path, got ${exit_code}" >&2
  exit 1
fi

echo "scan-test PASS"