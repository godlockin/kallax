#!/usr/bin/env bash
# tests/integration/review-tier-gate.test.sh
# EPIC-270 review tier gate 测试

set -uo pipefail

WS="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax-wt-EPIC-270"
GATE="$WS/scripts/ci/check-review-tier.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== EPIC-270 review tier gate tests ==="

# 1. 缺 review_tier 字段
echo "--- 1. 缺 review_tier 字段 ---"
echo "some body without tier" > "$TMP/no-tier.md"
if ! bash "$GATE" "$TMP/no-tier.md" "0 files changed, 0 insertions(+), 0 deletions(-)" 2>/dev/null; then
  ok "REJECT: 缺 review_tier"
else
  bad "应拒但放行"
fi

# 2. T1 自评: 0 行
echo "--- 2. T1 自评, 0 行 ---"
echo "review_tier: T1" > "$TMP/t1-empty.md"
if bash "$GATE" "$TMP/t1-empty.md" "0 files changed, 0 insertions(+), 0 deletions(-)" >/dev/null 2>&1; then
  ok "T1 通过 (0 行)"
else
  bad "T1 应过但拒"
fi

# 3. T1 但 200 行 → 拒
echo "--- 3. T1 但 200 行 → 拒 ---"
if ! bash "$GATE" "$TMP/t1-empty.md" "3 files changed, 150 insertions(+), 50 deletions(-)" 2>/dev/null; then
  ok "REJECT: T1 > 100 行"
else
  bad "应拒但放行"
fi

# 4. T2 但缺 review_summary → 拒
echo "--- 4. T2 缺 review_summary → 拒 ---"
echo "review_tier: T2" > "$TMP/t2-no-summary.md"
if ! bash "$GATE" "$TMP/t2-no-summary.md" "2 files changed, 50 insertions(+), 10 deletions(-)" 2>/dev/null; then
  ok "REJECT: T2 缺 review_summary"
else
  bad "应拒但放行"
fi

# 5. T2 review_summary 是空 block → 拒
echo "--- 5. T2 review_summary 空 block → 拒 ---"
printf 'review_tier: T2\nreview_summary: |\n' > "$TMP/t2-empty-summary.md"
if ! bash "$GATE" "$TMP/t2-empty-summary.md" "2 files changed, 50 insertions(+), 10 deletions(-)" 2>/dev/null; then
  ok "REJECT: review_summary 空"
else
  bad "应拒但放行"
fi

# 6. T2 review_summary 非空 → 过
echo "--- 6. T2 review_summary 非空 ---"
printf 'review_tier: T2\nreview_summary: |\n  独立核实者复现 pattern 边界, 发现 AC2 描述错.\n' > "$TMP/t2-good.md"
if bash "$GATE" "$TMP/t2-good.md" "2 files changed, 50 insertions(+), 10 deletions(-)" >/dev/null 2>&1; then
  ok "T2 通过 (review_summary 非空)"
else
  bad "T2 应过但拒"
fi

# 7. T3 但只 1 文件 → 拒
echo "--- 7. T3 1 文件 → 拒 ---"
printf 'review_tier: T3\nreview_summary: |\n  核实了 X.\n' > "$TMP/t3-1file.md"
if ! bash "$GATE" "$TMP/t3-1file.md" "1 files changed, 10 insertions(+), 0 deletions(-)" 2>/dev/null; then
  ok "REJECT: T3 < 5 文件"
else
  bad "应拒但放行"
fi

# 8. T3 6 文件 600 行 → 过
echo "--- 8. T3 6 文件 600 行 ---"
if bash "$GATE" "$TMP/t3-1file.md" "6 files changed, 500 insertions(+), 100 deletions(-)" >/dev/null 2>&1; then
  ok "T3 通过 (6 文件, 600 行)"
else
  bad "T3 应过但拒"
fi

# 9. review_summary 用 > 折叠符号也可
echo "--- 9. review_summary 用 > ---"
printf 'review_tier: T2\nreview_summary: >\n  核实了 X.\n' > "$TMP/t2-fold.md"
if bash "$GATE" "$TMP/t2-fold.md" "2 files changed, 50 insertions(+), 10 deletions(-)" >/dev/null 2>&1; then
  ok "T2 通过 (> 折叠符号)"
else
  bad "T2 应过但拒"
fi

# 10. review_summary 单行 (无 block 符号)
echo "--- 10. review_summary 单行 ---"
printf 'review_tier: T2\nreview_summary: 核实了 pattern 边界\n' > "$TMP/t2-inline.md"
if bash "$GATE" "$TMP/t2-inline.md" "2 files changed, 50 insertions(+), 10 deletions(-)" >/dev/null 2>&1; then
  ok "T2 通过 (单行 summary)"
else
  bad "T2 应过但拒 (单行 summary 没被 awk 抓到)"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
rm -rf "$TMP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
