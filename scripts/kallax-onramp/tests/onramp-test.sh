#!/usr/bin/env bash
# 4-Level Fact-Forcing 集成测试 (跟 Rule 9 联合, 跟"反讽" 闭环)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# kallax-onramp.sh is at scripts/kallax-onramp.sh (not in the kallax-onramp subdir)
ONRAMP="${SCRIPT_DIR}/../../kallax-onramp.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

# L1 存在性: 12 文件存在
[[ -f "${SCRIPT_DIR}/../../kallax-onramp.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/scan.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/pre-assess.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/recommend.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/route.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/summon.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/output.sh" ]]
[[ -f "${SCRIPT_DIR}/../templates/L1-light.md" ]]
[[ -f "${SCRIPT_DIR}/../templates/L2-deep.md" ]]
[[ -f "${SCRIPT_DIR}/../templates/L3-audit.md" ]]
[[ -f "${SCRIPT_DIR}/onramp-test.sh" ]]
echo "L1 PASS: 12 文件存在"

# L2 实质性: 跑 6 单元测试
bash "${SCRIPT_DIR}/scan-test.sh"
bash "${SCRIPT_DIR}/pre-assess-test.sh"
bash "${SCRIPT_DIR}/recommend-test.sh"
bash "${SCRIPT_DIR}/route-test.sh"
bash "${SCRIPT_DIR}/summon-test.sh"
bash "${SCRIPT_DIR}/output-test.sh"
echo "L2 PASS: 6 单元测试通过"

# L3 接线正确: 跑 mini-kallax 走完
# Mock claude with --print support
MOCK_DIR=$(mktemp -d)
cat > "${MOCK_DIR}/claude" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--print" ]]; then
  printf '{"scale":"small","domain":"backend","research_value":"low","roi":1,"rationale":"Mock mini"}\n'
else
  echo "mock claude: unknown arg ${1:-}" >&2
  exit 1
fi
EOF
chmod +x "${MOCK_DIR}/claude"
export PATH="${MOCK_DIR}:${PATH}"

# Mock 主公输入 "A" via pipe
result=$(echo "A" | bash "${ONRAMP}" "${FIXTURES}/mini-kallax" "lightweight" 2>&1)
echo "${result}" | grep -q "ONRAMP-mini-kallax"
echo "L3 PASS: mini-kallax 走完"

# L4 数据流动: 跑 medium + large 走完
result=$(echo "y" | bash "${ONRAMP}" "${FIXTURES}/medium-project" "refactor" 2>&1)
echo "${result}" | grep -q "ONRAMP-medium-project"

result=$(printf "C\ngeneralist\n" | bash "${ONRAMP}" "${FIXTURES}/large-project" "audit" 2>&1)
echo "${result}" | grep -q "ONRAMP-large-project"
echo "L4 PASS: medium + large 走完"

# Cleanup
rm -rf "${MOCK_DIR}"
echo "onramp-test PASS (4-Level)"