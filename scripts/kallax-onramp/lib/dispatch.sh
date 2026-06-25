#!/usr/bin/env bash
# scripts/kallax-onramp/lib/dispatch.sh — EPIC-057-B (8-tool expansion)
# Dispatch LLM pre-assess to the detected AI CLI tool.
# Source: tool-detect.sh sets KALLAX_DETECTED_TOOL + KALLAX_DETECTED_BINARY etc.
# Input: $1 = scan.json (raw, from onramp Step 1 scan.sh)
# Output: stdout = pre-assess JSON (or '{}' on failure, 跟 onramp 原 fallback 联合)
#
# Tool invocation matrix (实测 help — 跟 LESSON 5 联合, 0 ticket-fideism):
#   claude:      claude --print "<prompt>"            (--print / -p, 2.1.153 实测)
#   trae:        trae chat "<prompt>"                  (chat subcommand, 1.107.1 实测, VS Code fork)
#   antigravity: ❌ IDE-based, no non-interactive CLI   (不进入 dispatch, fall back to '{}')
#   opencode:    opencode run "<prompt>"               (run subcommand, 1.17.7 实测, no --non-interactive flag)
#   codex:       codex exec "<prompt>"                 (exec subcommand 假设, binary 缺失 → fallback)
#   gemini:      gemini "<prompt>"                     (positional, 0.22.2 实测, default one-shot)
#   cursor:      ❌ IDE-based, no non-interactive CLI   (不进入 dispatch, fall back to '{}')
#   windsurf:    ❌ IDE-based, no non-interactive CLI   (不进入 dispatch, fall back to '{}')
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
# 跟 LESSON 2 ($(subshell) 不传播 env var) 联合
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

# ── Dispatch by tool (实测 invocation — 8 工具 case) ──
# 8 cases: 5 real-CLI (claude/trae/opencode/codex/gemini) + 3 IDE-based fallthrough (antigravity/cursor/windsurf)
RESPONSE=""
case "${KALLAX_DETECTED_TOOL}" in
  claude)
    # claude --print <prompt> — 原 onramp 写法, 实测 2.1.153
    RESPONSE=$("${KALLAX_DETECTED_BINARY}" --print "${PROMPT}" 2>/dev/null) || RESPONSE=""
    ;;
  trae)
    # trae chat <prompt> — 实测 1.107.1 (VS Code fork with chat subcommand)
    # Mode default: 'agent'. 跟 claude 一样传 prompt 作为 positional arg.
    RESPONSE=$("${KALLAX_DETECTED_BINARY}" chat "${PROMPT}" 2>/dev/null) || RESPONSE=""
    ;;
  antigravity)
    # IDE-based (Electron app at /Applications/Antigravity.app/), no CLI for non-interactive prompts.
    # Even if .antigravity/ config dir exists, the binary in $PATH would be the editor GUI,
    # not a prompt CLI. Explicit fallback (跟 onramp 原 || echo '{}' 语义一致).
    echo "WARN: antigravity is IDE-based, no non-interactive prompt CLI; falling back to '{}'" >&2
    RESPONSE=""
    ;;
  opencode)
    # opencode run <message..> — 实测 1.17.7 (没有 --non-interactive flag, subcommand 是 run)
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
  cursor)
    # IDE-based editor, no non-interactive prompt CLI exposed.
    # Cursor's CLI is mostly for the editor itself, not LLM prompts.
    # Explicit fallback to preserve onramp semantic.
    echo "WARN: cursor is IDE-based, no non-interactive prompt CLI; falling back to '{}'" >&2
    RESPONSE=""
    ;;
  windsurf)
    # IDE-based editor (Codeium), no non-interactive prompt CLI exposed.
    # Explicit fallback to preserve onramp semantic.
    echo "WARN: windsurf is IDE-based, no non-interactive prompt CLI; falling back to '{}'" >&2
    RESPONSE=""
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
