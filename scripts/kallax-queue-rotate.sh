#!/usr/bin/env bash
# KALLAX Queue 每日轮转 (v2.0.0)
# 跟 Rule 17 atomic write + 文件并发竞争 5 步 联合
# 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QUEUE_DIR="${KALLAX_ROOT}/.kallax/queue"
ARCHIVE_DIR="${KALLAX_ROOT}/.kallax/queue/archive"
DATE=$(date +%Y-%m-%d)
DRY_RUN="${DRY_RUN:-true}"

# 创 archive 目录 (BE-7 修复模式 umask 077 + install -d -m 700)
umask 077
install -d -m 700 "${ARCHIVE_DIR}"

# 轮转 7 天前的 queue (跟"翻篇&精进" 战略 一致 — 不 bloat)
ROTATE_DAYS="${ROTATE_DAYS:-7}"

# 4 个 queue 子目录
for subdir in inbox outbox results dispatch; do
  QUEUE_SUB="${QUEUE_DIR}/${subdir}"
  if [[ -d "${QUEUE_SUB}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "DRY-RUN: would rotate ${QUEUE_SUB}/* to ${ARCHIVE_DIR}/${subdir}-${DATE}/"
      ls "${QUEUE_SUB}" 2>/dev/null | head -3
    else
      # 移动 7 天前修改的文件
      ARCHIVE_SUB="${ARCHIVE_DIR}/${subdir}-${DATE}"
      install -d -m 700 "${ARCHIVE_SUB}"
      find "${QUEUE_SUB}" -type f -mtime +${ROTATE_DAYS} -exec mv {} "${ARCHIVE_SUB}/" \; 2>/dev/null || true
    fi
  fi
done

echo "Queue rotate done (DRY_RUN=${DRY_RUN})"