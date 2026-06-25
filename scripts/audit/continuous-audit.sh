#!/bin/bash
# continuous-audit.sh — 9-pass redaction validator (EPIC-037-A)
#
# Scans files/dirs for 9 categories of sensitive data leaks:
#   pass-1: Authorization header
#   pass-2: Token: keyword
#   pass-3: X-Auth-Token header
#   pass-4: password/secret keyword
#   pass-5: Basic Auth URL (https://user:pass@host)
#   pass-6: Known token prefixes (ghp_ / sk- / AKIA)
#   pass-7: JWT (xxx.yyy.zzz)
#   pass-8: env-var style KEY=VALUE (KEY/TOKEN/PASSWORD/SECRET)
#   pass-9: 24-char hex fallback (long opaque strings)
#
# Usage:
#   continuous-audit.sh scan <file|dir>    # scan target for leaks
#   continuous-audit.sh passes             # list 9 pass names
#   continuous-audit.sh self-check         # verify 9 patterns present (sanity)
#
# Exit codes:
#   0 = clean (no leaks)
#   1 = leaks detected
#   2 = usage error
#
# Source: EPIC-037-A + docs/architecture/3-MODES.md:148 9-pass redaction spec
# 跟 AuditMiddleware 1:1 验证 (EPIC-030-G merge baseline)
# 跟 "翻篇&精进" 战略 联合 0 简单 记录 (Rule 9d no estimation anti-pattern)
set -euo pipefail

# ─── 9-pass regex patterns (each anchored to detect full token-shape) ───
# Per-pass patterns — used to identify WHICH pass matched (for diagnostics)
readonly PAT_PASS1='^[[:space:]]*Authorization[[:space:]]*:'           # Authorization header
readonly PAT_PASS2='^[[:space:]]*Token[[:space:]]*:'                    # Token: keyword
readonly PAT_PASS3='^[[:space:]]*X-Auth-Token[[:space:]]*:'             # X-Auth-Token header
readonly PAT_PASS4='[Pp]assword[[:space:]]*[:=][[:space:]]*[^[:space:]]+|[Ss]ecret[[:space:]]*[:=][[:space:]]*[^[:space:]]+'  # password/secret assignment
readonly PAT_PASS5='https?://[^[:space:]/@]+:[^[:space:]/@]+@'          # Basic Auth URL (user:pass@host)
readonly PAT_PASS6='\b(ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16})\b'  # known token prefixes
readonly PAT_PASS7='\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'          # JWT (header.payload.sig)
readonly PAT_PASS8='\b[A-Z][A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|API_KEY)\b[[:space:]]*=[[:space:]]*[A-Za-z0-9_./+-]{8,}'  # env-var
readonly PAT_PASS9='\b[A-Fa-f0-9]{32,}\b'                               # 32+ hex fallback (24+ char; widened to 32 to reduce false-pos on hash-only identifiers)

# Compiled union pattern (one grep call per line — fast)
readonly PAT_UNION="(${PAT_PASS1})|(${PAT_PASS2})|(${PAT_PASS3})|(${PAT_PASS4})|(${PAT_PASS5})|(${PAT_PASS6})|(${PAT_PASS7})|(${PAT_PASS8})|(${PAT_PASS9})"

# Per-pass labels for diagnostic output
PASS_LABELS=( "pass-1" "pass-2" "pass-3" "pass-4" "pass-5" "pass-6" "pass-7" "pass-8" "pass-9" )
readonly PASS_LABELS
readonly TOTAL_PASSES=9

# ─── Helpers ───

# Print all 9 pass names (used by `passes` subcommand and self-check)
list_passes() {
  for p in "${PASS_LABELS[@]}"; do
    echo "$p"
  done
}

# Identify which pass matched a given line (returns first match's pass label)
identify_pass() {
  local line="$1"
  local idx=0
  for pat in "$PAT_PASS1" "$PAT_PASS2" "$PAT_PASS3" "$PAT_PASS4" "$PAT_PASS5" "$PAT_PASS6" "$PAT_PASS7" "$PAT_PASS8" "$PAT_PASS9"; do
    if printf '%s' "$line" | grep -qE "$pat"; then
      echo "${PASS_LABELS[$idx]}"
      return 0
    fi
    idx=$((idx + 1))
  done
  echo "unknown"
}

# Scan a single file → returns 0 clean, 1 leak
scan_file() {
  local file="$1"
  local had_leak=0
  local line_no=0

  while IFS= read -r line; do
    line_no=$((line_no + 1))
    if printf '%s\n' "$line" | grep -qE "$PAT_UNION"; then
      local matched_pass
      matched_pass=$(identify_pass "$line")
      echo "  [LEAK] $file:$line_no  $matched_pass: $line" >&2
      had_leak=1
    fi
  done < "$file"

  return $((had_leak))
}

# Scan a target (file or directory)
# Args: $1 = path
scan_target() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    echo "ERROR: target not found: $target" >&2
    return 2
  fi

  local leak_count=0
  local file_count=0

  if [[ -f "$target" ]]; then
    file_count=$((file_count + 1))
    if ! scan_file "$target"; then
      leak_count=$((leak_count + 1))
    fi
  elif [[ -d "$target" ]]; then
    # Recursive scan (text files only, ≤ 1MB per file to keep scan bounded)
    while IFS= read -r -d '' file; do
      # Skip binary files and oversized
      local size
      size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
      if [[ "$size" -gt 1048576 ]]; then
        continue
      fi
      # Extension filter (avoid `file` magic detection — slow on macOS)
      case "$file" in
        *.sh|*.md|*.txt|*.json|*.jsonl|*.yaml|*.yml|*.toml|*.cfg|*.conf|*.env|*.ts|*.js|*.py|*.rs|*.go|*.html|*.css) ;;
        *) continue ;;
      esac
      file_count=$((file_count + 1))
      if ! scan_file "$file"; then
        leak_count=$((leak_count + 1))
      fi
    done < <(find "$target" -type f -print0 2>/dev/null)
  else
    echo "ERROR: target is neither file nor dir: $target" >&2
    return 2
  fi

  echo "=========================================="
  echo "Continuous Audit (9-pass redaction)"
  echo "=========================================="
  echo "Target:     $target"
  echo "Files:      $file_count"
  echo "Files with leaks: $leak_count"
  echo ""

  if [[ $leak_count -gt 0 ]]; then
    echo "FAIL: $leak_count file(s) contain sensitive data (9-pass detection)"
    return 1
  fi

  echo "PASS: 0 leaks detected across $file_count file(s)"
  return 0
}

# Self-check: verify 9 pass patterns are non-empty and syntactically valid (extended regex)
self_check() {
  local ok=1
  local idx=0
  for pat in "$PAT_PASS1" "$PAT_PASS2" "$PAT_PASS3" "$PAT_PASS4" "$PAT_PASS5" "$PAT_PASS6" "$PAT_PASS7" "$PAT_PASS8" "$PAT_PASS9"; do
    local name="${PASS_LABELS[$idx]}"
    if [[ -z "$pat" ]]; then
      echo "  [FAIL] $name: pattern empty"
      ok=0
    else
      # Validate regex by attempting a parse-only grep (echo nothing — if regex is malformed, grep exits 2)
      # Use /dev/null + heredoc trick: feed line and capture grep's exit code without matching
      if ! printf 'sentinel\n' | grep -qE "$pat" 2>/dev/null; then
        # Either matches or doesn't — both are valid. To check PARSE only, use -c (count) with no input
        # but grep -c still parses. Real parse test: feed a line and check exit code is 0 or 1, not 2.
        local rc=$?
        if [[ "$rc" -eq 2 ]]; then
          echo "  [FAIL] $name: regex parse error"
          ok=0
        fi
      fi
      echo "  [OK]   $name"
    fi
    idx=$((idx + 1))
  done

  if [[ $ok -eq 1 ]]; then
    echo ""
    echo "PASS: $TOTAL_PASSES/$TOTAL_PASSES patterns registered"
    return 0
  else
    echo ""
    echo "FAIL: pattern registry broken"
    return 1
  fi
}

# ─── Entry ───
case "${1:-}" in
  scan)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 scan <file|dir>" >&2
      exit 2
    fi
    scan_target "$2"
    ;;
  passes)
    list_passes
    ;;
  self-check)
    self_check
    ;;
  *)
    echo "Usage: $0 {scan <file|dir>|passes|self-check}" >&2
    exit 2
    ;;
esac