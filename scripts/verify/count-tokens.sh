#!/usr/bin/env bash
# KALLAX count-tokens.sh — 估算 session 加载的 token 数 (借鉴 eket, EPIC-080)
#
# 用法:
#   bash scripts/verify/count-tokens.sh              # 全部 (CLAUDE.md + 关键文件)
#   bash scripts/verify/count-tokens.sh --role master
#   bash scripts/verify/count-tokens.sh --compare v3.10.0 v3.11.0
#
# 退出码:
#   0 = OK
#   1 = 估算失败
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

count_chars() {
  local total=0
  for f in "$@"; do
    if [[ -f "$f" ]]; then
      local size
      size=$(wc -c < "$f" 2>/dev/null || echo 0)
      total=$(( total + size ))
    fi
  done
  echo "$total"
}

# 粗估: 1 byte ≈ 0.25 token (跟 OpenAI 经验)
estimate_tokens() {
  local bytes=$1
  echo $(( bytes / 4 ))
}

case "${1:-all}" in
  --role-master|all)
    bytes=$(count_chars "$CLAUDE_MD" \
      "$REPO_ROOT/confluence/decisions/branch-flow-governance-2026-07-09.md")
    tokens=$(estimate_tokens "$bytes")
    echo "kallax master role session:"
    echo "  CLAUDE.md: $(count_chars "$CLAUDE_MD") bytes"
    echo "  branch-flow: $(count_chars "$REPO_ROOT/confluence/decisions/branch-flow-governance-2026-07-09.md") bytes"
    echo "  total: $bytes bytes ≈ $tokens tokens (rough estimate)"
    ;;
  --compare)
    v1=${2:-v3.10.0}
    v2=${3:-v3.11.0}
    echo "Comparing session load: $v1 vs $v2"
    # 简化: 比 v1 和 v2 tag 时 CLAUDE.md 大小
    s1=$(git show "$v1:CLAUDE.md" 2>/dev/null | wc -c || echo 0)
    s2=$(git show "$v2:CLAUDE.md" 2>/dev/null | wc -c || echo 0)
    t1=$(estimate_tokens "$s1")
    t2=$(estimate_tokens "$s2")
    echo "  $v1 CLAUDE.md: $s1 bytes ≈ $t1 tokens"
    echo "  $v2 CLAUDE.md: $s2 bytes ≈ $t2 tokens"
    diff=$(( t2 - t1 ))
    echo "  diff: $diff tokens"
    ;;
  *)
    echo "Usage: $0 [all|--role-master|--compare v1 v2]"
    exit 1
    ;;
esac