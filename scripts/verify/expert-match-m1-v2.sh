#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXPERT_MATCH="$REPO_ROOT/scripts/expert-match.sh"

declare -a REQUIREMENTS=(
    "接口慢怎么优化" "数据库索引怎么加" "页面渲染卡顿" "组件状态管理混乱"
    "用户旅程卡在哪一步" "按钮点击率低" "这个需求值不值得做" "MVP应该砍哪些功能"
    "API鉴权怎么设计" "XSS漏洞怎么防" "微服务怎么拆" "模块边界划不清"
    "跨ticket协调" "团队任务分配" "React包体积怎么减小" "缓存击穿"
    "可用性问题" "优先级排序" "OWASP合规" "API契约设计"
    "请求超时了" "白屏" "首屏慢" "样式错乱" "新用户不会用"
    "老板让做这个值不值" "被攻击了" "数据泄露风险" "循环依赖" "谁负责这块"
)
declare -a EXPECTED=(
    "backend" "backend" "frontend" "frontend" "ux" "ux"
    "product" "product" "security" "security" "architect" "architect"
    "pm" "pm" "frontend" "backend" "ux" "product" "security" "architect"
    "backend" "frontend" "frontend" "frontend" "ux"
    "product" "security" "security" "architect" "pm"
)

PASS=0; FAIL=0; FAILS=()
for i in "${!REQUIREMENTS[@]}"; do
    req="${REQUIREMENTS[$i]}"; exp="${EXPECTED[$i]}"
    out=$(bash "$EXPERT_MATCH" "$req" 2>&1 || true)
    got=$(echo "$out" | grep -oE 'id=[a-z]+' | head -1 | sed 's/id=//')
    if [ "$got" = "$exp" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1)); FAILS+=("'$req' exp=$exp got=$got")
    fi
done
TOTAL=$((PASS+FAIL))
RATE=$(echo "scale=1; $PASS * 100 / $TOTAL" | bc)
echo "M1 KPI v2: $PASS/$TOTAL = ${RATE}% (target >= 80%)"
[ "$FAIL" -gt 0 ] && { echo "FAIL:"; printf '  %s\n' "${FAILS[@]}"; }
exit $((FAIL > 0 ? 1 : 0))