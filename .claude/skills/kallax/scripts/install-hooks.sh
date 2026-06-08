#!/usr/bin/env bash
# KALLAX install-hooks.sh -- EPIC-016-P
# Standalone installer for ~/.claude/skills/kallax/hooks/session_start.sh
# Used by the lean skill's Step 2 (1-call self-bootstrap).
# Standalone usage: bash scripts/install-hooks.sh
set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.}"
INSTALL_DIR="${HOME}/.claude/skills/kallax/hooks"
SOURCE_SCRIPT="${KALLAX_ROOT}/.kallax/hooks/session_start.sh"

mkdir -p "${INSTALL_DIR}"

if [ ! -f "${SOURCE_SCRIPT}" ]; then
  echo "[install-hooks] FAIL: source not found at ${SOURCE_SCRIPT}" >&2
  echo "[install-hooks] Hint: run from the project root containing .kallax/hooks/session_start.sh" >&2
  exit 1
fi

if [ -f "${INSTALL_DIR}/session_start.sh" ]; then
  echo "[install-hooks] already installed at ${INSTALL_DIR}/session_start.sh — skipping"
  exit 0
fi

cp "${SOURCE_SCRIPT}" "${INSTALL_DIR}/session_start.sh"
chmod +x "${INSTALL_DIR}/session_start.sh"
echo "[install-hooks] installed ${SOURCE_SCRIPT} -> ${INSTALL_DIR}/session_start.sh"
