#!/usr/bin/env bash
# raw_output: /tmp/claude-tasks/test-jargon-20260826-171938.log (exit=0, 12/12 PASS)
# EPIC-286: check-jargon 单脚本统一后的豁免行为测试
#
# 背景: 曾有两个同名脚本行为不一致 —
#   scripts/hooks/check-jargon.sh   (canonical, immutable #9, pre-commit 调用)
#     有 GIT_DIR 修复, 但缺 X/Y PASS 例外 + 历史文件豁免 (is_historical_file 是 dead code)
#   scripts/verify/check-jargon.sh  (已删)
#     有两个豁免, 但不被任何 hook 调用
#
# 后果: blacklist 的 replace 字段承诺 "附命令引用即可写 X/Y PASS",
# _scope 字段 + 主公 2026-08-11 拍板承诺 "历史内容不追溯", 两个承诺都没兑现
# → 贴 raw test output 撞 gate, 改老文档撞 gate → HOOK_BYPASS 常态化
#
# 主公 2026-08-22 拍板: 保留严格版 (hooks), 移植两个豁免, 删宽松版
#
# EPIC-286 拆 PR: 核心脚本改动走 PR #501-A, 本测试走 PR #501-B.
# B 必须在 A 合入 testing 后才能跑 (本测试验证 hooks/ 的豁免行为,
# hooks/ 改动在 A). review 顺序: A → B.
#
# Exit: 0 = 全 case PASS, 1 = 任一 FAIL
set -uo pipefail

# EPIC-286: REPO_ROOT 从脚本自身位置解析, 不从 cwd.
# 起因: 用 `git rev-parse --show-toplevel` 在 worktree 外调用会指向主仓,
# 测的就不是本 worktree 的脚本 (队伍 C 在 check-ticket-schema.sh:20 报过同型问题).
REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
SCRIPT="${REPO_ROOT}/scripts/hooks/check-jargon.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

FAIL=0
PASS_COUNT=0
TOTAL=0

assert_exit() {
  local desc="$1" expected="$2" file="$3"
  TOTAL=$((TOTAL + 1))
  set +e
  bash "$SCRIPT" "$file" >/dev/null 2>&1
  local actual=$?
  set -e
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc (exit=$actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc (expected exit=$expected, got $actual)" >&2
    FAIL=1
  fi
}

echo "EPIC-286 check-jargon 豁免行为测试"
echo ""

# Case 1: 单脚本存在性 — verify 版必须已删
echo "Case 1: 单脚本 (verify 版已删)"
TOTAL=$((TOTAL + 1))
if [ ! -f "${REPO_ROOT}/scripts/verify/check-jargon.sh" ] && [ -f "$SCRIPT" ]; then
  echo "  PASS: 仅 scripts/hooks/check-jargon.sh 存在"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: verify 版未删或 hooks 版缺失" >&2
  FAIL=1
fi

# Case 2: 裸 X/Y PASS 无命令证据 → 仍 fail (v3.8.0 假 PASS 防线不能拆)
echo "Case 2: 裸 X/Y PASS 无证据"
cat > "${TMPD}/bare-xy.md" << 'EOF'
# 测试报告

测试结果 25/25 PASS, 质量很高.
EOF
assert_exit "裸 25/25 PASS 应 fail" 1 "${TMPD}/bare-xy.md"

# Case 3: X/Y PASS 附命令证据 → 豁免 (兑现 replace 字段承诺)
echo "Case 3: X/Y PASS 附命令证据"
cat > "${TMPD}/xy-with-cmd.md" << 'EOF'
# 测试报告

跑 `bash scripts/test.sh` 得到:

结果 25/25 PASS
EOF
assert_exit "附 bash 命令引用应豁免" 0 "${TMPD}/xy-with-cmd.md"

# Case 4: X/Y PASS 附 exit= 证据 → 豁免
echo "Case 4: X/Y PASS 附 exit= 证据"
cat > "${TMPD}/xy-with-exit.md" << 'EOF'
# 测试报告

结果 9/9 PASS, exit=0
EOF
assert_exit "附 exit=0 应豁免" 0 "${TMPD}/xy-with-exit.md"

# Case 5: 命令证据超出 ±10 行窗口 → 不豁免
echo "Case 5: 证据超出窗口"
{
  echo "# 测试报告"
  echo ""
  echo '跑 `bash scripts/test.sh`'
  for i in $(seq 1 15); do echo "填充行 $i"; done
  echo "结果 25/25 PASS"
} > "${TMPD}/xy-far-cmd.md"
assert_exit "命令距 15 行应 fail" 1 "${TMPD}/xy-far-cmd.md"

# Case 6: 装饰词无例外 (只有 X/Y PASS 有窗口豁免)
echo "Case 6: 装饰词无例外"
cat > "${TMPD}/decorative.md" << 'EOF'
# 报告

跑 `bash scripts/test.sh` 验证, 这是生产级实现.
EOF
assert_exit "生产级 有命令也应 fail" 1 "${TMPD}/decorative.md"

# Case 7: 干净文件 → PASS
echo "Case 7: 干净文件"
cat > "${TMPD}/clean.md" << 'EOF'
# 报告

跑 `bash scripts/test.sh` 得 exit=0, 9 个 case 全过.
EOF
assert_exit "无违规应 pass" 0 "${TMPD}/clean.md"

# Case 8: Python scanner observable success contract
# 不依赖 Bash 私有函数; 通过脚本 exit/output 验证可观察行为.
echo "Case 8: Python scanner success contract"
cat > "${TMPD}/python-clean.md" << 'EOF'
# 报告

跑 `python3 scripts/check.py` 得 exit=0, 9 个 case 全过.
EOF
TOTAL=$((TOTAL + 1))
set +e
python_output="$(bash "$SCRIPT" "${TMPD}/python-clean.md" 2>&1)"
python_exit=$?
set -e
if [ "$python_exit" -eq 0 ] && echo "$python_output" | grep -q 'OK: 0 jargon violations'; then
  echo "  PASS: Python scanner 返回可观察 OK contract"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: Python scanner contract 异常 (exit=$python_exit, output=$python_output)" >&2
  FAIL=1
fi

# Case 9: Python scanner observable fail-closed contract
echo "Case 9: Python scanner fail-closed contract"
cat > "${TMPD}/python-bare-xy.md" << 'EOF'
# 测试报告

测试结果 25/25 PASS.
EOF
TOTAL=$((TOTAL + 1))
set +e
python_fail_output="$(bash "$SCRIPT" "${TMPD}/python-bare-xy.md" 2>&1)"
python_fail_exit=$?
set -e
if [ "$python_fail_exit" -eq 1 ] && echo "$python_fail_output" | grep -q 'FAIL:'; then
  echo "  PASS: Python scanner 公开 fail-closed contract 生效 (exit=1)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: Python scanner 未按 contract 失败 (exit=$python_fail_exit, output=$python_fail_output)" >&2
  FAIL=1
fi

# Case 10 (B 修 B3): META_EXEMPT 不用 'jargon' substring 通配
# 修复: 精确 basename / 显式 path glob, 不能 substring match 'jargon'
echo "Case 10: META_EXEMPT 不用 'jargon' 通配 (B 修 B3)"
TOTAL=$((TOTAL + 1))
# 排除注释行后, 检查是否含 *jargon* 通配 (作为数组元素)
in_meta_exempt_jargon=0
# 提取 META_EXEMPT_BASENAMES= 块到下一个 )
basenames_block="$(awk '/^META_EXEMPT_BASENAMES=\($/,/^\)$/' "$SCRIPT")"
if echo "$basenames_block" | grep -q '"jargon"'; then
  in_meta_exempt_jargon=1
fi
# 提取 META_EXEMPT_PATH_PATTERNS 块
paths_block="$(awk '/^META_EXEMPT_PATH_PATTERNS=\($/,/^\)$/' "$SCRIPT")"
if echo "$paths_block" | grep -E '"\*jargon\*"|"jargon"'; then
  in_meta_exempt_jargon=1
fi
if [ "$in_meta_exempt_jargon" -eq 0 ]; then
  echo "  PASS: META_EXEMPT 数组不含 'jargon' 通配"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: META_EXEMPT 仍含 'jargon' substring 通配" >&2
  FAIL=1
fi

# Case 11 (B 修 B3 实跑): 文件名含 'jargon' 但不是 fixture, 不应豁免
echo "Case 11: 文件名含 jargon 但不是 fixture 不豁免 (B 修 B3 实跑)"
cat > "${TMPD}/jargon-risk-report.md" << 'EOF'
# 报告

生产级工具.
EOF
TOTAL=$((TOTAL + 1))
set +e
bash "$SCRIPT" "${TMPD}/jargon-risk-report.md" >/dev/null 2>&1
case11_exit=$?
set -e
if [ "$case11_exit" -eq 1 ]; then
  echo "  PASS: 文件名含 jargon 不豁免, 命中 fail (exit=1)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: 文件名含 jargon 被豁免 (exit=$case11_exit, 期望 1)" >&2
  FAIL=1
fi

# Case 12: Python scanner observable decorative-claim contract
echo "Case 12: Python scanner 装饰词 contract"
cat > "${TMPD}/python-decorative.md" << 'EOF'
# 报告

跑 `python3 scripts/check.py` 验证, 这是生产级实现.
EOF
TOTAL=$((TOTAL + 1))
set +e
case12_output="$(bash "$SCRIPT" "${TMPD}/python-decorative.md" 2>&1)"
case12_exit=$?
set -e
if [ "$case12_exit" -eq 1 ] && echo "$case12_output" | grep -q 'FAIL:'; then
  echo "  PASS: Python scanner 装饰词仍 fail-closed (exit=1)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: Python scanner 装饰词未按 contract 拦截 (exit=$case12_exit)" >&2
  FAIL=1
fi

echo ""
echo "结果: $PASS_COUNT 个 case 通过"

if [ $FAIL -eq 0 ]; then
  echo "EPIC-286 check-jargon 豁免: ALL PASS"
  exit 0
else
  echo "EPIC-286 check-jargon 豁免: FAILED" >&2
  exit 1
fi
