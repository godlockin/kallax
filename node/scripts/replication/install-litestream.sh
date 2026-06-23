#!/usr/bin/env bash
# node/scripts/replication/install-litestream.sh — Install litestream binary
# EPIC-060-A Phase 2: WAL replication
# 跟 eket 4 级降级 模式 联合 (L1 litestream 主用 → L2 本地 SQLite 备)
# 跟"不埋坑" 战略 联合 (0 hardcoded credentials, env-driven)
# 跟 v2.7.1 Hard Rule #4 联合 (0 magic numbers, named constants)
# 跟 v2.7.1 Hard Rule #6 联合 (0 ignored errors, strict set -euo pipefail)
#
# Usage: bash node/scripts/replication/install-litestream.sh [version]
#   LITESTREAM_INSTALL_DIR — override install dir (default: $KALLAX_ROOT/.kallax/bin)
#   LITESTREAM_VERSION     — override version   (default: 0.3.13)
#
# Returns 0 on success, 1 on failure.

set -euo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly DEFAULT_VERSION="0.5.12"
readonly DEFAULT_INSTALL_DIR_NAME=".kallax/bin"
readonly REPO_OWNER="benbjohnson"
readonly REPO_NAME="litestream"

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
INSTALL_DIR="${LITESTREAM_INSTALL_DIR:-${KALLAX_ROOT}/${DEFAULT_INSTALL_DIR_NAME}}"
VERSION="${LITESTREAM_VERSION:-${DEFAULT_VERSION}}"

# ── Helpers ────────────────────────────────────────────────────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }

# ── Platform detection ─────────────────────────────────────────────────
detect_os_arch() {
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux"  ;;
        *) err "Unsupported OS: $(uname -s)"; return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) err "Unsupported arch: $(uname -m)"; return 1 ;;
    esac
    echo "${os}-${arch}"
}

# ── Check if already installed ─────────────────────────────────────────
is_installed() {
    [ -x "$INSTALL_DIR/litestream" ] && "$INSTALL_DIR/litestream" version >/dev/null 2>&1
}

# ── Download + extract ─────────────────────────────────────────────────
download_litestream() {
    local platform="$1"
    local asset="litestream-${VERSION}-${platform}.tar.gz"
    local url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/v${VERSION}/${asset}"
    local tmpdir
    tmpdir="$(mktemp -d -t litestream-install-XXXXXX)"
    local tarball="${tmpdir}/${asset}"

    info "Downloading $url"
    if ! curl -fSL --retry 3 --max-time 60 -o "$tarball" "$url"; then
        err "Download failed: $url"
        rm -rf "$tmpdir"
        return 1
    fi

    info "Extracting to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    if ! tar -xzf "$tarball" -C "$tmpdir"; then
        err "Extract failed: $tarball"
        rm -rf "$tmpdir"
        return 1
    fi
    cp "$tmpdir/litestream" "$INSTALL_DIR/litestream"
    chmod +x "$INSTALL_DIR/litestream"
    rm -rf "$tmpdir"
    ok "Installed litestream $VERSION ($platform) → $INSTALL_DIR/litestream"
}

# ── Main ───────────────────────────────────────────────────────────────
main() {
    local platform
    platform="$(detect_os_arch)" || exit 1

    if is_installed; then
        ok "litestream already installed: $($INSTALL_DIR/litestream version)"
        exit 0
    fi

    download_litestream "$platform" || exit 1

    if is_installed; then
        ok "Verify: $($INSTALL_DIR/litestream version)"
    else
        err "Install succeeded but binary not found at $INSTALL_DIR/litestream"
        exit 1
    fi
}

main "$@"