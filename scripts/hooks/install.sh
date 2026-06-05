#!/usr/bin/env bash
# KALLAX Git Hooks Installer
# Installs the pre-commit hook that protects the miao branch.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="${REPO_ROOT}/scripts/hooks"
HOOKS_DIR="${REPO_ROOT}/.git/hooks"

echo "==> KALLAX Hook Installer"

# Install pre-commit
if [ -f "${HOOKS_SRC}/pre-commit" ]; then
  cp "${HOOKS_SRC}/pre-commit" "${HOOKS_DIR}/pre-commit"
  chmod +x "${HOOKS_DIR}/pre-commit"
  echo "  ✓ pre-commit installed (protects miao from direct code changes)"
else
  echo "  ✗ pre-commit source not found at ${HOOKS_SRC}/pre-commit"
  exit 1
fi

echo ""
echo "Hooks installed. The miao branch is now protected:"
echo "  - Only Conductor can operate on miao"
echo "  - No direct source code changes on miao"
echo "  - All code must flow through: feature/* → testing → miao"
