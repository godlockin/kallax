#!/usr/bin/env bash
# KALLAX pre-commit hook — check-cargo-test-workspace (EPIC-102)
# 治 v3.8.0 red-blue review lesson #2: build OK ≠ test OK
#
# 原: `cargo build` 0 errors 报 PASS, 没跑 `cargo test` — 5 release 累计形式绿
# 修: pre-commit 强制 `cargo test --workspace --release`, 0 errors 才允许 commit
#
# 用法 (跟 check-claim-evidence.sh 1:1):
#   bash scripts/verify/check-cargo-test-workspace.sh
#
# 退出码:
#   0 = PASS (cargo test --workspace 0 errors)
#   1 = FAIL (compile error 或 test failure)
#   2 = skip (不是 release 触发, 走 --no-verify bypass)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
RUST_DIR="${REPO_ROOT}/rust"

if [[ ! -d "${RUST_DIR}" ]]; then
  echo "check-cargo-test-workspace: ${RUST_DIR} 不存在, skip"
  exit 0
fi

# 限定 Rust 相关文件 (避免每次 commit 都跑全)
CHANGED=$(git diff --cached --name-only 2>/dev/null | grep -E '\.(rs|toml)$' | head -5 || true)
if [[ -z "$CHANGED" ]]; then
  echo "check-cargo-test-workspace: 无 Rust 文件改动, skip"
  exit 0
fi

echo "check-cargo-test-workspace: 检测到 Rust 文件改动 ($CHANGED)"
echo "  跑 cargo test --workspace --release (治 v3.8.0 lesson #2)"

cd "${RUST_DIR}" || exit 1

# 跑 cargo test --workspace
# raw output 必现 (跟 v3.15.1 1:1 联合, 不允许 "build OK" 假装 "test OK")
if ! cargo test --workspace --release 2>&1 | tail -30; then
  echo ""
  echo "❌ check-cargo-test-workspace: cargo test --workspace 失败"
  echo "   治 v3.8.0 lesson #2 (build OK ≠ test OK)"
  echo "   Fix: 真跑 cargo test, 修所有 compile error + test failure"
  echo "   Bypass: git commit --no-verify (主公明确批准时)"
  exit 1
fi

echo ""
echo "✅ check-cargo-test-workspace: PASS (cargo test --workspace 0 errors)"
exit 0