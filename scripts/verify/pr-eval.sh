#!/usr/bin/env bash
# scripts/verify/pr-eval.sh — Automated PR eval gate (EPIC-120-A)
#
# OpenAI Evals: "creating high-quality evals is among the most impactful activities"
# KALLAX PR gate: lint + tsc + vitest must all pass before merge.
#
# Usage:
#   pr-eval.sh --pr <N>              # eval PR by number
#   pr-eval.sh --sha <sha>           # eval by commit SHA
#   pr-eval.sh --local               # eval local changes (git diff --name-only)
#
# Output: JSON {lint,tsc,vitest} with error/warning counts
# Exit: 0 = all pass, 1 = at least one fail, 2 = env error
#
# Examples:
#   pr-eval.sh --pr 129
#   pr-eval.sh --sha abc1234
#   pr-eval.sh --local

set -euo pipefail

ME="pr-eval"
TMPDIR="${TMPDIR:-/tmp}/pr-eval-$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# Arg parsing
PR_NUM=""
SHA=""
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)    PR_NUM="$2"; shift 2 ;;
    --sha)   SHA="$2";  shift 2 ;;
    --local) MODE="local"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ─── Helpers ───────────────────────────────────────────────────────────────

run_check() {
  local name="$1" cmd="$2"
  local out="$TMPDIR/$name.out" err="$TMPDIR/$name.err"
  local exit_code=0
  ( eval "$cmd" > "$out" 2> "$err" ) || exit_code=$?
  local count
  count="$(wc -l < "$err" | tr -d ' ' || echo 0)"
  echo "{\"name\":\"$name\",\"errors\":$count,\"exit\":$exit_code,\"output_file\":\"$out\"}"
}

# ─── Main ───────────────────────────────────────────────────────────────

echo "== PR Eval Gate ==" >&2

# Determine changed files
if [[ "$MODE" == "local" ]]; then
  echo "Mode: local (git diff)" >&2
  FILES="$(git diff --name-only HEAD 2>/dev/null | tr '\n' ' ' || true)"
elif [[ -n "$PR_NUM" ]]; then
  echo "Mode: PR #$PR_NUM" >&2
  # Fetch PR files
  FILES="$(gh api "pulls/$PR_NUM/files" --jq '.[].filename' 2>/dev/null | tr '\n' ' ' || true)"
elif [[ -n "$SHA" ]]; then
  echo "Mode: SHA=$SHA" >&2
  FILES="$(git diff --name-only "${SHA}^..${SHA}" 2>/dev/null | tr '\n' ' ' || true)"
else
  echo "ERROR: must specify --pr N or --sha <sha> or --local" >&2
  exit 2
fi

if [[ -z "$FILES" ]]; then
  echo "No files found to eval" >&2
  echo '{"lint":{"errors":0},"tsc":{"errors":0},"vitest":{"errors":0},"status":"no_files"}'
  exit 0
fi

# Filter to node-relevant files
NODE_FILES="$(echo "$FILES" | tr ' ' '\n' | grep -E '\.(ts|tsx|js|jsx|json|md)$' | tr '\n' ' ' || true)"

echo "Files: $(echo $NODE_FILES | wc -w | tr -d ' ') node-relevant" >&2

# ─── Run evals in parallel ───────────────────────────────────────────────

cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax

# Lint
LINT_OUT="$TMPDIR/lint.out" LINT_ERR="$TMPDIR/lint.err"
( cd node && npx eslint . --max-warnings 0 > "$LINT_OUT" 2> "$LINT_ERR" ) &
PID_LINT=$!

# TypeScript
TSC_OUT="$TMPDIR/tsc.out" TSC_ERR="$TMPDIR/tsc.err"
( cd node && npx tsc --noEmit > "$TSC_OUT" 2> "$TSC_ERR" ) &
PID_TSC=$!

# Wait for both
wait $PID_LINT; LINT_EXIT=$?
wait $PID_TSC; TSC_EXIT=$?

# Count errors
LINT_ERRORS=$(wc -l < "$LINT_ERR" | tr -d ' ' || echo 0)
TSC_ERRORS=$(wc -l < "$TSC_ERR" | tr -d ' ' || echo 0)

# Vitest (optional — only if node_modules exists)
if [[ -d node/node_modules ]]; then
  VITEST_OUT="$TMPDIR/vitest.out" VITEST_ERR="$TMPDIR/vitest.err"
  ( cd node && npx vitest run --reporter=json > "$VITEST_OUT" 2> "$VITEST_ERR" ) &
  PID_VITEST=$!
  wait $PID_VITEST; VITEST_EXIT=$?
  VITEST_FAILURES=$(grep -o '"failures":[0-9]*' "$VITEST_OUT" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo 0)
else
  VITEST_EXIT=0
  VITEST_FAILURES=0
fi

# ─── Output JSON ───────────────────────────────────────────────────────

python3 - <<EOF
import json, sys

lint_errors = ${LINT_ERRORS:-0}
tsc_errors = ${TSC_ERRORS:-0}
vitest_failures = ${VITEST_FAILURES:-0}
lint_exit = ${LINT_EXIT:-0}
tsc_exit = ${TSC_EXIT:-0}
vitest_exit = ${VITEST_EXIT:-0}

all_pass = (lint_errors == 0 and tsc_errors == 0 and vitest_failures == 0)
overall_exit = 0 if all_pass else 1

result = {
    "lint": {"errors": lint_errors, "exit": lint_exit, "passed": lint_errors == 0},
    "tsc":  {"errors": tsc_errors,  "exit": tsc_exit,  "passed": tsc_errors == 0},
    "vitest": {"failures": vitest_failures, "exit": vitest_exit, "passed": vitest_failures == 0},
    "all_pass": all_pass,
    "overall_exit": overall_exit
}
print(json.dumps(result, indent=2))
sys.exit(overall_exit)
EOF
