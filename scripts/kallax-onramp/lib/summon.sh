#!/usr/bin/env bash
# Step 3: 召唤专家 (复用 5 default + 5 extended skill 文档)
# 跟 Rule 5 DRY 联合, 跟"反讽" 闭环 — 0 重写

set -euo pipefail

CHOICE_JSON="${1:-}"

# 解析
experts_array=$(echo "${CHOICE_JSON}" | jq -c '.experts')

# 5 default experts 在 worktree 的 .kallax/experts/default/
# 5 extended experts 在 ~/.claude/skills/kallax/extended/
WORKTREE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEFAULT_DIR="${WORKTREE_ROOT}/.kallax/experts/default"
EXTENDED_DIR="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended"

summoned="[]"
warnings="[]"

# 遍历 experts
for expert in $(echo "${experts_array}" | jq -r '.[]'); do
  # 先查 default/, 再查 extended/
  if [[ -f "${DEFAULT_DIR}/${expert}.md" ]]; then
    skill_path="${DEFAULT_DIR}/${expert}.md"
  elif [[ -f "${EXTENDED_DIR}/${expert}.md" ]]; then
    skill_path="${EXTENDED_DIR}/${expert}.md"
  else
    # 缺专家 → 降级
    warnings=$(echo "${warnings}" | jq --arg e "${expert}" '. + ["expert_not_found: " + $e]')
    continue
  fi

  # 构造 summoned entry
  entry=$(jq -n --arg r "${expert}" --arg p "${skill_path}" '{role: $r, skill_path: $p}')
  summoned=$(echo "${summoned}" | jq --argjson e "${entry}" '. + [$e]')
done

cat <<EOF
{
  "summoned": ${summoned},
  "warnings": ${warnings}
}
EOF