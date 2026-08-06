#!/usr/bin/env bash
# Final-review regressions: portable paths, emergency test bypass, jq escaping.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE="${ROOT}/scripts/lib/workspace.sh"
BRANCH_FLOW="${ROOT}/scripts/branch-4pr.sh"
PERFORMER="${ROOT}/scripts/performer-complete.sh"

# workspace.sh: existing and missing paths work; absolute and traversal paths fail.
workspace_test_root="$(mktemp -d)"
trap 'rm -rf "${workspace_test_root}"' EXIT
source "${WORKSPACE}"
workspace_init "${workspace_test_root}"
workspace_fs_write 'nested/file.txt' 'portable'
[[ "$(workspace_fs_read 'nested/file.txt')" == 'portable' ]]
workspace_fs_exists 'missing.txt' && exit 1 || true
workspace_fs_read '../outside.txt' >/dev/null 2>&1 && exit 1 || true
workspace_fs_write '/tmp/absolute.txt' 'blocked' >/dev/null 2>&1 && exit 1 || true

# branch-4pr.sh: --skip-tests is emergency-only and requires a reason.
if bash "${BRANCH_FLOW}" feature/test --skip-tests --dry-run >/dev/null 2>&1; then
  echo 'FAIL: --skip-tests accepted without emergency reason' >&2
  exit 1
fi
if bash "${BRANCH_FLOW}" feature/test --skip-tests --emergency '' --dry-run >/dev/null 2>&1; then
  echo 'FAIL: empty emergency reason accepted' >&2
  exit 1
fi
grep -Fq 'cargo test --workspace --release' "${BRANCH_FLOW}"
grep -Fq 'EMERGENCY_REASON' "${BRANCH_FLOW}"

# performer-complete.sh: dynamic jq values must be passed as arguments.
grep -Fq 'jq --arg now "${NOW}" --arg branch "${BRANCH}"' "${PERFORMER}"
grep -Fq 'jq --arg pr_url "${PR_URL}" --arg now "${NOW}" --arg branch "${BRANCH}"' "${PERFORMER}"
if grep -Eq 'jq "[^\n]*(NOW|BRANCH|PR_URL)' "${PERFORMER}"; then
  echo 'FAIL: interpolated dynamic jq filter remains' >&2
  exit 1
fi

echo 'PASS: final-review regressions'
