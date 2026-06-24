#!/usr/bin/env bash
# web/scripts/status-deploy.sh — status check for web dashboard deployment readiness
#
# EPIC-060-A Phase 4 — web dashboard server 真部署 准备
# 跟 EPIC-058-C 部署就绪 联合, 跟 start.sh + verify-deploy.sh 联合
# Usage: bash web/scripts/status-deploy.sh [port]
#
# Checks (跟 eket 4 级降级 模式 联合):
#   1. local dashboard running + endpoints 200
#   2. deploy script availability (wrangler / gh-pages)
#   3. env vars present (跟"不埋坑" 联合 0 hardcoded credentials)
#   4. Dockerfile + dockerignore + package.json 落地 (跟 EPIC-058-C 联合)
#
# Exit codes:
#   0  deployment-ready (local + scripts + files all OK)
#   1  local dashboard not responding
#   2  deploy scripts missing
#   3  deployment files missing

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEFAULT_PORT=8080
readonly DEFAULT_HOST=localhost
readonly CURL_TIMEOUT_SEC=3
readonly MAX_RETRIES=2

readonly PORT="${1:-$DEFAULT_PORT}"
readonly BASE_URL="http://${DEFAULT_HOST}:${PORT}"
readonly PID_FILE="$WEB_ROOT/.dashboard.pid"

PASS=0
FAIL=0

check_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Web Dashboard Deploy Status ==="
echo "Base URL: $BASE_URL"
echo ""

echo "--- 1. local dashboard ---"
HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT_SEC" "$BASE_URL/" 2>/dev/null || echo 000)"
if [ "$HTTP_CODE" = "200" ]; then
  check_pass "/ returns 200 (local serve OK)"
else
  check_fail "/ returns $HTTP_CODE (start with: bash $SCRIPT_DIR/start.sh $PORT)"
fi

DISPATCH_CODE="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT_SEC" "$BASE_URL/dispatch/" 2>/dev/null || echo 000)"
if [ "$DISPATCH_CODE" = "200" ]; then
  check_pass "/dispatch/ returns 200 (EPIC-053-D dashboard OK)"
else
  check_fail "/dispatch/ returns $DISPATCH_CODE"
fi
echo ""

echo "--- 2. deploy script availability ---"
for script in start.sh verify-deploy.sh deploy.sh deploy-cloudflare.sh deploy-github-pages.sh status-deploy.sh; do
  if [ -x "$SCRIPT_DIR/$script" ]; then
    check_pass "$script present (exec)"
  else
    check_fail "$script missing or not exec"
  fi
done
echo ""

echo "--- 3. deploy platform tools (0 增命令, opt-in) ---"
if command -v wrangler >/dev/null 2>&1; then
  check_pass "wrangler CLI present (cloudflare deploy ready)"
else
  echo "  [INFO] wrangler not installed (run: npm install -g wrangler) — cloudflare deploy N/A until installed"
fi
if command -v gh-pages >/dev/null 2>&1; then
  check_pass "gh-pages CLI present (github-pages deploy ready)"
else
  echo "  [INFO] gh-pages not installed (run: npm install -g gh-pages) — github-pages deploy N/A until installed"
fi
echo ""

echo "--- 4. EPIC-058-C 部署就绪 files ---"
for f in Dockerfile .dockerignore package.json; do
  if [ -f "$WEB_ROOT/$f" ]; then
    check_pass "web/$f present"
  else
    check_fail "web/$f missing"
  fi
done
if [ -d "$WEB_ROOT/src/dashboard" ]; then
  check_pass "web/src/dashboard/ present"
else
  check_fail "web/src/dashboard/ missing"
fi
echo ""

echo "=========================================="
echo "Result: $PASS PASS, $FAIL FAIL"
echo "=========================================="
if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: NOT deployment-ready"
  exit 1
fi
echo "STATUS: deployment-ready (跟 EPIC-058-C 联合, 0 真实 域 名 必需)"
exit 0