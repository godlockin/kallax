#!/usr/bin/env bash
# KALLAX check-dco.sh — DCO Signed-off-by validator (EPIC-137-C)
#
# Purpose:
#   Local pre-push / PR-time self-check for DCO Signed-off-by trailers.
#   Complement to .githooks/prepare-commit-msg (EPIC-137-B) which appends
#   the trailer, and .github/dco.yml which is the server-side enforcer.
#
# Contract (must match prepare-commit-msg + DCO app):
#   - Trailer format: `Signed-off-by: NAME <EMAIL>` (case-sensitive, ": " sep)
#   - Trailer email MUST equal committer email (defends against forged sign-off:
#     someone hand-adding `Signed-off-by: X <x@y>` while committer ident differs)
#   - Merge commits exempt (matches hook: source=merge)
#   - Multiple Signed-off-by lines OK (co-author / remediation)
#   - Zero Signed-off-by lines = FAIL
#
# Usage: scripts/check-dco.sh [--base <ref>] [--head <ref>] [--allow-pre-cutoff <sha>] [-v] [--help]

set -eu

BASE="miao"
HEAD="HEAD"
VERBOSE=0

# Default DCO cutoff SHA: PR #148 merge commit (v3.29.0 landed 2026-07-26).
# DCO went live from this commit; older commits on miao (EPIC-133/134/135 series)
# predate the sign-off mechanism and are grandfathered via --allow-pre-cutoff.
# Rationale: without this, first PR to newly-synced testing would fail on
# base-branch history it did not author. See EPIC-142 CLAUDE.md record.
KALLAX_DCO_CUTOFF="7187bb5704bb34596c64728ab1fd461191d10f83"
CUTOFF_SHA=""

usage() {
  cat <<'EOF'
Usage: scripts/check-dco.sh [--base <ref>] [--head <ref>] [--allow-pre-cutoff <sha>] [-v] [--help]

Validate DCO Signed-off-by trailers on all non-merge commits in <base>..<head>.

Options:
  --base <ref>                Base ref to diff from (default: miao; falls back to origin/miao)
  --head <ref>                Head ref to diff to   (default: HEAD)
  --allow-pre-cutoff [<sha>]  Skip DCO check for commits that are ancestors of <sha>
                              (default cutoff: KALLAX_DCO_CUTOFF, PR #148 merge = v3.29.0).
                              Rationale: commits before DCO cutoff are grandfathered
                              (they predate the sign-off mechanism). Skipped commits
                              are silent and do not count in the PASS/TOTAL summary.
  -v, --verbose               Print each PASS commit (default: silent for PASS)
  -h, --help                  Show this help and exit 0

Exit codes:
  0  all checked commits signed OR no commits in range
  1  one or more commits fail DCO check
  2  usage error / base ref not found

Examples:
  scripts/check-dco.sh                              # check HEAD vs miao
  scripts/check-dco.sh --base origin/miao           # explicit remote base
  scripts/check-dco.sh --base main --head feature/x # arbitrary range
  scripts/check-dco.sh -v                           # print PASS commits too
  scripts/check-dco.sh --allow-pre-cutoff           # skip commits <= default cutoff (PR #148)
  scripts/check-dco.sh --allow-pre-cutoff abc1234   # skip commits <= abc1234
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base)   BASE="${2:-}"; shift 2 || { echo "check-dco: --base requires arg" >&2; exit 2; } ;;
    --head)   HEAD="${2:-}"; shift 2 || { echo "check-dco: --head requires arg" >&2; exit 2; } ;;
    --allow-pre-cutoff)
      # Optional-arg flag: next positional is used only if it doesn't look like another flag.
      if [ $# -ge 2 ] && [ -n "${2:-}" ] && [ "${2#-}" = "$2" ]; then
        CUTOFF_SHA="$2"
        shift 2
      else
        CUTOFF_SHA="$KALLAX_DCO_CUTOFF"
        shift
      fi
      ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "check-dco: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Resolve base ref: try as-is, then origin/<base> as fallback
if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
  if git rev-parse --verify --quiet "origin/$BASE" >/dev/null; then
    BASE="origin/$BASE"
  else
    echo "check-dco: base ref not found: $BASE (also tried origin/$BASE)" >&2
    exit 2
  fi
fi

if ! git rev-parse --verify --quiet "$HEAD" >/dev/null; then
  echo "check-dco: head ref not found: $HEAD" >&2
  exit 2
fi

# Resolve cutoff SHA if grace policy engaged. Unknown SHA disables the grace
# (treat as if no cutoff was requested) rather than failing the whole check.
# EPIC-198: 允许多个 cutoff SHA (逗号分隔), 跟 EPIC-142 branch-flow-history 1:1
CUTOFF_RESOLVED=""
if [ -n "$CUTOFF_SHA" ]; then
  IFS=',' read -ra CUTOFFS <<< "$CUTOFF_SHA"
  for c in "${CUTOFFS[@]}"; do
    if git rev-parse --verify --quiet "${c}^{commit}" >/dev/null; then
      CUTOFF_RESOLVED="${CUTOFF_RESOLVED} $(git rev-parse "${c}^{commit}")"
    else
      echo "check-dco: --allow-pre-cutoff SHA unknown ($c), grace disabled" >&2
    fi
  done
fi

# Enumerate non-merge commits in range (oldest first for readable output)
COMMITS=$(git log --no-merges --reverse --format='%H' "$BASE..$HEAD" 2>/dev/null || true)

TOTAL=0
PASS=0
FAIL_LINES=""

# Extract email from a Signed-off-by trailer line.
# Portable across BSD sed (macOS) and GNU sed (Linux).
# Input on stdin: full commit message. Output: unique trailer emails, one per line.
extract_signoff_emails() {
  grep -E '^Signed-off-by: .+<[^>]+>' | sed -E 's/.*<([^>]+)>.*/\1/' || true
}

if [ -n "$COMMITS" ]; then
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue

    # Pre-cutoff skip: commit is an ancestor of any cutoff SHA (inclusive).
    # Silent skip — commit not counted in TOTAL/PASS/FAIL.
    if [ -n "$CUTOFF_RESOLVED" ]; then
      SKIP=0
      for cutoff in $CUTOFF_RESOLVED; do
        if git merge-base --is-ancestor "$sha" "$cutoff" 2>/dev/null; then
          SKIP=1
          break
        fi
      done
      if [ "$SKIP" -eq 1 ]; then
        continue
      fi
    fi

    TOTAL=$((TOTAL + 1))

    subject=$(git log --format='%s' -n 1 "$sha")
    # Truncate subject to 40 chars for output alignment
    subj40=$(printf '%s' "$subject" | cut -c1-40)
    sha8=$(printf '%s' "$sha" | cut -c1-8)

    body=$(git log --format='%B' -n 1 "$sha")
    committer_email=$(git log --format='%ce' -n 1 "$sha")

    # Gather all Signed-off-by trailer emails
    signoff_emails=$(printf '%s\n' "$body" | extract_signoff_emails)

    if [ -z "$signoff_emails" ]; then
      FAIL_LINES="${FAIL_LINES}[✗] ${sha8} ${subj40}  missing-signoff
"
      continue
    fi

    # Check if any Signed-off-by email matches committer email
    matched=0
    first_trailer_email=""
    while IFS= read -r sigmail; do
      [ -n "$sigmail" ] || continue
      [ -z "$first_trailer_email" ] && first_trailer_email="$sigmail"
      if [ "$sigmail" = "$committer_email" ]; then
        matched=1
        break
      fi
    done <<EOF
$signoff_emails
EOF

    if [ "$matched" -eq 1 ]; then
      PASS=$((PASS + 1))
      if [ "$VERBOSE" -eq 1 ]; then
        printf '[✓] %s %s\n' "$sha8" "$subj40"
      fi
    else
      FAIL_LINES="${FAIL_LINES}[✗] ${sha8} ${subj40}  email-mismatch:${first_trailer_email}≠${committer_email}
"
    fi
  done <<EOF
$COMMITS
EOF
fi

# Print failures (if any)
if [ -n "$FAIL_LINES" ]; then
  printf '%s' "$FAIL_LINES"
fi

printf 'check-dco: %d/%d commits PASS (base=%s, head=%s)\n' "$PASS" "$TOTAL" "$BASE" "$HEAD"

if [ "$TOTAL" -eq 0 ]; then
  exit 0
fi

if [ "$PASS" -eq "$TOTAL" ]; then
  exit 0
fi

exit 1
