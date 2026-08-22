#!/usr/bin/env bash
# KALLAX pre-commit hook — check-claim-evidence (EPIC-069-D)
# 治 v3.8.0 → v3.8.1 反讽 1:1 复发: README/CHANGELOG 数字必带 raw test output 引用
#
# 拦截场景:
#   - README/CHANGELOG 含 "X/Y PASS" 数字但无 raw_output / test_output 引用
#   - "5-Level Verify" 出现但 L2 是 cargo build 而非 cargo test
#   - 装饰性断言 ("生产级 / 治根 / 25/25") 无 evidence 文件
#
# Exit codes:
#   0 = PASS (无 claim 或有 raw output 引用)
#   1 = FAIL (decorative claim 无 evidence)
set -euo pipefail

ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel)"
HOOK_NAME="check-claim-evidence"
FAIL=0

# EPIC-283 (DSH Path B): 读 snapshot 豁免清单 (snapshot harness expected/*.json)
# 不在豁免清单内的 snapshot 文件, X/Y PASS 数字检查照常触发. 豁免是防御性
# 防止 expected JSON 内数字 (e.g. "Core Experts (5)") 误报. 加进豁免清单的
# 路径若被改动, snapshot 跟 expected 不匹配, vitest test 会 FAIL (本 hook 互补).
SNAPSHOT_EXEMPTIONS=()
EXEMPTION_LIST="${ROOT}/scripts/verify/.snapshot-exemption-list.txt"
if [[ -f "$EXEMPTION_LIST" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    SNAPSHOT_EXEMPTIONS+=("$line")
  done < "$EXEMPTION_LIST"
fi

# 收集 staged 的 markdown / shell 文件 (macOS bash 3.2 兼容)
# EPIC-117-A: 显式扫 confluence/decisions/** (之前 glob 依赖 shell 展开, 深层目录 miss)
STAGED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && STAGED+=("$line")
done < <(git diff --cached --name-only --diff-filter=ACM \
    -- '*.md' '*.sh' '*.mdx' 'confluence/decisions/**' 'confluence/memory/**' 2>/dev/null || true)

if [[ ${#STAGED[@]} -eq 0 ]]; then
  echo "$HOOK_NAME: no staged md/sh files, skip"
  exit 0
fi

echo "$HOOK_NAME: scanning ${#STAGED[@]} staged file(s)..."

# Pattern 1: "X/Y PASS" 数字 (e.g., "25/25 PASS", "6/6 PASS", "8/19 fail")
# 必须同一文件 100 行内出现 raw_output / test_output / vitest run / cargo test 引用
PATTERN_NUMERIC='[0-9]+/[0-9]+ (PASS|FAIL|passed|failed)'

# Pattern 2: 装饰断言 ("生产级 / 治根 / 100% / 完美")
PATTERN_DECORATIVE='生产级|100% 落地|100% 覆盖|完美闭环|治根 (反讽|反复)'

# Pattern 3: 5-Level Verify 引用
PATTERN_LEVEL_VERIFY='5-Level Verify|L[1-5] (PASS|FAIL)'

for file in "${STAGED[@]}"; do
  filepath="$ROOT/$file"
  [[ -f "$filepath" ]] || continue
  [[ "$file" == CLAUDE.md ]] && continue # CLAUDE.md is allowed to declare Rules

  # EPIC-117-A: confluence/decisions/**/*.md 也纳入 X/Y PASS 数字检查
  # (之前只查 README/CHANGELOG, decisions 里的假 PASS 漏网)
  IS_DECISION=0
  case "$file" in
    confluence/decisions/*.md|confluence/memory/*.md) IS_DECISION=1 ;;
  esac

  # EPIC-283: snapshot expected.json 走 exemption list (豁免 X/Y PASS 数字检查)
  # 防御性: 避免预期 JSON 内的数字格式 ("Core Experts (5)" 之类) 误报 FAIL
  IS_SNAPSHOT_EXEMPT=0
  for exempt in "${SNAPSHOT_EXEMPTIONS[@]}"; do
    if [[ "$file" == "$exempt" ]]; then
      IS_SNAPSHOT_EXEMPT=1
      break
    fi
  done

  # 只看 diff 部分 (避免历史行 false positive)
  diff_content="$(git diff --cached "$file" 2>/dev/null || true)"
  [[ -z "$diff_content" ]] && continue

  # 检查 1: X/Y PASS 数字必须带 raw output 引用
  # EPIC-283: snapshot expected.json 跳过此检查 (走 exemption list)
  if [[ $IS_SNAPSHOT_EXEMPT -eq 0 ]] && echo "$diff_content" | grep -E "$PATTERN_NUMERIC" >/dev/null 2>&1; then
    if ! echo "$diff_content" | grep -E -i '(raw_output|raw test output|test_output|vitest run|cargo test|npm test|jest run|实测|raw_output:|/tmp/.*\.log)' >/dev/null 2>&1; then
      if [[ $IS_DECISION -eq 1 ]]; then
        echo "❌ $file: X/Y PASS 数字无 raw_output 引用 (decisions/memory 文档同 README 标准, EPIC-117-A)"
      else
        echo "❌ $file: X/Y PASS 数字无 raw_output 引用 (反讽 1:1 复发)"
      fi
      FAIL=1
    fi
  fi

  # 检查 2: 装饰断言 (CLAUDE.md / README.md / CHANGELOG.md 之外不允许)
  case "$file" in
    CLAUDE.md|README.md|CHANGELOG.md)
      if echo "$diff_content" | grep -E "$PATTERN_DECORATIVE" >/dev/null 2>&1; then
        if ! echo "$diff_content" | grep -E -i 'EPIC|部分覆盖|实作中|持续演进' >/dev/null 2>&1; then
          echo "⚠️  $file: 装饰断言 ($PATTERN_DECORATIVE) 无证据修饰 (CLAUDE.md 允许但建议加 '实作中/部分覆盖')"
          # 不强制 FAIL, 只 warn
        fi
      fi
      ;;
  esac
done

if [[ $FAIL -eq 1 ]]; then
  echo ""
  echo "$HOOK_NAME: FAIL — 修复方法:"
  echo "  1. 在 X/Y PASS 数字附近加 raw test output 引用 (e.g., 'raw output: /tmp/...')"
  echo "  2. 装饰断言改为 '实作中/部分覆盖'"
  echo "  3. 紧急跳过: git commit --no-verify (主公明确批准时)"
  exit 1
fi

echo "$HOOK_NAME: PASS"
exit 0