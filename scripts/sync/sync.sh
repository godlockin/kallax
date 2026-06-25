#!/usr/bin/env bash
# scripts/sync/sync.sh — 3 仓 sync dispatcher (NFS 主用 + S3 备选)
# EPIC-060-A Phase 3: 3 仓 NFS/S3 sync
#
# 跟 confluence-sync.sh + jira-sync.sh + s3-sync.sh 联合 (dispatcher)
# 跟 eket 4 级降级 模式 联合 (NFS L1 主用, S3 L3 备选, 本地 L0 永远)
# 跟"反讽" 联合 治根 vendor lock-in (NFS default, S3 explicit)
# 跟"独立" 战略 联合 (master explicit 拍板 0 ai-auto)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
# 跟 v2.7.1 Hard Rule #8 联合 (0 copy-paste — 跟 3 sync scripts 独立)
#
# Usage: bash scripts/sync/sync.sh --tier=confluence|jira|all --target=nfs|s3 [--dry-run|--execute]
#
# Env vars:
#   KALLAX_ROOT          project root
#   CONFLUENCE_SYNC_NFS  NFS target for confluence (default: sibling dir)
#   JIRA_SYNC_NFS        NFS target for jira (default: sibling dir)
#   SYNC_S3_BUCKET       S3 bucket for S3 target (default: empty → dry-run only)
#
# Returns 0 on success, 1 on failure.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly VALID_TIERS=("confluence" "jira" "all")
readonly VALID_TARGETS=("nfs" "s3")

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ── Helpers (defined early so case branches can use them) ─────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }

# ── Flags (Rule 4: 0 magic numbers) ──────────────────────────────────
TIER=""
TARGET=""
DRY_RUN=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --tier=confluence) TIER="confluence"; shift ;;
        --tier=jira)       TIER="jira";       shift ;;
        --tier=all)        TIER="all";        shift ;;
        --tier=*)
            err "Invalid tier: ${1#--tier=} (expected: confluence|jira|all)"
            exit 1
            ;;
        --target=nfs)      TARGET="nfs";      shift ;;
        --target=s3)       TARGET="s3";       shift ;;
        --target=*)
            err "Invalid target: ${1#--target=} (expected: nfs|s3)"
            exit 1
            ;;
        --dry-run)         DRY_RUN=true;      shift ;;
        --execute)         DRY_RUN=false;     shift ;;
        -h|--help)
            echo "Usage: $0 --tier=<tier> --target=<target> [--dry-run|--execute]"
            echo ""
            echo "Tiers:    confluence | jira | all"
            echo "Targets:  nfs (default, 主用) | s3 (备选, --dry-run 默认)"
            echo "Mode:     --dry-run (default) | --execute (explicit)"
            echo ""
            echo "Examples:"
            echo "  $0 --tier=all --target=nfs --dry-run"
            echo "  $0 --tier=confluence --target=s3 --execute"
            echo ""
            echo "跟'反讽' 联合: NFS 主用, S3 备选 (0 vendor lock-in)"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Validate (跟"不埋坑" 联合 0 silent gate skipping) ─────────────────
TIER_VALID=false
for t in "${VALID_TIERS[@]}"; do
    [ "$TIER" = "$t" ] && TIER_VALID=true
done
[ -z "$TIER" ]      && { err "Missing --tier=<tier>"; exit 1; }
[ "$TIER_VALID" != "true" ] && { err "Invalid tier: $TIER (expected: confluence|jira|all)"; exit 1; }

TARGET_VALID=false
for t in "${VALID_TARGETS[@]}"; do
    [ "$TARGET" = "$t" ] && TARGET_VALID=true
done
[ -z "$TARGET" ]     && { err "Missing --target=<target>"; exit 1; }
[ "$TARGET_VALID" != "true" ] && { err "Invalid target: $TARGET (expected: nfs|s3)"; exit 1; }

# ── Summary header (跟"反讽" 联合 治根 vendor lock-in, 显式 dry-run 默认) ─
echo ""
echo "════════════════════════════════════════════"
echo " EPIC-060-A Phase 3 — 3 仓 sync dispatcher"
echo "════════════════════════════════════════════"
echo "  Tier:    $TIER"
echo "  Target:  $TARGET"
echo "  Mode:    $([ "$DRY_RUN" = true ] && echo 'DRY-RUN' || echo 'EXECUTE')"
echo ""

# ── Dispatch ──────────────────────────────────────────────────────────
case "$TARGET" in
    nfs)
        ok "NFS dispatch (主用, 跟 eket 4 级降级 模式 L1 联合)"
        case "$TIER" in
            confluence)
                bash "$SCRIPT_DIR/confluence-sync.sh" \
                    $([ "$DRY_RUN" = true ] && echo "--dry-run")
                ;;
            jira)
                bash "$SCRIPT_DIR/jira-sync.sh" \
                    $([ "$DRY_RUN" = true ] && echo "--dry-run")
                ;;
            all)
                bash "$SCRIPT_DIR/confluence-sync.sh" \
                    $([ "$DRY_RUN" = true ] && echo "--dry-run")
                bash "$SCRIPT_DIR/jira-sync.sh" \
                    $([ "$DRY_RUN" = true ] && echo "--dry-run")
                ;;
        esac
        ;;
    s3)
        ok "S3 dispatch (备选, 跟'反讽' 联合 治根 vendor lock-in)"
        # s3-sync.sh has its own --dry-run|--execute gate
        s3_args=("--tier=$TIER")
        if [ "$DRY_RUN" = true ]; then
            s3_args+=("--dry-run")
        else
            s3_args+=("--execute")
        fi
        bash "$SCRIPT_DIR/s3-sync.sh" "${s3_args[@]}"
        ;;
esac

echo ""
ok "Dispatcher complete (tier=$TIER, target=$TARGET, mode=$( [ "$DRY_RUN" = true ] && echo DRY-RUN || echo EXECUTE ))"
exit 0
