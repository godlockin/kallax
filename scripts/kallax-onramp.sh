#!/usr/bin/env bash
# KALLAX Onramp — 项目分析入口
# Step 1: Scan → Step 2: Pre-assess → Step 3: Route → Step 4: Summon → Step 5: Output
# 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟 Rule 5 DRY 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_LIB="${SCRIPT_DIR}/kallax-onramp/lib"
ONRAMP_DIR="$(cd "$(dirname "${SCRIPT_DIR}")" && pwd)"

# ---- Step 1: Scan ----
PROJECT_PATH="${1:-}"
MODE="${2:-lightweight}"

if [[ -z "${PROJECT_PATH}" || ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: project path required" >&2
  exit 1
fi

echo "==> Step 1: Scanning ${PROJECT_PATH}..." >&2
SCAN_DATA=$(bash "${ONRAMP_LIB}/scan.sh" "${PROJECT_PATH}")
loc=$(echo "${SCAN_DATA}" | jq -r '.loc')
files=$(echo "${SCAN_DATA}" | jq -r '.files')
modules=$(echo "${SCAN_DATA}" | jq -r '.modules')
language_mix=$(echo "${SCAN_DATA}" | jq -r '.language_mix')
has_claude_md=$(echo "${SCAN_DATA}" | jq -r '.has_claude_md')
has_readme=$(echo "${SCAN_DATA}" | jq -r '.has_readme')
git_log_days=$(echo "${SCAN_DATA}" | jq -r '.git_log_days')
smell_indicators=$(echo "${SCAN_DATA}" | jq -r '.smell_indicators')

# ---- Step 2: Pre-assess + Recommend ----
# EPIC-057-B: dispatch to detected tool (claude/opencode/codex/gemini).
# Replaces hardcoded `claude --print` with tool-detect + dispatch.
# Fallback (on detect fail or tool fail) = '{}'  (跟原 onramp 语义一致).
echo "==> Step 2: Pre-assessing..." >&2
PRE_ASSESS_JSON=$(bash "${ONRAMP_LIB}/dispatch.sh" "${SCAN_DATA}")
RECOMMEND_JSON=$(bash "${ONRAMP_LIB}/recommend.sh" "${SCAN_DATA}" "${PRE_ASSESS_JSON}")

# ---- Step 3: Route (ask user) ----
echo "==> Step 3: Routing..." >&2
CHOICE_JSON=$(bash "${ONRAMP_LIB}/route.sh" "${RECOMMEND_JSON}" < /dev/stdin)

choice=$(echo "${CHOICE_JSON}" | jq -r '.choice')
if [[ "${choice}" == "CANCEL" ]]; then
  echo "Cancelled." >&2
  exit 0
fi

# ---- Step 4: Summon ----
echo "==> Step 4: Summoning experts..." >&2
SUMMON_JSON=$(bash "${ONRAMP_LIB}/summon.sh" "${CHOICE_JSON}")

# ---- Step 5: Output ----
echo "==> Step 5: Generating report..." >&2
OUTPUT_JSON=$(bash "${ONRAMP_LIB}/output.sh" "${CHOICE_JSON}" "${SUMMON_JSON}" "${PROJECT_PATH}")

echo "${OUTPUT_JSON}"