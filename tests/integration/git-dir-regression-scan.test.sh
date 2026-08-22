#!/usr/bin/env bash
# EPIC-277-G AC3 — 防 GIT_DIR 回归扫描 + 解析验证
#
# 验证: 所有 scripts/hooks/ + scripts/hooks/install.sh 中 `git -C` + rev-parse 调用,
#       全部带 env -u GIT_DIR -u GIT_WORK_TREE (跟 #467 卡 F 暴露的 bug 1:1).
#
# 退出码: 0 = 全 PASS, 1 = 至少 1 缺 env -u

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/scripts/hooks"

PASS_COUNT=0
FAIL_COUNT=0
FAIL_FILES=()

echo "── AC3: scripts/hooks/ 全 hook 在 GIT_DIR 已设环境下仍能正确解析 repo root ──"
echo ""

# ── 1. 静态扫描: 所有 `git -C .* rev-parse` 必须带 env -u ──
echo "[1/2] 静态扫描: git -C + rev-parse 必须带 env -u GIT_DIR -u GIT_WORK_TREE"

while IFS= read -r -d '' file; do
  while IFS= read -r line_num; do
    line_content="$(sed -n "${line_num}p" "${file}")"
    # 跳过注释行 (以 # 开头)
    [[ "${line_content}" =~ ^[[:space:]]*# ]] && continue
    # 跳过无 git -C 行
    [[ "${line_content}" != *"git -C"* ]] && continue
    # 跳过无 rev-parse 行
    [[ "${line_content}" != *"rev-parse"* ]] && continue
    # 必须含 env -u GIT_DIR -u GIT_WORK_TREE
    if [[ "${line_content}" == *"env -u GIT_DIR -u GIT_WORK_TREE"* ]]; then
      PASS_COUNT=$((PASS_COUNT + 1))
      printf "  ✓ %s:%d\n" "${file#${REPO_ROOT}/}" "${line_num}"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAIL_FILES+=("${file}:${line_num}")
      printf "  ✗ %s:%d  缺 env -u GIT_DIR -u GIT_WORK_TREE\n" "${file#${REPO_ROOT}/}" "${line_num}"
    fi
  done < <(grep -n 'git -C ' "${file}" | cut -d: -f1)
done < <(find "${HOOKS_DIR}" -name "*.sh" -print0)

echo ""
echo "[2/2] 动态验证: 在 GIT_DIR 已设环境下, install.sh --verify 9/9 PASS"

# ── 2. 动态验证: 模拟 git hook 环境 ──
TEST_REPO="$(mktemp -d)"
git -C "${TEST_REPO}" init -q
# 模拟 git hook 环境 GIT_DIR 已设
export GIT_DIR="${TEST_REPO}/.git"
export GIT_WORK_TREE="${TEST_REPO}"
RESULT=$(env -u GIT_DIR -u GIT_WORK_TREE bash "${HOOKS_DIR}/install.sh" --verify 2>&1)
EXIT=$?
unset GIT_DIR GIT_WORK_TREE

if [[ ${EXIT} -eq 0 ]]; then
  echo "  ✓ install.sh --verify 9/9 PASS (GIT_DIR 已 unset)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ install.sh --verify exit=${EXIT}"
  echo "${RESULT}" | head -5
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

rm -rf "${TEST_REPO}"

echo ""
echo "── 总结 ──"
echo "PASS: ${PASS_COUNT}"
echo "FAIL: ${FAIL_COUNT}"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
  echo ""
  echo "失败文件:"
  printf '  - %s\n' "${FAIL_FILES[@]}"
  exit 1
fi

exit 0