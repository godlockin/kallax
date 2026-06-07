#!/usr/bin/env bash
#
# l1-match-test.sh — L1 match test for EXPERT-EXTENSION Sprint A
# Usage: l1-match-test.sh --baseline <json> --experts <dir>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

BASELINE_FILE=""
EXPERTS_DIR=""

usage() {
    cat <<EOF
Usage: $(basename "$0") --baseline <json> --experts <dir>

Options:
  --baseline <json> Path to l1-baseline-data.json
  --experts <dir>     Path to experts directory
  -h, --help          Show this help
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --baseline)
            BASELINE_FILE="$2"
            shift 2
            ;;
        --experts)
            EXPERTS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

[[ -z "$BASELINE_FILE" ]] && { echo "ERROR: --baseline required" >&2; usage; }
[[ -z "$EXPERTS_DIR" ]] && { echo "ERROR: --experts required" >&2; usage; }
[[ -f "$BASELINE_FILE" ]] || { echo "ERROR: baseline file not found: $BASELINE_FILE" >&2; exit 1; }

# Expert list
EXPERTS="backend frontend architect product ux"

# Run match test using Python
python3 <<PYEOF
import json
import sys

# Expert trigger keywords from INDEX.md (symptom-based)
EXPERT_KEYWORDS = {
    'backend': '接口响应慢 列表加载 卡顿 查询 数据库 后端 服务端 API 接口慢 响应慢'.split(),
    'frontend': '页面卡顿 组件错位 前端 UI 界面卡 加载慢 渲染 样式布局'.split(),
    'architect': '架构选型 模块边界 抽象层 设计 结构 重构 架构争议'.split(),
    'product': '优先级 功能该不该做 砍哪个 产品 决策'.split(),
    'ux': '界面操作 文案 按钮找不到 UX 用户体验 交互流失'.split()
}

# Load baseline data
with open('$BASELINE_FILE', 'r') as f:
    tickets = json.load(f)

# Initialize counters
counters = {}
for expert in ['backend', 'frontend', 'architect', 'product', 'ux']:
    counters[f'{expert}_exact_hit'] = 0
    counters[f'{expert}_exact_miss'] = 0
    counters[f'{expert}_substring_hit'] = 0
    counters[f'{expert}_substring_miss'] = 0
    counters[f'{expert}_threshold_hit'] = 0
    counters[f'{expert}_threshold_miss'] = 0

total_matches = 0
all_results = []

for ticket in tickets:
    ticket_id = ticket['ticket_id']
    title = ticket.get('title', '')
    description_keywords = ticket.get('description_keywords', {})
    actual_expert = ticket.get('actual_expert', 'unknown')

    # Combine title and all keywords for matching
    all_kws = []
    for kws_list in description_keywords.values():
        if kws_list and isinstance(kws_list, str):
            all_kws.extend(kws_list.split())
    combined_text = (title + ' ' + ' '.join(all_kws)).lower()

    ticket_result = {
        'ticket_id': ticket_id,
        'actual_expert': actual_expert,
        'matches': {}
    }

    for expert in ['backend', 'frontend', 'architect', 'product', 'ux']:
        kws = description_keywords.get(expert, '') or ''
        if isinstance(kws, str):
            kws_list = kws.split()
        else:
            kws_list = []

        # Exact match: count keyword hits (word boundary match)
        exact_hit = sum(1 for kw in kws_list if kw.lower() in combined_text.split())

        # Substring match: count substring hits
        substring_hit = sum(1 for kw in kws_list if kw.lower() in combined_text)

        # Threshold match: >=2 hits = hit
        threshold_hit = 1 if substring_hit >= 2 else 0

        ticket_result['matches'][expert] = {
            'exact': exact_hit,
            'substring': substring_hit,
            'threshold': threshold_hit
        }

        # Update counters based on actual_expert
        if actual_expert == expert:
            # This ticket belongs to this expert
            if exact_hit > 0:
                counters[f'{expert}_exact_hit'] += 1
            else:
                counters[f'{expert}_exact_miss'] += 1

            if substring_hit > 0:
                counters[f'{expert}_substring_hit'] += 1
            else:
                counters[f'{expert}_substring_miss'] += 1

            if threshold_hit == 1:
                counters[f'{expert}_threshold_hit'] += 1
            else:
                counters[f'{expert}_threshold_miss'] += 1
        elif actual_expert == 'unknown':
            # For unknown tickets, count as miss if no keywords matched
            if exact_hit == 0:
                counters[f'{expert}_exact_miss'] += 1
            if substring_hit == 0:
                counters[f'{expert}_substring_miss'] += 1
            if threshold_hit == 0:
                counters[f'{expert}_threshold_miss'] += 1

    all_results.append(ticket_result)
    total_matches += 1

# Output results
print("=" * 60)
print("L1 MATCH TEST RESULTS")
print("=" * 60)
print(f"\nTotal tickets processed: {total_matches}")
print(f"Strategies tested: exact (word match), substring (contains), threshold (>=2 hits)\n")

# Per-expert results
print("-" * 60)
print(f"{'Expert':<12} {'Strategy':<15} {'Hit':<8} {'Miss':<8} {'Rate':<10}")
print("-" * 60)

for expert in ['backend', 'frontend', 'architect', 'product', 'ux']:
    for strategy in ['exact', 'substring', 'threshold']:
        hit_key = f'{expert}_{strategy}_hit'
        miss_key = f'{expert}_{strategy}_miss'
        hit = counters[hit_key]
        miss = counters[miss_key]
        total = hit + miss
        rate = (hit / total * 100) if total > 0 else 0
        print(f"{expert:<12} {strategy:<15} {hit:<8} {miss:<8} {rate:>7.1f}%")

    print()

# Overall results
print("-" * 60)
print("OVERALL HIT RATES")
print("-" * 60)

for strategy in ['exact', 'substring', 'threshold']:
    total_hit = sum(counters[f'{expert}_{strategy}_hit'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
    total_miss = sum(counters[f'{expert}_{strategy}_miss'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
    total = total_hit + total_miss
    rate = (total_hit / total * 100) if total > 0 else 0
    print(f"{strategy:<15} {total_hit:<8} {total_miss:<8} {rate:>7.1f}%")

print()

# Decision based on overall threshold hit rate
threshold_total_hit = sum(counters[f'{expert}_threshold_hit'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
threshold_total_miss = sum(counters[f'{expert}_threshold_miss'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
threshold_total = threshold_total_hit + threshold_total_miss
threshold_rate = (threshold_total_hit / threshold_total * 100) if threshold_total > 0 else 0

print("=" * 60)
print("DECISION")
print("=" * 60)
if threshold_rate < 30:
    print(f"Overall L1 miss rate: {100-threshold_rate:.1f}% (>30%)")
    print("Decision: EXPAND - Sprint B recommended (miss rate > 30%)")
else:
    print(f"Overall L1 hit rate: {threshold_rate:.1f}% (>= 30%)")
    print("Decision: VALIDATE - No Sprint B needed (hit rate >= 30%)")
print("=" * 60)

# Output JSON for report
report_data = {
    'total_tickets': total_matches,
    'counters': counters,
    'overall': {}
}

for strategy in ['exact', 'substring', 'threshold']:
    total_hit = sum(counters[f'{expert}_{strategy}_hit'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
    total_miss = sum(counters[f'{expert}_{strategy}_miss'] for expert in ['backend', 'frontend', 'architect', 'product', 'ux'])
    total = total_hit + total_miss
    rate = (total_hit / total * 100) if total > 0 else 0
    report_data['overall'][strategy] = {
        'hit': total_hit,
        'miss': total_miss,
        'rate': rate
    }

print("\n--- JSON OUTPUT ---")
print(json.dumps(report_data, ensure_ascii=False, indent=2))
PYEOF

echo ""
echo "INFO: L1 match test complete"