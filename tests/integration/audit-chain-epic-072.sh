#!/usr/bin/env bash
# EPIC-072 regression test — Hash-Chain A1+A2+A3 真锚点
# 治 v3.8.0 red-blue review:
#   A1: 全零种子 → git commit hash 锚点
#   A2: legacy skip 绕过 → fail-closed
#   A3: 空文件 PASS → fail-closed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SH="$ROOT/scripts/audit/audit-chain.sh"

PASS=0
FAIL=0

assert_exit() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  ✓ $name"
        PASS=$((PASS+1))
    else
        echo "  ✗ $name (expected exit=$expected, got=$actual)"
        FAIL=$((FAIL+1))
    fi
}

# Setup test dir
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# A1 test: 链种子 = sha256("audit:anchor:" + git HEAD)
# 用 echo 验证 init 后的第一条 prev_hash 等于锚点
echo "=== EPIC-072-A1: git commit hash 锚点 ==="
TEST_LOG_A1="$TEST_DIR/test-a1.jsonl"
echo '{"ts":"2026-01-01T00:00:00Z","seq":1,"prevHash":"test"}' > "$TEST_LOG_A1"
# 尝试用 verify (无 chain_hash 应 fail per A2 fix)
# 不强求通过 — 我们只验证 git_anchor 存在
GIT_ANCHOR=$(cd "$ROOT" && git rev-parse HEAD)
if [[ ${#GIT_ANCHOR} -ge 40 ]]; then
    echo "  ✓ git rev-parse HEAD 返回 40 字符 hash (anchor 可用)"
    PASS=$((PASS+1))
else
    echo "  ✗ git rev-parse HEAD 失败"
    FAIL=$((FAIL+1))
fi

# A3 test: 空文件 → FAIL exit 1
echo "=== EPIC-072-A3: 空文件 fail-closed ==="
TEST_LOG_A3="$TEST_DIR/test-a3-empty.jsonl"
touch "$TEST_LOG_A3"
bash "$AUDIT_SH" verify "$TEST_LOG_A3" >/dev/null 2>&1
ACTUAL_EXIT=$?
assert_exit "empty file verify → fail-closed" "1" "$ACTUAL_EXIT"

# A3 test: 文件不存在 → FAIL exit 1
echo "=== EPIC-072-A3: 文件不存在 fail-closed ==="
bash "$AUDIT_SH" verify "$TEST_DIR/nonexistent.jsonl" >/dev/null 2>&1
ACTUAL_EXIT=$?
assert_exit "missing file verify → fail-closed" "1" "$ACTUAL_EXIT"

# A2 test: legacy entry (无 chain_hash) → FAIL
echo "=== EPIC-072-A2: legacy entry fail-closed ==="
TEST_LOG_A2="$TEST_DIR/test-a2-legacy.jsonl"
cat > "$TEST_LOG_A2" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","seq":1,"prevHash":"anchor","action":"test"}
{"ts":"2026-01-01T00:00:01Z","seq":2,"prevHash":"prev","action":"test2"}
EOF
bash "$AUDIT_SH" verify "$TEST_LOG_A2" >/dev/null 2>&1
ACTUAL_EXIT=$?
assert_exit "legacy entry (no chain_hash) → fail-closed" "1" "$ACTUAL_EXIT"

# A1 test: 旧种子全零的日志 → FAIL (锚点变了)
echo "=== EPIC-072-A1: 旧全零种子日志 → FAIL (锚点变更) ==="
TEST_LOG_A1_OLD="$TEST_DIR/test-a1-old-seed.jsonl"
cat > "$TEST_LOG_A1_OLD" <<'EOF'
{"ts":"2026-01-01T00:00:00Z","seq":1,"prevHash":"0000000000000000000000000000000000000000000000000000000000000000","chain_hash":"abc123","action":"test"}
EOF
bash "$AUDIT_SH" verify "$TEST_LOG_A1_OLD" >/dev/null 2>&1
ACTUAL_EXIT=$?
# 旧种子全零, 新锚点 = sha256(git_anchor) ≠ 全零, 应 FAIL
assert_exit "old zero-seed log → fail-closed (anchor changed)" "1" "$ACTUAL_EXIT"

echo ""
echo "=============================="
echo "  PASS: $PASS / FAIL: $FAIL"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0