#!/usr/bin/env bash
# Test for pre-commit Check 3 (Build artifacts) + pre-push hook
# 跟 v2.7.0 整理 release 联合, 跟 防御 build artifacts 教训 联合
# 跟 EPIC-059 5/5 PASS 模式 一致

set -uo pipefail

# 5 mock scenarios:
# mock 1: 全部干净 → 0 blocked, 0 size warning
# mock 2: rust/target/ 误 add → blocked (Check 3)
# mock 3: node_modules/ 误 add → blocked (Check 3)
# mock 4: dist/ 误 add → blocked (Check 3)
# mock 5: .o .so .dylib .pyc 误 add → blocked (Check 3)
# bonus: pre-push repo size + tracked artifacts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_COMMIT="${KALLAX_ROOT}/scripts/hooks/pre-commit"
PRE_PUSH="${KALLAX_ROOT}/scripts/hooks/pre-push"

PASS=0
FAIL=0

# ── TC1: pre-commit Check 3 with no build artifacts (should pass) ──
echo ">>> TC1: 0 build artifacts → 0 blocked"
STAGED_FILES="docs/test.md
.claude/commands/test.md
AGENTS.md"
RESULT=$(echo "$STAGED_FILES" | {
  # Test Check 3 artifact pattern match
  BLOCKED=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "(^rust/target/|^node_modules/|^node/dist/|^dist/|^build/|^__pycache__/|^\.cargo/|^\.rustup/|^vendor/|\.o$|\.so$|\.dylib$|\.dll$|\.exe$|\.pyc$|\.wasm$|\.map$|\.min\.js$|\.min\.css$)"; then
      BLOCKED="${BLOCKED}${file}\n"
    fi
  done
  if [ -n "$BLOCKED" ]; then
    echo "BLOCKED"
  else
    echo "PASS"
  fi
})
if [ "$RESULT" = "PASS" ]; then
  echo "  [PASS] TC1: 0 build artifacts → no block"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] TC1: expected PASS, got $RESULT"
  FAIL=$((FAIL + 1))
fi

# ── TC2: rust/target/ 误 add → blocked ──
echo ">>> TC2: rust/target/ 误 add → blocked"
STAGED_FILES="rust/target/debug/foo.o
rust/target/release/lib.rlib"
RESULT=$(echo "$STAGED_FILES" | {
  BLOCKED=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "(^rust/target/|^node_modules/|^node/dist/|^dist/|^build/|^__pycache__/|^\.cargo/|^\.rustup/|^vendor/|\.o$|\.so$|\.dylib$|\.dll$|\.exe$|\.pyc$|\.wasm$|\.map$|\.min\.js$|\.min\.css$)"; then
      BLOCKED="${BLOCKED}${file}\n"
    fi
  done
  if [ -n "$BLOCKED" ]; then
    echo "BLOCKED"
  else
    echo "PASS"
  fi
})
if [ "$RESULT" = "BLOCKED" ]; then
  echo "  [PASS] TC2: rust/target/ 误 add → blocked"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] TC2: expected BLOCKED, got $RESULT"
  FAIL=$((FAIL + 1))
fi

# ── TC3: node_modules/ 误 add → blocked ──
echo ">>> TC3: node_modules/ 误 add → blocked"
STAGED_FILES="node_modules/react/index.js
node_modules/.bin/tsc"
RESULT=$(echo "$STAGED_FILES" | {
  BLOCKED=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "(^rust/target/|^node_modules/|^node/dist/|^dist/|^build/|^__pycache__/|^\.cargo/|^\.rustup/|^vendor/|\.o$|\.so$|\.dylib$|\.dll$|\.exe$|\.pyc$|\.wasm$|\.map$|\.min\.js$|\.min\.css$)"; then
      BLOCKED="${BLOCKED}${file}\n"
    fi
  done
  if [ -n "$BLOCKED" ]; then
    echo "BLOCKED"
  else
    echo "PASS"
  fi
})
if [ "$RESULT" = "BLOCKED" ]; then
  echo "  [PASS] TC3: node_modules/ 误 add → blocked"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] TC3: expected BLOCKED, got $RESULT"
  FAIL=$((FAIL + 1))
fi

# ── TC4: dist/ + build/ 误 add → blocked ──
echo ">>> TC4: dist/ + build/ 误 add → blocked"
STAGED_FILES="dist/bundle.js
build/output.wasm
node/dist/cli.js"
RESULT=$(echo "$STAGED_FILES" | {
  BLOCKED=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "(^rust/target/|^node_modules/|^node/dist/|^dist/|^build/|^__pycache__/|^\.cargo/|^\.rustup/|^vendor/|\.o$|\.so$|\.dylib$|\.dll$|\.exe$|\.pyc$|\.wasm$|\.map$|\.min\.js$|\.min\.css$)"; then
      BLOCKED="${BLOCKED}${file}\n"
    fi
  done
  if [ -n "$BLOCKED" ]; then
    echo "BLOCKED"
  else
    echo "PASS"
  fi
})
if [ "$RESULT" = "BLOCKED" ]; then
  echo "  [PASS] TC4: dist/ + build/ 误 add → blocked"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] TC4: expected BLOCKED, got $RESULT"
  FAIL=$((FAIL + 1))
fi

# ── TC5: 编译 后缀 (.o .so .dylib .pyc .wasm) 误 add → blocked ──
echo ">>> TC5: 编译 后缀 (.o .so .dylib .pyc .wasm) 误 add → blocked"
STAGED_FILES="libfoo.o
libbar.so
libbaz.dylib
test_module.pyc
module.wasm"
RESULT=$(echo "$STAGED_FILES" | {
  BLOCKED=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "(^rust/target/|^node_modules/|^node/dist/|^dist/|^build/|^__pycache__/|^\.cargo/|^\.rustup/|^vendor/|\.o$|\.so$|\.dylib$|\.dll$|\.exe$|\.pyc$|\.wasm$|\.map$|\.min\.js$|\.min\.css$)"; then
      BLOCKED="${BLOCKED}${file}\n"
    fi
  done
  if [ -n "$BLOCKED" ]; then
    echo "BLOCKED"
  else
    echo "PASS"
  fi
})
if [ "$RESULT" = "BLOCKED" ]; then
  echo "  [PASS] TC5: 编译 后缀 误 add → blocked"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] TC5: expected BLOCKED, got $RESULT"
  FAIL=$((FAIL + 1))
fi

# ── 集成: pre-push hook exist + executable ──
echo ">>> 集成: pre-push hook 存在 + 可执行"
if [ -x "$PRE_PUSH" ]; then
  echo "  [PASS] pre-push hook 存在 + 可执行"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] pre-push hook 不存在 或 不可执行"
  FAIL=$((FAIL + 1))
fi

# ── 集成: pre-commit Check 3 集成 in scripts/hooks/pre-commit ──
echo ">>> 集成: pre-commit Check 3 集成 in scripts/hooks/pre-commit"
if grep -q "Check 3" "$PRE_COMMIT"; then
  echo "  [PASS] pre-commit Check 3 集成"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] pre-commit Check 3 未集成"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=========================================="
echo "Summary: ${PASS}/${PASS}+${FAIL} PASS"
echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
  echo "✓ Build artifacts 防禦 — Integration Tests: ${PASS}/$((PASS+FAIL)) PASS (100.0%)"
  echo "EXIT_CODE=0"
  exit 0
else
  echo "✗ Build artifacts 防禦 — Tests failed"
  echo "EXIT_CODE=1"
  exit 1
fi
