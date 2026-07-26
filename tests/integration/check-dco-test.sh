#!/usr/bin/env bash
# tests/integration/check-dco-test.sh — EPIC-137-C
# 3 scenarios: all-signed / missing-signoff / forged-email.
# Runs check-dco.sh against a throwaway git repo in /tmp.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK="$REPO_ROOT/scripts/check-dco.sh"

if [ ! -x "$CHECK" ]; then
  echo "FAIL: $CHECK not executable" >&2
  exit 1
fi

TMP="$(mktemp -d -t check-dco-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
TOTAL=3

section() { printf '\n=== %s ===\n' "$1"; }

# ------------------------------------------------------------------
# Helper: init a fresh repo with a base commit on 'base' branch
# ------------------------------------------------------------------
init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -q -b base
  git config user.name "Alice"
  git config user.email "a@k.io"
  git config commit.gpgsign false
  echo "seed" > seed.txt
  git add seed.txt
  # Sign the base commit too so base ref itself is clean (not needed for range,
  # but keeps intent obvious).
  GIT_COMMITTER_NAME="Alice" GIT_COMMITTER_EMAIL="a@k.io" \
    git commit -q -m "base commit

Signed-off-by: Alice <a@k.io>"
  git checkout -q -b feat
}

# ------------------------------------------------------------------
# Scenario 1: all signed → exit 0, 3/3 PASS
# ------------------------------------------------------------------
section "Scenario 1: all signed"
S1="$TMP/s1"
(
  init_repo "$S1"
  for i in 1 2 3; do
    echo "c$i" > "f$i.txt"
    git add "f$i.txt"
    git commit -q -m "commit $i

Signed-off-by: Alice <a@k.io>"
  done
)

cd "$S1"
S1_OUT=$("$CHECK" --base base --head HEAD 2>&1) && S1_EXIT=0 || S1_EXIT=$?
echo "$S1_OUT"
echo "exit=$S1_EXIT"
if [ "$S1_EXIT" -eq 0 ] && echo "$S1_OUT" | grep -q "3/3 commits PASS"; then
  echo "S1: PASS"
  PASS=$((PASS + 1))
else
  echo "S1: FAIL — expected exit 0 + '3/3 commits PASS'"
fi

# ------------------------------------------------------------------
# Scenario 2: one unsigned (middle commit) → exit 1, 2/3 PASS
# ------------------------------------------------------------------
section "Scenario 2: middle commit missing signoff"
S2="$TMP/s2"
(
  init_repo "$S2"
  # commit 1 — signed
  echo c1 > f1.txt && git add f1.txt
  git commit -q -m "commit 1

Signed-off-by: Alice <a@k.io>"
  # commit 2 — UNSIGNED (use --no-verify so any local hooks don't append)
  echo c2 > f2.txt && git add f2.txt
  git commit -q --no-verify -m "commit 2 unsigned"
  # commit 3 — signed
  echo c3 > f3.txt && git add f3.txt
  git commit -q -m "commit 3

Signed-off-by: Alice <a@k.io>"
)

cd "$S2"
BAD_SHA=$(git log --format='%H' --no-merges | sed -n '2p' | cut -c1-8)
S2_OUT=$("$CHECK" --base base --head HEAD 2>&1) && S2_EXIT=0 || S2_EXIT=$?
echo "$S2_OUT"
echo "exit=$S2_EXIT"
echo "bad_sha=$BAD_SHA"
if [ "$S2_EXIT" -eq 1 ] \
   && echo "$S2_OUT" | grep -q "2/3 commits PASS" \
   && echo "$S2_OUT" | grep -qE "^\[✗\] $BAD_SHA .* missing-signoff"; then
  echo "S2: PASS"
  PASS=$((PASS + 1))
else
  echo "S2: FAIL — expected exit 1 + '2/3 commits PASS' + '[✗] $BAD_SHA ... missing-signoff'"
fi

# ------------------------------------------------------------------
# Scenario 3: forged trailer (email mismatch) → exit 1, email-mismatch reason
# ------------------------------------------------------------------
section "Scenario 3: forged Signed-off-by email"
S3="$TMP/s3"
(
  init_repo "$S3"
  # Committer ident stays Alice <a@k.io>, but trailer claims fake@evil
  echo c1 > f1.txt && git add f1.txt
  git commit -q --no-verify -m "commit 1 forged

Signed-off-by: X <fake@evil>"
)

cd "$S3"
S3_OUT=$("$CHECK" --base base --head HEAD 2>&1) && S3_EXIT=0 || S3_EXIT=$?
echo "$S3_OUT"
echo "exit=$S3_EXIT"
if [ "$S3_EXIT" -eq 1 ] \
   && echo "$S3_OUT" | grep -q "0/1 commits PASS" \
   && echo "$S3_OUT" | grep -q "email-mismatch:fake@evil≠a@k.io"; then
  echo "S3: PASS"
  PASS=$((PASS + 1))
else
  echo "S3: FAIL — expected exit 1 + '0/1 commits PASS' + 'email-mismatch:fake@evil≠a@k.io'"
fi

# ------------------------------------------------------------------
section "Summary"
printf 'PASS %d/%d\n' "$PASS" "$TOTAL"
if [ "$PASS" -eq "$TOTAL" ]; then
  exit 0
fi
exit 1
