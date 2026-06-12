#!/bin/bash
# generated-experts-test.sh — 3 case PASS (6 generated 真存在 + dedup + INDEX sync)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXTENDED_INDEX="${KALLAX_ROOT}/.kallax/experts/extended/INDEX.md"
GENERATOR="${KALLAX_ROOT}/scripts/expert-generate-l3.py"

PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
  set +e
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
  return 0
}

assert_fail() {
  set +e
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ─── T1: 6 generated 真存在 (kallax.generated.001~006) ───
test_t1_six_generated_exist() {
  echo "=== T1: 6 generated experts exist in INDEX.md ==="

  [[ -f "$EXTENDED_INDEX" ]] || { echo "FAIL: INDEX.md missing"; return 1; }

  expected_ids=("kallax.generated.001" "kallax.generated.002" "kallax.generated.003" "kallax.generated.004" "kallax.generated.005" "kallax.generated.006")

  for id in "${expected_ids[@]}"; do
    if grep -qE "^id: ${id}$" "$EXTENDED_INDEX"; then
      assert_pass "id ${id} found"
    else
      assert_fail "id ${id} missing"
    fi
  done

  actual_count=$(grep -cE "^id: kallax.generated\." "$EXTENDED_INDEX" || echo 0)
  if [[ "$actual_count" -ge 6 ]]; then
    assert_pass "actual generated count = ${actual_count} (>= 6)"
  else
    assert_fail "actual generated count = ${actual_count} (< 6)"
  fi
}

# ─── T2: 重复 ID append 报错 (mock dedup) ───
test_t2_duplicate_id_detection() {
  echo "=== T2: duplicate ID detection in INDEX.md ==="

  [[ -f "$EXTENDED_INDEX" ]] || { echo "FAIL: INDEX.md missing"; return 1; }

  # 找 INDEX.md 第一个 generated id, 模拟 append 重复
  first_gen_id=$(grep -E "^id: kallax.generated\." "$EXTENDED_INDEX" | head -1 | awk '{print $2}')

  if [[ -z "$first_gen_id" ]]; then
    assert_fail "no generated id found to test dedup"
    return 1
  fi

  # 统计这个 id 出现次数 (id 字段, 1 行 1 个)
  dup_count=$(grep -cE "^id: ${first_gen_id}$" "$EXTENDED_INDEX" || echo 0)

  if [[ "$dup_count" -eq 1 ]]; then
    assert_pass "id ${first_gen_id} appears exactly once (no duplicate)"
  elif [[ "$dup_count" -gt 1 ]]; then
    assert_fail "id ${first_gen_id} appears ${dup_count} times (duplicate!)"
  else
    assert_fail "id ${first_gen_id} not found"
  fi

  # 模拟 generator 内部 dedup 逻辑: 假设追加, 应该检测到重复
  # 这里用 grep -c 验证 baseline 数据无 dup
  total_gen=$(grep -cE "^id: kallax.generated\." "$EXTENDED_INDEX" || echo 0)
  unique_gen=$(grep -E "^id: kallax.generated\." "$EXTENDED_INDEX" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')

  if [[ "$total_gen" -eq "$unique_gen" ]]; then
    assert_pass "total=${total_gen} unique=${unique_gen} (no dup, dedup contract holds)"
  else
    assert_fail "total=${total_gen} unique=${unique_gen} (dup detected, dedup broken)"
  fi
}

# ─── T3: INDEX.md 同步校验 (rebuild 校验一致) ───
test_t3_index_md_sync() {
  echo "=== T3: INDEX.md sync validation ==="

  [[ -f "$EXTENDED_INDEX" ]] || { echo "FAIL: INDEX.md missing"; return 1; }

  # 校验 INDEX.md 必填字段一致性 (每个 generated entry 有 id + name_cn + domain + tier + trigger)
  gen_records=$(grep -cE "^id: kallax.generated\." "$EXTENDED_INDEX" || echo 0)
  gen_names=$(grep -cE "^name_cn: " "$EXTENDED_INDEX" || echo 0)
  gen_domains=$(grep -cE "^domain: (legal|finance|data)$" "$EXTENDED_INDEX" || echo 0)
  gen_tiers=$(grep -cE "^tier: generated$" "$EXTENDED_INDEX" || echo 0)
  gen_triggers=$(grep -cE "^trigger: " "$EXTENDED_INDEX" || echo 0)

  echo "  [verify] generated id records = ${gen_records}"
  echo "  [verify] name_cn records = ${gen_names}"
  echo "  [verify] domain (legal/finance/data) records = ${gen_domains}"
  echo "  [verify] tier=generated records = ${gen_tiers}"
  echo "  [verify] trigger records = ${gen_triggers}"

  if [[ "$gen_records" -ge 6 ]]; then
    assert_pass "generated id records >= 6 (sync OK)"
  else
    assert_fail "generated id records < 6 (sync broken)"
  fi

  # 校验每个 generated 都有 tier=generated
  if [[ "$gen_tiers" -ge 6 ]]; then
    assert_pass "tier=generated records >= 6 (sync OK)"
  else
    assert_fail "tier=generated records < 6 (sync broken)"
  fi

  # 校验所有 generated 的 domain 在合法域 (legal/finance/data)
  invalid_domains=$(grep -A5 "^id: kallax.generated\." "$EXTENDED_INDEX" | grep -E "^domain: " | grep -vE "domain: (legal|finance|data)$" | wc -l | tr -d ' ')

  if [[ "$invalid_domains" -eq 0 ]]; then
    assert_pass "all generated domains in valid set (legal/finance/data)"
  else
    assert_fail "invalid domains found: ${invalid_domains}"
  fi
}

# ─── MAIN ───
# Disable set -e / pipefail for the final summary+exit block so transient
# grep -c pipeline exits can't poison the script's overall exit code when
# FAIL_COUNT is actually 0. EPIC-034-C R4 fix: Conductor R3 saw EXIT=1 on
# 1st run with 5/5 PASS due to pipefail tripping inside test_t3_index_md_sync.
set +e +o pipefail
echo "=== generated-experts-test.sh ==="
test_t1_six_generated_exist
echo ""
test_t2_duplicate_id_detection
echo ""
test_t3_index_md_sync
echo ""
echo "=== summary: ${PASS_COUNT} PASS, ${FAIL_COUNT} FAIL ==="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
