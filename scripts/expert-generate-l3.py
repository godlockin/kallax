#!/usr/bin/env python3
"""
scripts/expert-generate-l3.py — EPIC-024-C Sprint 3 L3 Generation

Real LLM API integration with mock fallback.
- Reads KALLAX_LLM_API_KEY env var
- If set: calls real OpenAI-compatible LLM API
- If not set: falls back to mock (same as demo)

This script:
1. Reads existing 7 default + 90 extended experts
2. Performs gap analysis (domain distribution)
3. Generates 3-5 expert candidates per gap domain (LLM or mock)
4. Validates schema + dedup
5. Appends to extended INDEX.md
"""

import re
import sys
import json
import os
from pathlib import Path
from collections import Counter
from typing import Optional

# === CONFIG ===
# Resolve REPO_ROOT from script location: walk up to git toplevel so this works
# in both main repo and worktrees (Round 2 fix: REPO_ROOT was hardcoded to main
# repo, causing writes to silently land in main instead of current worktree).
SCRIPT_DIR = Path(__file__).resolve().parent
def _find_repo_root(start: Path) -> Path:
    cur = start
    while cur != cur.parent:
        if (cur / ".git").exists() or (cur / ".git").is_file():
            return cur
        cur = cur.parent
    return start
REPO_ROOT = _find_repo_root(SCRIPT_DIR)
DEFAULT_EXPERTS_DIR = REPO_ROOT / ".kallax/experts/default"
EXTENDED_INDEX = REPO_ROOT / ".kallax/experts/extended/INDEX.md"
OUTPUT_FILE = Path("/tmp/l3-candidates-generated.md")

# LLM API config from env
LLM_API_KEY = os.environ.get("KALLAX_LLM_API_KEY", "")
LLM_BASE_URL = os.environ.get("KALLAX_LLM_BASE_URL", "https://api.deepseek.com/anthropic")
LLM_MODEL = os.environ.get("KALLAX_LLM_MODEL", "deepseek-chat")

# Allowed domains (from design doc)
ALLOWED_DOMAINS = {
    "legal", "finance", "data", "product", "marketing",
    "tech", "security", "business", "consulting", "hr",
    "knowledge", "ops", "pr", "training", "design", "ai", "ux"
}

# Gap domains (from design doc C-SPRINT-3-DESIGN.md)
GAP_DOMAINS = ["legal", "finance", "data"]

# M1 test cases (30 real ticket descriptions from EPIC-016)
# These must NOT appear verbatim in trigger fields
M1_TEST_CASES = [
    "接口慢怎么优化", "数据库索引怎么加", "页面渲染卡顿", "组件状态管理混乱",
    "用户旅程卡在哪一步", "按钮点击率低", "这个需求值不值得做",
    "微服务架构选型", "缓存击穿怎么办", "N+1查询怎么查",
    "前端重渲染优化", "SQL慢查询优化", "接口超时处理",
    "用户留存率下降", "怎么加监控告警", "锁竞争怎么解决",
    "连接池耗尽", "内存泄漏怎么查", "GC频繁怎么调",
    "死锁怎么排查", "分布式事务一致性", "灰度发布方案",
    "AB test怎么设计", "代码重构节奏", "技术债评估",
    "安全漏洞扫描", "权限控制设计", "数据加密方案",
    "压测怎么做", "性能瓶颈定位"
]

# === LOAD EXPERTS ===
def load_default_experts() -> list[dict]:
    """Load 7 default experts from .kallax/experts/default/*.md"""
    experts = []
    for md_file in DEFAULT_EXPERTS_DIR.glob("*.md"):
        content = md_file.read_text()
        id_match = re.search(r"^id:\s*(.+)$", content, re.MULTILINE)
        name_match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
        trigger_match = re.search(r"^trigger:\s*(.+)$", content, re.MULTILINE)

        if id_match and name_match:
            experts.append({
                "id": id_match.group(1).strip(),
                "name": name_match.group(1).strip(),
                "name_cn": name_match.group(1).strip(),
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
                "name_cn": name_match.group(1).strip(),
                "domain": domain_match.group(1).strip() if domain_match else "unknown",
                "tier": "extended",
                "trigger": trigger_match.group(1).strip() if trigger_match else "",
            })
    return experts

def analyze_domain_gaps(experts: list[dict]) -> list[tuple[str, int]]:
    """Count domain distribution and identify gaps"""
    domain_counts = Counter(e["domain"] for e in experts)

    # Find missing/underrepresented domains
    gaps = []
    for domain in ALLOWED_DOMAINS:
        count = domain_counts.get(domain, 0)
        if count < 3:  # threshold for "gap"
            gaps.append((domain, count))

    # Sort by count ascending (most missing first)
    gaps.sort(key=lambda x: x[1])
    return gaps

# === LLM API ===
def call_llm_api(prompt: str) -> Optional[dict]:
    """Call Anthropic-compatible LLM API (DeepSeek /anthropic endpoint).
    Returns JSON response or None on error."""
    if not LLM_API_KEY:
        return None

    import urllib.request
    import urllib.error

    # Anthropic Messages API format
    url = f"{LLM_BASE_URL}/v1/messages"
    payload = json.dumps({
        "model": LLM_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 2048
    })

    req = urllib.request.Request(
        url,
        data=payload.encode("utf-8"),
        headers={
            "x-api-key": LLM_API_KEY,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            # Anthropic response: result["content"][0]["text"]
            content = result["content"][0]["text"]
            # Parse JSON from response
            # Strip markdown code blocks if present
            content = content.strip()
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()
            return json.loads(content)
    except Exception as e:
        print(f"WARN: LLM API call failed: {e}", file=sys.stderr)
        return None

def build_llm_prompt(domain: str, all_expert_ids: list[str], all_expert_names: list[str]) -> str:
    """Build LLM prompt for expert generation."""
    # Get existing IDs and names for dedup
    existing_info = "\n".join([f"- {id}: {name}" for id, name in zip(all_expert_ids[:50], all_expert_names[:50])])

    return f"""You are an expert in generating KALLAX expert persona candidates.

## Task
Generate 3-5 expert candidates for the gap domain: {domain}

## Rules
1. Each expert MUST have unique ID not in existing list
2. name_cn must be2-6 Chinese characters, not duplicate existing
3. domain must be one of: {', '.join(ALLOWED_DOMAINS)}
4. tier must be "generated"
5. trigger must have ≥20 pipe-separated tokens (keywords)
6. description must be ≥20 characters
7. DO NOT include test case phrases verbatim in trigger fields
8. **CRITICAL DOMAIN CONSTRAINT**: generated tier MUST NOT use these default domains: architect, backend, frontend, ux, product, security, pm, ai (default tier), also NOT in default 7 expert trigger high-frequency range. Use gap domains: {', '.join(GAP_DOMAINS)} (legal, finance, data) or细分 ai subdomains

## Existing experts (for dedup):
{existing_info}

## Output format
OUTPUT JSON ONLY, NO MARKDOWN. Array of objects:
[
  {{
    "id": "kallax.generated.001",
    "name_cn": "法务顾问",
    "role": "首席法律顾问",
    "emoji": "⚖️",
    "domain": "{domain}",
    "tier": "generated",
    "description": "合同审核/知识产权/监管合规/法律风险控制",
    "trigger": "合同法务|知识产权|监管合规|..."
  }}
]

Generate 3-5 candidates now. JSON array only, no explanation."""

# === MOCK LLM (fallback) ===
def mock_llm_call(domain: str, gap_count: int) -> list[dict]:
    """
    Fallback mock when no LLM API key is set.
    Returns hardcoded expert candidates matching LLM output schema.
    """
    # Hardcoded mock responses per domain (each trigger has 24+ pipe-separated tokens)
    mock_candidates = {
        "legal": [
            {
                "id": "kallax.generated.001",
                "name_cn": "法务合规总监",
                "role": "首席法律顾问",
                "emoji": "⚖️",
                "domain": "legal",
                "tier": "generated",
                "description": "合同审核/知识产权/监管合规/法律风险控制,10年+经验",
                "trigger": "合同法务|法律风险|合同审核|许可协议|商标专利|著作权|法律顾问|首席|顾问|法务|合规|风险|审核|协议|许可|商标|专利|版权|监管|跨境法律|诉讼|仲裁|合规培训|合规审计|合规检查|合规报告|合同谈判|诉讼策略|法律意见书|监管申报|尽职调查|法律咨询"
            },
            {
                "id": "kallax.generated.002",
                "name_cn": "合规官",
                "role": "合规总监",
                "emoji": "📋",
                "domain": "legal",
                "tier": "generated",
                "description": "企业合规体系建设/内部控制/反垄断/出口管制",
                "trigger": "合规体系|内部控制|反垄断|出口管制|合规官|总监|体系建设|内控|反垄断法|贸易管制|制裁|合规培训|合规审计|合规检查|合规报告|合规风险|合规流程|合规制度|合规管理|合规监控|合规文化|合规审查|合规评估|合规咨询|合规建议|合规标准"
            },
            {
                "id": "kallax.generated.003",
                "name_cn": "知识产权顾问",
                "role": "IP总监",
                "emoji": "📜",
                "domain": "legal",
                "tier": "generated",
                "description": "专利布局/商标保护/著作权管理/商业秘密",
                "trigger": "专利布局|商标保护|著作权管理|商业秘密|专利申请|专利检索|专利分析|商标注册|商标侵权|版权登记|著作权保护|商业秘密保护|知识产权|专利|商标|版权|知识产权战略|专利布局|专利运营|知识产权交易|知识产权评估|专利诉讼|知识产权纠纷|知识产权法律"
            },
        ],
        "finance": [
            {
                "id": "kallax.generated.004",
                "name_cn": "高级财务分析师",
                "role": "财务总监",
                "emoji": "💹",
                "domain": "finance",
                "tier": "generated",
                "description": "财务分析/预算管理/成本控制/投资评估,专注科技公司",
                "trigger": "财务分析|预算管理|成本控制|投资评估|财务报表|财务审计|成本优化|现金流|财务预测|预算编制|财务模型|投资回报|ROI分析|财务计划|资金管理|财务风险|财务报告|财务指标|盈利分析|成本分析|预算执行|财务控制|财务分析|资金计划|预算跟踪|成本分析|资产配置"
            },
            {
                "id": "kallax.generated.005",
                "name_cn": "投融资顾问",
                "role": "投资总监",
                "emoji": "💰",
                "domain": "finance",
                "tier": "generated",
                "description": "融资规划/投资人关系/并购咨询/估值建模",
                "trigger": "投融资|融资规划|投资人关系|并购咨询|估值建模|商业计划|路演|投资人|融资|投资|并购|M&A|尽职调查|估值|财务模型|投资条款|股权融资|债券融资|估值方法|DCF|LBO|并购整合|投后管理|投资组合|基金募集|投资者关系|资本结构|融资策略|交易结构"
            },
            {
                "id": "kallax.generated.006",
                "name_cn": "税务顾问",
                "role": "税务总监",
                "emoji": "🧾",
                "domain": "finance",
                "tier": "generated",
                "description": "跨境税务架构/转让定价规划/反避税合规咨询",
                "trigger": "税务筹划|转让定价|跨境税务|税务合规|企业所得税|个人所得税|增值税|税务规划|税务优化|税务风险|税务审计|国际税务|税务协定|税收优惠|税务申报|税负分析|税务筹划|转让定价|预提所得税|税务备案|税务调查|税务处罚|税务复议|税务诉讼"
            },
        ],
        "data": [
            {
                "id": "kallax.generated.007",
                "name_cn": "数据分析师",
                "role": "BI分析师",
                "emoji": "📊",
                "domain": "data",
                "tier": "generated",
                "description": "BI报表/数据分析/指标体系/数据可视化",
                "trigger": "数据分析|BI报表|指标体系|数据可视化|Tableau|PowerBI|仪表盘|数据看板|数据分析|指标设计|KPI体系|数据挖掘|数据清洗|ETL|数据仓库|报表开发|数据洞察|业务分析|数据驱动|数据呈现|趋势分析|对比分析|归因分析|数据探索|数据监控|数据预警|异常检测|数据共享|数据开放"
            },
            {
                "id": "kallax.generated.008",
                "name_cn": "数据工程师",
                "role": "数据平台负责人",
                "emoji": "🏗️",
                "domain": "data",
                "tier": "generated",
                "description": "大数据架构/数据管道/实时处理/数据治理",
                "trigger": "数据工程|大数据架构|数据管道|实时处理|数据治理|Spark|Flink|Kafka|数据湖|数据仓库|ETL|数据集成|数据质量|数据血缘|元数据|数据平台|流式处理|批处理|数据建模|数据架构|数据存储|数据检索|数据同步|数据服务|数据API|数据分发|数据缓存|数据归档|数据备份"
            },
            {
                "id": "kallax.generated.009",
                "name_cn": "算法工程师",
                "role": "ML平台负责人",
                "emoji": "🤖",
                "domain": "data",
                "tier": "generated",
                "description": "推荐系统/NLP/深度学习模型训练与部署",
                "trigger": "机器学习|推荐算法|NLP|LLM|模型训练|深度学习|推荐系统|协同过滤|内容推荐|个性化推荐|模型部署|MLOps|特征工程|数据预处理|算法优化|模型评估|算法工程师|机器学习|深度学习|神经网络|计算机视觉|NLP|自然语言处理|推荐系统|搜索排序|推荐算法|数据挖掘"
            },
        ],
    }

    # Return 2-3 candidates per domain
    return mock_candidates.get(domain, [])[:3]

def generate_experts_for_domain(domain: str, all_expert_ids: list[str], all_expert_names: list[str]) -> list[dict]:
    """Generate expert candidates for a domain via LLM or mock fallback."""
    if LLM_API_KEY:
        print(f"  [LLM] Calling API for domain: {domain}")
        prompt = build_llm_prompt(domain, all_expert_ids, all_expert_names)
        result = call_llm_api(prompt)
        if result and isinstance(result, list):
            return result
        print(f"  [LLM] API failed, falling back to mock")
    return mock_llm_call(domain, 0)


def preflight_dedup_check(candidates: list[dict], existing_names: set) -> list[dict]:
    """
    Pre-mock dedup check: grep INDEX.md for any candidate name_cn that already exists.
    Returns filtered list (deduped candidates) and prints warnings for skipped ones.
    EPIC-034-C Round 2c: 主公拍 A 方案, mock fallback 跑前先 grep 检测, 重复则 skip + warn.
    """
    filtered = []
    for cand in candidates:
        if cand["name_cn"] in existing_names:
            print(f"    ! DEDUP_SKIP: {cand['id']} '{cand['name_cn']}' already in INDEX.md")
            continue
        filtered.append(cand)
    return filtered

# === VALIDATE ===
def validate_candidate(candidate: dict, existing_ids: set, existing_names: set) -> tuple[bool, str]:
    """
    Validate candidate schema per P0 rules:
    - id: unique (vs existing 97)
    - name_cn: not duplicate
    - domain: in allowed set
    - tier: "generated"
    - trigger: >=20 pipe-separated tokens
    - description: >= 20 characters
    - trigger must NOT contain M1 test cases verbatim
    """
    required_fields = ["id", "name_cn", "role", "emoji", "domain", "tier", "description", "trigger"]

    for field in required_fields:
        if field not in candidate or not candidate[field]:
            return False, f"Missing required field: {field}"

    if candidate["id"] in existing_ids:
        return False, f"Duplicate ID: {candidate['id']}"

    if candidate["name_cn"] in existing_names:
        return False, f"Duplicate name_cn: {candidate['name_cn']}"

    if candidate["tier"] != "generated":
        return False, f"Invalid tier: {candidate['tier']} (must be 'generated')"

    if candidate["domain"] not in ALLOWED_DOMAINS:
        return False, f"Invalid domain: {candidate['domain']} not in allowed set"

    trigger_count = len([t for t in candidate["trigger"].split("|") if t.strip()])
    if trigger_count < 20:
        return False, f"Trigger token count {trigger_count} < 20"

    if len(candidate["description"]) < 20:
        return False, f"Description '{candidate['description']}'< 20 chars"

    # Anti-fab check: test cases must NOT appear verbatim in trigger
    trigger_lower = candidate["trigger"].lower()
    for tc in M1_TEST_CASES:
        if tc in trigger_lower:
            return False, f"Test case verbatim in trigger: '{tc}'"

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
    print("EPIC-024-C Sprint 3 L3 Generation (Real + Mock Fallback)")
    print("=" * 60)
    print()

    # Step 1: Load existing experts
    print("[1/6] Loading existing experts...")
    default_experts = load_default_experts()
    extended_experts = load_extended_experts()
    all_experts = default_experts + extended_experts

    print(f"  - Default experts: {len(default_experts)}")
    print(f"  - Extended experts: {len(extended_experts)}")
    print(f"  - Total: {len(all_experts)}")
    print()

    # Step 2: Gap analysis
    print("[2/6] Performing gap analysis...")
    domain_counts = Counter(e["domain"] for e in all_experts)
    print("  Domain distribution:")
    for domain, count in sorted(domain_counts.items(), key=lambda x: -x[1]):
        print(f"    {domain}: {count}")

    gaps = analyze_domain_gaps(all_experts)
    print()
    print(f"  Gap domains (count < 3): {len(gaps)}")
    for i, (domain, count) in enumerate(gaps[:5], 1):
        print(f"    {i}. {domain}: {count} experts")
    print()

    # Step 3: Generate experts via LLM or mock
    print("[3/6] Generating experts for gap domains...")
    if LLM_API_KEY:
        print(f"  LLM API: {LLM_BASE_URL}/v1/messages (model: {LLM_MODEL})")
    else:
        print("  LLM API: NOT SET — using mock fallback")
    print()

    existing_ids = {e["id"] for e in all_experts}
    existing_names = {e["name_cn"] for e in all_experts}
    all_candidates = []

    # Generate for SPRINT 3 target gap domains (legal + finance = 6 candidates 001-006)
    # Round 2: 主公指示 6 个 (legal×3 + finance×3), 跟 Sprint 3 design ID 对齐
    target_domains = [d for d in GAP_DOMAINS if d in {"legal", "finance"}]
    for domain in target_domains:
        count = domain_counts.get(domain, 0)
        print(f"  Generating for domain: {domain} (current count: {count})")
        candidates = generate_experts_for_domain(domain,
            list(existing_ids), list(existing_names))

        # EPIC-034-C Round 2c: preflight dedup — skip mock candidates whose name_cn already in INDEX.md
        candidates = preflight_dedup_check(candidates, existing_names)

        for candidate in candidates:
            valid, msg = validate_candidate(candidate, existing_ids, existing_names)
            if valid:
                all_candidates.append(candidate)
                existing_ids.add(candidate["id"])
                existing_names.add(candidate["name_cn"])
                print(f"    + {candidate['id']}: {candidate['name_cn']} ({candidate['emoji']})")
            else:
                print(f"    - REJECTED {candidate.get('id', 'unknown')}: {msg}")

    print()
    print(f"  Total candidates generated: {len(all_candidates)}")
    print()

    # Step 4: Write output to extended INDEX.md
    print("[4/6] Appending to extended INDEX.md...")
    if not EXTENDED_INDEX.exists():
        print(f"ERROR: Extended INDEX not found at {EXTENDED_INDEX}", file=sys.stderr)
        return 1

    # Read existing content
    existing_content = EXTENDED_INDEX.read_text()

    # Always start append with newline separator (works regardless of whether
    # existing content ends with --- or plain text). Force \n split so each new
    # YAML block is on its own line.
    append_content = "\n"
    for candidate in all_candidates:
        append_content += format_expert_yaml(candidate)

    new_content = existing_content.rstrip() + "\n" + append_content
    EXTENDED_INDEX.write_text(new_content)

    # Verify actually wrote (Round 2 fix: confirm bytes appended, not just len)
    final_size = EXTENDED_INDEX.stat().st_size
    delta = final_size - len(existing_content.encode("utf-8"))
    print(f"  Appended {len(all_candidates)} candidates to {EXTENDED_INDEX}")
    print(f"  [verify] INDEX size: {len(existing_content)} -> {final_size} bytes (delta {delta:+d})")
    print(f"  [verify] target = {EXTENDED_INDEX}")
    print(f"  [verify] exists = {EXTENDED_INDEX.exists()}")
    print(f"  [verify] is in REPO_ROOT (.kallax/experts/extended) = {str(EXTENDED_INDEX).startswith(str(REPO_ROOT) + '/.kallax/experts/extended')}")
    print()

    # Step 5: Write temp output file for review
    print("[5/6] Writing temp output for review...")
    output_lines = [
        "# L3 Generated Expert Candidates",
        "",
        f"> Generated: 2026-06-09",
        f"> LLM API: {'YES' if LLM_API_KEY else 'MOCK (no API key)'}",
        f"> Candidates: {len(all_candidates)}",
        "",
        "---",
        "",
    ]
    for candidate in all_candidates:
        output_lines.append(format_expert_yaml(candidate))

    OUTPUT_FILE.write_text("\n".join(output_lines))
    print(f"  Written to {OUTPUT_FILE}")
    print()

    # Step 6: Summary
    print("[6/6] Summary")
    print("=" * 60)
    print(f"  Experts loaded: {len(all_experts)} (7 default + {len(extended_experts)} extended)")
    print(f"  Gap domains: {len(gaps)}")
    print(f"  Candidates generated: {len(all_candidates)}")
    print(f"  New tier: 'generated' (distinguishes from extended)")
    print(f"  Extended INDEX updated: {EXTENDED_INDEX}")
    print(f"  Temp output: {OUTPUT_FILE}")
    print()
    if LLM_API_KEY:
        print("  Mode: REAL LLM API")
    else:
        print("  Mode: MOCK FALLBACK (KALLAX_LLM_API_KEY not set)")
    print("=" * 60)

    return 0

if __name__ == "__main__":
    sys.exit(main())