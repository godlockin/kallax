#!/usr/bin/env bash
# Step 4: 输出 Markdown 报告 + audit log
# B2: KALLAX_ROOT path fixed (2 layers ../..)
# B3: Template rendering with sed placeholders
# B4: Expert outputs read actual skill documents
# 跟 Rule 31 不可篡改 audit log 联合 (BE-7 修复模式)
# 跟 Rule 17 atomic write 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="$(cd "$(dirname "${SCRIPT_DIR}")" && pwd)"
# 路径: lib/ → kallax-onramp/ → scripts/ → 项目根 (2 层 ../..)
KALLAX_ROOT="$(cd "${ONRAMP_DIR}/../.." && pwd)"

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

# 扫描项目获取数据 (用于 B3 渲染)
scan_data=$(bash "${ONRAMP_DIR}/lib/scan.sh" "${PROJECT_PATH}" 2>/dev/null || echo '{}')
loc=$(echo "${scan_data}" | jq -r '.loc // "?"')
files=$(echo "${scan_data}" | jq -r '.files // "?"')
modules=$(echo "${scan_data}" | jq -r '.modules // "?"')
language_mix=$(echo "${scan_data}" | jq -r '.language_mix // "?"')
has_claude_md=$(echo "${scan_data}" | jq -r '.has_claude_md')
has_readme=$(echo "${scan_data}" | jq -r '.has_readme')
git_log_days=$(echo "${scan_data}" | jq -r '.git_log_days // "?"')

# B4: 读取 expert skill 文档内容
expert_outputs=""
summoned=$(echo "${SUMMON_JSON}" | jq -c '.summoned')
i=1
for entry in $(echo "${summoned}" | jq -r '.[] | @json'); do
  role=$(echo "${entry}" | jq -r '.role')
  skill_path=$(echo "${entry}" | jq -r '.skill_path')

  if [[ -n "${skill_path}" && -f "${skill_path}" ]]; then
    # 读取 skill 文档的 name 和 description
    skill_name=$(grep -m1 "^name:" "${skill_path}" 2>/dev/null | sed 's/^name:[[:space:]]*//' || echo "${role}")
    skill_desc=$(grep -m1 "^description:" "${skill_path}" 2>/dev/null | sed 's/^description:[[:space:]]*//' || echo "No description")

    # 读取 skill 文档内容的前几行作为摘要 (单行,无换行)
    skill_content=$(head -20 "${skill_path}" 2>/dev/null | tail -n +3 | head -10 | tr '\n' ' ' | sed 's/  */ /g')

    expert_outputs="${expert_outputs}
### ${i}. ${skill_name}

**角色**: ${role}
**Skill 路径**: ${skill_path}
**描述**: ${skill_desc}

${skill_content}
"
    i=$((i + 1))
  fi
done

# 如果没有 expert 输出,提供默认消息
if [[ -z "${expert_outputs}" ]]; then
  expert_outputs="
### Architect 视角

暂无专家数据,建议运行完整分析获取专家意见.
"
fi

# B3: 渲染 - sed replace single-line placeholders
cp "${template}" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{project}}|${project}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{date}}|${date}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{loc}}|${loc}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{files}}|${files}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{modules}}|${modules}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{language_mix}}|${language_mix}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{has_claude_md}}|${has_claude_md}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{has_readme}}|${has_readme}|g" "${tmp_file}"
LC_ALL=C sed -i '' "s|{{git_log_days}}|${git_log_days}|g" "${tmp_file}"

# B3: expert_output multiline - use python3 for robust replacement
python3 -c "
import sys
with open('${tmp_file}', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('{{expert_output}}', '''${expert_outputs}''')
with open('${tmp_file}', 'w', encoding='utf-8') as f:
    f.write(content)
"

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