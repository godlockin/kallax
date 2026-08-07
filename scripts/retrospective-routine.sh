#!/usr/bin/env bash
# scripts/retrospective-routine.sh — EPIC-161 阶段性回顾 6 阶段 routine
#
# 主公 2026-08-03 拍板: 复盘、整理、review docs、升级、归档、删除.
# 跟 eket MASTER-RULES.md §10 Post-Process 4 步骤 升级 (跟 EPIC-059-E Post-Process 11 步骤 1:1 互补).
#
# Usage:
#   retrospective-routine.sh --dry-run                       # 显示 6 阶段 inventory (fail-safe default)
#   retrospective-routine.sh --apply                        # 实际 执行 (override dry-run)
#   retrospective-routine.sh --phase=release                 # release 触发
#   retrospective-routine.sh --phase=quarter                 # quarterly 触发
#   retrospective-routine.sh --phase=governance-debt         # 治理债 threshold 触发
#   retrospective-routine.sh --stages=retrospect,archive     # 只跑 2 阶段
#   retrospective-routine.sh --json                          # JSON 输出 (跟 EPIC-069-D 透明可验证 1:1)
#   retrospective-routine.sh --help                          # 详细帮助
#
# 6 阶段 (跟主公拍板顺序 1:1):
#   1. retrospect (复盘)         — 列最近 N release, key changes / decisions / regressions
#   2. consolidate (整理)        — 合并重复 docs / 移除 dead refs / 压缩 oversized files (>200 行 CLAUDE.md pattern)
#   3. review-docs (review 文档) — 验证 lazy-load refs / path-scoped rules / docs/reference/ relevance
#   4. upgrade (升级)            — deps outdated / tool version / install.sh Omnibus
#   5. archive (归档)            — 移 deprecated → _archived/ (跟 v3.32.0 38 docs 1:1)
#   6. delete (删除)             — 0-use files / unused exports / dead scripts
#
# 默认行为: dry-run (跟 Rule 4 "Fail Fast" 联合, 默认安全)
# 真实 执行:  --apply (override dry-run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# KALLAX_ROOT 优先 git top-level (worktree-safe), fallback 到 scripts/../..
if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  KALLAX_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
  KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Constants
readonly TOTAL_STAGES=6
readonly STAGE_NAMES=(
    "retrospect"
    "consolidate"
    "review-docs"
    "upgrade"
    "archive"
    "delete"
)

# Defaults
DRY_RUN=true
APPLY=false
PHASE="all"
STAGES_FILTER=""
JSON_OUTPUT=false

# Parse args
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)        DRY_RUN=true; shift ;;
      --apply)          APPLY=true; DRY_RUN=false; shift ;;
      --phase=*)
        PHASE="${1#--phase=}"
        shift
        ;;
      --stages=*)
        STAGES_FILTER="${1#--stages=}"
        shift
        ;;
      --json)           JSON_OUTPUT=true; shift ;;
      -h|--help)
        cat <<'EOF'
retrospective-routine.sh — EPIC-161 阶段性回顾 6 阶段 routine

Usage:
  retrospective-routine.sh --dry-run                       # 显示 6 阶段 inventory (default)
  retrospective-routine.sh --apply                        # 实际执行
  retrospective-routine.sh --phase=release|quarter|governance-debt|all
  retrospective-routine.sh --stages=retrospect,archive    # 部分跑
  retrospective-routine.sh --json                          # JSON 输出

6 阶段:
  1. retrospect     — 列最近 N release, key changes / decisions / regressions
  2. consolidate    — 合并重复 docs / 移除 dead refs / 压缩 oversized files
  3. review-docs    — 验证 lazy-load refs / path-scoped rules
  4. upgrade        — deps / tool version / install.sh Omnibus
  5. archive        — 移 deprecated → _archived/
  6. delete         — 0-use files / unused exports / dead scripts

Default: --dry-run (fail-safe). Use --apply to execute.
EOF
        exit 0
        ;;
      *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
  done
}

# Helper: should run stage N?
should_run_stage() {
  local stage="$1"
  [ -z "$STAGES_FILTER" ] && return 0
  case ",$STAGES_FILTER," in
    *",$stage,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Helper: emit message
emit() {
  local stage="$1"; local msg="$2"
  if $JSON_OUTPUT; then
    return 0  # JSON mode: skip per-line emit
  fi
  if $DRY_RUN; then
    echo "[dry-run] [$stage] $msg"
  else
    echo "[apply]   [$stage] $msg"
  fi
}

# ─── Stage 1: retrospect ──────────────────────────────────────────────────

stage_retrospect() {
  local stage="retrospect"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "listing recent N release from CHANGELOG.md"

  local changelog="${KALLAX_ROOT}/CHANGELOG.md"
  if [ ! -f "$changelog" ]; then
    echo "  ! CHANGELOG.md not found, skipping"
    return 0
  fi

  local releases
  releases=$(grep -E "^## \[" "$changelog" 2>/dev/null | head -10 || echo "")
  if [ -z "$releases" ]; then
    echo "  ! no releases found in CHANGELOG.md"
    return 0
  fi

  echo "  Recent releases (top 10):"
  echo "$releases" | sed 's/^/    /'

  # Per release, extract key changes (跟 EPIC-069-D 透明可验证)
  local release_count
  release_count=$(echo "$releases" | wc -l | tr -d ' ')
  echo "  Total releases scanned: $release_count"
}

# ─── Stage 2: consolidate ─────────────────────────────────────────────────

stage_consolidate() {
  local stage="consolidate"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "scanning oversized files + duplicate docs"

  # Check CLAUDE.md line count (跟 EPIC-159 Anthropic 硬阈值 ≤ 200)
  local claude_md="${KALLAX_ROOT}/CLAUDE.md"
  if [ -f "$claude_md" ]; then
    local lines
    lines=$(wc -l < "$claude_md" | tr -d ' ')
    if [ "$lines" -gt 200 ]; then
      echo "  ⚠ CLAUDE.md = $lines 行 (> 200 Anthropic 硬阈值, 建议 trim)"
    else
      echo "  ✓ CLAUDE.md = $lines 行 (≤ 200 OK)"
    fi
  fi

  # Check duplicated files (same name in multiple dirs)
  local dup_count=0
  while IFS= read -r f; do
    local name
    name=$(basename "$f")
    local count
    count=$(find "$KALLAX_ROOT" -name "$name" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 1 ]; then
      dup_count=$((dup_count + 1))
    fi
  done < <(find "$KALLAX_ROOT" -maxdepth 3 -type f \( -name "*.md" -o -name "*.sh" \) 2>/dev/null | head -20)
  echo "  Duplicate file candidates: $dup_count (heuristic)"

  # Count _archived/ dir size (跟 v3.32.0 38 docs pattern 1:1)
  if [ -d "$KALLAX_ROOT/_archived" ]; then
    local archived
    archived=$(find "$KALLAX_ROOT/_archived" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  _archived/ 已存: $archived files"
  else
    echo "  _archived/ 不存在"
  fi
}

# ─── Stage 3: review-docs ──────────────────────────────────────────────────

stage_review_docs() {
  local stage="review-docs"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "verifying lazy-load + path-scoped rules"

  # .claude/rules/ files count (跟 EPIC-159)
  local rules_count=0
  if [ -d "$KALLAX_ROOT/.claude/rules" ]; then
    rules_count=$(find "$KALLAX_ROOT/.claude/rules" -maxdepth 1 -type l -o -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  .claude/rules/ files: $rules_count"

  # docs/reference/ files count (lazy-load)
  local ref_count=0
  if [ -d "$KALLAX_ROOT/docs/reference" ]; then
    ref_count=$(find "$KALLAX_ROOT/docs/reference" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  docs/reference/ files: $ref_count"

  # confluence/ decisions (主公拍板记录)
  local decisions=0
  if [ -d "$KALLAX_ROOT/confluence/decisions" ]; then
    decisions=$(find "$KALLAX_ROOT/confluence/decisions" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  confluence/decisions/ files: $decisions"

  # Each .claude/rules/*.md 应含 paths: frontmatter (跟 EPIC-159 AC)
  local missing_paths=0
  if [ -d "$KALLAX_ROOT/.claude/rules" ]; then
    for f in "$KALLAX_ROOT"/.claude/rules/*.md; do
      [ -f "$f" ] || continue
      if ! grep -q "^paths:" "$f"; then
        echo "  ⚠ $(basename "$f") missing paths: frontmatter"
        missing_paths=$((missing_paths + 1))
      fi
    done
  fi
  if [ "$missing_paths" -eq 0 ]; then
    echo "  ✓ All rules files have paths: frontmatter"
  else
    echo "  ⚠ $missing_paths rules files missing paths: frontmatter"
  fi
}

# ─── Stage 4: upgrade ─────────────────────────────────────────────────────

stage_upgrade() {
  local stage="upgrade"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "checking deps + tool version + install.sh Omnibus"

  # node version
  if command -v node >/dev/null 2>&1; then
    echo "  node: $(node --version 2>&1)"
  else
    echo "  ! node not found"
  fi

  # rust version
  if command -v rustc >/dev/null 2>&1; then
    echo "  rustc: $(rustc --version 2>&1 | cut -d' ' -f2)"
  else
    echo "  ! rustc not found"
  fi

  # Cargo.toml version vs current version (跟 EPIC-147 version drift pattern)
  if [ -f "$KALLAX_ROOT/rust/Cargo.toml" ]; then
    local cargo_ver
    cargo_ver=$(grep -E "^version" "$KALLAX_ROOT/rust/Cargo.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    echo "  rust/Cargo.toml version: $cargo_ver"
  fi

  if [ -f "$KALLAX_ROOT/node/package.json" ]; then
    local node_ver
    node_ver=$(jq -r '.version // "unknown"' "$KALLAX_ROOT/node/package.json" 2>/dev/null)
    echo "  node/package.json version: $node_ver"
  fi

  # install.sh --inventory (跟 EPIC-160 Omnibus 1:1)
  if [ -x "$KALLAX_ROOT/scripts/install.sh" ]; then
    local inv_total
    inv_total=$(bash "$KALLAX_ROOT/scripts/install.sh" --inventory 2>&1 | grep -oE 'Total: [0-9]+ files' | grep -oE '[0-9]+' || echo "?")
    echo "  install.sh --inventory: $inv_total files"
  fi
}

# ─── Stage 5: archive ─────────────────────────────────────────────────────

stage_archive() {
  local stage="archive"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "scanning deprecated/abandoned files"

  # Find files with 'deprecated' / 'abandoned' / 'archived' markers
  local deprecated_count=0
  while IFS= read -r f; do
    if grep -qE "DEPRECATED|ABANDONED|@deprecated" "$f" 2>/dev/null; then
      deprecated_count=$((deprecated_count + 1))
      echo "    - $f"
    fi
  done < <(find "$KALLAX_ROOT" -maxdepth 4 -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" \) 2>/dev/null | grep -v node_modules | head -50)
  echo "  Deprecated markers found: $deprecated_count"

  # Check if _archived/ exists
  if [ ! -d "$KALLAX_ROOT/_archived" ]; then
    if $APPLY; then
      mkdir -p "$KALLAX_ROOT/_archived"
      echo "  ✓ Created _archived/ directory"
    else
      echo "  ! _archived/ 不存在 (--apply 后会创建)"
    fi
  fi
}

# ─── Stage 6: delete ───────────────────────────────────────────────────────

stage_delete() {
  local stage="delete"
  if ! should_run_stage "$stage"; then return 0; fi
  emit "$stage" "scanning 0-use files + unused exports"

  # 0-byte files (heuristic for placeholder/abandoned)
  local zero_byte=0
  while IFS= read -r f; do
    if [ ! -s "$f" ]; then
      zero_byte=$((zero_byte + 1))
      echo "    - $f (0 bytes)"
    fi
  done < <(find "$KALLAX_ROOT" -maxdepth 4 -type f 2>/dev/null | grep -v node_modules | head -50)
  echo "  0-byte files: $zero_byte"

  # Dead code sentinel status (跟 EPIC-131/132)
  if [ -x "$KALLAX_ROOT/scripts/scan-dead-code.sh" ]; then
    local scan_exit
    scan_exit=$(bash "$KALLAX_ROOT/scripts/scan-dead-code.sh" > /dev/null 2>&1; echo $?)
    echo "  scan-dead-code.sh exit: $scan_exit (0=PASS, 1=FAIL, 2=BLOCKED-env)"
  fi
}

# ─── Main dispatch ─────────────────────────────────────────────────────────

print_header() {
  echo "================================================"
  echo "Retrospective Routine (EPIC-161) — 6 stages"
  echo "Phase: $PHASE"
  if $DRY_RUN; then
    echo "Mode:  DRY-RUN (--apply to execute)"
  else
    echo "Mode:  APPLY"
  fi
  if [ -n "$STAGES_FILTER" ]; then
    echo "Filter: $STAGES_FILTER"
  fi
  echo "================================================"
  echo ""
}

main() {
  parse_args "$@"

  # JSON mode: skip header, emit pure JSON only
  if $JSON_OUTPUT; then
    printf '{"phase":"%s","dry_run":%s,"stages":[' "$PHASE" "$($DRY_RUN && echo true || echo false)"
    local first=true
    for stage in "${STAGE_NAMES[@]}"; do
      if should_run_stage "$stage"; then
        if $first; then first=false; else printf ','; fi
        printf '"%s"' "$stage"
      fi
    done
    printf ']}\n'
    return 0
  fi

  print_header

  stage_retrospect
  echo ""
  stage_consolidate
  echo ""
  stage_review_docs
  echo ""
  stage_upgrade
  echo ""
  stage_archive
  echo ""
  stage_delete
  echo ""
  echo "================================================"
  echo "Done. Phase: $PHASE, Dry-run: $($DRY_RUN && echo yes || echo no)"
  echo "================================================"
}

main "$@"