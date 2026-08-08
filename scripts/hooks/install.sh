#!/usr/bin/env bash
# KALLAX Git Hooks Installer — EPIC-224 (死文件激活)
#
# Installs pre-commit + pre-push + commit-msg hooks and repairs broken core.hooksPath.
#
# EPIC-224 起因: `git config core.hooksPath` 曾指向 /tmp/kallax-fix-epic131/.githooks
# (已不存在的临时目录) → 所有 pre-commit hook 从未运行, 5 immutable scripts 全部失效.
# 本 installer 必须检测并修复这种情况.
#
# Usage:
#   bash scripts/hooks/install.sh           # 安装 + 修复 hooksPath
#   bash scripts/hooks/install.sh --verify  # 只检查不改 (exit 1 = 有问题)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="${REPO_ROOT}/scripts/hooks"
GIT_DIR="$(git rev-parse --git-common-dir)"
# worktree 场景下 --git-common-dir 可能是相对路径
case "$GIT_DIR" in
  /*) ;;
  *) GIT_DIR="${REPO_ROOT}/${GIT_DIR}" ;;
esac
HOOKS_DIR="${GIT_DIR}/hooks"

VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && VERIFY_ONLY=1

problems=0

echo "==> KALLAX Hook Installer (EPIC-224)"
echo "    repo:      $REPO_ROOT"
echo "    git dir:   $GIT_DIR"
echo "    hooks dir: $HOOKS_DIR"
echo ""

# ── Check 1: core.hooksPath 是否指向存在的目录 ──────────────────────────
echo "--- core.hooksPath 检查 ---"
CONFIGURED_PATH="$(git config --get core.hooksPath 2>/dev/null || true)"

if [ -n "$CONFIGURED_PATH" ]; then
  case "$CONFIGURED_PATH" in
    /*) resolved="$CONFIGURED_PATH" ;;
    *)  resolved="${REPO_ROOT}/${CONFIGURED_PATH}" ;;
  esac

  if [ -d "$resolved" ]; then
    echo "  OK: core.hooksPath = $CONFIGURED_PATH (存在)"
  else
    echo "  BROKEN: core.hooksPath = $CONFIGURED_PATH (目录不存在)"
    echo "          → 所有 hook 从未运行 (5 immutable scripts 失效)"
    problems=1
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      git config --unset core.hooksPath
      echo "  FIXED: 已 unset core.hooksPath, 回退默认 ${HOOKS_DIR}"
    fi
  fi
else
  echo "  OK: core.hooksPath 未设置 (用默认 ${HOOKS_DIR})"
fi
echo ""

# ── Check 2: hook 文件是否已安装且为最新 ────────────────────────────────
echo "--- hook 安装检查 ---"
for hook in pre-commit pre-push; do
  src="${HOOKS_SRC}/${hook}"
  dst="${HOOKS_DIR}/${hook}"

  if [ ! -f "$src" ]; then
    echo "  SKIP: $hook 源文件不存在"
    continue
  fi

  if [ ! -f "$dst" ]; then
    echo "  MISSING: $hook 未安装"
    problems=1
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      mkdir -p "$HOOKS_DIR"
      cp "$src" "$dst"
      chmod +x "$dst"
      echo "  INSTALLED: $hook"
    fi
  elif ! cmp -s "$src" "$dst"; then
    echo "  STALE: $hook 已安装但跟源文件不一致"
    problems=1
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      cp "$src" "$dst"
      chmod +x "$dst"
      echo "  UPDATED: $hook"
    fi
  else
    echo "  OK: $hook 已安装且最新"
  fi
done
echo ""

# ── Check 3: commitlint (EPIC-221 加了 config 但无 runner) ──────────────
echo "--- commitlint 检查 (EPIC-221 + EPIC-224) ---"
if [ -f "${REPO_ROOT}/commitlint.config.js" ]; then
  COMMIT_MSG_HOOK="${HOOKS_DIR}/commit-msg"
  if [ ! -f "$COMMIT_MSG_HOOK" ]; then
    echo "  MISSING: commit-msg hook (config 存在但无 runner)"
    problems=1
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      mkdir -p "$HOOKS_DIR"
      cp "${HOOKS_SRC}/commit-msg" "$COMMIT_MSG_HOOK"
      chmod +x "$COMMIT_MSG_HOOK"
      echo "  INSTALLED: commit-msg hook (DCO + Conventional Commits)"
    fi
  elif [ -f "${HOOKS_SRC}/commit-msg" ] && ! cmp -s "${HOOKS_SRC}/commit-msg" "$COMMIT_MSG_HOOK"; then
    echo "  STALE: commit-msg 跟源文件不一致"
    problems=1
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      cp "${HOOKS_SRC}/commit-msg" "$COMMIT_MSG_HOOK"
      chmod +x "$COMMIT_MSG_HOOK"
      echo "  UPDATED: commit-msg"
    fi
  else
    echo "  OK: commit-msg hook 已安装"
  fi
else
  echo "  SKIP: commitlint.config.js 不存在"
fi
echo ""

# ── Summary ────────────────────────────────────────────────────────────
if [ "$VERIFY_ONLY" -eq 1 ]; then
  if [ "$problems" -eq 0 ]; then
    echo "OK: hook 体系健康 (hooksPath + pre-commit + pre-push + commit-msg)"
    exit 0
  fi
  echo "FAIL: hook 体系有问题, 跑 'bash scripts/hooks/install.sh' 修复"
  exit 1
fi

echo "==> 安装完成. 生效的 gate:"
echo "  pre-commit:"
echo "    - 5 immutable (decorative/narrative/fail-closed/self-heal/claim-evidence)"
echo "    - EPIC-220 disclaimer audit (staged .md)"
echo "    - EPIC-219 snapshot 提醒 (CLAUDE.md / .claude/rules, advisory)"
echo "    - EPIC-223 ticket schema (staged ticket.json, >archived_before 强制)"
echo "    - miao 分支保护"
echo "  commit-msg:"
echo "    - DCO Signed-off-by 强制 (EPIC-221 config 激活)"
echo "    - Conventional Commits type 检查"
echo ""
echo "Bypass (主公 approval only): KALLAX_HOOK_BYPASS=1 git commit ..."