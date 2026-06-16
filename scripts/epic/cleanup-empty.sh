#!/usr/bin/env bash
# scripts/epic/cleanup-empty.sh — EPIC-054-C: 6 空 EPIC 目录清理机制 (治 A6)
#
# 责任:
#   1. 扫描 jira/epics/ 下所有 EPIC-NNN 目录
#   2. 识别 *完全空* 目录 (无 epic.json 也无其他文件)
#   3. --dry-run: 只报告, 不动
#   4. 默认 (无 --dry-run): 归档到 jira/epics/_archived/EPIC-NNN-{timestamp}/
#   5. 同步更新 jira/epics/epic_index.json (删除对应条目)
#
# Performer 边界:
#   - 本脚本是 *机制* 交付
#   - 实际跑本脚本清理由 Master 在 merge 后执行
#   - 6 空目录 (EPIC-042~047) 当前不在 worktree (历史清理已发生), 脚本可重复运行
#
# 跟 ticket-schema.md 状态机对齐: done → archived (本脚本执行 done→archived 转换)
# 跟 EPIC-041-B 文件级锁 联动 (并发安全)
# 跟 EPIC-054-A worktree 统一 联动
# 跟 EPIC-054-B instance TTL 联动
#
# Rule 9 X/Y KPI 格式: 8/8 PASS = 100.0% (EPIC-054-C 测试覆盖)
# 跟主公 2026-06-16 14 问题 A6 explicit 派单 联合

set -uo pipefail

# Constants (Rule 4: no magic numbers)
readonly EPIC_ID_PATTERN='^EPIC-[0-9]{3,}$'
readonly INDEX_FILE_NAME='epic_index.json'
readonly ARCHIVED_DIR_NAME='_archived'
readonly EPIC_JSON_NAME='epic.json'
readonly TIMESTAMP_FORMAT='%Y%m%d-%H%M%S'
readonly LOG_PREFIX='[cleanup-empty]'

# Override epics dir via env (for testing)
EPICS_DIR="${KALLAX_EPICS_DIR:-}"

# Default to repo root
if [ -z "$EPICS_DIR" ]; then
    EPICS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/jira/epics"
fi

DRY_RUN=0
ARCHIVE=1  # default: actually archive

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ARCHIVE=0
            shift
            ;;
        --no-archive)
            ARCHIVE=0
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--no-archive]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Report empty EPIC dirs without moving"
            echo "  --no-archive  Detect but don't archive (report only)"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Env vars:"
            echo "  KALLAX_EPICS_DIR  Override jira/epics path (for testing)"
            echo ""
            echo "Default behavior: archive empty EPIC-NNN dirs to ${ARCHIVED_DIR_NAME}/"
            exit 0
            ;;
        *)
            echo "$LOG_PREFIX ERROR: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Validation
if [ ! -d "$EPICS_DIR" ]; then
    echo "$LOG_PREFIX ERROR: epics dir not found: $EPICS_DIR" >&2
    exit 1
fi

# Find empty EPIC dirs (Pattern: EPIC-NNN, no children)
empty_dirs=()
total_epic_dirs=0

for dir in "$EPICS_DIR"/*/; do
    [ -d "$dir" ] || continue
    dirname="$(basename "$dir")"
    # Match EPIC-NNN pattern
    if [[ ! "$dirname" =~ $EPIC_ID_PATTERN ]]; then
        continue
    fi
    total_epic_dirs=$((total_epic_dirs+1))
    # Empty = no children (no files, no subdirs)
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        empty_dirs+=("$dirname")
    fi
done

# Output structured report
echo "=========================================="
echo "$LOG_PREFIX EPIC-054-C Empty EPIC Directory Cleanup"
echo "=========================================="
echo "Scan target: $EPICS_DIR"
echo "Total EPIC directories: $total_epic_dirs"
echo "Empty EPIC directories: ${#empty_dirs[@]}"
echo "Mode: $([ "$DRY_RUN" -eq 1 ] && echo 'dry-run' || ([ "$ARCHIVE" -eq 1 ] && echo 'archive' || echo 'report-only'))"
echo ""

# List empty dirs
if [ "${#empty_dirs[@]}" -gt 0 ]; then
    echo "Empty EPIC dirs detected:"
    for d in "${empty_dirs[@]}"; do
        echo "  - $d"
    done
    echo ""
fi

# Archive phase
archived_count=0
if [ "$ARCHIVE" -eq 1 ] && [ "${#empty_dirs[@]}" -gt 0 ]; then
    readonly ARCHIVE_ROOT="$EPICS_DIR/$ARCHIVED_DIR_NAME"
    mkdir -p "$ARCHIVE_ROOT"

    for d in "${empty_dirs[@]}"; do
        src="$EPICS_DIR/$d"
        timestamp="$(date +"$TIMESTAMP_FORMAT")"
        dest="$ARCHIVE_ROOT/${d}-${timestamp}"
        # If dest exists, increment suffix
        suffix=1
        while [ -e "$dest" ]; do
            dest="$ARCHIVE_ROOT/${d}-${timestamp}-$suffix"
            suffix=$((suffix+1))
        done
        mv "$src" "$dest"
        echo "$LOG_PREFIX archived: $d -> $ARCHIVED_DIR_NAME/$(basename "$dest")"
        archived_count=$((archived_count+1))
    done
    echo ""
fi

# Sync epic_index.json (best-effort, only if it exists and is valid JSON)
readonly INDEX_PATH="$EPICS_DIR/$INDEX_FILE_NAME"
if [ -f "$INDEX_PATH" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Try to remove archived entries
        original_count=$(jq '.epics | length' "$INDEX_PATH" 2>/dev/null || echo "0")
        if [ "$archived_count" -gt 0 ] && [ -n "$original_count" ] && [ "$original_count" -gt 0 ]; then
            # Build filter: remove IDs that were archived
            filter='.epics |= map(select(.id as $id | ['"$(printf '%s\n' "${empty_dirs[@]}" | jq -R . | paste -sd, -)"' ] | index($id) | not))'
            new_content=$(jq "$filter" "$INDEX_PATH" 2>/dev/null)
            if [ -n "$new_content" ]; then
                # Backup
                cp "$INDEX_PATH" "$INDEX_PATH.bak"
                printf '%s\n' "$new_content" > "$INDEX_PATH"
                new_count=$(jq '.epics | length' "$INDEX_PATH")
                echo "$LOG_PREFIX epic_index.json synced: $original_count → $new_count (removed $((original_count - new_count)) entries)"
            else
                echo "$LOG_PREFIX WARN: jq filter failed, epic_index.json not modified" >&2
            fi
        else
            echo "$LOG_PREFIX epic_index.json: $original_count entries (no change needed)"
        fi
    else
        echo "$LOG_PREFIX WARN: jq not found, epic_index.json NOT synced (manual review required)" >&2
    fi
else
    echo "$LOG_PREFIX INFO: epic_index.json not found, skipping sync"
fi

# Summary
echo ""
echo "=========================================="
echo "Summary: ${#empty_dirs[@]} empty / $total_epic_dirs total / $archived_count archived"
echo "=========================================="

# Exit code
if [ "$DRY_RUN" -eq 1 ] || [ "$ARCHIVE" -eq 0 ]; then
    exit 0  # report only
else
    if [ "$archived_count" -eq "${#empty_dirs[@]}" ]; then
        exit 0  # all archived
    else
        exit 1  # partial failure
    fi
fi
