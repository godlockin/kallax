#!/usr/bin/env bash
# tests/integration/dco-hook-test.sh
# EPIC-137-B — validate .githooks/prepare-commit-msg (5 scenarios)
#
# Each scenario spins a temp git repo, copies the hook, runs the hook
# directly (not via `git commit`, to control $COMMIT_SOURCE precisely
# in scenarios 3), and asserts on the message-file contents.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK="${REPO_ROOT}/.githooks/prepare-commit-msg"

if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook not executable: $HOOK" >&2
  exit 2
fi

PASS=0
FAIL=0
RESULTS=""

record() {
  # $1 = name, $2 = ok|fail, $3 = detail
  local name="$1" status="$2" detail="$3"
  if [ "$status" = "ok" ]; then
    PASS=$((PASS + 1))
    RESULTS="${RESULTS}PASS  ${name}  ${detail}
"
  else
    FAIL=$((FAIL + 1))
    RESULTS="${RESULTS}FAIL  ${name}  ${detail}
"
  fi
}

# Fresh scratch dir
SCRATCH="$(mktemp -d -t kallax-dco-hook-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

setup_repo() {
  # $1 = subdir name
  local d="$SCRATCH/$1"
  mkdir -p "$d"
  cd "$d"
  git init -q -b main
  git config user.name "Alice Committer"
  git config user.email "alice@kallax.test"
  git config commit.gpgsign false
  # Reset any inherited trailer config for a clean baseline
  git config --unset-all trailer.ifExists 2>/dev/null || true
  echo "$d"
}

# ─────────────────────────────────────────────────────────────
# Scenario 1: empty commit -m "feat: x" → trailer appended
# ─────────────────────────────────────────────────────────────
scenario_1() {
  local dir; dir=$(setup_repo s1); cd "$dir"
  local msg=".git/COMMIT_EDITMSG"
  printf 'feat: x\n' > "$msg"
  # Simulate `git commit -m` invocation: source = "message"
  "$HOOK" "$msg" "message"
  if grep -q '^Signed-off-by: Alice Committer <alice@kallax.test>$' "$msg"; then
    record "S1-empty-commit-m"       "ok"   "trailer appended"
  else
    record "S1-empty-commit-m"       "fail" "trailer missing; content=$(tr '\n' '|' < "$msg")"
  fi
}

# ─────────────────────────────────────────────────────────────
# Scenario 2: already has Signed-off-by → do NOT duplicate
# ─────────────────────────────────────────────────────────────
scenario_2() {
  local dir; dir=$(setup_repo s2); cd "$dir"
  local msg=".git/COMMIT_EDITMSG"
  cat > "$msg" <<'EOF'
feat: y

Body line here.

Signed-off-by: Bob Prior <bob@prior.test>
EOF
  "$HOOK" "$msg" "message"
  local n
  n=$(grep -c '^Signed-off-by:' "$msg" || true)
  if [ "$n" = "1" ] && grep -q '^Signed-off-by: Bob Prior <bob@prior.test>$' "$msg"; then
    record "S2-already-signed"       "ok"   "single trailer preserved (n=$n)"
  else
    record "S2-already-signed"       "fail" "expected 1 trailer, got $n; content=$(tr '\n' '|' < "$msg")"
  fi
}

# ─────────────────────────────────────────────────────────────
# Scenario 3: merge commit source → skip (no trailer)
# ─────────────────────────────────────────────────────────────
scenario_3() {
  local dir; dir=$(setup_repo s3); cd "$dir"
  local msg=".git/MERGE_MSG"
  cat > "$msg" <<'EOF'
Merge branch 'feature/x'
EOF
  "$HOOK" "$msg" "merge"
  if grep -q '^Signed-off-by:' "$msg"; then
    record "S3-merge-skip"           "fail" "trailer wrongly added for merge; content=$(tr '\n' '|' < "$msg")"
  else
    record "S3-merge-skip"           "ok"   "merge commit exempt"
  fi
}

# ─────────────────────────────────────────────────────────────
# Scenario 4: --author=Other → trailer uses COMMITTER, not author
# ─────────────────────────────────────────────────────────────
scenario_4() {
  local dir; dir=$(setup_repo s4); cd "$dir"
  # Simulate `git commit --author="Other Person <other@x.test>" -m "feat"`
  # We can't easily invoke real git commit here (hook is what we're
  # testing), but the hook resolves NAME/EMAIL via `git config user.*`
  # regardless of --author. So we assert exactly that: hook uses
  # user.name / user.email (committer ident), NOT any author override.
  # We further stress this by setting GIT_AUTHOR_* env to a different
  # identity when invoking the hook.
  local msg=".git/COMMIT_EDITMSG"
  printf 'feat: cherry-picked change\n' > "$msg"
  GIT_AUTHOR_NAME="Other Person" \
  GIT_AUTHOR_EMAIL="other@x.test" \
    "$HOOK" "$msg" "message"
  if grep -q '^Signed-off-by: Alice Committer <alice@kallax.test>$' "$msg" && \
     ! grep -q 'other@x.test' "$msg"; then
    record "S4-committer-not-author" "ok"   "signed as committer (Alice), not author (Other)"
  else
    record "S4-committer-not-author" "fail" "wrong identity; content=$(tr '\n' '|' < "$msg")"
  fi
}

# ─────────────────────────────────────────────────────────────
# Scenario 5: local trailer.ifExists=doNothing + body → hook still appends
# ─────────────────────────────────────────────────────────────
scenario_5() {
  local dir; dir=$(setup_repo s5); cd "$dir"
  git config trailer.ifExists doNothing
  local msg=".git/COMMIT_EDITMSG"
  cat > "$msg" <<'EOF'
feat: z

Some body text.
EOF
  "$HOOK" "$msg" "message"
  if grep -q '^Signed-off-by: Alice Committer <alice@kallax.test>$' "$msg"; then
    record "S5-trailer-config-override" "ok"   "explicit --if-exists overrode local config"
  else
    record "S5-trailer-config-override" "fail" "hook silently bypassed; content=$(tr '\n' '|' < "$msg")"
  fi
}

# ─── Run all ─────────────────────────────────────────────────
scenario_1
scenario_2
scenario_3
scenario_4
scenario_5

echo ""
echo "── DCO Hook Test Results ──────────────────────────────"
printf '%s' "$RESULTS"
echo "───────────────────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
echo "PASS ${PASS}/${TOTAL}"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
