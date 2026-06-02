#!/usr/bin/env bash
# /kallax-analyze — Analyze project structure and dependencies

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Project Analysis"

require_git_repo

TARGET="${1:-.}"

echo "  Analyzing: ${TARGET}"
echo ""

# File type breakdown
echo "  ${BOLD}File Distribution${NC}"
echo ""

TOTAL_FILES=$(find "$TARGET" -type f \
  ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/target/*' ! -path '*/dist/*' \
  2>/dev/null | wc -l | tr -d ' ')

TS_FILES=$(find "$TARGET" -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l | tr -d ' ')
RS_FILES=$(find "$TARGET" -name '*.rs' 2>/dev/null | wc -l | tr -d ' ')
SH_FILES=$(find "$TARGET" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
MD_FILES=$(find "$TARGET" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
JSON_FILES=$(find "$TARGET" -name '*.json' -o -name '*.yaml' -o -name '*.yml' 2>/dev/null | wc -l | tr -d ' ')

echo "  TypeScript:  ${TS_FILES}"
echo "  Rust:        ${RS_FILES}"
echo "  Shell:       ${SH_FILES}"
echo "  Markdown:    ${MD_FILES}"
echo "  Config:      ${JSON_FILES}"
echo "  Total:       ${TOTAL_FILES}"
echo ""

# Git stats
echo "  ${BOLD}Git Summary${NC}"
echo ""

COMMITS=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
BRANCHES=$(git branch 2>/dev/null | wc -l | tr -d ' ')
CONTRIBUTORS=$(git shortlog -sn 2>/dev/null | wc -l | tr -d ' ')
LAST_COMMIT=$(git log -1 --format="%ar" 2>/dev/null)

echo "  Commits:       ${COMMITS}"
echo "  Branches:      ${BRANCHES}"
echo "  Contributors:  ${CONTRIBUTORS}"
echo "  Last commit:   ${LAST_COMMIT}"
echo ""

# Dependencies
echo "  ${BOLD}Dependencies${NC}"
echo ""

if [ -f "package.json" ]; then
  DEPS=$(grep -c '"' package.json 2>/dev/null || echo "0")
  echo "  Node.js:  $(node -v 2>/dev/null || echo 'not installed')"
  echo "  Packages: $(grep -c '"@' package.json 2>/dev/null || echo '0') dependencies"
fi

if [ -f "Cargo.toml" ]; then
  echo "  Rust:     $(rustc --version 2>/dev/null || echo 'not installed')"
fi

echo ""

# Structure
echo "  ${BOLD}Project Structure${NC}"
echo ""

# Show top-level dirs
find . -maxdepth 1 -type d ! -name '.*' ! -name node_modules ! -name target 2>/dev/null | sort | while read -r d; do
  NAME=$(basename "$d")
  if [ "$NAME" != "." ]; then
    COUNT=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  ${NAME}/  (${COUNT} files)"
  fi
done

echo ""
echo "  Saved: ${KALLAX_DIR}/inbox/analysis_$(date +%Y%m%d).md"
echo ""
