#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SCRIPT_DIR}/../lib/output.sh"
TEST_PROJECT="/tmp/onramp-render-test-$$"

mkdir -p "${TEST_PROJECT}"
echo "test" > "${TEST_PROJECT}/README.md"

# Mock claude for pre-assess
MOCK_CLAUDE="/tmp/mock-claude-$$"
cat > "${MOCK_CLAUDE}" <<'EOF'
#!/usr/bin/env bash
printf '{"scale":"small","domain":"backend","research_value":"low","roi":1}'
EOF
chmod +x "${MOCK_CLAUDE}"

# Mock summon to return a real expert path
MOCK_SUMMON="/tmp/mock-summon-$$"
cat > "${MOCK_SUMMON}" <<'EOF'
#!/usr/bin/env bash
cat <<JSON
{"summoned":[{"role":"architect","skill_path":"/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/default/architect.md"}]}
JSON
EOF
chmod +x "${MOCK_SUMMON}"

# Run output.sh with mocks
PATH="${MOCK_CLAUDE}:${MOCK_SUMMON}:${PATH}" result=$(bash "${OUTPUT}" '{"choice":"A"}' '{"summoned":[{"role":"architect","skill_path":"/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/default/architect.md"}]}' "${TEST_PROJECT}" 2>/dev/null)
output_file=$(echo "${result}" | jq -r '.output_path')

# Verify: no {{ }} placeholders
if grep -q "{{" "${output_file}"; then
  echo "FAIL: placeholders still in output"
  grep "{{" "${output_file}" | head -3
  rm -rf "${TEST_PROJECT}" "${MOCK_CLAUDE}" "${MOCK_SUMMON}"
  exit 1
fi

# Verify: contains project name
grep -q "onramp-render-test" "${output_file}" || grep -q "test" "${output_file}"

rm -rf "${TEST_PROJECT}" "${MOCK_CLAUDE}" "${MOCK_SUMMON}"
echo "render-test PASS"
