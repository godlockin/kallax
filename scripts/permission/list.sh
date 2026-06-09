#!/bin/bash
# kallax role:list — 列出所有角色
#
# P0 修复项:
#   - set -euo pipefail
#   - fail-closed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 尝试加载 authz.sh (可选, 用于动态列表)
if [[ -f "$SCRIPT_DIR/../lib/authz.sh" ]]; then
  source "$SCRIPT_DIR/../lib/authz.sh" 2>/dev/null || true
fi

echo "Available roles:"
echo "  - master (inherits: conductor)"
echo "  - conductor"
echo "  - performer"
echo "  - readonly"
echo "  - auditor (inherits: readonly)"
echo "  - super-admin (inherits: master)"
echo "  - emergency-responder (inherits: super-admin)"