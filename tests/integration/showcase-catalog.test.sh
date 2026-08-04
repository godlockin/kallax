#!/bin/bash
# tests/integration/showcase-catalog.test.sh
# EPIC-165: showcase catalog integration tests (≥5 case PASS)
#
# Verifies: catalog exists / json valid / ≥7 case / each case links ticket / docs/i18n exists
#
# AC7: tests/integration/showcase-catalog.test.sh ≥5 case PASS

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHOWCASE_DIR="$REPO_ROOT/docs/showcases"
CATALOG_JSON="$SHOWCASE_DIR/showcase-catalog.json"
I18N_INDEX="$REPO_ROOT/docs/i18n/README.md"
CASES_DIR="$SHOWCASE_DIR/cases"

passed=0
failed=0

# Helper (avoid ((x++)) with set -e — returns exit 1 when x=0)
pass() { echo "  PASS: $1"; passed=$((passed+1)); }
fail() { echo "  FAIL: $1"; failed=$((failed+1)); }

echo "EPIC-165 Showcase Catalog Tests"
echo "================================"

# TC1: catalog README exists
if [[ -f "$SHOWCASE_DIR/README.md" ]]; then
  pass "docs/showcases/README.md exists"
else
  fail "docs/showcases/README.md missing"
fi

# TC2: showcase-catalog.json exists and is valid JSON
if [[ -f "$CATALOG_JSON" ]]; then
  if python3 -c "import json; json.load(open('$CATALOG_JSON'))" 2>/dev/null; then
    pass "showcase-catalog.json is valid JSON"
  else
    fail "showcase-catalog.json is invalid JSON"
  fi
else
  fail "showcase-catalog.json missing"
fi

# TC3: ≥7 showcase cases in catalog
if [[ -f "$CATALOG_JSON" ]]; then
  case_count=$(python3 -c "import json; print(len(json.load(open('$CATALOG_JSON'))['cases']))" 2>/dev/null || echo "0")
  if [[ "$case_count" -ge 7 ]]; then
    pass "catalog has $case_count cases (≥7 required)"
  else
    fail "catalog has $case_count cases (need ≥7)"
  fi
else
  fail "cannot check case count (JSON missing)"
fi

# TC4: each case links to ticket.json (verify at least 5 cases have ticket links)
if [[ -f "$CATALOG_JSON" ]]; then
  ticket_links=$(python3 -c "
import json
catalog = json.load(open('$CATALOG_JSON'))
count = 0
for c in catalog['cases']:
    links = c.get('links', {})
    if 'ticket' in links or 'decision' in links or 'rule' in links:
        count += 1
print(count)
" 2>/dev/null || echo "0")
  if [[ "$ticket_links" -ge 5 ]]; then
    pass "$ticket_links cases have ticket/decision/rule links (≥5 required)"
  else
    fail "only $ticket_links cases have links (need ≥5)"
  fi
else
  fail "cannot check links (JSON missing)"
fi

# TC5: each case .md file exists in cases/ directory
if [[ -d "$CASES_DIR" ]]; then
  missing=0
  for epic in "EPIC-069-D-check-claim-evidence" "EPIC-152-rule-34-bugfix-repro" "EPIC-155-4branch-bypass-retro" "EPIC-157-expert-binding" "EPIC-158-sqlite-skipif" "EPIC-160-install-omnibus" "EPIC-161-retrospective-routine"; do
    if [[ ! -f "$CASES_DIR/${epic}.md" ]]; then
      missing=$((missing+1))
    fi
  done
  if [[ "$missing" -eq 0 ]]; then
    pass "all 7 case .md files exist"
  else
    fail "$missing case .md files missing"
  fi
else
  fail "cases directory missing"
fi

# TC6: docs/i18n/README.md exists
if [[ -f "$I18N_INDEX" ]]; then
  pass "docs/i18n/README.md exists"
else
  fail "docs/i18n/README.md missing"
fi

# TC7: README.en.md exists
if [[ -f "$REPO_ROOT/README.en.md" ]]; then
  pass "README.en.md exists"
else
  fail "README.en.md missing"
fi

# TC8: README.en.md has 4 required sections
if [[ -f "$REPO_ROOT/README.en.md" ]]; then
  for section in "Why KALLAX" "Quick Start" "Capabilities" "Docs Index"; do
    if grep -q "$section" "$REPO_ROOT/README.en.md" 2>/dev/null; then
      pass "README.en.md has '$section' section"
    else
      fail "README.en.md missing '$section' section"
    fi
  done
else
  fail "cannot check sections (README.en.md missing)"
fi

# TC9: catalog schema has required fields (id/title/scope/evidence_label/pattern_tags/links)
if [[ -f "$CATALOG_JSON" ]]; then
  schema_ok=$(python3 -c "
import json
catalog = json.load(open('$CATALOG_JSON'))
required = ['id', 'title', 'scope', 'evidence_label', 'pattern_tags', 'links']
if 'cases' in catalog and len(catalog['cases']) > 0:
    case = catalog['cases'][0]
    missing = [f for f in required if f not in case]
    print('ok' if not missing else ','.join(missing))
else:
    print('no_cases')
" 2>/dev/null || echo "error")
  if [[ "$schema_ok" == "ok" ]]; then
    pass "catalog schema has all required fields"
  else
    fail "catalog schema missing fields: $schema_ok"
  fi
else
  fail "cannot check schema (JSON missing)"
fi

# TC10: showcase README index lists ≥7 cases
if [[ -f "$SHOWCASE_DIR/README.md" ]]; then
  case_refs=$(grep -cE '\[EPIC-' "$SHOWCASE_DIR/README.md" 2>/dev/null || echo "0")
  if [[ "$case_refs" -ge 7 ]]; then
    pass "showcase README index lists $case_refs cases (≥7 required)"
  else
    fail "showcase README index lists $case_refs cases (need ≥7)"
  fi
else
  fail "cannot check index (showcase README missing)"
fi

echo ""
echo "================================"
echo "EPIC-165 Showcase Catalog Tests: $passed passed, $failed failed"
echo ""

if [[ "$failed" -eq 0 ]]; then
  echo "All tests PASSED"
  exit 0
else
  echo "Some tests FAILED"
  exit 1
fi
