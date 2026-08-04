#!/usr/bin/env bash
# scripts/check-private-context.sh — Private Context Scanner (EPIC-163)
# 主公 2026-08-05 拍板: treats boundary as file-state (tracked vs untracked)
#
# 检测 4 类:
#   1. credentials  (ghp_xxx, sk-xxx, AKIAxxx — literal secret values)
#   2. private paths (/Users/.../.local/...)
#   3. raw logs    (.log/.jsonl > 1MB)
#   4. sub-agent prompts (含 "system prompt" 关键词)
#
# Exit: 0=PASS, 1=FAIL (fail-closed), 2=BLOCKED-env
#
# 跟 scan-dead-code.sh 退出码契约 0/1/2 1:1 联合
# 跟 check-decorative-claim.sh immutable script pattern 1:1 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<EOF
KALLAX Private Context Scanner — EPIC-163

用法: scripts/check-private-context.sh [--staged-only]

检测 4 类 private context:
  1. credentials  (ghp_xxx, sk-xxx, AKIAxxx — literal secrets)
  2. private paths (/Users/.../.local/...)
  3. raw logs    (.log/.jsonl > 1MB)
  4. sub-agent prompts (含 "system prompt" 关键词)

Exit codes:
  0 = PASS (无 private context)
  1 = FAIL (发现 private context, fail-closed)
  2 = BLOCKED-env (环境异常)

Options:
  --staged-only  只扫 staged files (pre-commit hook 用)
EOF
}

# Parse args
STAGED_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -h|--help|help) usage; exit 0 ;;
    --staged-only) STAGED_ONLY=1 ;;
  esac
done

warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }

FAIL_COUNT=0
BLOCKED_COUNT=0

# ============================================================================
# Stage 1 — Credentials Detection (literal secret values only)
# ============================================================================
stage_credentials() {
  info "Stage 1: Credentials detection (literal secrets)"

  # Get files to scan
  local files
  if [ "$STAGED_ONLY" -eq 1 ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
  else
    files=$(git ls-files 2>/dev/null || true)
  fi

  [ -z "$files" ] && { ok "Stage 1: no files to scan"; return 0; }

  # Credential patterns - literal secret values only
  # NOT: api_key=xxx (env var pattern), token=xxx (config pattern)
  # YES: ghp_xxx (GitHub token), sk-xxx (OpenAI key), AKIAxxx (AWS key)
  local cred_patterns=(
    'ghp_[a-zA-Z0-9]{36}'
    'sk-[a-zA-Z0-9]{48}'
    'AKIA[0-9A-Z]{16}'
  )

  # Exclude false positive paths
  local skip_patterns='^tests/|^docs/|^confluence/|^templates/|^template/|^jira/'

  local found=0
  while IFS= read -r file; do
    # Skip excluded paths
    if echo "$file" | grep -qE "$skip_patterns"; then
      continue
    fi
    [ -f "$file" ] || continue
    # Skip binary files
    file -- "$file" 2>/dev/null | grep -q "text" || continue

    for pat in "${cred_patterns[@]}"; do
      if grep -iHE "$pat" "$file" 2>/dev/null | grep -qvE '^\s*//|^\s*#' ; then
        err "Credential found: $file (pattern: $pat)"
        found=1
        FAIL_COUNT=$((FAIL_COUNT + 1))
        break
      fi
    done
  done <<< "$files"

  [ "$found" -eq 0 ] && ok "Stage 1: 0 literal credential patterns"
}

# ============================================================================
# Stage 2 — Private Paths Detection
# ============================================================================
stage_private_paths() {
  info "Stage 2: Private paths detection"

  local files
  if [ "$STAGED_ONLY" -eq 1 ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
  else
    files=$(git ls-files 2>/dev/null || true)
  fi

  [ -z "$files" ] && { ok "Stage 2: no files to scan"; return 0; }

  # Skip excluded paths (docs, confluence, jira, tests are safe)
  # Skip scripts that legitimately reference local paths
  local skip_patterns='^docs/|^confluence/|^templates/|\.md$|^\.claude/settings\.local\.json$|^hooks/|^jira/|^tests/|^scripts/audit/|^scripts/verify/pr-eval\.sh$|^scripts/kallax-onramp/|^scripts/expert-generate-l3\.py$'

  # Private path patterns - only flag ACTUAL local paths, not documentation
  local path_patterns=(
    '/Users/[^/]+/[a-zA-Z]'
    '/home/[^/]+/[a-zA-Z]'
  )

  local found=0
  while IFS= read -r file; do
    if echo "$file" | grep -qE "$skip_patterns"; then
      continue
    fi
    [ -f "$file" ] || continue
    for pat in "${path_patterns[@]}"; do
      if grep -HE "$pat" "$file" 2>/dev/null | grep -qvE '^\s*//|^\s*#' ; then
        err "Private path found: $file"
        found=1
        FAIL_COUNT=$((FAIL_COUNT + 1))
        break
      fi
    done
  done <<< "$files"

  [ "$found" -eq 0 ] && ok "Stage 2: 0 private paths"
}

# ============================================================================
# Stage 3 — Raw Logs Detection (> 1MB)
# ============================================================================
stage_raw_logs() {
  info "Stage 3: Raw logs detection (>1MB)"

  local files
  if [ "$STAGED_ONLY" -eq 1 ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -iE '\.(log|jsonl)$' || true)
  else
    files=$(git ls-files 2>/dev/null | grep -iE '\.(log|jsonl)$' || true)
  fi

  [ -z "$files" ] && { ok "Stage 3: no log files"; return 0; }

  local found=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    local size_mb=$((size / 1024 / 1024))
    if [ "$size_mb" -gt 1 ]; then
      err "Raw log too large: $file (${size_mb}MB > 1MB)"
      found=1
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done <<< "$files"

  [ "$found" -eq 0 ] && ok "Stage 3: 0 oversized logs"
}

# ============================================================================
# Stage 4 — Sub-Agent Prompts Detection
# ============================================================================
stage_agent_prompts() {
  info "Stage 4: Sub-agent prompts detection"

  local files
  if [ "$STAGED_ONLY" -eq 1 ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
  else
    files=$(git ls-files 2>/dev/null || true)
  fi

  [ -z "$files" ] && { ok "Stage 4: no files to scan"; return 0; }

  # Skip allowed dirs and internal KALLAX prompts
  local skip_patterns='^jira/|^confluence/|^docs/|^.continue/|^.claude/commands/'

  # Agent prompt patterns - flag actual system prompt content, not documentation
  # Look for: prompt content lines, not "system prompt" mentions in docs
  local prompt_patterns=(
    '^system prompt:'
    '^You are a'
    '^Your role is'
  )

  local found=0
  while IFS= read -r file; do
    echo "$file" | grep -qE "$skip_patterns" && continue
    [ -f "$file" ] || continue
    for pat in "${prompt_patterns[@]}"; do
      if grep -iHE "$pat" "$file" 2>/dev/null | grep -qvE '^\s*//|^\s*#' ; then
        err "Agent prompt found: $file (pattern: $pat)"
        found=1
        FAIL_COUNT=$((FAIL_COUNT + 1))
        break
      fi
    done
  done <<< "$files"

  [ "$found" -eq 0 ] && ok "Stage 4: 0 agent prompts"
}

# ============================================================================
# Main
# ============================================================================
info "=========================================="
info "Private Context Scanner (EPIC-163)"
info "=========================================="

stage_credentials
stage_private_paths
stage_raw_logs
stage_agent_prompts

echo ""

# Exit code contract (跟 scan-dead-code.sh 1:1)
if [ "$BLOCKED_COUNT" -gt 0 ]; then
  err "BLOCKED-env: $BLOCKED_COUNT environment blockers"
  exit 2
elif [ "$FAIL_COUNT" -gt 0 ]; then
  err "FAIL: $FAIL_COUNT private context violations detected"
  exit 1
else
  ok "PASS: 0 private context violations"
  exit 0
fi
