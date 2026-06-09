#!/bin/bash
# EPIC-022-A Security verification script
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §4 (P0 修复项)
#
# P0 验证项:
#   - fail-closed: 任何 authz 错误 exit 1 deny
#   - set -euo pipefail on all scripts
#   - role 名称 validation (防 trailing space, typo)
#   - 循环继承检测

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== EPIC-022-A Security Verification ==="
PASS=0
FAIL=0

# L1 存在性检查
echo ""
echo "[L1] Checking file existence..."
for file in \
  "$WORKTREE_ROOT/src/permissions/roles/auditor.md" \
  "$WORKTREE_ROOT/src/permissions/roles/readonly.md" \
  "$WORKTREE_ROOT/src/permissions/roles/role-binding.md" \
  "$WORKTREE_ROOT/src/permissions/role-loader.ts" \
  "$WORKTREE_ROOT/src/permissions/permissions-schema.ts" \
  "$WORKTREE_ROOT/scripts/permission/list.sh" \
  "$WORKTREE_ROOT/scripts/permission/whoami.sh" \
  "$WORKTREE_ROOT/scripts/permission/check.sh"; do
  if [[ -f "$file" ]]; then
    echo "  ✓ $(basename "$file")"
    ((PASS++))
  else
    echo "  ✗ MISSING: $file"
    ((FAIL++))
  fi
done

# L2 实质性检查
echo ""
echo "[L2] Checking content size (>500 bytes)..."
for file in \
  "$WORKTREE_ROOT/src/permissions/roles/auditor.md" \
  "$WORKTREE_ROOT/src/permissions/roles/readonly.md" \
  "$WORKTREE_ROOT/src/permissions/roles/role-binding.md"; do
  size=$(wc -c < "$file" 2>/dev/null || echo 0)
  if [[ "$size" -gt 500 ]]; then
    echo "  ✓ $(basename "$file") ($size bytes)"
    ((PASS++))
  else
    echo "  ✗ TOO SMALL: $(basename "$file") ($size bytes)"
    ((FAIL++))
  fi
done

# L3 接线正确性检查
echo ""
echo "[L3] Checking shell script syntax..."
for script in \
  "$WORKTREE_ROOT/scripts/permission/list.sh" \
  "$WORKTREE_ROOT/scripts/permission/whoami.sh" \
  "$WORKTREE_ROOT/scripts/permission/check.sh"; do
  if bash -n "$script" 2>/dev/null; then
    echo "  ✓ $(basename "$script") syntax OK"
    ((PASS++))
  else
    echo "  ✗ SYNTAX ERROR: $(basename "$script")"
    ((FAIL++))
  fi
done

# P0 检查: set -euo pipefail
echo ""
echo "[P0] Checking set -euo pipefail..."
for script in \
  "$WORKTREE_ROOT/scripts/permission/list.sh" \
  "$WORKTREE_ROOT/scripts/permission/whoami.sh" \
  "$WORKTREE_ROOT/scripts/permission/check.sh"; do
  if grep -q 'set -euo pipefail' "$script" 2>/dev/null; then
    echo "  ✓ $(basename "$script") has set -euo pipefail"
    ((PASS++))
  else
    echo "  ✗ MISSING set -euo pipefail: $(basename "$script")"
    ((FAIL++))
  fi
done

# P0 检查: role 名称 validation
echo ""
echo "[P0] Checking role name validation..."
if grep -q 'validateRoleName\|pattern.*^[a-z]' "$WORKTREE_ROOT/src/permissions/role-loader.ts" 2>/dev/null; then
  echo "  ✓ Role name validation found"
  ((PASS++))
else
  echo "  ✗ MISSING role name validation"
  ((FAIL++))
fi

# P0 检查: 循环继承检测
echo ""
echo "[P0] Checking circular inheritance detection..."
if grep -q 'detectCycle\|Circular inheritance' "$WORKTREE_ROOT/src/permissions/role-loader.ts" 2>/dev/null; then
  echo "  ✓ Circular inheritance detection found"
  ((PASS++))
else
  echo "  ✗ MISSING circular inheritance detection"
  ((FAIL++))
fi

# P0 检查: fail-closed (exit 1 on error)
echo ""
echo "[P0] Checking fail-closed..."
if grep -q 'DENIED' "$WORKTREE_ROOT/scripts/permission/check.sh" 2>/dev/null && grep -q 'exit 1' "$WORKTREE_ROOT/scripts/permission/check.sh" 2>/dev/null; then
  echo "  ✓ Fail-closed (exit 1 on DENIED) found in check.sh"
  ((PASS++))
else
  echo "  ✗ MISSING fail-closed pattern"
  ((FAIL++))
fi

# Summary
echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  echo "STATUS: FAILED"
  exit 1
else
  echo "STATUS: ALL PASS"
  exit 0
fi
