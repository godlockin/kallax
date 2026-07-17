#!/usr/bin/env bash
# scripts/kallax-tools.sh — EPIC-122-G: KALLAX Tool Registry (仿 grok-build ToolIndex)
#
# 参照 xai-tool-protocol define_methods! 模式，建立 KALLAX 工具注册表。
#
# Usage:
#   kallax tools list [--json]          # 列出所有工具
#   kallax tools search <query> [--json] # 搜索工具
#   kallax tools info <name>            # 工具详细信息
#
# Exit:
#   0 = success
#   1 = error / no results

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# === Tool Registry ===
# Format: name|description|category|file_path|tags
TOOL_REGISTRY=(
  "heartbeat-daemon|周期性心跳 daemon，维持实例活跃|daemon|scripts/heartbeat-daemon.sh|daemon,heartbeat,governance"
  "expert-invocation-queue|Expert invocation 降级队列 (redis→sqlite→file)|lib|scripts/lib/expert-invocation-queue.sh|queue,expert,invocation"
  "daemon|Library: run_daemon() 标准 daemon 启动|lib|scripts/lib/daemon.sh|daemon,library"
  "check-tools|检查 jq/git/bash/sqlite3 版本|verify|scripts/check-tools.sh|tools,version,check"
  "check-scope-creep|PR scope vs ticket scope 一致性检查|verify|scripts/verify/check-scope-creep.sh|verify,scope,PR"
  "check-checkin-points|EPIC checkin_points 存在性验证|verify|scripts/verify/check-checkin-points.sh|verify,checkin,EPIC"
  "check-claim-evidence|README 数字必须有 raw output 引用|verify|scripts/verify/check-claim-evidence.sh|verify,evidence,claim"
  "check-epic-4-piece|EPIC 四件套完整性检查|verify|scripts/verify/check-epic-4-piece.sh|verify,EPIC,schema"
  "check-cargo-test|Cargo test --workspace 通过检查|verify|scripts/verify/check-cargo-test-workspace.sh|verify,cargo,test"
  "governance-3phase|3 阶段治理协调脚本|audit|scripts/audit/governance-3phase.sh|governance,3phase,audit"
  "sprint-metrics|北极星 4 指标计算|metrics|scripts/metrics/sprint-metrics.sh|metrics,sprint,KPI"
  "memory-promote|L0-L4 记忆分层升级|memory|scripts/memory-promote.sh|memory,L0-L4,knowledge"
  "worktree-cleaner|清理已合并 worktree|worktree|scripts/worktree-cleaner.sh|worktree,cleanup,git"
  "kallax-init|初始化 KALLAX session 或实例|setup|scripts/kallax-init.sh|setup,init,session"
  "kallax-doctor|KALLAX 健康检查诊断|setup|scripts/kallax-doctor.sh|doctor,health,diagnose"
  "kallax-verify|五层验证入口|verify|scripts/kallax-verify.sh|verify,5level"
  "post-process|EPIC 完成后 11 步 post-process|process|scripts/post-process.sh|process,post,EPIC"
  "branch-promote|4-branch 流程 promote|process|scripts/branch-promote.sh|git,branch,promote"
  "performer-init|Performer session 初始化|performer|scripts/performer-init.sh|performer,session"
  "conductor-session-init|Conductor session 初始化|conductor|scripts/conductor-session-init.sh|conductor,session"
)

# === Parse arguments ===
COMMAND="${1:-}"
shift 2>/dev/null || true

JSON_OUTPUT=0
if [[ "$1" == "--json" ]]; then JSON_OUTPUT=1; shift; fi

SEARCH_QUERY="${1:-}"

case "$COMMAND" in
  list) ;;
  search) [[ -z "$SEARCH_QUERY" ]] && { echo "ERROR: search requires <query>" >&2; exit 1; } ;;
  info) [[ -z "$SEARCH_QUERY" ]] && { echo "ERROR: info requires <name>" >&2; exit 1; } ;;
  -h|--help|'') echo "Usage: kallax tools {list|search <query>|info <name>} [--json]"; exit 0 ;;
  *) echo "ERROR: unknown command: $COMMAND" >&2; exit 1 ;;
esac

# === Tool Registry Search ===
# Uses simple grep-based matching (no jq/python required)

search_tools() {
  local query="$1"
  local results=()
  local lc_query
  lc_query=$(echo "$query" | tr '[:upper:]' '[:lower:]')

  for entry in "${TOOL_REGISTRY[@]}"; do
    IFS='|' read -r name desc category file tags <<< "$entry"

    # Match against name, description, category, tags
    local haystack
    haystack=$(echo "${name} ${desc} ${category} ${tags}" | tr '[:upper:]' '[:lower:]')

    if echo "$haystack" | grep -qi "$lc_query"; then
      results+=("$entry")
    fi
  done

  printf '%s\n' "${results[@]}"
}

format_tool() {
  local entry="$1"
  IFS='|' read -r name desc category file tags <<< "$entry"
  echo "  $name"
  echo "    $desc"
  echo "    category=$category | file=$file | tags=[$tags]"
  echo ""
}

format_tool_json() {
  local entry="$1"
  IFS='|' read -r name desc category file tags <<< "$entry"
  cat <<EOF
    {
      "name": "$name",
      "description": "$desc",
      "category": "$category",
      "file_path": "$file",
      "tags": [$(echo "$tags" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')]
    }
EOF
}

# === Execute command ===
case "$COMMAND" in
  list)
    if [[ "$JSON_OUTPUT" == "1" ]]; then
      echo "{"
      echo "  \"tools\": ["
      first=true
      for entry in "${TOOL_REGISTRY[@]}"; do
        if [[ "$first" != "true" ]]; then echo ","; fi
        first=false
        format_tool_json "$entry"
      done
      echo ""
      echo "  ],"
      echo "  \"total\": ${#TOOL_REGISTRY[@]}"
      echo "}"
    else
      echo "=========================================="
      echo "KALLAX Tool Registry (${#TOOL_REGISTRY[@]} tools)"
      echo "=========================================="
      for entry in "${TOOL_REGISTRY[@]}"; do
        format_tool "$entry"
      done
    fi
    ;;

  search)
    results=$(search_tools "$SEARCH_QUERY")
    count=$(echo "$results" | wc -l | tr -d ' ')

    if [[ -z "$results" || "$count" == "0" ]]; then
      echo "No tools matching: $SEARCH_QUERY" >&2
      exit 1
    fi

    if [[ "$JSON_OUTPUT" == "1" ]]; then
      echo "{"
      echo "  \"query\": \"$SEARCH_QUERY\","
      echo "  \"results\": ["
      first=true
      while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        if [[ "$first" != "true" ]]; then echo ","; fi
        first=false
        format_tool_json "$entry"
      done <<< "$results"
      echo ""
      echo "  ],"
      echo "  \"count\": $count"
      echo "}"
    else
      echo "=========================================="
      echo "Search: \"$SEARCH_QUERY\" — $count results"
      echo "=========================================="
      while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        format_tool "$entry"
      done <<< "$results"
    fi
    ;;

  info)
    found=""
    for entry in "${TOOL_REGISTRY[@]}"; do
      IFS='|' read -r name desc category file tags <<< "$entry"
      if [[ "$name" == "$SEARCH_QUERY" ]]; then
        found="$entry"
        break
      fi
    done

    if [[ -z "$found" ]]; then
      echo "ERROR: tool not found: $SEARCH_QUERY" >&2
      exit 1
    fi

    IFS='|' read -r name desc category file tags <<< "$found"
    echo "=========================================="
    echo "Tool: $name"
    echo "=========================================="
    echo "Description: $desc"
    echo "Category:    $category"
    echo "File:        $file"
    echo "Tags:        [$tags]"
    echo ""
    echo "Source:      $REPO_ROOT/$file"
    ;;
esac
