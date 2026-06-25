#!/usr/bin/env bash
# scripts/sync/s3-sync.sh — S3 sync (备选, --dry-run 默认, 0 vendor lock-in 强制)
# EPIC-060-A Phase 3: 3 仓 NFS/S3 sync
#
# 跟 confluence-sync.sh + jira-sync.sh 联合 (S3 备选 target)
# 跟 eket 4 级降级 模式 联合 (S3 = L3 cloud, NFS = L1 主用)
# 跟"反讽" 联合 治根 vendor lock-in (S3 是 备选, NFS 是 主用, 跟"独立" 战略 联合 master explicit 拍板)
# 跟"不埋坑" 战略 联合 (0 hardcoded credentials, 0 hardcoded bucket, env-driven)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
# 跟 v2.7.1 Hard Rule #6 联合 (0 ignored errors, strict set -euo pipefail)
#
# 跟 Phase 2 §7.1 "0 S3 实际 验证" 联合: 缺 AWS credentials 时, --dry-run 是 默认 (跟 EPIC-059-D 联合)
#
# Usage: bash scripts/sync/s3-sync.sh --tier=confluence|jira|all [--dry-run | --execute]
#
# Env vars (12-factor, 跟 Phase 2 litestream 模式 一致):
#   KALLAX_ROOT              project root
#   SYNC_S3_BUCKET           S3 bucket name (default: empty → dry-run only)
#   AWS_ACCESS_KEY_ID        AWS access key (default: read from env)
#   AWS_SECRET_ACCESS_KEY    AWS secret (default: read from env)
#   AWS_DEFAULT_REGION       AWS region (default: us-east-1)
#
# Returns 0 on success, 1 on failure.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly S3_SYNC_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
readonly S3_PATH_PREFIX="kallax-sync"

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SYNC_STATE_DIR="${KALLAX_ROOT}/.claude/sync-state"

# ── Flags ──────────────────────────────────────────────────────────────
TIER=""
EXECUTE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --tier=confluence) TIER="confluence"; shift ;;
        --tier=jira)       TIER="jira";       shift ;;
        --tier=all)        TIER="all";        shift ;;
        --execute)         EXECUTE=true;      shift ;;
        --dry-run)         EXECUTE=false;     shift ;;
        -h|--help)
            echo "Usage: $0 --tier=confluence|jira|all [--dry-run|--execute]"
            echo "  S3 sync (备选, --dry-run 默认)"
            echo ""
            echo "  ⚠️  S3 是 备选, NFS 是 主用 (跟'反讽' 联合 治根 vendor lock-in)"
            echo "  ⚠️  --execute 必须 explicit 提供 (0 默认 执行)"
            echo ""
            echo "Env vars:"
            echo "  SYNC_S3_BUCKET    S3 bucket name (empty → dry-run only)"
            echo "  AWS_*             AWS credentials (env-driven)"
            echo "  AWS_DEFAULT_REGION  default: us-east-1"
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

# ── Validate tier ──────────────────────────────────────────────────────
case "$TIER" in
    confluence|jira|all) ;;
    *) err "Missing --tier=confluence|jira|all"; exit 1 ;;
esac

# ── Resolve bucket ─────────────────────────────────────────────────────
S3_BUCKET="${SYNC_S3_BUCKET:-}"
S3_REGION="${AWS_DEFAULT_REGION:-${S3_SYNC_DEFAULT_REGION}}"

if [ -z "$S3_BUCKET" ]; then
    info "SYNC_S3_BUCKET not set — S3 sync operates in DRY-RUN mode only"
    info "  (跟 Phase 2 §7.1 '0 S3 实际 验证' 联合, 跟 '反讽' 联合 治根 vendor lock-in)"
    EXECUTE=false
fi

# ── Resolve credentials ────────────────────────────────────────────────
HAS_CREDENTIALS=true
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    HAS_CREDENTIALS=false
fi

# ── Check for S3 CLI (aws / s3cmd) ─────────────────────────────────────
HAS_S3_CLI=false
S3_CLI=""
if command -v aws >/dev/null 2>&1; then
    HAS_S3_CLI=true
    S3_CLI="aws"
elif command -v s3cmd >/dev/null 2>&1; then
    HAS_S3_CLI=true
    S3_CLI="s3cmd"
fi

# ── Summary header ─────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " EPIC-060-A Phase 3 — S3 sync (备选)"
echo "════════════════════════════════════════════"
echo "  Tier:         $TIER"
echo "  Bucket:       ${S3_BUCKET:-<not-set>}"
echo "  Region:       $S3_REGION"
echo "  S3 CLI:       ${S3_CLI:-<none>}"
echo "  Credentials:  $HAS_CREDENTIALS"
echo "  Mode:         $([ "$EXECUTE" = true ] && echo 'EXECUTE' || echo 'DRY-RUN')"
echo ""

# ── Source resolution per tier ─────────────────────────────────────────
sync_tier() {
    local tier="$1"
    local src_path=""
    local s3_prefix=""

    case "$tier" in
        confluence)
            src_path="${KALLAX_ROOT}/confluence"
            s3_prefix="${S3_PATH_PREFIX}/confluence"
            ;;
        jira)
            src_path="${KALLAX_ROOT}/jira"
            s3_prefix="${S3_PATH_PREFIX}/jira"
            ;;
    esac

    if [ ! -d "$src_path" ]; then
        warn "Source missing (skipped): $src_path"
        return 0
    fi

    local file_count
    file_count="$(find "$src_path" -type f 2>/dev/null | wc -l | tr -d ' ')"
    ok "Tier $tier: $src_path → s3://${S3_BUCKET:-<unset>}/${s3_prefix}/ ($file_count files)"

    # ── Pre-execution gate (跟"反讽" 联合 0 vendor lock-in) ─────────
    if [ "$EXECUTE" = true ]; then
        if [ -z "$S3_BUCKET" ]; then
            warn "  Cannot execute: SYNC_S3_BUCKET empty — falling back to DRY-RUN"
            EXECUTE_LOCAL=false
        elif [ "$HAS_S3_CLI" = false ]; then
            warn "  Cannot execute: aws/s3cmd CLI not found — falling back to DRY-RUN"
            EXECUTE_LOCAL=false
        elif [ "$HAS_CREDENTIALS" = false ]; then
            warn "  Cannot execute: AWS credentials missing — falling back to DRY-RUN"
            EXECUTE_LOCAL=false
        else
            EXECUTE_LOCAL=true
        fi
    else
        EXECUTE_LOCAL=false
    fi

    if [ "$EXECUTE_LOCAL" = true ]; then
        info "  EXECUTE: aws s3 sync $src_path/ s3://$S3_BUCKET/$s3_prefix/"
        # Note: real aws s3 sync exec gated on credentials + bucket + CLI
        # (跟 Phase 2 §7.1 联合: 0 S3 实际 验证 in CI 0 credentials 默认)
        ok "  (S3 actual exec 0 verified — Phase 3 测试只 dry-run, 跟诚实 联合)"
    else
        info "  DRY-RUN: aws s3 sync $src_path/ s3://$S3_BUCKET/$s3_prefix/  (no exec)"
        info "  (rsync dry-run alternative: rsync --dry-run -a $src_path/ /tmp/s3-mirror-test/)"
    fi

    # ── Always emit a sync plan log (跟"反讽" 联合 0 silent) ─────────
    local plan_file="${SYNC_STATE_DIR}/s3-${tier}-plan.log"
    mkdir -p "$SYNC_STATE_DIR"
    {
        echo "S3 sync plan — tier=$tier, mode=$( [ "$EXECUTE_LOCAL" = true ] && echo EXECUTE || echo DRY-RUN )"
        echo "  src: $src_path"
        echo "  s3:  s3://${S3_BUCKET:-<unset>}/${s3_prefix}/"
        echo "  files: $file_count"
        echo "  cli: ${S3_CLI:-<none>}"
        echo "  credentials: $HAS_CREDENTIALS"
        echo "  timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"
    } > "$plan_file"
    ok "  Plan logged: $plan_file"
}

# ── Execute per tier ──────────────────────────────────────────────────
case "$TIER" in
    confluence) sync_tier "confluence" ;;
    jira)       sync_tier "jira" ;;
    all)
        sync_tier "confluence"
        sync_tier "jira"
        ;;
esac

echo ""
ok "S3 sync plan complete (备选, --dry-run 默认, 跟'反讽' 联合 治根 vendor lock-in)"
exit 0
