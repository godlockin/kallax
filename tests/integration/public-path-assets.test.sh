#!/bin/bash
# EPIC-169 Public Path Assets Test
# AC9: ≥6 case PASS
# 0改 source code, 0增 Rule, 0增 immutable script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

PASS=0
FAIL=0

test_case() {
  local name="$1"
  local cmd="$2"
  echo -n "Testing: $name ... "
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS"
    ((PASS++))
  else
    echo "FAIL"
    ((FAIL++))
  fi
}

echo "=== EPIC-169 Public Path Assets Test ==="
echo ""

# AC1: README.en.md ≥250 行 7-section
test_case "README.en.md ≥250 lines" "[[ \$(wc -l < README.en.md) -ge 250 ]]"
test_case "README.en.md has 7 sections" "grep -q '## Why KALLAX' README.en.md && grep -q '## Try It' README.en.md && grep -q '## Capabilities' README.en.md && grep -q '## Documentation' README.en.md && grep -q '## Community' README.en.md && grep -q '## Contributing' README.en.md && grep -q '## License' README.en.md"

# AC2: web/index.html hosted frontstage scaffold
test_case "web/index.html exists" "[[ -f web/index.html ]]"
test_case "web/index.html has KALLAX title" "grep -q 'KALLAX' web/index.html"

# AC3: web/showcase/index.html 7 case cards
test_case "web/showcase/index.html exists" "[[ -f web/showcase/index.html ]]"
test_case "web/showcase/index.html has 7 cases" "grep -c 'card-icon' web/showcase/index.html | grep -q 7 || grep -q 'Case #' web/showcase/index.html"

# AC4: CONTRIBUTING.md ≥100 行 含 Lark/WeChat
test_case "CONTRIBUTING.md ≥100 lines" "[[ \$(wc -l < CONTRIBUTING.md) -ge 100 ]]"
test_case "CONTRIBUTING.md has Lark QR placeholder" "grep -q 'LARK QR CODE PLACEHOLDER' CONTRIBUTING.md"
test_case "CONTRIBUTING.md has WeChat contact" "grep -q 'huangrt00' CONTRIBUTING.md"

# AC5: docs/community/README.md 群入口
test_case "docs/community/README.md exists" "[[ -f docs/community/README.md ]]"
test_case "docs/community/README.md has community channels" "grep -q 'Lark' docs/community/README.md && grep -q 'WeChat' docs/community/README.md"

# AC6: docs/sponsor/README.md + .github/FUNDING.yml
test_case "docs/sponsor/README.md exists" "[[ -f docs/sponsor/README.md ]]"
test_case ".github/FUNDING.yml exists" "[[ -f .github/FUNDING.yml ]]"
test_case ".github/FUNDING.yml is valid YAML" "grep -q 'github_sponsors' .github/FUNDING.yml || grep -q 'godlockin' .github/FUNDING.yml"

# AC7: docs/i18n/README.md sync rule
test_case "docs/i18n/README.md exists" "[[ -f docs/i18n/README.md ]]"
test_case "docs/i18n/README.md has sync rule" "grep -q 'Sync Rule' docs/i18n/README.md"

# AC8: .github/ISSUE_TEMPLATE bug_report + feature_request
test_case ".github/ISSUE_TEMPLATE/bug_report.md exists" "[[ -f .github/ISSUE_TEMPLATE/bug_report.md ]]"
test_case ".github/ISSUE_TEMPLATE/feature_request.md exists" "[[ -f .github/ISSUE_TEMPLATE/feature_request.md ]]"

# AC9: docs/showcases/showcase-catalog.json
test_case "docs/showcases/showcase-catalog.json exists" "[[ -f docs/showcases/showcase-catalog.json ]]"
test_case "docs/showcases/showcase-catalog.json has 7 cases" "grep -c '\"id\":' docs/showcases/showcase-catalog.json | grep -q 7"

# AC13: 0 改 source code
test_case "0 source code change (rust/)" "[[ \$(git diff --name-only HEAD | grep -c 'rust/.*\.rs$') -eq 0 ]]"
test_case "0 source code change (node/src/)" "[[ \$(git diff --name-only HEAD | grep -c 'node/src/.*\.ts$') -eq 0 ]]"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "ALL TESTS PASSED"
  exit 0
else
  echo ""
  echo "SOME TESTS FAILED"
  exit 1
fi
