#!/usr/bin/env bash
# scripts/kallax-onramp/lib/dispatch.sh — EPIC-057-B
# Dispatch LLM pre-assess to the detected AI CLI tool.
# Source: tool-detect.sh sets KALLAX_DETECTED_TOOL + KALLAX_DETECTED_BINARY etc.
# Input: $1 = scan.json (raw, from onramp Step 1 scan.sh)
# Output: stdout = pre-assess JSON (or '{}' on failure, 跟 onramp 原 fallback 联合)
#
# Tool invocation matrix (实测 help — AC#3):
#   claude:   claude --print "<prompt>"             (--print / -p)
#   opencode: opencode run "<prompt>"               (subcommand, no --non-interactive flag)
#   codex:    codex exec "<prompt>"                 (binary 缺失 → fallback claude)
#   gemini:   gemini "<prompt>"                     (positional, default one-shot)
#
# 跟"反讽" 闭环, 跟 Rule 4 Fail Fast 联合, 跟 Rule 8 Observable 联合

set -uo pipefail

# Locate tool-detect.sh relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DETECT_SH="${SCRIPT_DIR}/tool-detect.sh"

# Source tool-detect.sh (gives us detect_tool + env vars)
# shellcheck disable=SC1091
source "${TOOL_DETECT_SH}"

SCAN_JSON="${1:-}"

if [[ -z "${SCAN_JSON}" ]]; then
  echo "ERROR: dispatch.sh requires scan.json as arg 1" >&2
  echo '{}'
  exit 0  # exit 0 + echo '{}' 跟 onramp 现有 fallback 语义一致
fi

# ── Run detect_tool to populate KALLAX_DETECTED_TOOL + JSON output ──
# IMPORTANT: Must run in CURRENT shell (not subshell) so env vars propagate.
# Subshell $(...) would isolate the KALLAX_DETECTED_* assignments.
# We capture stdout via temp file to suppress the JSON output (we want only
# the LLM response on stdout, not the detect JSON).
DETECT_TMP=$(mktemp)
set +e
detect_tool > "${DETECT_TMP}" 2>/dev/null
DETECT_RC=$?
set -e

if [[ ${DETECT_RC} -ne 0 ]]; then
  # detect_tool already printed error to stderr. Echo '{}' to stdout (跟 onramp fallback 联合)
  echo "WARN: tool detection failed, falling back to '{}'" >&2
  rm -f "${DETECT_TMP}"
  echo '{}'
  exit 0
fi
# Validate KALLAX_DETECTED_TOOL is set (set -u safety)
if [[ -z "${KALLAX_DETECTED_TOOL:-}" ]]; then
  echo "WARN: detect_tool succeeded but KALLAX_DETECTED_TOOL unset" >&2
  rm -f "${DETECT_TMP}"
  echo '{}'
  exit 0
fi
rm -f "${DETECT_TMP}"

# ── Construct pre-assess prompt (跟 onramp 原 Step 2 语义一致) ──
PROMPT="基于以下项目扫描数据, 输出 JSON:
{
  \"scale\": \"small/medium/large/huge\",
  \"domain\": \"backend/frontend/fullstack/ml/data/infra/mixed\",
  \"research_value\": \"low/medium/high/critical\",
  \"roi\": 1-5,
  \"rationale\": \"<100 字理由>\"
}

扫描数据: ${SCAN_JSON}"

# ── Dispatch by tool (实测 invocation — AC#3) ──
RESPONSE=""
case "${KALLAX_DETECTED_TOOL}" in
  claude)
    # claude --print <prompt> — 原 onramp 写法, 实测 2.1.153
    RESPONSE=$("${KALLAX_DETECTED_BINARY}" --print "${PROMPT}" 2>/dev/null) || RESPONSE=""
    ;;
  opencode)
    # opencode run <message..> — 实测 1.17.7 (没有 --non-interactive flag)
    RESPONSE=$("${KALLAX_DETECTED_BINARY}" run "${PROMPT}" 2>/dev/null) || RESPONSE=""
    ;;
  codex)
    # codex exec <prompt> — 假设 exec subcommand 存在 (binary 缺失时 fallback)
    # 实测: codex binary 缺失于本机 PATH; 保留 exec 假设作为 paper-over
    if [[ -x "${KALLAX_DETECTED_BINARY}" ]]; then
      RESPONSE=$("${KALLAX_DETECTED_BINARY}" exec "${PROMPT}" 2>/dev/null) || RESPONSE=""
    else
      echo "WARN: codex binary not executable, falling back" >&2
      RESPONSE=""
    fi
    ;;
  gemini)
    # gemini <prompt> — 实测 0.22.2 (positional query 默认 one-shot, -i 是 interactive)
    RESPONSE=$("${KALLAX_DETECTED_BINARY}" "${PROMPT}" 2>/dev/null) || RESPONSE=""
    ;;
  *)
    echo "WARN: unknown detected tool: ${KALLAX_DETECTED_TOOL}" >&2
    RESPONSE=""
    ;;
esac

# ── Fallback on empty response (跟 onramp 原 || echo '{}' 语义一致) ──
if [[ -z "${RESPONSE}" ]]; then
  echo "WARN: ${KALLAX_DETECTED_TOOL} returned empty, using '{}' fallback" >&2
  echo '{}'
  exit 0
fi

echo "${RESPONSE}"
exit 0
