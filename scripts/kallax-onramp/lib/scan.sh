#!/usr/bin/env bash
# Step 1a: 纯 shell 扫描 (0 LLM, < 1 min)
# 跟 Rule 4 Fail Fast 联合, 跟"反讽" 闭环

set -euo pipefail

PROJECT_PATH="${1:-}"

if [[ -z "${PROJECT_PATH}" || ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

cd "${PROJECT_PATH}"

project=$(basename "$(pwd)")
loc=$(find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.md" -o -name "*.rs" -o -name "*.go" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
files=$(find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
modules=$(find . -maxdepth 2 -type d -not -path "*/node_modules*" -not -path "*/.git*" -not -path "*/worktrees*" 2>/dev/null | wc -l | tr -d ' ')
has_claude_md=$([ -f "CLAUDE.md" ] && echo true || echo false)
has_readme=$([ -f "README.md" ] && echo true || echo false)
git_log_days=$(git log --since="30 days ago" --oneline 2>/dev/null | wc -l | tr -d ' ')

# language mix (simplified)
sh_count=$(find . -name "*.sh" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
ts_count=$(find . \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
py_count=$(find . -name "*.py" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
md_count=$(find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
rs_count=$(find . -name "*.rs" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
go_count=$(find . -name "*.go" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
total=$((sh_count + ts_count + py_count + md_count + rs_count + go_count))
if [[ ${total} -gt 0 ]]; then
  language_mix="Shell:$((sh_count * 100 / total)),TS:$((ts_count * 100 / total)),PY:$((py_count * 100 / total)),MD:$((md_count * 100 / total)),RS:$((rs_count * 100 / total)),GO:$((go_count * 100 / total))"
else
  language_mix="unknown"
fi

# smell indicators
smell_indicators="[]"
if [[ ${loc} -gt 5000 && ${ts_count} -gt 10 && ! -d "tests" ]]; then
  smell_indicators='["no_tests"]'
fi
if [[ ${files} -gt 100 && ${sh_count} -gt 50 ]]; then
  smell_indicators='["no_tests","many_scripts"]'
fi

cat <<EOF
{
  "project": "${project}",
  "loc": ${loc},
  "files": ${files},
  "modules": ${modules},
  "has_claude_md": ${has_claude_md},
  "has_readme": ${has_readme},
  "git_log_days": ${git_log_days},
  "language_mix": "${language_mix}",
  "smell_indicators": ${smell_indicators}
}
EOF