#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_ASSESS="${SCRIPT_DIR}/../lib/pre-assess.sh"

# Mock scan.json
SCAN_JSON='{"project":"kallax","loc":45230,"files":287,"modules":5,"has_claude_md":true,"has_readme":true,"git_log_days":14,"language_mix":"TS:60,Shell:30,MD:10","smell_indicators":["no_tests"]}'

# Mock claude CLI (跟"反讽" 联合, mock 不靠真实 API)
MOCK_DIR=$(mktemp -d)
cat > "${MOCK_DIR}/claude" <<'EOF'
#!/usr/bin/env bash
# Mock LLM 输出
cat <<JSON
{"scale":"medium","domain":"backend","research_value":"high","roi":4,"rationale":"Mock 评估"}
JSON
EOF
chmod +x "${MOCK_DIR}/claude"
export PATH="${MOCK_DIR}:${PATH}"

result=$(bash "${PRE_ASSESS}" "${SCAN_JSON}" "接手重构")
echo "${result}" | jq -e '.scale == "medium"' > /dev/null
echo "${result}" | jq -e '.roi >= 1 and .roi <= 5' > /dev/null
echo "${result}" | jq -e '.research_value' > /dev/null

rm -rf "${MOCK_DIR}"
echo "pre-assess-test PASS"