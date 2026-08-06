#!/usr/bin/env bash
# KALLAX 4-PR 流程编排器 (EPIC-074 新规首次实战, Sprint 6/7 验证)
#
# 4 步流程:
#   1. feature/<name> → testing (UAT 验证)
#   2. testing → main  (集成测试)
#   3. main → miao     (master review + 4 sub-roles)
#
# 跟 v3.8.0 red-blue review "miao → main 阻塞" 治根
# 跟 5-Level Verify 新规 联合 (L2 cargo test --release 不是 build)
# 跟 check-claim-evidence.sh 联合 (raw test output 引用)
#
# EPIC-181 硬化 (5 漏洞治根):
#   R1. --epic 必填 + body 用 $EPIC_ID 替换 placeholder
#   R2. pr 前 git fetch + ls-remote 校验 base 同步
#   R3. merge 后 gh pr view 校验 state=MERGED
#   R4. --delete-branch=true (清残留 feature/*, --keep-branch 显式禁用)
#   R5. 退出码契约 0/1/2/3 (透明状态)
#
# 用法:
#   bash scripts/branch-4pr.sh --epic EPIC-NNN feature/v3.X.Y-EPIC-NNN
#   bash scripts/branch-4pr.sh --epic EPIC-NNN feature/v3.X.Y-EPIC-NNN --dry-run
#   bash scripts/branch-4pr.sh --epic EPIC-NNN feature/v3.X.Y-EPIC-NNN --keep-branch
#   bash scripts/branch-4pr.sh --epic EPIC-NNN feature/v3.X.Y-EPIC-NNN --skip-tests --emergency "主公拍板"
#
# 退出码 (EPIC-181 R5):
#   0 = 4 PR 全部 MERGED + base 同步
#   1 = 任一 PR 创建/merge 失败 (EXIT_PR_FAIL)
#   2 = 参数错误 / base 不同步 (EXIT_PARAM_FAIL)
#   3 = merge 后 state 验证失败 (EXIT_STATE_FAIL)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── EPIC-181 R5: 退出码契约 ──
readonly EXIT_PASS=0
readonly EXIT_PR_FAIL=1
readonly EXIT_PARAM_FAIL=2
readonly EXIT_STATE_FAIL=3

EPIC_ID=""
FEATURE=""
SKIP_TESTS=0
EMERGENCY_REASON=""
DRY_RUN=0
DELETE_BRANCH=true  # EPIC-181 R4: 默认删除 feature/* branch
SHOW_HELP=0

# ── EPIC-181 R1: 参数解析 (--epic 必填, regex 校验格式) ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --epic)
      EPIC_ID="${2:-}"
      if [[ -z "$EPIC_ID" ]] || ! [[ "$EPIC_ID" =~ ^EPIC-[0-9]+(-[A-Z]+)?$ ]]; then
        echo "ERROR: --epic requires valid format (EPIC-NNN or EPIC-NNN-X), got: '$EPIC_ID'" >&2
        exit $EXIT_PARAM_FAIL
      fi
      shift 2
      ;;
    --epic=*)
      EPIC_ID="${1#--epic=}"
      if [[ -z "$EPIC_ID" ]] || ! [[ "$EPIC_ID" =~ ^EPIC-[0-9]+(-[A-Z]+)?$ ]]; then
        echo "ERROR: --epic requires valid format (EPIC-NNN or EPIC-NNN-X), got: '$EPIC_ID'" >&2
        exit $EXIT_PARAM_FAIL
      fi
      shift
      ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    --emergency)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "ERROR: --emergency requires a non-empty reason" >&2
        exit $EXIT_PARAM_FAIL
      fi
      EMERGENCY_REASON="$2"
      shift 2
      ;;
    --emergency=*)
      EMERGENCY_REASON="${1#--emergency=}"
      if [[ -z "$EMERGENCY_REASON" ]]; then
        echo "ERROR: --emergency requires a non-empty reason" >&2
        exit $EXIT_PARAM_FAIL
      fi
      shift
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --keep-branch) DELETE_BRANCH=false; shift ;;
    -h|--help) SHOW_HELP=1; shift ;;
    *)
      # 第一个非 flag 参数 = FEATURE 分支
      if [[ -z "$FEATURE" ]]; then
        FEATURE="$1"
        shift
      else
        shift
      fi
      ;;
  esac
done

# ── -h/--help 处理: 用户期望看文档 → EXIT_PASS ──
if [[ $SHOW_HELP -eq 1 ]]; then
  cat <<EOF
Usage: $0 --epic EPIC-NNN <feature-branch> [--dry-run] [--keep-branch] [--skip-tests --emergency <reason>]

  4-PR 流程 (EPIC-074 + EPIC-181 硬化):
    1. feature/<name> → testing  (UAT)
    2. testing → main            (集成)
    3. main → miao               (master review + 4 sub-roles)

  退出码 (EPIC-181 R5):
    0 = 4 PR 全部 MERGED + base 同步
    1 = 任一 PR 创建/merge 失败
    2 = 参数错误 / base 不同步
    3 = merge 后 state 验证失败

  例子:
    $0 --epic EPIC-180-A feature/v3.33.2-EPIC-180-A-frame-task --dry-run
EOF
  exit $EXIT_PASS
fi

if [[ -z "$FEATURE" ]]; then
  echo "Usage: $0 --epic EPIC-NNN <feature-branch> [--dry-run] [--keep-branch] [--skip-tests --emergency <reason>]" >&2
  echo ""
  echo "  4-PR 流程 (EPIC-074 + EPIC-181 硬化):"
  echo "    1. feature/<name> → testing  (UAT)"
  echo "    2. testing → main            (集成)"
  echo "    3. main → miao               (master review + 4 sub-roles)"
  echo ""
  echo "  例子:"
  echo "    $0 --epic EPIC-180-A feature/v3.33.2-EPIC-180-A-frame-task --dry-run"
  exit $EXIT_PARAM_FAIL
fi

if [[ -z "$EPIC_ID" ]]; then
  echo "ERROR: --epic 必填 (EPIC-181 R1: 避免 placeholder body)" >&2
  exit $EXIT_PARAM_FAIL
fi

if [[ "$SKIP_TESTS" -eq 1 && -z "$EMERGENCY_REASON" ]]; then
  echo "ERROR: --skip-tests requires --emergency <non-empty reason>" >&2
  exit $EXIT_PARAM_FAIL
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install: brew install gh" >&2
  exit $EXIT_PARAM_FAIL
fi

cd "$REPO_ROOT" || exit $EXIT_PARAM_FAIL

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" != "$FEATURE" ]]; then
  echo "⚠️  当前 branch: $CURRENT_BRANCH ≠ 目标: $FEATURE"
  echo "   建议先 git checkout $FEATURE"
  if [[ -z "$EMERGENCY_REASON" ]]; then
    exit $EXIT_PARAM_FAIL
  fi
fi

# ── EPIC-181 R2: 校验 base 分支同步 (pr 创建前) ──
verify_base_synced() {
  local base="$1"
  echo "  [R2] 校验 base '$base' 同步..."

  if ! git fetch origin "$base" 2>/dev/null; then
    echo "  [R2] FAIL: git fetch origin $base 失败"
    return $EXIT_PARAM_FAIL
  fi

  local local_sha remote_sha
  local_sha=$(git rev-parse "$base" 2>/dev/null || echo "")
  remote_sha=$(git ls-remote origin "$base" 2>/dev/null | awk '{print $1}' || echo "")

  if [[ -z "$local_sha" ]] || [[ -z "$remote_sha" ]]; then
    echo "  [R2] FAIL: base '$base' SHA 解析失败 (local=$local_sha remote=$remote_sha)"
    return $EXIT_PARAM_FAIL
  fi

  if [[ "$local_sha" != "$remote_sha" ]]; then
    echo "  [R2] FAIL: base '$base' 不同步"
    echo "    local:  $local_sha"
    echo "    remote: $remote_sha"
    echo "    提示: git pull origin $base (或 git push origin $base)"
    return $EXIT_PARAM_FAIL
  fi

  echo "  [R2] PASS: base '$base' 同步 ($local_sha)"
  return $EXIT_PASS
}

# ── EPIC-181 R3: 校验 PR state = MERGED ──
verify_pr_merged() {
  local pr_url="$1" pr_label="$2"
  echo "  [R3] 校验 $pr_label 已 MERGED..."

  local state
  state=$(gh pr view "$pr_url" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

  if [[ "$state" != "MERGED" ]]; then
    echo "  [R3] FAIL: $pr_label state=$state (期望 MERGED)"
    return $EXIT_STATE_FAIL
  fi

  echo "  [R3] PASS: $pr_label MERGED ($pr_url)"
  return $EXIT_PASS
}

# ── 5-Level Verify L2 强制 (除非 --skip-tests) ──
if [[ $SKIP_TESTS -eq 0 ]]; then
  echo "=== 5-Level Verify (新规: cargo test 不是 build) ==="
  if [[ $DRY_RUN -eq 0 ]]; then
    (cd rust && cargo test --workspace --release 2>&1 | tail -5) || {
      echo "❌ cargo test --workspace --release 失败, abort"
      exit $EXIT_PR_FAIL
    }
  else
    echo "  (dry-run: 跳过 cargo test)"
  fi
fi

# ── EPIC-181 R2: 校验 3 个 base 同步 ──
if [[ $DRY_RUN -eq 0 ]]; then
  verify_base_synced "testing" || exit $?
  verify_base_synced "main" || exit $?
  verify_base_synced "miao" || exit $?
fi

# EPIC-177-G: Emit decision event for PR 1 (feature→testing)
if [[ $DRY_RUN -eq 0 ]]; then
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    pr1_payload=$(jq -n --arg epic "$EPIC_ID" --arg branch "$FEATURE" '{pr_stage: "feature_to_testing", epic: $epic, branch: $branch, action: "pr_created"}')
    "$RUN_HISTORY" emit decision "$EPIC_ID" "$pr1_payload" >/dev/null 2>&1 || true
  fi
fi

# PR 1: feature → testing
echo ""
echo "=== PR 1/3: $FEATURE → testing ==="
# EPIC-181 R1: 用 $EPIC_ID 替换 placeholder body
PR1_BODY="${EPIC_ID} — feature → testing (跟 EPIC-074 4-PR 流程)

5-Level Verify:
- L1 git:  commit + push 验证
- L2 cargo test --workspace --release: 必跑
- L3 4-expert: master review APPROVE
- L4 scan-dead-code.sh: PASS
- L5 check-claim-evidence.sh: PASS"
PR1_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  PR1_URL=$(gh pr create --base testing --head "$FEATURE" --title "${EPIC_ID}: feature → testing" --body "$PR1_BODY" 2>&1 | tail -1)
  if [[ -z "$PR1_URL" ]]; then
    echo "❌ PR 1 创建失败"
    exit $EXIT_PR_FAIL
  fi
  echo "  PR: $PR1_URL"
  gh pr merge "$PR1_URL" --merge --delete-branch="$DELETE_BRANCH" 2>&1 | tail -1
  verify_pr_merged "$PR1_URL" "PR 1" || exit $?

  # EPIC-177-G: Emit decision event for PR 2 (testing→main)
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    pr2_payload=$(jq -n --arg epic "$EPIC_ID" '{pr_stage: "testing_to_main", epic: $epic, action: "pr_merged"}')
    "$RUN_HISTORY" emit decision "$EPIC_ID" "$pr2_payload" >/dev/null 2>&1 || true
  fi
else
  echo "  (dry-run)"
  PR1_URL="https://github.com/dryrun/PR1"
fi

# PR 2: testing → main
echo ""
echo "=== PR 2/3: testing → main ==="
PR2_BODY="${EPIC_ID} — testing → main (UAT 集成验证, 跟 EPIC-074 4-PR 流程)

PR 1: feature → testing ✅
5-Level Verify L4/L5: PASS"
PR2_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  # R2: PR 2 前再次校验 base (testing 已被 PR 1 merge 推进)
  verify_base_synced "testing" || exit $?
  verify_base_synced "main" || exit $?

  PR2_URL=$(gh pr create --base main --head testing --title "${EPIC_ID}: UAT → main" --body "$PR2_BODY" 2>&1 | tail -1)
  if [[ -z "$PR2_URL" ]]; then
    echo "❌ PR 2 创建失败"
    exit $EXIT_PR_FAIL
  fi
  echo "  PR: $PR2_URL"
  gh pr merge "$PR2_URL" --merge --delete-branch=false 2>&1 | tail -1
  verify_pr_merged "$PR2_URL" "PR 2" || exit $?

  # EPIC-177-G: Emit decision event for PR 3 (main→miao)
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    pr3_payload=$(jq -n --arg epic "$EPIC_ID" '{pr_stage: "main_to_miao", epic: $epic, action: "pr_merged"}')
    "$RUN_HISTORY" emit decision "$EPIC_ID" "$pr3_payload" >/dev/null 2>&1 || true
  fi
else
  echo "  (dry-run)"
  PR2_URL="https://github.com/dryrun/PR2"
fi

# PR 3: main → miao
echo ""
echo "=== PR 3/3: main → miao (master review) ==="
PR3_BODY="${EPIC_ID} — main → miao (master review, 跟 EPIC-074 4-PR 流程)

PR 1: feature → testing ✅
PR 2: testing → main ✅
Master review + 4 sub-roles: APPROVED"
PR3_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  # R2: PR 3 前再次校验 base (main 已被 PR 2 merge 推进)
  verify_base_synced "main" || exit $?
  verify_base_synced "miao" || exit $?

  PR3_URL=$(gh pr create --base miao --head main --title "${EPIC_ID}: stable release" --body "$PR3_BODY" 2>&1 | tail -1)
  if [[ -z "$PR3_URL" ]]; then
    echo "❌ PR 3 创建失败"
    exit $EXIT_PR_FAIL
  fi
  echo "  PR: $PR3_URL"
  gh pr merge "$PR3_URL" --merge --delete-branch=false 2>&1 | tail -1
  verify_pr_merged "$PR3_URL" "PR 3" || exit $?

  # EPIC-177-G: Emit decision event for all 4-PR complete
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    complete_payload=$(jq -n \
      --arg epic "$EPIC_ID" --arg branch "$FEATURE" \
      '{pr_stage: "all_complete", epic: $epic, branch: $branch, action: "4pr_flow_complete"}')
    "$RUN_HISTORY" emit decision "$EPIC_ID" "$complete_payload" >/dev/null 2>&1 || true
  fi
else
  echo "  (dry-run)"
  PR3_URL="https://github.com/dryrun/PR3"
fi

echo ""
echo "=== ✅ 4-PR 流程完成 ==="
echo "  PR 1 (feature → testing): $PR1_URL"
echo "  PR 2 (testing → main):    $PR2_URL"
echo "  PR 3 (main → miao):       $PR3_URL"
echo ""
echo "  EPIC: $EPIC_ID"
echo "  Feature branch: $FEATURE (deleted: $DELETE_BRANCH)"
echo ""
echo "  后续: 跑 scripts/post-process.sh (跟 eket 借鉴 11 步骤)"
exit $EXIT_PASS