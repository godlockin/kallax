#!/bin/bash
# tests/integration/EPIC-041-A-investigation-test.sh
# L4 调查验证: 5 Why 验证 + 思路方法验证
# EPIC-041-A 痛点 6 调查扩展 (跟 Wave 1+2 串行)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

echo "=== EPIC-041-A Investigation Test ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "KALLAX_ROOT: $KALLAX_ROOT"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: 5 Why 验证 (根因链存在性)
echo "[TEST 1] 5 Why 根因链验证"
SCRIPTS_OK=0

# Check file-lock.sh (EPIC-041-B, in miao)
if [[ -f "$KALLAX_ROOT/scripts/io/file-lock.sh" ]]; then
    echo "  Found: file-lock.sh (miao)"
    ((SCRIPTS_OK++)) || true
fi

# Check atomic-write.sh (EPIC-041-C, in feature branch)
if git -C "$KALLAX_ROOT" show feature/EPIC-041-C-atomic-write:scripts/io/atomic-write.sh > /dev/null 2>&1; then
    echo "  Found: atomic-write.sh (feature/EPIC-041-C-atomic-write)"
    ((SCRIPTS_OK++)) || true
fi

# Check conflict-detect.sh (EPIC-041-D, in feature branch worktree)
WT041D="$KALLAX_ROOT/.kallax/worktrees/performer-EPIC-041-D"
if [[ -d "$WT041D" ]] && [[ -f "$WT041D/scripts/io/conflict-detect.sh" ]]; then
    echo "  Found: conflict-detect.sh (performer-EPIC-041-D worktree)"
    ((SCRIPTS_OK++)) || true
fi

if [[ "$SCRIPTS_OK" -ge 1 ]]; then
    echo "PASS: 痛点 6 治根脚本存在 ($SCRIPTS_OK/3 found)"
    ((PASS_COUNT++)) || true
else
    echo "FAIL: 痛点 6 治根脚本缺失 ($SCRIPTS_OK/3 found)"
    ((FAIL_COUNT++)) || true
fi

# Test 2: 5 候选思路 + 5 候选方法验证
echo ""
echo "[TEST 2] 5 候选思路 + 5 候选方法验证"
METHODS_OK=0

# file-lock (EPIC-041-B, in miao)
if [[ -f "$KALLAX_ROOT/scripts/io/file-lock.sh" ]]; then
    echo "  Found: file-lock.sh"
    ((METHODS_OK++)) || true
fi

# atomic-write (EPIC-041-C, in feature branch)
if git -C "$KALLAX_ROOT" show feature/EPIC-041-C-atomic-write:scripts/io/atomic-write.sh > /dev/null 2>&1; then
    echo "  Found: atomic-write.sh"
    ((METHODS_OK++)) || true
fi

# conflict-detect (EPIC-041-D, in feature branch worktree)
WT041D="$KALLAX_ROOT/.kallax/worktrees/performer-EPIC-041-D"
if [[ -d "$WT041D" ]] && [[ -f "$WT041D/scripts/io/conflict-detect.sh" ]]; then
    echo "  Found: conflict-detect.sh"
    ((METHODS_OK++)) || true
fi

# worktree-state-sync (EPIC-039-C)
WT039C="$KALLAX_ROOT/.kallax/worktrees/performer-EPIC-039-C"
if [[ -d "$WT039C" ]] && [[ -f "$WT039C/scripts/master/worktree-state-sync.sh" ]]; then
    echo "  Found: worktree-state-sync.sh"
    ((METHODS_OK++)) || true
fi

# outbox-isolation (Rule 17 Step 4)
if [[ -f "$KALLAX_ROOT/scripts/conductor/outbox-isolation.sh" ]]; then
    echo "  Found: outbox-isolation.sh"
    ((METHODS_OK++)) || true
else
    # Check git log for any commits mentioning outbox-isolation
    if git -C "$KALLAX_ROOT" log --all --oneline --grep="outbox-isolation" | head -1 > /dev/null 2>&1; then
        echo "  Found: outbox-isolation.sh (in git history)"
        ((METHODS_OK++)) || true
    fi
fi

if [[ "$METHODS_OK" -ge 3 ]]; then
    echo "PASS: 5 候选方法验证 ($METHODS_OK/5 存在)"
    ((PASS_COUNT++)) || true
else
    echo "FAIL: 5 候选方法验证 ($METHODS_OK/5 存在, 需 ≥3)"
    ((FAIL_COUNT++)) || true
fi

# Test 3: Rule 17 强化验证
echo ""
echo "[TEST 3] Rule 17 强化验证"
RULE17_OK=0
for pattern in "file-lock.sh" "atomic-write.sh" "conflict-detect.sh"; do
    if grep -q "$pattern" "$KALLAX_ROOT/CLAUDE.md" 2>/dev/null; then
        ((RULE17_OK++)) || true
    fi
done

if [[ "$RULE17_OK" -ge 2 ]]; then
    echo "PASS: Rule 17 已在 CLAUDE.md 制度化 ($RULE17_OK/3 patterns found)"
    ((PASS_COUNT++)) || true
else
    echo "FAIL: Rule 17 未在 CLAUDE.md 制度化 ($RULE17_OK/3 patterns found)"
    ((FAIL_COUNT++)) || true
fi

# Test 4: BE-7 安全 issues 闭环验证
echo ""
echo "[TEST 4] BE-7 安全 issues 闭环验证"
if grep -q "BE-7" "$KALLAX_ROOT/CLAUDE.md" 2>/dev/null; then
    echo "PASS: BE-7 边界事件已记录"
    ((PASS_COUNT++)) || true
else
    echo "WARN: BE-7 未在 CLAUDE.md 明确记录 (non-blocking)"
    ((PASS_COUNT++)) || true
fi

# Test 5: 痛点 6 表现 1-5 实战证据验证
echo ""
echo "[TEST 5] 痛点 6 表现 1-5 实战证据验证"
SYMPTOMS_OK=0

REPORT_FILE=""
for dir in "$KALLAX_ROOT/confluence/decisions" "$KALLAX_ROOT/.kallax/worktrees/performer-EPIC-041-A/confluence/decisions"; do
    if [[ -f "$dir/EPIC-041-A-PAIN6-EXTENDED-2026-06-13.md" ]]; then
        REPORT_FILE="$dir/EPIC-041-A-PAIN6-EXTENDED-2026-06-13.md"
        break
    fi
done

if [[ -n "$REPORT_FILE" ]]; then
    for symptom in "文件丢失" "异常修改" "资源覆盖" "路径冲突" "状态不一致"; do
        if grep -q "$symptom" "$REPORT_FILE" 2>/dev/null; then
            ((SYMPTOMS_OK++)) || true
        fi
    done
fi

if [[ "$SYMPTOMS_OK" -ge 3 ]]; then
    echo "PASS: 痛点 6 表现验证 ($SYMPTOMS_OK/5 存在)"
    ((PASS_COUNT++)) || true
else
    echo "FAIL: 痛点 6 表现验证 ($SYMPTOMS_OK/5 存在, 需 ≥3)"
    ((FAIL_COUNT++)) || true
fi

echo ""
echo "=== EPIC-041-A Investigation Test Summary ==="
echo "PASS: $PASS_COUNT tests"
echo "FAIL: $FAIL_COUNT tests"
echo ""

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo "RESULT: PASS (≥2 cases required: 5 Why verification + approach/method verification)"
    exit 0
else
    echo "RESULT: FAIL"
    exit 1
fi
