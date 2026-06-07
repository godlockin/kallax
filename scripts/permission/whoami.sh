#!/bin/bash
# kallax role:whoami — 显示当前角色 + 权限
#
# P0 修复项:
#   - set -euo pipefail
#   - fail-closed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 获取当前 role (从 state.json 或环境变量)
CURRENT_ROLE="${KALLAX_CURRENT_ROLE:-$(cat "$KALLAX_ROOT/.kallax/state/state.json" 2>/dev/null | jq -r '.current_role // "unknown"')}"

echo "Current role: ${CURRENT_ROLE}"

# 显示权限
case "$CURRENT_ROLE" in
  master)
    echo "Grants: miao.write, miao.merge, release.tag, instance.gc, testing.*, task.*"
    echo "Denies: (none)"
    ;;
  conductor)
    echo "Grants: testing.merge, testing.write, task.assign, instance.read, log.read"
    echo "Denies: miao.write, miao.merge"
    ;;
  performer)
    echo "Grants: task.claim, worktree.create, worktree.commit, ticket.read, log.read"
    echo "Denies: *.merge, *.write (except in worktree)"
    ;;
  readonly)
    echo "Grants: *.read"
    echo "Denies: *.write, *.commit, *.merge, task.claim, worktree.create"
    ;;
  auditor)
    echo "Grants: *.read, audit.export, instance.read, log.read"
    echo "Denies: *.write, *.merge, instance.terminate"
    ;;
  super-admin)
    echo "Grants: (all grants)"
    echo "Denies: (none)"
    ;;
  emergency-responder)
    echo "Grants: instance.terminate, super-admin grants"
    echo "Denies: (none beyond emergency scope)"
    ;;
  *)
    echo "ERROR: Unknown role: ${CURRENT_ROLE}"
    exit 1  # P0: fail-closed
    ;;
esac