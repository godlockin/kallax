#!/usr/bin/env bash
# KALLAX v3.5.0 hotfix (跟 B 组 U-003 + P-002 治根 联合, 跟 V310-B P-001 1:1 联合):
# pre-commit hook verify release doc 引用 evidence 文件 != dryrun 副本 (byte-identical 即 fail)
# 跟 V310-B tag-audit.sh --scope ch 模式 1:1 联合

set -euo pipefail

EVIDENCE_DIR="docs/evidence"

fail=0

# Find all release doc + evidence file pairs
for release_dir in "$EVIDENCE_DIR"/*/; do
  [ -d "$release_dir" ] || continue
  release="$(basename "$release_dir")"

  for actual_txt in "$release_dir"*-actual.txt; do
    [ -f "$actual_txt" ] || continue
    dryrun_txt="${actual_txt/-actual.txt/-dryrun.txt}"
    if [ ! -f "$dryrun_txt" ]; then
      echo "[$release] WARN: $actual_txt has no corresponding -dryrun.txt (skip)"
      continue
    fi

    if diff -q "$dryrun_txt" "$actual_txt" > /dev/null 2>&1; then
      echo "[$release] FAIL: $actual_txt 跟 $dryrun_txt byte-identical (跟 P-002 evidence byte-identical 反讽 联合)"
      fail=1
    else
      echo "[$release] PASS: $actual_txt != $dryrun_txt (byte-diff)"
    fi
  done
done

if [ "$fail" -eq 1 ]; then
  echo ""
  echo "❌ FAIL: 1+ evidence files byte-identical 跟 dryrun — 跟 B 组 U-003 + P-002 反讽 联合"
  echo "   fix: 跑 'bash scripts/graceful-exit.sh --actual' 重新生成 evidence (跟 S-001 1:1)"
  exit 1
fi

echo "✅ PASS: all evidence files byte-differ 跟 dryrun counterparts"