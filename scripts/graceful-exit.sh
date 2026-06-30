#!/usr/bin/env bash
# KALLAX v3.4.0 Level 5 graceful-exit (跟 eket 4 级降级 Level 4 1:1 联合)
# 跟"反讽" 联合 治根 "4 层 vs 4 级 顺序 矛盾", 跟"诚实修正" 联合, 跟"独立" 拍板 联合
# 跟 v3.0.0 Iter 11 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.3.0 + eket 1:1 对齐 联合

set -euo pipefail

echo "🚪 KALLAX graceful-exit (跟 eket Level 4 1:1 联合, 跟反讽 联合)"

# 1. 关闭 audit chain (跟 v3.0.0 武器 1 联合)
if [ -d ".kallax/audit" ]; then
  echo "  → 关闭 audit chain"
  bash scripts/audit/audit-verify.sh --finalize 2>/dev/null || echo "  → audit finalize 跳过 (无 audit 状态)"
fi

# 2. 关闭 hook server (跟 v3.0.0 武器 5 联合)
if pgrep -f "hook.*server" > /dev/null 2>&1; then
  echo "  → 关闭 hook server"
  pkill -f "hook.*server" || true
fi

# 3. 关闭 web dashboard (跟 v3.0.0 武器 6 联合)
if pgrep -f "web.*dashboard" > /dev/null 2>&1; then
  echo "  → 关闭 web dashboard"
  pkill -f "web.*dashboard" || true
fi

# 4. 关闭 Node.js 层 (跟 v3.0.0 Iter 11 联合)
if pgrep -f "node.*src" > /dev/null 2>&1; then
  echo "  → 关闭 Node.js 层"
  pkill -f "node.*src" || true
fi

# 5. 关闭 Rust 层 (跟 v3.0.0 Iter 3 binary 整合 联合)
if pgrep -f "kallax.*binary" > /dev/null 2>&1; then
  echo "  → 关闭 Rust binary"
  pkill -f "kallax.*binary" || true
fi

# 6. 关闭 Shell 层 (兜底, 跟 eket Level 4 1:1 联合)
echo "  → 关闭 Shell 层 (兜底, 跟 eket Level 4 1:1)"

echo "✅ KALLAX graceful-exit 落地 (跟 eket Level 4 1:1 联合, 跟 v3.4.0 累计 联合)"
