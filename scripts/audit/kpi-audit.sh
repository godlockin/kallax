#!/bin/bash
# kpi-audit.sh — Rule 9a KPI falsification detector (EPIC-037-A)
#
# Scans files/dirs for KPI estimate / hedge patterns (anti-fabrication):
#   - ~70% / ~60-70 / ~ 80
#   - 约 80% / 大约 90 / 约70%
#   - 大概 80 / 估计 / roughly 80
#   - around 80 / approximately 80
#   - PARTIAL (reported as PASS)
#   - should be 90% (assertion hedge)
#
# Usage:
#   kpi-audit.sh scan <file|dir>    # scan target for KPI falsification
#   kpi-audit.sh patterns           # list anti-pattern names
#   kpi-audit.sh self-check         # verify all patterns registered
#
# Exit codes:
#   0 = clean (no estimate patterns)
#   1 = estimate / PARTIAL pattern detected
#   2 = usage error
#
# Source: EPIC-037-A AC: Rule 9a KPI 估数 detection
# 跟 check-kpi-precision.sh (scripts/verify/) 联合 — 此脚本是 周期 audit,
#   check-kpi-precision.sh 是 每次 commit 前 pre-commit
# 跟 v2.6.0 8 次 KPI falsification 反复教训 联合 (file:line:
#   confluence/memory/lessons/performer-kpi-falsification-pattern.md)
# 跟 "翻篇&精进" 战略 联合 0 简单 记录
set -euo pipefail

# ─── Anti-pattern registry (extended regex) ───
# Per-pattern entries — used for identification of which pattern matched
readonly PAT_TILDE_PCT='~\s*[0-9]+'
readonly PAT_TILDE_RANGE='~\s*[0-9]+\s*-\s*[0-9]+'
readonly PAT_APPROX_AROUND='around\s+[0-9]+'
readonly PAT_APPROX_APPROXIMATELY='approximately\b'
readonly PAT_APPROX_ROUGHLY='roughly\b'
readonly PAT_APPROX_SHOULD='should\s+(be|have)'
readonly PAT_PARTIAL='PARTIAL'
readonly PAT_ZH_DADAYUE='大约\s*[0-9]+'
readonly PAT_ZH_YUE='约\s*[0-9]+\s*[%％]?'
readonly PAT_ZH_DAGAI='大概\s*[0-9]+'
readonly PAT_ZH_GUJI='估计'

# Compiled union — single grep call per line for speed
readonly PAT_UNION="(${PAT_TILDE_PCT})|(${PAT_TILDE_RANGE})|(${PAT_APPROX_AROUND})|(${PAT_APPROX_APPROXIMATELY})|(${PAT_APPROX_ROUGHLY})|(${PAT_APPROX_SHOULD})|(${PAT_PARTIAL})|(${PAT_ZH_DADAYUE})|(${PAT_ZH_YUE})|(${PAT_ZH_DAGAI})|(${PAT_ZH_GUJI})"

PATTERN_LABELS=( "tilde-pct" "tilde-range" "approx-english-around" "approx-english-approximately" "approx-english-roughly" "approx-english-should" "partial-keyword" "zh-dadayue" "zh-yue" "zh-dagai" "zh-guji" )
readonly PATTERN_LABELS
readonly TOTAL_PATTERNS=11

# ─── Helpers ───

list_patterns() {
  for p in "${PATTERN_LABELS[@]}"; do
    echo "$p"
  done
}

# Identify which anti-pattern matched a line (returns label)
identify_pattern() {
  local line="$1"
  local idx=0
  for pat in "$PAT_TILDE_PCT" "$PAT_TILDE_RANGE" "$PAT_APPROX_AROUND" "$PAT_APPROX_APPROXIMATELY" "$PAT_APPROX_ROUGHLY" "$PAT_APPROX_SHOULD" "$PAT_PARTIAL" "$PAT_ZH_DADAYUE" "$PAT_ZH_YUE" "$PAT_ZH_DAGAI" "$PAT_ZH_GUJI"; do
    if printf '%s' "$line" | grep -qE "$pat"; then
      echo "${PATTERN_LABELS[$idx]}"
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
      local matched
      matched=$(identify_pattern "$line")
      echo "  [LEAK] $file:$line_no  $matched: $line" >&2
      had_leak=1
    fi
  done < "$file"

  return $((had_leak))
}

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
    while IFS= read -r -d '' file; do
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
  echo "KPI Audit (Rule 9a falsification detection)"
  echo "=========================================="
  echo "Target:     $target"
  echo "Files:      $file_count"
  echo "Files with leaks: $leak_count"
  echo ""

  if [[ $leak_count -gt 0 ]]; then
    echo "FAIL: $leak_count file(s) contain KPI estimate / PARTIAL patterns"
    return 1
  fi

  echo "PASS: 0 estimate patterns across $file_count file(s) — all KPI use exact X/Y"
  return 0
}

self_check() {
  local ok=1
  local idx=0
  for pat in "$PAT_TILDE_PCT" "$PAT_TILDE_RANGE" "$PAT_APPROX_AROUND" "$PAT_APPROX_APPROXIMATELY" "$PAT_APPROX_ROUGHLY" "$PAT_APPROX_SHOULD" "$PAT_PARTIAL" "$PAT_ZH_DADAYUE" "$PAT_ZH_YUE" "$PAT_ZH_DAGAI" "$PAT_ZH_GUJI"; do
    local name="${PATTERN_LABELS[$idx]}"
    if [[ -z "$pat" ]]; then
      echo "  [FAIL] $name: pattern empty"
      ok=0
    else
      echo "  [OK]   $name"
    fi
    idx=$((idx + 1))
  done

  if [[ $ok -eq 1 ]]; then
    echo ""
    echo "PASS: $TOTAL_PATTERNS/$TOTAL_PATTERNS anti-patterns registered"
    return 0
  fi
  echo ""
  echo "FAIL: anti-pattern registry broken"
  return 1
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
  patterns)
    list_patterns
    ;;
  self-check)
    self_check
    ;;
  *)
    echo "Usage: $0 {scan <file|dir>|patterns|self-check}" >&2
    exit 2
    ;;
esac