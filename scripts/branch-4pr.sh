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
# 用法:
#   bash scripts/branch-4pr.sh feature/v3.12.0-EPIC-XXX
#   bash scripts/branch-4pr.sh feature/v3.12.0-EPIC-XXX --skip-tests
#   bash scripts/branch-4pr.sh feature/v3.12.0-EPIC-XXX --dry-run
#
# 退出码:
#   0 = 4 PR 全部 MERGED
#   1 = 任一 PR 失败
#   2 = 参数错误

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FEATURE="${1:-}"
SKIP_TESTS=0
EMERGENCY=0
DRY_RUN=0

shift || true
for arg in "$@"; do
  case "$arg" in
    --skip-tests) SKIP_TESTS=1 ;;
    --emergency) EMERGENCY=1 ;;
    --dry-run) DRY_RUN=1 ;;
  esac
done

if [[ -z "$FEATURE" || "$FEATURE" == "--help" || "$FEATURE" == "-h" ]]; then
  echo "Usage: $0 <feature-branch> [--skip-tests] [--emergency] [--dry-run]"
  echo ""
  echo "  4-PR 流程 (EPIC-074 新规):"
  echo "    1. feature/<name> → testing  (UAT)"
  echo "    2. testing → main            (集成)"
  echo "    3. main → miao               (master review + 4 sub-roles)"
  echo ""
  echo "  例子:"
  echo "    $0 feature/v3.12.0-EPIC-083"
  echo "    $0 feature/v3.12.0-EPIC-083 --dry-run"
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install: brew install gh"
  exit 1
fi

cd "$REPO_ROOT" || exit 2

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" != "$FEATURE" ]]; then
  echo "⚠️  当前 branch: $CURRENT_BRANCH ≠ 目标: $FEATURE"
  echo "   建议先 git checkout $FEATURE"
  if [[ $EMERGENCY -eq 0 ]]; then
    exit 1
  fi
fi

# 5-Level Verify L2 强制 (除非 --skip-tests)
if [[ $SKIP_TESTS -eq 0 ]]; then
  echo "=== 5-Level Verify (新规: cargo test 不是 build) ==="
  if [[ $DRY_RUN -eq 0 ]]; then
    (cd rust && cargo test --release 2>&1 | tail -5) || {
      echo "❌ cargo test --release 失败, abort"
      exit 1
    }
  else
    echo "  (dry-run: 跳过 cargo test)"
  fi
fi

# EPIC-177-G: Emit decision event for PR 1 (feature→testing)
if [[ $DRY_RUN -eq 0 ]]; then
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    local pr1_payload
    pr1_payload=$(jq -n --arg branch "$FEATURE" '{pr_stage: "feature_to_testing", branch: $branch, action: "pr_created"}')
    "$RUN_HISTORY" emit decision "$FEATURE" "$pr1_payload" >/dev/null 2>&1 || true
  fi
fi

# PR 1: feature → testing
echo ""
echo "=== PR 1/3: $FEATURE → testing ==="
PR1_BODY="EPIC-XXX (auto-generated 4-PR body, replace with actual)"
PR1_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  PR1_URL=$(gh pr create --base testing --head "$FEATURE" --title "EPIC: feature → testing" --body "$PR1_BODY" 2>&1 | tail -1)
  if [[ -z "$PR1_URL" ]]; then
    echo "❌ PR 1 创建失败"
    exit 1
  fi
  echo "  PR: $PR1_URL"
  gh pr merge "$PR1_URL" --merge --delete-branch=false 2>&1 | tail -1

  # EPIC-177-G: Emit decision event for PR 2 (testing→main)
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    local pr2_payload
    pr2_payload=$(jq -n '{pr_stage: "testing_to_main", action: "pr_merged"}')
    "$RUN_HISTORY" emit decision "$FEATURE" "$pr2_payload" >/dev/null 2>&1 || true
  fi
else
  echo "  (dry-run)"
  PR1_URL="https://github.com/dryrun/PR1"
fi

# PR 2: testing → main
echo ""
echo "=== PR 2/3: testing → main ==="
PR2_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  PR2_URL=$(gh pr create --base main --head testing --title "EPIC: UAT → main" --body "UAT 集成验证 (跟 EPIC-074 4-PR 流程)" 2>&1 | tail -1)
  if [[ -z "$PR2_URL" ]]; then
    echo "❌ PR 2 创建失败"
    exit 1
  fi
  echo "  PR: $PR2_URL"
  gh pr merge "$PR2_URL" --merge --delete-branch=false 2>&1 | tail -1

  # EPIC-177-G: Emit decision event for PR 3 (main→miao)
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    local pr3_payload
    pr3_payload=$(jq -n '{pr_stage: "main_to_miao", action: "pr_merged"}')
    "$RUN_HISTORY" emit decision "$FEATURE" "$pr3_payload" >/dev/null 2>&1 || true
  fi
else
  echo "  (dry-run)"
  PR2_URL="https://github.com/dryrun/PR2"
fi

# PR 3: main → miao
echo ""
echo "=== PR 3/3: main → miao (master review) ==="
PR3_URL=""
if [[ $DRY_RUN -eq 0 ]]; then
  PR3_URL=$(gh pr create --base miao --head main --title "EPIC: stable release" --body "Master review (跟 EPIC-074 4-PR 流程)" 2>&1 | tail -1)
  if [[ -z "$PR3_URL" ]]; then
    echo "❌ PR 3 创建失败"
    exit 1
  fi
  echo "  PR: $PR3_URL"
  gh pr merge "$PR3_URL" --merge --delete-branch=false 2>&1 | tail -1

  # EPIC-177-G: Emit decision event for all 4-PR complete
  RUN_HISTORY="${REPO_ROOT}/scripts/heartbeat/run-history.sh"
  if [ -f "$RUN_HISTORY" ]; then
    local complete_payload
    complete_payload=$(jq -n \
      --arg branch "$FEATURE" \
      '{pr_stage: "all_complete", branch: $branch, action: "4pr_flow_complete"}')
    "$RUN_HISTORY" emit decision "$FEATURE" "$complete_payload" >/dev/null 2>&1 || true
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
echo "  后续: 跑 scripts/post-process.sh (跟 eket 借鉴 11 步骤)"