#!/usr/bin/env python3
"""
scripts/expert-generate-l3.py — EPIC-024-C Sprint 3 L3 Generation Mock Demo

DEMO ONLY: Uses hardcoded response to simulate LLM API call.
Replace mock_llm_call() with real LLM API integration in Phase 2.

This script:
1. Reads existing 7 default + 90 extended experts
2. Performs gap analysis (domain distribution)
3. Simulates LLM generation via hardcoded response
4. Outputs 5 mock expert candidates to /tmp/l3-mock-output.md
"""

import re
import sys
from pathlib import Path
from collections import Counter

# === CONFIG ===
REPO_ROOT = Path("/Users/chenchen/working/sourcecode/tools/dev-tools/kallax")
DEFAULT_EXPERTS_DIR = REPO_ROOT / ".kallax/experts/default"
EXTENDED_INDEX = REPO_ROOT / ".kallax/worktrees/performer-EPIC-024-B/.kallax/experts/extended/INDEX.md"
OUTPUT_FILE = Path("/tmp/l3-mock-output.md")

# === LOAD EXPERTS ===
def load_default_experts() -> list[dict]:
    """Load 7 default experts from .kallax/experts/default/*.md"""
    experts = []
    for md_file in DEFAULT_EXPERTS_DIR.glob("*.md"):
        content = md_file.read_text()
        id_match = re.search(r"^id:\s*(.+)$", content, re.MULTILINE)
        name_match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
        trigger_match = re.search(r"^trigger:\s*(.+)$", content, re.MULTILINE)
        domain_match = re.search(r"^name:\s*.*?(\w+)", content, re.MULTILINE)

        if id_match and name_match:
            experts.append({
                "id": id_match.group(1).strip(),
                "name": name_match.group(1).strip(),
                "domain": "architecture", # default experts are generalist
                "tier": "default",
                "trigger": trigger_match.group(1).strip() if trigger_match else "",
            })
    return experts

def load_extended_experts() -> list[dict]:
    """Load 90 extended experts from worktree INDEX.md"""
    experts = []
    if not EXTENDED_INDEX.exists():
        print(f"WARN: Extended INDEX not found at {EXTENDED_INDEX}", file=sys.stderr)
        return experts

    content = EXTENDED_INDEX.read_text()
    # Split by --- frontmatter delimiter
    records = re.split(r"\n---\n", content)

    for record in records:
        id_match = re.search(r"^id:\s*(.+)$", record, re.MULTILINE)
        name_match = re.search(r"^name_cn:\s*(.+)$", record, re.MULTILINE)
        domain_match = re.search(r"^domain:\s*(.+)$", record, re.MULTILINE)
        trigger_match = re.search(r"^trigger:\s*(.+)$", record, re.MULTILINE)

        if id_match and name_match:
            experts.append({
                "id": id_match.group(1).strip(),
                "name": name_match.group(1).strip(),
                "domain": domain_match.group(1).strip() if domain_match else "unknown",
                "tier": "extended",
                "trigger": trigger_match.group(1).strip() if trigger_match else "",
            })
    return experts

def analyze_domain_gaps(experts: list[dict]) -> list[tuple[str, int]]:
    """Count domain distribution and identify gaps"""
    domain_counts = Counter(e["domain"] for e in experts)

    # All domains we want to cover
    all_domains = [
        "legal", "finance", "data", "product", "marketing",
        "tech", "security", "business", "consulting", "hr",
        "knowledge", "ops", "pr", "training", "design", "ai", "ux"
    ]

    # Find missing/underrepresented domains
    gaps = []
    for domain in all_domains:
        count = domain_counts.get(domain, 0)
        if count < 3:  # threshold for "gap"
            gaps.append((domain, count))

    # Sort by count ascending (most missing first)
    gaps.sort(key=lambda x: x[1])
    return gaps

# === MOCK LLM ===
def mock_llm_call(domain: str, gap_count: int) -> list[dict]:
    """
    DEMO ONLY — Replace with real LLM API call in Phase 2.

    Simulates LLM generating 5 expert candidates for a gap domain.
    Returns hardcoded response matching real LLM output schema.
    """
    # Hardcoded mock responses per domain (each trigger has 24+ pipe-separated tokens)
    mock_candidates = {
        "legal": [
            {
                "id": "kallax.extended.091",
                "name_cn": "法务顾问",
                "role": "首席法律顾问",
                "emoji": "⚖️",
                "domain": "legal",
                "tier": "extended",
                "description": "合同审核/知识产权/监管合规/法律风险控制",
                "trigger": "合同法务|知识产权|监管合规|法律风险|合同审核|许可协议|商标专利|著作权|数据合规|GDPR|隐私政策|法律顾问|首席|顾问|法务|合规|风险|审核|协议|许可|商标|专利|版权|监管|数据保护|跨境法律|诉讼|仲裁|合规培训|合规审计|合规检查|合规报告"
            },
            {
                "id": "kallax.extended.092",
                "name_cn": "合规官",
                "role": "合规总监",
                "emoji": "📋",
                "domain": "legal",
                "tier": "extended",
                "description": "企业合规体系建设/内部控制/反垄断/出口管制",
                "trigger": "合规体系|内部控制|反垄断|出口管制|合规官|总监|体系建设|内控|反垄断法|贸易管制|制裁|enbargo|合规培训|合规审计|合规检查|合规报告|合规风险|合规流程|合规制度|合规管理|合规监控|合规文化|合规审查|合规评估|合规咨询|合规建议|合规标准"
            },
        ],
        "finance": [
            {
                "id": "kallax.extended.093",
                "name_cn": "财务分析师",
                "role": "财务总监",
                "emoji": "💹",
                "domain": "finance",
                "tier": "extended",
                "description": "财务分析/预算管理/成本控制/投资评估",
                "trigger": "财务分析|预算管理|成本控制|投资评估|财务报表|财务审计|成本优化|现金流|财务预测|预算编制|财务模型|投资回报|ROI分析|财务计划|资金管理|财务风险|财务报告|财务指标|盈利分析|成本分析|预算执行|财务控制|财务分析|资金计划|预算跟踪|成本分析|资产配置"
            },
            {
                "id": "kallax.extended.094",
                "name_cn": "投融资顾问",
                "role": "投资总监",
                "emoji": "💰",
                "domain": "finance",
                "tier": "extended",
                "description": "融资规划/投资人关系/并购咨询/估值建模",
                "trigger": "投融资|融资规划|投资人关系|并购咨询|估值建模|商业计划|路演|投资人|融资|投资|并购|M&A|尽职调查|估值|财务模型|投资条款|股权融资|债券融资|估值方法|DCF|LBO|并购整合|投后管理|投资组合|基金募集|投资者关系|资本结构|融资策略|交易结构"
            },
        ],
        "data": [
            {
                "id": "kallax.extended.095",
                "name_cn": "数据分析师",
                "role": "BI分析师",
                "emoji": "📊",
                "domain": "data",
                "tier": "extended",
                "description": "BI报表/数据分析/指标体系/数据可视化",
                "trigger": "数据分析|BI报表|指标体系|数据可视化|Tableau|PowerBI|仪表盘|数据看板|数据分析|指标设计|KPI体系|数据挖掘|数据清洗|ETL|数据仓库|报表开发|数据洞察|业务分析|数据驱动|数据呈现|趋势分析|对比分析|归因分析|数据探索|数据监控|数据预警|异常检测|数据共享|数据开放"
            },
            {
                "id": "kallax.extended.096",
                "name_cn": "数据工程师",
                "role": "数据平台负责人",
                "emoji": "🏗️",
                "domain": "data",
                "tier": "extended",
                "description": "大数据架构/数据管道/实时处理/数据治理",
                "trigger": "数据工程|大数据架构|数据管道|实时处理|数据治理|Spark|Flink|Kafka|数据湖|数据仓库|ETL|数据集成|数据质量|数据血缘|元数据|数据平台|流式处理|批处理|数据建模|数据架构|数据存储|数据检索|数据同步|数据服务|数据API|数据分发|数据缓存|数据归档|数据备份"
            },
        ],
        "product": [
            {
                "id": "kallax.extended.097",
                "name_cn": "增长产品经理",
                "role": "增长负责人",
                "emoji": "📈",
                "domain": "product",
                "tier": "extended",
                "description": "用户增长/产品增长/增长黑客/A/B测试",
                "trigger": "用户增长|产品增长|增长黑客|A/B测试|产品经理|增长负责人|用户研究|产品设计|功能优化|留存提升|转化优化|获客成本|用户获取|用户激活|用户留存|用户裂变|病毒营销|增长策略|增长实验|增长指标|增长漏斗|增长渠道|增长黑客|增长团队|增长引擎"
            },
        ],
        "ux": [
            {
                "id": "kallax.extended.098",
                "name_cn": "用户研究员",
                "role": "UX研究负责人",
                "emoji": "🔬",
                "domain": "ux",
                "tier": "extended",
                "description": "用户研究/可用性测试/用户旅程/体验优化",
                "trigger": "用户研究|可用性测试|用户旅程|体验优化|UX研究|调研方法|用户访谈|问卷调查|可用性|用户测试|体验地图|用户旅程图|用户画像|需求分析|用户行为|用户反馈|用户洞察|体验设计|体验优化|体验评估|体验指标|体验研究|用户中心|同理心地图|用户体验|用户满意度"
            },
        ],
    }

    # Return 2-3 candidates per domain (demo purposes)
    return mock_candidates.get(domain, [])[:2]

# === VALIDATE ===
def validate_candidate(candidate: dict, existing_ids: set) -> tuple[bool, str]:
    """Validate candidate schema and dedup"""
    required_fields = ["id", "name_cn", "role", "emoji", "domain", "tier", "description", "trigger"]

    for field in required_fields:
        if field not in candidate or not candidate[field]:
            return False, f"Missing required field: {field}"

    if candidate["id"] in existing_ids:
        return False, f"Duplicate ID: {candidate['id']}"

    if candidate["tier"] != "extended":
        return False, f"Invalid tier: {candidate['tier']}"

    trigger_count = len(candidate["trigger"].split("|"))
    if trigger_count < 24:
        return False, f"Trigger token count {trigger_count} < 24"

    return True, "OK"

def format_expert_yaml(candidate: dict) -> str:
    """Format candidate as YAML frontmatter block"""
    lines = [
        "---",
        f"id: {candidate['id']}",
        f"name_cn: {candidate['name_cn']}",
        f"role: {candidate['role']}",
        f"emoji: {candidate['emoji']}",
        f"domain: {candidate['domain']}",
        f"tier: {candidate['tier']}",
        f"description: {candidate['description']}",
        f"trigger: {candidate['trigger']}",
        "---",
        "",
    ]
    return "\n".join(lines)

# === MAIN ===
def main():
    print("=" * 60)
    print("EPIC-024-C Sprint 3 L3 Generation Mock Demo")
    print("=" * 60)
    print()

    # Step 1: Load existing experts
    print("[1/5] Loading existing experts...")
    default_experts = load_default_experts()
    extended_experts = load_extended_experts()
    all_experts = default_experts + extended_experts

    print(f"  - Default experts: {len(default_experts)}")
    print(f"  - Extended experts: {len(extended_experts)}")
    print(f"  - Total: {len(all_experts)}")
    print()

    # Step 2: Gap analysis
    print("[2/5] Performing gap analysis...")
    domain_counts = Counter(e["domain"] for e in all_experts)
    print("  Domain distribution:")
    for domain, count in sorted(domain_counts.items(), key=lambda x: -x[1]):
        print(f"    {domain}: {count}")

    gaps = analyze_domain_gaps(all_experts)
    print()
    print("  Top-5 domain gaps (count < 3):")
    for i, (domain, count) in enumerate(gaps[:5], 1):
        print(f"    {i}. {domain}: {count} experts")
    print()

    # Step 3: Mock LLM generation
    print("[3/5] Generating mock experts via LLM simulation...")
    print("  (DEMO ONLY — replace with real LLM API call in Phase 2)")
    print()

    existing_ids = {e["id"] for e in all_experts}
    all_candidates = []

    for domain, count in gaps[:3]:  # Top 3 gap domains
        print(f"  Generating for domain: {domain}")
        candidates = mock_llm_call(domain, count)

        for candidate in candidates:
            valid, msg = validate_candidate(candidate, existing_ids)
            if valid:
                all_candidates.append(candidate)
                existing_ids.add(candidate["id"])
                print(f"    + {candidate['id']}: {candidate['name_cn']} ({candidate['emoji']})")
            else:
                print(f"    - REJECTED {candidate.get('id', 'unknown')}: {msg}")

    print()
    print(f"  Total candidates generated: {len(all_candidates)}")
    print()

    # Step 4: Write output
    print("[4/5] Writing output to", OUTPUT_FILE)
    output_lines = [
        "# L3 Mock Expert Candidates",
        "",
        "> **DEMO OUTPUT** — Generated by `scripts/expert-generate-l3.py`",
        "> **DO NOT COMMIT** — For demonstration only",
        "",
        f"Generated: 2026-06-09",
        f"Candidates: {len(all_candidates)}",
        "",
        "---",
        "",
    ]

    for candidate in all_candidates:
        output_lines.append(format_expert_yaml(candidate))

    OUTPUT_FILE.write_text("\n".join(output_lines))
    print(f"  Written {len(output_lines)} lines to {OUTPUT_FILE}")
    print()

    # Step 5: Summary
    print("[5/5] Summary")
    print("=" * 60)
    print(f"  Experts loaded: {len(all_experts)} (7 default + {len(extended_experts)} extended)")
    print(f"  Gap domains identified: {len(gaps)}")
    print(f"  Candidates generated: {len(all_candidates)}")
    print(f"  Output file: {OUTPUT_FILE}")
    print()
    print("  Mock demo complete. Proceed to Phase 2 for real LLM integration.")
    print("=" * 60)

    return 0

if __name__ == "__main__":
    sys.exit(main())