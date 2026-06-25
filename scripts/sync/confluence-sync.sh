#!/usr/bin/env bash
# scripts/sync/confluence-sync.sh — confluence/ 仓 NFS sync (rsync 跨 release 主用)
# EPIC-060-A Phase 3: 3 仓 NFS/S3 sync
#
# 跟 confluence/decisions/ + confluence/memory/ + confluence/research/ 联合 (docs + decisions 仓)
# 跟 eket 4 级降级 模式 联合 (L1 NFS 主用, L0 本地 fs 备)
# 跟"反讽" 联合 治根 vendor lock-in (rsync 跨 release 共识, 0 S3 锁定)
# 跟"不埋坑" 战略 联合 (0 hardcoded paths, env-driven)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
# 跟 v2.7.1 Hard Rule #8 联合 (0 copy-paste — 跟 jira-sync.sh 共享 envsubst pattern)
#
# Usage: bash scripts/sync/confluence-sync.sh [--dry-run] [--target=nfs|local]
#
# Env vars:
#   KALLAX_ROOT          project root (default: auto-detect from script path)
#   CONFLUENCE_SYNC_NFS  NFS target path (default: $KALLAX_ROOT/../confluence-sync/)
#                        Set to empty string to skip NFS sync (local-only)
#
# Returns 0 on success, 1 on failure.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly CONFLUENCE_SUBDIRS=(
    "decisions"
    "memory"
    "research"
    "architecture"
    "runbooks"
    "templates"
    "pitfalls"
)
readonly RSYNC_FLAGS=(
    --archive           # -a: recursive + perms + times + group + owner + devices
    --compress          # -z: compress during transfer
    --human-readable    # output in human-readable format
    --itemize-changes   # -i: detailed change summary
    --delete-after      # delete extraneous after transfer (mirror)
    --partial           # keep partial transfers for resume
)

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFLUENCE_SRC="${KALLAX_ROOT}/confluence"

# NFS target: default to sibling dir, overridable via env (0 hardcoded paths)
CONFLUENCE_NFS="${CONFLUENCE_SYNC_NFS:-${KALLAX_ROOT}/../confluence-sync}"

# ── Flags ──────────────────────────────────────────────────────────────
DRY_RUN=false
TARGET="nfs"
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)    DRY_RUN=true; shift ;;
        --target=local) TARGET="local"; shift ;;
        --target=nfs)   TARGET="nfs";   shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--target=nfs|local]"
            echo "  Confluence仓 sync via rsync (跨 release 累计, 0 vendor lock-in)"
            echo ""
            echo "Env vars:"
            echo "  KALLAX_ROOT          project root"
            echo "  CONFLUENCE_SYNC_NFS  NFS target path (default: \$KALLAX_ROOT/../confluence-sync)"
            echo ""
            echo "Subdirs synced:"
            for d in "${CONFLUENCE_SUBDIRS[@]}"; do
                echo "  - confluence/$d"
            done
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }
warn()  { echo "[WARN] $*"; }

# ── Verify rsync ───────────────────────────────────────────────────────
if ! command -v rsync >/dev/null 2>&1; then
    err "rsync not found. Run: bash scripts/sync/install-rsync.sh"
    exit 1
fi

# ── Verify source exists ───────────────────────────────────────────────
if [ ! -d "$CONFLUENCE_SRC" ]; then
    err "Source not found: $CONFLUENCE_SRC"
    exit 1
fi

# ── Verify each subdir exists (跟 Phase 1+2 联合 跨 release 累计) ─────
EXISTING_SUBDIRS=()
for d in "${CONFLUENCE_SUBDIRS[@]}"; do
    if [ -d "$CONFLUENCE_SRC/$d" ]; then
        EXISTING_SUBDIRS+=("$d")
    else
        warn "Subdir missing (skipped): confluence/$d"
    fi
done

if [ "${#EXISTING_SUBDIRS[@]}" -eq 0 ]; then
    err "No confluence subdirs found under $CONFLUENCE_SRC"
    exit 1
fi

# ── Build rsync include/exclude list (0 magic numbers, named subdirs) ─
# Pattern: --include=/<dir>/ for the dir itself + --include=/<dir>/* for contents
# (跟 openrsync + GNU rsync 跨 platform 兼容 联合)
INCLUDE_ARGS=()
for d in "${EXISTING_SUBDIRS[@]}"; do
    INCLUDE_ARGS+=("--include=/$d/")
    INCLUDE_ARGS+=("--include=/$d/*")
done

# ── Resolve target ─────────────────────────────────────────────────────
case "$TARGET" in
    nfs)
        if [ -z "$CONFLUENCE_NFS" ]; then
            err "NFS target empty (set CONFLUENCE_SYNC_NFS or use --target=local)"
            exit 1
        fi
        TARGET_PATH="$CONFLUENCE_NFS"
        info "Target: NFS → $TARGET_PATH"
        ;;
    local)
        TARGET_PATH="${KALLAX_ROOT}/.claude/sync-state/confluence"
        info "Target: local mirror → $TARGET_PATH"
        ;;
    *)
        err "Unknown target: $TARGET (expected: nfs|local)"
        exit 1
        ;;
esac

# ── Create target dir ──────────────────────────────────────────────────
mkdir -p "$TARGET_PATH"

# ── Ensure sync-state log dir exists (跟"反讽" 联合 0 silent) ──────────
SYNC_LOG_DIR="${KALLAX_ROOT}/.claude/sync-state"
mkdir -p "$SYNC_LOG_DIR"
SYNC_LOG_FILE="${SYNC_LOG_DIR}/confluence-sync.log"

# ── Build rsync command ────────────────────────────────────────────────
RSYNC_CMD=(rsync "${RSYNC_FLAGS[@]}" "${INCLUDE_ARGS[@]}" --exclude="*")
if [ "$DRY_RUN" = true ]; then
    RSYNC_CMD+=("--dry-run")
    info "DRY RUN — no changes will be made"
fi

# ── Summary header ─────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " EPIC-060-A Phase 3 — confluence/ 仓 sync"
echo "════════════════════════════════════════════"
echo "  Source:      $CONFLUENCE_SRC"
echo "  Target:      $TARGET_PATH"
echo "  Subdirs:     ${EXISTING_SUBDIRS[*]}"
echo "  Dry-run:     $DRY_RUN"
echo ""

# ── Execute rsync (跟 eket 4 级降级 模式 L1 NFS 主用 联合) ─────────────
ok "Starting rsync (rsync binary exec, 0 mocks, 跟 Hard Rule #3 联合)"
if ! "${RSYNC_CMD[@]}" "$CONFLUENCE_SRC/" "$TARGET_PATH/" 2>&1 | tee "$SYNC_LOG_FILE" >/dev/null; then
    err "rsync failed (see $SYNC_LOG_FILE)"
    exit 1
fi
ok "rsync completed"

# ── L2 fallback verification (跟 eket 4 级降级 模式 联合) ─────────────
local_count="$(find "$CONFLUENCE_SRC" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$TARGET" = "nfs" ] || [ "$DRY_RUN" = true ]; then
    ok "L1 NFS:    $TARGET_PATH (sync target)"
fi
ok "L2 local:  $CONFLUENCE_SRC (always-on source, 跟 eket 4 级降级 模式 联合)"
ok "Source contains $local_count files (跨 release 累计)"

echo ""
ok "confluence/ 仓 sync complete (跟 Phase 1+2+4+5 联合 跨 layer 跨 node 复制)"
exit 0
