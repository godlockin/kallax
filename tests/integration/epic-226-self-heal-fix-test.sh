#!/usr/bin/env bash
# EPIC-226 test — self-heal fire-and-forget 真修 (C 方案第二部分)
# TDD: 10 TC (detector 修 3 + 文件修 3 + smoke 2 + 集成 2)
# Usage: bash tests/integration/epic-226-self-heal-fix-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/verify/check-self-heal.sh"
PASS=0
FAIL=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local rc
  "$@" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq "$expected" ]; then ok "$desc (exit=$rc)"; else ko "$desc (expected $expected, got $rc)"; fi
}

assert_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then ok "$desc"; else ko "$desc (no '$pattern' in $file)"; fi
}

echo "=== EPIC-226: self-heal fire-and-forget 真修 ==="
echo ""

echo "--- Group 1: detector 修 (排除 TS 误报 + shell 假阳性) ---"
# TARGET_FILE 单文件测 (detector 新增支持)
ts_false="${TMPDIR_TEST}/false.ts"
cat > "$ts_false" << 'EOF'
type CleanupHandler = () => Promise<void> | void;
async function foo(): Promise<void> {
  if (errors.length > 0) { return; }
}
EOF
assert_exit "TS 假阳性 (无 writeFile) → exit 0" 0 env TARGET_FILE="$ts_false" bash "$SCRIPT"

ts_real="${TMPDIR_TEST}/real.ts"
cat > "$ts_real" << 'EOF'
import { writeFileSync } from 'fs';
writeFileSync('/tmp/test', 'data');
EOF
assert_exit "TS 真 fire-and-forget → exit 1" 1 env TARGET_FILE="$ts_real" bash "$SCRIPT"

echo ""
echo "--- Group 2: self-heal pattern 匹配 3 种形式 ---"
form1="${TMPDIR_TEST}/form1.sh"
printf '#!/bin/bash\nchmod 600 file\nif ! verify then chmod 600 file\n' > "$form1"
assert_exit "if ! verify then chmod → exit 0" 0 env TARGET_FILE="$form1" bash "$SCRIPT"

form2="${TMPDIR_TEST}/form2.sh"
printf '#!/bin/bash\nchmod 600 file\nchmod 600 file || chmod 600 file\n' > "$form2"
assert_exit "retry-self-heal pattern → exit 0" 0 env TARGET_FILE="$form2" bash "$SCRIPT"

form3="${TMPDIR_TEST}/form3.sh"
cat > "$form3" << 'EOF'
#!/bin/bash
chmod 600 file || {
    echo "ERROR" >&2
    exit 1
}
EOF
assert_exit "block-error-handle pattern → exit 0" 0 env TARGET_FILE="$form3" bash "$SCRIPT"

echo ""
echo "--- Group 3: 3 个真修文件 (retry pattern) ---"
# retry pattern: 同行有 `||` 紧跟 chmod 600
if grep -qE 'chmod 600[^|]*\|\|[^|]*chmod 600' scripts/audit/audit-log-sink.sh; then
  ok "audit-log-sink.sh 含 retry-self-heal"; else ko "audit-log-sink.sh 缺 retry"; fi
if grep -qE 'chmod 600[^|]*\|\|[^|]*chmod 600' scripts/io/conflict-detect.sh; then
  ok "conflict-detect.sh 含 retry-self-heal"; else ko "conflict-detect.sh 缺 retry"; fi
if grep -qE 'chmod 600[^|]*\|\|[^|]*chmod 600' scripts/io/file-lock.sh; then
  ok "file-lock.sh 含 retry-self-heal"; else ko "file-lock.sh 缺 retry"; fi

echo ""
echo "--- Group 4: 全仓扫描 0 violations ---"
assert_exit "scripts/verify/check-self-heal.sh 全仓 → exit 0" 0 bash "$SCRIPT"

echo ""
echo "--- Group 5: 回归 (其他 EPIC 测试) ---"
[ -f "tests/integration/epic-223-ticket-archive-test.sh" ] && assert_exit "EPIC-223 回归 → exit 0" 0 bash "tests/integration/epic-223-ticket-archive-test.sh"
[ -f "tests/integration/epic-224-hook-activation-test.sh" ] && assert_exit "EPIC-224 回归 → exit 0" 0 bash "tests/integration/epic-224-hook-activation-test.sh"

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1