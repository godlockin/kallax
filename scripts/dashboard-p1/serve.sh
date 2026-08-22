#!/usr/bin/env bash
# scripts/dashboard-p1/serve.sh
# EPIC-281 Phase 1 — 本地预览 (127.0.0.1 only, R5 mitigation)
#
# Python http.server 单 listener, port 8765, 只 listen 127.0.0.1 (hard-code).
# 防公网 host 暴露 jira/ 父级 (R5 mitigation).
#
# Usage:
#   bash scripts/dashboard-p1/serve.sh           # 默认 dist/dashboard + 127.0.0.1:8765
#   bash scripts/dashboard-p1/serve.sh --port 9000
#
# Exit codes:
#   0 = server started (background)
#   1 = missing python3 or dist dir

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist/dashboard"
PORT=8765
HOST="127.0.0.1"  # hard-code — 不接受 0.0.0.0 (R5 mitigation)

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --dir) DIST_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 required" >&2; exit 1; }
[[ -d "$DIST_DIR" ]] || { echo "FAIL: dist dir not found: $DIST_DIR (run emit.sh first)" >&2; exit 1; }

# 强校验 HOST 不被环境变量 override (R5 mitigation)
if [[ "${DASHBOARD_HOST:-127.0.0.1}" != "127.0.0.1" ]]; then
  echo "FAIL: DASHBOARD_HOST must be 127.0.0.1 (refuse 0.0.0.0 / public bind)" >&2
  exit 1
fi

LOG="/tmp/claude-tasks/dashboard-serve-${PORT}-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"

echo "Serving: file://$DIST_DIR"
echo "URL:     http://${HOST}:${PORT}/"
echo "Log:     $LOG"

# python -m http.server 默认 bind 到 0.0.0.0 — 用 --bind 强锁 127.0.0.1
exec python3 -m http.server "$PORT" --bind "$HOST" --directory "$DIST_DIR" 2>&1 | tee "$LOG"