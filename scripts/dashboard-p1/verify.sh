#!/usr/bin/env bash
# scripts/dashboard-p1/verify.sh
# EPIC-281 Phase 1 — fail-closed gate (跟 check-smoke-retention.sh 同模式, EPIC-174 辅助)
#
# render 前必跑 check-ticket-schema.sh + check-claim-evidence.sh (9-immutable 子集).
# exit ≠ 0 fail-closed.
#
# Usage:
#   bash scripts/dashboard-p1/verify.sh
#
# Exit codes:
#   0 = PASS (emit 可跑)
#   1 = FAIL (gate 失败, fail-closed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/scripts/hooks"

# 9-immutable 子集 (跟 check-smoke-retention.sh 同模式, 跑其中 2 个就够 EPIC-281 scope):
#   - check-ticket-schema.sh (EPIC-223): 验新 ticket 字段齐
#   - check-claim-evidence.sh (EPIC-069-D): 扫 README/CHANGELOG 数字
# Phase 1 emit 不写 README/CHANGELOG, 但作为 gate 强跑防意外.

FAILED=0

echo "─── dashboard-p1 verify (fail-closed gate) ───"

# ── check-ticket-schema.sh: 新 ticket (> 222) schema 齐 ──
if [[ -x "${HOOKS_DIR}/check-ticket-schema.sh" ]]; then
  echo "[1/2] check-ticket-schema.sh --all (EPIC-223)"
  if ! bash "${HOOKS_DIR}/check-ticket-schema.sh" --all >/dev/null 2>&1; then
    echo "  FAIL: check-ticket-schema.sh exit != 0 (新 ticket schema 缺字段)"
    FAILED=1
  else
    echo "  PASS"
  fi
else
  echo "  SKIP: check-ticket-schema.sh not found (hook 未安装, 跑 scripts/hooks/install.sh)"
  # EPIC-224 教训: hook 静默失效比没有 hook 更危险 — 显式 FAIL
  echo "  FAIL: hook missing, run 'bash scripts/hooks/install.sh --verify'"
  FAILED=1
fi

# ── check-claim-evidence.sh: 扫 README/CHANGELOG 数字 ──
if [[ -x "${HOOKS_DIR}/check-claim-evidence.sh" ]]; then
  echo "[2/2] check-claim-evidence.sh (EPIC-069-D)"
  if ! bash "${HOOKS_DIR}/check-claim-evidence.sh" >/dev/null 2>&1; then
    echo "  FAIL: check-claim-evidence.sh exit != 0 (README/CHANGELOG 数字无 raw_output)"
    FAILED=1
  else
    echo "  PASS"
  fi
else
  echo "  SKIP: check-claim-evidence.sh not found"
  echo "  FAIL: hook missing"
  FAILED=1
fi

# ── emit 自检 (跑 emit.sh, 验 data.json + index.html 都生成) ──
echo "[emit] 跑 emit.sh 自检"
if ! bash "${SCRIPT_DIR}/emit.sh" >/dev/null 2>&1; then
  echo "  FAIL: emit.sh exit != 0"
  FAILED=1
elif [[ ! -s "${PROJECT_ROOT}/dist/dashboard/data.json" ]]; then
  echo "  FAIL: dist/dashboard/data.json empty"
  FAILED=1
elif [[ ! -s "${PROJECT_ROOT}/dist/dashboard/index.html" ]]; then
  echo "  FAIL: dist/dashboard/index.html empty"
  FAILED=1
else
  data_size=$(wc -c < "${PROJECT_ROOT}/dist/dashboard/data.json")
  html_size=$(wc -c < "${PROJECT_ROOT}/dist/dashboard/index.html")
  echo "  PASS: data.json=${data_size}B, index.html=${html_size}B"
fi

echo "────────────────────────────────────────────────"
if [[ $FAILED -eq 0 ]]; then
  echo "OK: verify PASS"
  exit 0
else
  echo "FAILED: verify FAIL (fail-closed)"
  exit 1
fi