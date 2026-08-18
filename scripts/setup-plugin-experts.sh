#!/usr/bin/env bash
# scripts/setup-plugin-experts.sh — 拉远程专家池到本地外挂目录
#
# 单向覆盖: 拉取 github.com/godlockin/kallax-experts 仓库, 用其 experts/ 目录
# 覆盖本地 ~/.claude/skills/kallax-experts/. 失败时回滚 (rename-based atomic).
#
# 用法:
#   bash scripts/setup-plugin-experts.sh                    # 拉取
#   bash scripts/setup-plugin-experts.sh --check           # 干跑 (只报告)
#   bash scripts/setup-plugin-experts.sh --rollback        # 回滚到上次成功状态
#
# 配置: 远程 URL (默认 github.com/godlockin/kallax-experts) 和本地路径 (默认 ~/.claude/skills/kallax-experts)

set -uo pipefail

REMOTE_URL="${KALLAX_EXPERTS_REMOTE:-https://github.com/godlockin/kallax-experts.git}"
LOCAL_DIR="${KALLAX_EXPERTS_DIR:-$HOME/.claude/skills/kallax-experts}"

action="setup"
if [ $# -gt 0 ]; then
  case "$1" in
    --check)  action="check" ;;
    --rollback) action="rollback" ;;
    *) echo "Usage: $0 [--check|--rollback]"; exit 1 ;;
  esac
fi

if [ "$action" = "rollback" ]; then
  LATEST=$(ls -dt ${LOCAL_DIR}.backup.* 2>/dev/null | head -1)
  if [ -z "$LATEST" ]; then
    echo "ERROR: 找不到 backup, 无可回滚"; exit 1
  fi
  rm -rf "$LOCAL_DIR"
  mv "$LATEST" "$LOCAL_DIR"
  echo "rollback 完成: 恢复 $LATEST → $LOCAL_DIR"
  exit 0
fi

# check / setup 都需要 clone
if [ "$action" = "check" ]; then
  echo "DRY-RUN: 将要 git clone $REMOTE_URL → $LOCAL_DIR (覆盖现有)"
  echo "现有: $([ -d "$LOCAL_DIR" ] && echo "$LOCAL_DIR 存在 ($(ls "$LOCAL_DIR" | wc -l | tr -d ' ') 个条目)" || echo "不存在")"
  exit 0
fi

# setup
if [ ! -d "$LOCAL_DIR" ]; then
  echo "INFO: $LOCAL_DIR 不存在, 首次 clone"
  git clone --depth 1 "$REMOTE_URL" "$LOCAL_DIR"
  echo "clone 完成: $LOCAL_DIR"
  exit 0
fi

# 已存在 → atomic 替换: rename 旧 → backup, clone 新 → 旧路径
BACKUP="${LOCAL_DIR}.backup.$$"
mv "$LOCAL_DIR" "$BACKUP"
if ! git clone --depth 1 "$REMOTE_URL" "$LOCAL_DIR"; then
  echo "ERROR: clone 失败, 回滚到 $BACKUP"
  rm -rf "$LOCAL_DIR"
  mv "$BACKUP" "$LOCAL_DIR"
  exit 1
fi
echo "替换完成: 旧 $LOCAL_DIR → $BACKUP (可回滚)"
