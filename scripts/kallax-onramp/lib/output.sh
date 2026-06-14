#!/usr/bin/env bash
# Step 4: 输出 Markdown 报告 + audit log
# 跟 Rule 31 不可篡改 audit log 联合 (BE-7 修复模式)
# 跟 Rule 17 atomic write 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="$(cd "$(dirname "${SCRIPT_DIR}")" && pwd)"
KALLAX_ROOT="$(cd "${ONRAMP_DIR}/../../../../.." && pwd)"

CHOICE_JSON="${1:-}"
SUMMON_JSON="${2:-}"
PROJECT_PATH="${3:-}"

project=$(basename "${PROJECT_PATH}")
date=$(date +%Y-%m-%d)
output_dir="${KALLAX_ROOT}/docs/analysis"
mkdir -p "${output_dir}"
output_file="${output_dir}/ONRAMP-${project}-${date}.md"
tmp_file="${output_file}.tmp.$$"

# 选模板
choice=$(echo "${CHOICE_JSON}" | jq -r '.choice')
case "${choice}" in
  A)
    template="${ONRAMP_DIR}/templates/L1-light.md"
    ;;
  B|Y)
    template="${ONRAMP_DIR}/templates/L2-deep.md"
    ;;
  C|CUSTOM)
    template="${ONRAMP_DIR}/templates/L3-audit.md"
    ;;
  *)
    template="${ONRAMP_DIR}/templates/L1-light.md"
    ;;
esac

# 渲染 (简化: 直接 cp + 替换)
cp "${template}" "${tmp_file}"

# Atomic mv (跟 Rule 17 联合)
mv "${tmp_file}" "${output_file}"
chmod 644 "${output_file}"

# Audit log (跟 Rule 31 联合, BE-7 修复模式)
audit_dir="${KALLAX_ROOT}/.kallax/logs"
mkdir -p "${audit_dir}"
chmod 700 "${audit_dir}"
audit_file="${audit_dir}/onramp-${date}.jsonl"

cat <<EOF >> "${audit_file}"
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "${project}",
  "choice": "${choice}",
  "output_path": "${output_file}",
  "summoned_count": $(echo "${SUMMON_JSON}" | jq -r '.summoned | length')
}
EOF
chmod 600 "${audit_file}"

cat <<EOF
{
  "output_path": "${output_file}",
  "audit_log": "${audit_file}"
}
EOF