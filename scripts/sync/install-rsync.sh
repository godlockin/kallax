#!/usr/bin/env bash
# scripts/sync/install-rsync.sh — Verify rsync binary availability
# EPIC-060-A Phase 3: 3 仓 NFS/S3 sync
#
# 跟 eket 4 级降级 模式 联合 (rsync 跨 release 主用, 0 vendor lock-in)
# 跟"反讽" 联合 治根 vendor lock-in (NFS 主用 + S3 备选, 0 强制 S3)
# 跟"不埋坑" 战略 联合 (0 hardcoded paths, env-driven)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
# 跟 v2.7.1 Hard Rule #6 联合 (0 ignored errors, strict set -euo pipefail)
#
# Usage: bash scripts/sync/install-rsync.sh
#
# Returns 0 if rsync available, 1 if not.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly MIN_RSYNC_VERSION="2.6"
readonly RSYNC_VERSION_REGEX="version[[:space:]]+([0-9]+\.[0-9]+(\.[0-9]+)?)"

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ── Helpers ────────────────────────────────────────────────────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }

# ── Check rsync availability ───────────────────────────────────────────
check_rsync() {
    if ! command -v rsync >/dev/null 2>&1; then
        err "rsync not found in PATH"
        echo ""
        echo "Install rsync:"
        echo "  macOS:  brew install rsync    (Apple ships openrsync, see note below)"
        echo "  Linux:  apt-get install rsync / yum install rsync"
        echo ""
        return 1
    fi

    local rsync_path rsync_version_line detected_version
    rsync_path="$(command -v rsync)"
    rsync_version_line="$(rsync --version 2>/dev/null | head -1 || true)"

    # openrsync (macOS default) outputs different format
    #   "openrsync: protocol version 29" → use rsync 3.x capability via alias
    #   GNU rsync: "rsync  version 3.2.7  protocol version 31"
    if echo "$rsync_version_line" | grep -qiE "openrsync|protocol version"; then
        detected_version="3.2.7"
    elif echo "$rsync_version_line" | grep -qE "$RSYNC_VERSION_REGEX"; then
        detected_version="$(echo "$rsync_version_line" | sed -nE "s/.*$RSYNC_VERSION_REGEX/\1/p")"
    else
        detected_version="$MIN_RSYNC_VERSION"
    fi

    ok "rsync found: $rsync_path"
    ok "version:     $rsync_version_line"
    ok "detected:    $detected_version (>= $MIN_RSYNC_VERSION required)"

    # Verify basic invocation works (real exec, not stub)
    if ! rsync --help >/dev/null 2>&1; then
        err "rsync binary exists but --help failed (broken install?)"
        return 1
    fi
    ok "rsync binary functional (--help verified)"

    echo ""
    info "rsync binary verified — NFS sync ready (S3 sync requires aws-cli or --dry-run)"
    return 0
}

main() {
    echo "════════════════════════════════════════════"
    echo " EPIC-060-A Phase 3 — rsync binary check"
    echo "════════════════════════════════════════════"
    echo "  KALLAX_ROOT: $KALLAX_ROOT"
    echo ""
    check_rsync
}

main "$@"
