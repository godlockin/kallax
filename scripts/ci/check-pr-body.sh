#!/usr/bin/env bash
# check-pr-body.sh — Validate KALLAX PR body against 7-class risk schema
# Source: EPIC-138-B (borrow-from-cindy pr-template-rules.yml, bash flavor)
# Rules aligned with .github/PULL_REQUEST_TEMPLATE.md (EPIC-138-A)
#
# Input priority: $1 file > stdin > $PR_BODY env var
# Output: human-readable errors, then final line "PASS" (exit 0) or "FAIL: ..." (exit 1)

set -u

# --- Input resolution ---
BODY=""
if [ "${1:-}" != "" ] && [ -f "$1" ]; then
  BODY=$(cat "$1")
elif [ ! -t 0 ]; then
  BODY=$(cat)
elif [ "${PR_BODY:-}" != "" ]; then
  BODY="$PR_BODY"
else
  echo "ERROR: no PR body provided (arg1 file / stdin / \$PR_BODY)" >&2
  echo "FAIL: no-input"
  exit 1
fi

if [ -z "$BODY" ]; then
  echo "ERROR: PR body is empty" >&2
  echo "FAIL: empty-body"
  exit 1
fi

# --- Exact headings (must match PR template verbatim) ---
RISK_HEADINGS=(
  "### 1. 5-Level Verify (L2)"
  "### 2. state.json 边界"
  "### 3. worktree 隔离"
  "### 4. Dead-code sentinel"
  "### 5. Rule / immutable script"
  "### 6. Rust ↔ Node 边界"
  "### 7. 跨 EPIC 复用"
)

REASONS=()

# --- A. 7 risk sections all present ---
for h in "${RISK_HEADINGS[@]}"; do
  if ! printf '%s\n' "$BODY" | grep -Fxq "$h"; then
    REASONS+=("missing-risk-section:$h")
  fi
done

# --- B. Each risk section: either `- [x]` or `不涉及: <reason ≥5 chars>` ---
# Iterate section-by-section using awk to extract block between heading N and next `###` or `---` or `## `
TMPBODY=$(mktemp)
printf '%s\n' "$BODY" > "$TMPBODY"

check_risk_block() {
  local heading="$1"
  local next_pattern='^(### [0-9]+\.|---|## )'
  # Extract the block after heading until the next boundary
  local block
  block=$(awk -v h="$heading" -v np="$next_pattern" '
    BEGIN { inblk=0 }
    {
      if (inblk && $0 ~ np) { exit }
      if (inblk) print $0
      if ($0 == h) { inblk=1 }
    }
  ' "$TMPBODY")

  # Check for `- [x]` (checked) — case-insensitive x/X
  if printf '%s\n' "$block" | grep -qE '^\s*-\s*\[[xX]\]'; then
    return 0
  fi

  # Check for `不涉及: <reason>` with ≥5 chars after the colon
  # Accept ASCII `:` or fullwidth `：`; also allow leading `- [ ] 不涉及:` prefix
  local reason
  reason=$(printf '%s\n' "$block" | grep -oE '不涉及[:：][^<]*' | head -1 | sed -E 's/^不涉及[:：]//' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  # Strip a literal `<原因>` placeholder if it's the whole content
  if [ "$reason" = "<原因>" ] || [ -z "$reason" ]; then
    return 1
  fi
  # Length check (chars, not bytes; use wc -m)
  local len
  len=$(printf '%s' "$reason" | wc -m | tr -d ' ')
  if [ "$len" -lt 5 ]; then
    return 1
  fi
  return 0
}

for h in "${RISK_HEADINGS[@]}"; do
  # skip if already flagged missing
  if printf '%s\n' "$BODY" | grep -Fxq "$h"; then
    if ! check_risk_block "$h"; then
      REASONS+=("unchecked-and-no-reason:$h")
    fi
  fi
done

# --- C. `## 自动验证 (raw output)` must exist AND contain ≥1 fenced code block ---
AUTO_HEADING="## 自动验证 (raw output)"
if ! printf '%s\n' "$BODY" | grep -Fxq "$AUTO_HEADING"; then
  REASONS+=("missing-section:$AUTO_HEADING")
else
  # Extract block between `## 自动验证 (raw output)` and next `## ` heading
  auto_block=$(awk -v h="$AUTO_HEADING" '
    BEGIN { inblk=0 }
    {
      if (inblk && $0 ~ /^## /) { exit }
      if (inblk) print $0
      if ($0 == h) { inblk=1 }
    }
  ' "$TMPBODY")

  # Count fenced code blocks: pairs of ```
  fence_count=$(printf '%s\n' "$auto_block" | grep -cE '^```')
  # Need at least 2 fence markers (opening + closing) for ≥1 block
  if [ "$fence_count" -lt 2 ]; then
    REASONS+=("no-code-block-in-auto-verify:fence_count=$fence_count")
  else
    # Check at least one code block has non-empty content between fences
    has_content=$(printf '%s\n' "$auto_block" | awk '
      BEGIN { infence=0; content="" }
      /^```/ {
        if (infence) {
          if (content ~ /[^[:space:]]/) { print "yes"; exit }
          content=""
          infence=0
        } else {
          infence=1
        }
        next
      }
      { if (infence) content = content $0 "\n" }
    ')
    if [ "$has_content" != "yes" ]; then
      REASONS+=("empty-code-block-in-auto-verify")
    fi
  fi
fi

# --- D. `## 手工验证` and `## 未执行验证` must exist ---
for sec in "## 手工验证" "## 未执行验证"; do
  if ! printf '%s\n' "$BODY" | grep -Fxq "$sec"; then
    REASONS+=("missing-section:$sec")
  fi
done

# --- E. `## 摘要` and `## 关联 ticket` sections must have content (≥5 chars) ---
check_section_content() {
  local heading="$1"
  if ! printf '%s\n' "$BODY" | grep -Fxq "$heading"; then
    REASONS+=("missing-section:$heading")
    return
  fi
  local block
  block=$(awk -v h="$heading" '
    BEGIN { inblk=0 }
    {
      if (inblk && ($0 ~ /^## / || $0 ~ /^---$/)) { exit }
      if (inblk) print $0
      if ($0 == h) { inblk=1 }
    }
  ' "$TMPBODY")

  # Strip HTML comments and whitespace-only lines and pure `-` bullets
  content=$(printf '%s\n' "$block" \
    | sed -E 's/<!--.*-->//g' \
    | awk '/<!--/,/-->/{next} {print}' \
    | grep -vE '^\s*$' \
    | grep -vE '^\s*-\s*$' \
    | tr -d '[:space:]')

  local len
  len=$(printf '%s' "$content" | wc -m | tr -d ' ')
  if [ "$len" -lt 5 ]; then
    REASONS+=("no-content:$heading (len=$len)")
  fi
}

check_section_content "## 摘要"
check_section_content "## 关联 ticket"

rm -f "$TMPBODY"

# --- Verdict ---
if [ "${#REASONS[@]}" -eq 0 ]; then
  echo "PASS"
  exit 0
fi

echo "PR body validation failed:" >&2
for r in "${REASONS[@]}"; do
  echo "  - $r" >&2
done
echo "FAIL: ${#REASONS[@]} issue(s)"
exit 1
