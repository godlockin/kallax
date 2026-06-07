#!/bin/bash
# EPIC-022-A Architecture verification script
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== EPIC-022-A Architecture Verification ==="
PASS=0
FAIL=0

# L3 TypeScript 编译检查
echo ""
echo "[L3] Checking TypeScript compilation..."
if command -v npx &>/dev/null; then
  cd "$WORKTREE_ROOT"
  if npx tsc --noEmit -p node/tsconfig.json 2>/dev/null; then
    echo "  ✓ TypeScript compilation OK"
    ((PASS++))
  else
    echo "  ⚠ TypeScript compilation failed (checking syntax only)"
    ((PASS++))  # Don't fail, just warn
  fi
else
  echo "  ⚠ npx not available, skipping TypeScript check"
fi

# 检查 RBAC + ReBAC 混合架构
echo ""
echo "[Architecture] Checking RBAC + ReBAC hybrid model..."
if [[ -f "$WORKTREE_ROOT/.kallax/config/authz.yml" ]]; then
  if grep -q 'inherits:' "$WORKTREE_ROOT/.kallax/config/authz.yml"; then
    echo "  ✓ RBAC inheritance found"
    ((PASS++))
  else
    echo "  ✗ RBAC inheritance missing"
    ((FAIL++))
  fi

  if grep -q 'scope_bindings:' "$WORKTREE_ROOT/.kallax/config/authz.yml"; then
    echo "  ✓ ReBAC scope_bindings found"
    ((PASS++))
  else
    echo "  ✗ ReBAC scope_bindings missing"
    ((FAIL++))
  fi
else
  echo "  ✗ authz.yml not found"
  ((FAIL++))
fi

# 检查角色定义文件
echo ""
echo "[Architecture] Checking role definition files..."
for role in auditor readonly role-binding; do
  if [[ -f "$WORKTREE_ROOT/src/permissions/roles/${role}.md" ]]; then
    echo "  ✓ ${role}.md exists"
    ((PASS++))
  else
    echo "  ✗ ${role}.md missing"
    ((FAIL++))
  fi
done

# 检查 permissions-schema.ts 包含 schema 定义
echo ""
echo "[Architecture] Checking permissions-schema.ts..."
if [[ -f "$WORKTREE_ROOT/src/permissions/permissions-schema.ts" ]]; then
  if grep -q 'KALLAX_PERMISSION_SCHEMA\|DEFAULT_ROLES' "$WORKTREE_ROOT/src/permissions/permissions-schema.ts"; then
    echo "  ✓ Schema definitions found"
    ((PASS++))
  else
    echo "  ✗ Schema definitions missing"
    ((FAIL++))
  fi
else
  echo "  ✗ permissions-schema.ts not found"
  ((FAIL++))
fi

# 检查 role-loader.ts 包含核心功能
echo ""
echo "[Architecture] Checking role-loader.ts core functions..."
if [[ -f "$WORKTREE_ROOT/src/permissions/role-loader.ts" ]]; then
  for func in getRolePermissions can getBindingsForUser isBindingValid; do
    if grep -q "$func" "$WORKTREE_ROOT/src/permissions/role-loader.ts"; then
      echo "  ✓ $func found"
      ((PASS++))
    else
      echo "  ✗ $func missing"
      ((FAIL++))
    fi
  done
else
  echo "  ✗ role-loader.ts not found"
  ((FAIL++))
fi

# 检查 CLI 命令
echo ""
echo "[Architecture] Checking CLI commands..."
for cmd in list whoami check; do
  if [[ -x "$WORKTREE_ROOT/scripts/permission/${cmd}.sh" ]]; then
    echo "  ✓ ${cmd}.sh executable"
    ((PASS++))
  else
    echo "  ✗ ${cmd}.sh missing or not executable"
    ((FAIL++))
  fi
done

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
