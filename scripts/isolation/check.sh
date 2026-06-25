#!/bin/bash
#===============================================================================
# scripts/isolation/check.sh — Worktree file-scope overlap + worktree_role 交叉
# Rule 8 L3: Worktree isolation enforcement
# EPIC-035-B: worktree_role 交叉验证 (T1.worktree_role 跟 T2.worktree_role 兼容检测)
#
# 用法:
#   scripts/isolation/check.sh <ticket1.json> [ticket2.json ...]
#   scripts/isolation/check.sh --self <ticket.json>  # check single ticket
#   scripts/isolation/check.sh --matrix              # print compatibility matrix
#
# 退出码:
#   0 = no conflict (worktree_role 兼容, file_scope 无 overlap)
#   1 = conflict detected (overlap 或 role 不兼容)
#   2 = usage error
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

#===============================================================================
# Constants — worktree_role 兼容性矩阵 (Rule 8 L3 单一真相来源)
#===============================================================================
# 角色定义: master (策略) / conductor (协调) / performer (执行) / auditor (只读审计)
# 兼容性规则:
#   - 同 role + file_scope overlap = CONFLICT (避免覆盖)
#   - master↔{conductor,performer,auditor} = OK (层间独立)
#   - conductor↔{performer,auditor} = OK (层间独立)
#   - performer↔auditor = OK (auditor 只读, 不冲突)
#   - auditor↔auditor = OK (只读)
#===============================================================================
readonly VALID_ROLES=("master" "conductor" "performer" "auditor")

# 角色层 (决定默认兼容性) — 用 _role_layer 函数访问 (兼容 bash 3.2)
_role_layer() {
  case "$1" in
    master) echo "L0" ;;
    conductor) echo "L1" ;;
    performer) echo "L2" ;;
    auditor) echo "L3" ;;
    *) echo "??" ;;
  esac
}

# Read-only 角色 (跟其他角色都兼容, 不会触发 file conflict)
readonly READ_ONLY_ROLES=("auditor")

#===============================================================================
# Helpers
#===============================================================================
log_err() { echo "ERROR: $1" >&2; }
log_warn() { echo "WARN: $1" >&2; }
log_info() { echo "INFO: $1"; }

usage() {
  cat <<'USAGE'
Usage:
  scripts/isolation/check.sh <ticket1.json> [ticket2.json ...]
  scripts/isolation/check.sh --self <ticket.json>
  scripts/isolation/check.sh --matrix

Options:
  --self <ticket.json>   Check a single ticket (验证 schema + 自身 file_scope)
  --matrix               Print worktree_role 兼容性矩阵 (5 角色 × 4 = 20 cells)
  --quiet                Suppress info output (errors still go to stderr)
  -h, --help             Show this help

Exit codes:
  0 = no conflict
  1 = conflict detected
  2 = usage error
USAGE
  exit "${1:-0}"
}

# role_is_valid <role>
role_is_valid() {
  local r="$1"
  for v in "${VALID_ROLES[@]}"; do
    [[ "$v" == "$r" ]] && return 0
  done
  return 1
}

# role_is_readonly <role>
role_is_readonly() {
  local r="$1"
  for v in "${READ_ONLY_ROLES[@]}"; do
    [[ "$v" == "$r" ]] && return 0
  done
  return 1
}

#===============================================================================
# role_compatible <role1> <role2>
# Returns 0 if T1.role and T2.role can coexist (no rule violation).
# Rule: 任意一方为 auditor → OK; 否则要求 file_scope 不重叠 (caller decides)
# 这里只检查 role 维度是否互斥, file_scope 维度由调用方检查.
#===============================================================================
role_compatible() {
  local r1="$1"
  local r2="$2"

  # 任意一方为 auditor (read-only) → 永远兼容
  if role_is_readonly "$r1" || role_is_readonly "$r2"; then
    return 0
  fi

  # 同 role → 需要 caller 检查 file_scope (这里返回 "needs check")
  # 不同 role → 不同 layer, 默认兼容
  if [[ "$r1" == "$r2" ]]; then
    return 0  # 角色层兼容, 留给 scope 检查
  fi

  # master 跟 conductor/performer 都兼容 (层间)
  if [[ "$r1" == "master" ]] || [[ "$r2" == "master" ]]; then
    return 0
  fi

  # conductor 跟 performer 兼容 (层间)
  if [[ "$r1" == "conductor" && "$r2" == "performer" ]] \
    || [[ "$r1" == "performer" && "$r2" == "conductor" ]]; then
    return 0
  fi

  return 0
}

#===============================================================================
# scope_overlap <pattern1> <pattern2>
# 简化版 glob overlap 检查: 比较目录前缀.
# 规则:
#   - 两个 pattern 的前 2 段 (dir/subdir) 都匹配 → overlap
#   - 否则不 overlap
#   - 例子:
#     scripts/isolation/check.sh vs scripts/isolation/foo.sh → OVERLAP
#     scripts/isolation/ vs scripts/verify/ → NO overlap (第 2 段不同)
#     scripts/foo.sh vs audit/logs/ → NO overlap (第 1 段就不同)
#===============================================================================
scope_overlap() {
  local p1="$1"
  local p2="$2"

  # 去除尾部 /** 或 /* 后比较前缀
  local base1="${p1%/\*\*}"
  local base2="${p2%/\*\*}"
  base1="${base1%/\*}"
  base2="${base2%/\*}"

  # 提取前 2 段 (dir/subdir)
  local dir1="${base1%%/*}"
  local rest1="${base1#*/}"
  local subdir1="${rest1%%/*}"

  local dir2="${base2%%/*}"
  local rest2="${base2#*/}"
  local subdir2="${rest2%%/*}"

  # 第 1 段必须相同
  if [[ "$dir1" != "$dir2" ]] || [[ -z "$dir1" ]]; then
    return 1
  fi

  # 第 2 段: 至少一方为空 (说明 pattern 在 dir 级别) → overlap
  # 双方都有第 2 段 → 必须相同才算 overlap
  if [[ -z "$subdir1" ]] || [[ -z "$subdir2" ]]; then
    return 0  # dir 级 pattern vs subdir pattern → overlap
  fi

  if [[ "$subdir1" == "$subdir2" ]]; then
    return 0  # 同 dir+subdir → overlap
  fi

  return 1  # dir 相同但 subdir 不同 → no overlap
}

#===============================================================================
# _ticket_extract <ticket.json> <field>
# 提取 ticket.json 字段 (用 jq, 缺失返回空字符串 + exit 0)
#===============================================================================
_ticket_extract() {
  local ticket="$1"
  local field="$2"

  if [[ ! -f "$ticket" ]]; then
    log_err "ticket file not found: $ticket"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_err "jq not found (required for ticket parsing)"
    return 1
  fi

  jq -r "$field // empty" "$ticket" 2>/dev/null
}

#===============================================================================
# _ticket_scope_patterns <ticket.json>
# 提取 file_scope.includes 数组, 每行一个 glob pattern.
#===============================================================================
_ticket_scope_patterns() {
  local ticket="$1"
  jq -r '.file_scope.includes[]? // empty' "$ticket" 2>/dev/null
}

#===============================================================================
# check_ticket <ticket.json>
# 验证单 ticket 的 worktree_role 字段和 file_scope schema.
# 返回 0 = valid, 1 = invalid
#===============================================================================
check_ticket() {
  local ticket="$1"
  local quiet="${QUIET:-0}"

  if [[ ! -f "$ticket" ]]; then
    log_err "ticket not found: $ticket"
    return 1
  fi

  local tid
  tid="$(_ticket_extract "$ticket" '.id')"
  local role
  role="$(_ticket_extract "$ticket" '.worktree_role')"
  local scope_count
  scope_count="$(_ticket_extract "$ticket" '[.file_scope.includes[]?] | length')"

  if [[ -z "$tid" ]]; then
    log_err "ticket missing .id: $ticket"
    return 1
  fi

  if [[ -z "$role" ]]; then
    log_err "ticket $tid missing worktree_role field (EPIC-035-A 要求)"
    return 1
  fi

  if ! role_is_valid "$role"; then
    log_err "ticket $tid invalid worktree_role: '$role' (must be one of: ${VALID_ROLES[*]})"
    return 1
  fi

  if [[ -z "$scope_count" ]] || [[ "$scope_count" -eq 0 ]]; then
    log_err "ticket $tid missing file_scope.includes"
    return 1
  fi

  [[ "$quiet" -eq 0 ]] && log_info "  $tid role=$role layer=$(_role_layer "$role") scope_patterns=$scope_count"
  return 0
}

#===============================================================================
# check_pair <ticket1.json> <ticket2.json>
# 检查两个 ticket 的 worktree_role 兼容性 + file_scope overlap.
#===============================================================================
check_pair() {
  local t1="$1"
  local t2="$2"
  local quiet="${QUIET:-0}"

  local id1 id2 role1 role2
  id1="$(_ticket_extract "$t1" '.id')"
  id2="$(_ticket_extract "$t2" '.id')"
  role1="$(_ticket_extract "$t1" '.worktree_role')"
  role2="$(_ticket_extract "$t2" '.worktree_role')"

  [[ "$quiet" -eq 0 ]] && log_info "Cross-check: $id1 ($role1) ↔ $id2 ($role2)"

  # 1) role 维度
  if ! role_compatible "$role1" "$role2"; then
    log_err "role conflict: $id1.role=$role1 incompatible with $id2.role=$role2"
    return 1
  fi

  # 2) 同 role (且都不是 auditor) 才需要 scope overlap 检查
  if [[ "$role1" == "$role2" ]] \
    && ! role_is_readonly "$role1"; then
    local p1 p2 overlap_found=0
    while IFS= read -r p1; do
      [[ -z "$p1" ]] && continue
      while IFS= read -r p2; do
        [[ -z "$p2" ]] && continue
        if scope_overlap "$p1" "$p2"; then
          log_err "scope overlap: $id1 '$p1' ↔ $id2 '$p2' (same role=$role1)"
          overlap_found=1
        fi
      done < <(_ticket_scope_patterns "$t2")
    done < <(_ticket_scope_patterns "$t1")

    if [[ "$overlap_found" -ne 0 ]]; then
      return 1
    fi
  fi

  [[ "$quiet" -eq 0 ]] && log_info "  ✓ compatible"
  return 0
}

#===============================================================================
# print_matrix
# 打印 5 角色 × 5 角色 = 20 cells 兼容性矩阵
#===============================================================================
print_matrix() {
  echo "=========================================="
  echo " worktree_role 兼容性矩阵 (Rule 8 L3)"
  echo "=========================================="
  printf "%-12s" "T1\\T2"
  for c in "${VALID_ROLES[@]}"; do
    printf "%-12s" "$c"
  done
  echo ""
  echo "------------------------------------------"
  for r1 in "${VALID_ROLES[@]}"; do
    printf "%-12s" "$r1"
    for r2 in "${VALID_ROLES[@]}"; do
      if [[ "$r1" == "$r2" ]]; then
        if role_is_readonly "$r1"; then
          printf "%-12s" "OK(scope)"
        else
          printf "%-12s" "OK(scope)"
        fi
      elif role_is_readonly "$r1" || role_is_readonly "$r2"; then
        printf "%-12s" "OK"
      else
        printf "%-12s" "OK"
      fi
    done
    echo ""
  done
  echo "------------------------------------------"
  echo "  OK(scope) = 需进一步检查 file_scope overlap"
  echo "  OK         = role 维度兼容 (无 file 冲突)"
  echo "  CONFLICT    = role 不兼容"
  echo ""
  echo "  Layer: master=L0  conductor=L1  performer=L2  auditor=L3"
  echo "  Read-only: auditor (永远 OK 跟其他角色)"
}

#===============================================================================
# main
#===============================================================================
main() {
  if [[ $# -eq 0 ]]; then
    usage 2
  fi

  case "$1" in
    -h|--help)
      usage 0
      ;;
    --matrix)
      print_matrix
      exit 0
      ;;
    --self)
      QUIET="${QUIET:-0}"
      [[ $# -lt 2 ]] && { log_err "--self requires <ticket.json>"; exit 2; }
      if check_ticket "$2"; then
        exit 0
      else
        exit 1
      fi
      ;;
    --quiet)
      QUIET=1
      shift
      [[ $# -eq 0 ]] && { log_err "tickets required after --quiet"; exit 2; }
      ;;
  esac

  if [[ $# -lt 1 ]]; then
    usage 2
  fi

  # 检查所有 ticket 的 schema
  local schema_fail=0
  for t in "$@"; do
    if ! check_ticket "$t"; then
      schema_fail=1
    fi
  done
  if [[ "$schema_fail" -ne 0 ]]; then
    log_err "ticket schema validation failed"
    exit 1
  fi

  # 两两组合检查 (bash 3.2 兼容: 用数组而非 ${!...})
  local -a tickets=("$@")
  local conflict=0
  local n=${#tickets[@]}
  local i j
  for ((i=0; i<n-1; i++)); do
    for ((j=i+1; j<n; j++)); do
      if ! check_pair "${tickets[$i]}" "${tickets[$j]}"; then
        conflict=1
      fi
    done
  done

  if [[ "$conflict" -ne 0 ]]; then
    log_err "isolation check FAILED (conflict detected)"
    exit 1
  fi

  log_info "isolation check PASS (${n} tickets compatible)"
  exit 0
}

main "$@"
