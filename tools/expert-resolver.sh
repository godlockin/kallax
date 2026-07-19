#!/usr/bin/env python3
"""
expert-resolver — CLI expert matching with keyword + embedding + LLM hybrid scoring
Usage: python3 tools/expert-resolver.py <query> [--pool=local|all|extended] [--json] [--top=N] [--embedding|--llm]
"""
import json
import sys
import re
import argparse
import os
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# Optional embedding support
try:
    from sentence_transformers import SentenceTransformer
    import numpy as np
    EMBEDDING_AVAILABLE = True
except ImportError:
    EMBEDDING_AVAILABLE = False

# Constants
WEIGHT_TRIGGER = 100
WEIGHT_USE_WHEN = 10
WEIGHT_SUBSTRING = 5
WEIGHT_PREFIX = 0.5
KEYWORD_WEIGHT = 0.6
EMBEDDING_WEIGHT = 0.4
EMBEDDING_SCALE = 500

DATA_JSON = Path(__file__).parent.parent.parent / "kallax-experts" / "docs" / "experts" / "data.json"

def find_repo_root():
    """Find repo root by searching upward for KALLAX identity or git"""
    import os
    dir = Path(__file__).resolve().parent
    while dir != dir.parent:
        if (dir / ".kallax" / "IDENTITY.md").exists() or (dir / ".git").exists():
            return dir
        dir = dir.parent
    return None

# Override: if KALLAX_ROOT env set, use it; otherwise search upward
_kallax_root = os.environ.get('KALLAX_ROOT')
if _kallax_root:
    DATA_JSON = Path(_kallax_root) / "kallax-experts" / "docs" / "experts" / "data.json"
else:
    _repo = find_repo_root()
    if _repo:
        DATA_JSON = _repo / "kallax-experts" / "docs" / "experts" / "data.json"

def load_experts():
    """Load experts from data.json"""
    if not DATA_JSON.exists():
        print(f"ERROR: {DATA_JSON} not found", file=sys.stderr)
        print("Hint: Run 'python3 tools/build-experts.py' to generate it", file=sys.stderr)
        sys.exit(1)
    with open(DATA_JSON) as f:
        return json.load(f)

def tokenize_query(query):
    """Tokenize query into list of tokens"""
    tokens = set()

    # English words (3+ chars)
    english = re.findall(r'[a-zA-Z][a-zA-Z0-9]{2,}', query)
    tokens.update(w.lower() for w in english)

    # Chinese n-grams (2, 3, 4 char sliding windows)
    chinese_seqs = re.findall(r'[一-鿿]+', query)
    for seq in chinese_seqs:
        for size in (2, 3, 4):
            for i in range(len(seq) - size + 1):
                tokens.add(seq[i:i+size])

    return list(tokens)

def score_expert_keyword(expert, query_tokens):
    """Score expert by keyword matching"""
    total = 0.0
    reasons = []

    triggers_zh = expert.get('triggers_zh', '')
    triggers_en = expert.get('triggers_en', '')
    name = expert.get('name', '')
    role_id = expert.get('role_id', '')
    use_when_zh = expert.get('use_when_zh', [])
    use_when_en = expert.get('use_when_en', [])

    matched_tokens = set()

    # Trigger scoring (100 pts each)
    for tok in query_tokens:
        tok_lower = tok.lower()
        for field_val in [triggers_zh, triggers_en, name, role_id]:
            if field_val and tok_lower in field_val.lower() and tok not in matched_tokens:
                total += WEIGHT_TRIGGER
                matched_tokens.add(tok)
                reasons.append(f"trigger:{tok}×1")
                break

    # use_when scoring (10/5/0.5 pts)
    for phrase in use_when_zh + use_when_en:
        phrase_lower = phrase.lower()
        phrase_score = 0
        hit_type = ''

        for tok in query_tokens:
            tok_lower = tok.lower()
            if tok_lower in phrase_lower:
                phrase_score = WEIGHT_USE_WHEN
                hit_type = 'use_when'
                break

        if phrase_score == 0:
            for tok in query_tokens:
                tok_lower = tok.lower()
                if tok_lower in phrase_lower:
                    phrase_score = WEIGHT_SUBSTRING
                    hit_type = 'substring'
                    break

        if phrase_score == 0 and len(phrase) <= 6:
            for tok in query_tokens:
                if tok.startswith(phrase) or tok.endswith(phrase):
                    phrase_score = WEIGHT_PREFIX
                    hit_type = 'prefix'
                    break

        if phrase_score > 0:
            total += phrase_score
            reasons.append(f"{hit_type}:{phrase}×1")

    return total, ','.join(reasons) if reasons else ''

def compute_embeddings(experts, query):
    """Compute cosine similarity between query and expert descriptions"""
    if not EMBEDDING_AVAILABLE:
        return {}

    model = SentenceTransformer('all-MiniLM-L6-v2')

    expert_texts = []
    expert_ids = []
    for exp in experts:
        parts = [
            exp.get('name', ''),
            exp.get('name_en', ''),
            exp.get('vibe', ''),
            exp.get('triggers_zh', ''),
            exp.get('triggers_en', ''),
            ' '.join(exp.get('use_when_zh', [])),
            ' '.join(exp.get('use_when_en', [])),
            ' '.join(exp.get('domains', [])),
        ]
        text = ' '.join(p for p in parts if p)
        expert_texts.append(text)
        expert_ids.append(exp['role_id'])

    query_emb = model.encode([query], normalize_embeddings=True)
    expert_embs = model.encode(expert_texts, normalize_embeddings=True)

    similarities = np.dot(expert_embs, query_emb.T).flatten()

    return dict(zip(expert_ids, similarities))

def call_claude_api(query, experts):
    """Call Claude API for semantic expert matching"""
    api_key = os.environ.get('ANTHROPIC_API_KEY') or os.environ.get('CLAUDE_API_KEY')
    if not api_key:
        return None

    # Build expert descriptions
    expert_list = []
    for i, exp in enumerate(experts):
        parts = [
            f"#{i+1} {exp.get('name', '')} ({exp.get('role_id', '')})",
            f"   vibe: {exp.get('vibe', '')}",
            f"   use_when_zh: {', '.join(exp.get('use_when_zh', []))}",
            f"   use_when_en: {', '.join(exp.get('use_when_en', []))}",
            f"   domains: {', '.join(exp.get('domains', []))}",
        ]
        expert_list.append('\n'.join(parts))

    prompt = f"""用户问题: {query}

从以下 experts 中选出最合适的（可多选，最多 3 个），按匹配度排序。
只返回 JSON 格式：{{"matches": [{"role_id": "...", "reason": "..."}, ...]}}

Experts:
{chr(10).join(expert_list)}"""

    try:
        req = Request(
            'https://api.anthropic.com/v1/messages',
            data=json.dumps({
                'model': 'claude-opus-4-7',
                'max_tokens': 500,
                'messages': [{'role': 'user', 'content': prompt}]
            }).encode(),
            headers={
                'x-api-key': api_key,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
            }
        )
        with urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read())
            return result['content'][0]['text']
    except (URLError, HTTPError, KeyError, json.JSONDecodeError) as e:
        print(f"WARNING: LLM API call failed: {e}", file=sys.stderr)
        return None

def hybrid_score(keyword_score, embed_score):
    """Combine keyword and embedding scores"""
    return keyword_score * KEYWORD_WEIGHT + embed_score * EMBEDDING_SCALE * EMBEDDING_WEIGHT

def output_human(results, query, pool, use_embedding):
    """Human-readable output"""
    pool_sizes = {'local': 15, 'all': 25, 'extended': 350}
    pool_size = pool_sizes.get(pool, 15)

    print("=" * 60)
    print(f"  Query: \"{query}\"  |  Pool: {pool} ({pool_size} experts)")
    mode = f"hybrid (keyword {KEYWORD_WEIGHT} + embedding {EMBEDDING_WEIGHT})" if use_embedding else "keyword only"
    print(f"  Mode: {mode}")
    print("=" * 60)

    if not results:
        print("(No experts matched your query. Try different keywords.)")
        print("=" * 60)
        return

    for rank, (score, role_id, reason, k_score, e_score) in enumerate(results, 1):
        emoji = next((e['emoji'] for e in experts if e['role_id'] == role_id), '❓')
        name = next((e['name'] for e in experts if e['role_id'] == role_id), role_id)

        score_str = f"{score:.2f}" if score != int(score) else f"{score:.0f}"
        detail = f" [kwd={k_score:.0f}, emb={e_score:.1f}]" if use_embedding else ""

        print(f"#{rank}  {emoji}  {role_id}          Score:{score_str}{detail}")
        print(f"    {reason[:80]}")

    print("=" * 60)
    print(f"SUMMARY: best={results[0][1] if results else 'none'} count={len(results)}")

def output_json(results, query, pool, use_embedding):
    """JSON output for LLM agents"""
    output = {
        'query': query,
        'pool': pool,
        'mode': 'hybrid' if use_embedding else 'keyword',
        'results': [],
        'best_match': results[0][1] if results else None,
        'total_matched': len(results)
    }

    for rank, (score, role_id, reason, k_score, e_score) in enumerate(results, 1):
        emoji = next((e['emoji'] for e in experts if e['role_id'] == role_id), '❓')
        name = next((e['name'] for e in experts if e['role_id'] == role_id), role_id)

        entry = {
            'rank': rank,
            'role_id': role_id,
            'name': name,
            'emoji': emoji,
            'score': round(score, 2),
            'hit_reason': reason,
            'bridge': f'/kallax-expert {role_id}'
        }
        if use_embedding:
            entry['keyword_score'] = round(k_score, 2)
            entry['embedding_score'] = round(e_score, 2)

        output['results'].append(entry)

    print(json.dumps(output, ensure_ascii=False, indent=2))

# Parse arguments
parser = argparse.ArgumentParser(description='Expert resolver')
parser.add_argument('query', nargs='?', default='')
parser.add_argument('--pool', default='local')
parser.add_argument('--json', action='store_true')
parser.add_argument('--top', type=int, default=0)
parser.add_argument('--embedding', action='store_true')
parser.add_argument('--llm', action='store_true')
args = parser.parse_args()

if not args.query:
    print("ERROR: Query is required", file=sys.stderr)
    sys.exit(1)

# Load experts
experts = load_experts()

# Tokenize
tokens = tokenize_query(args.query)

# Keyword scoring
scored = []
for exp in experts:
    k_score, reason = score_expert_keyword(exp, tokens)
    scored.append((k_score, exp['role_id'], reason))

# LLM mode: try API first, fallback to skill-based session LLM
if args.llm:
    llm_result = call_claude_api(args.query, experts)
    if llm_result:
        try:
            # Parse JSON from LLM response
            import re as re_module
            json_match = re_module.search(r'\{[\s\S]*\}', llm_result)
            if json_match:
                llm_data = json.loads(json_match.group())
                # Build results from LLM output
                role_id_to_exp = {exp['role_id']: exp for exp in experts}
                results = []
                for i, m in enumerate(llm_data.get('matches', [])[:args.top or 3]):
                    rid = m.get('role_id', '')
                    if rid in role_id_to_exp:
                        exp = role_id_to_exp[rid]
                        results.append((100 - i * 10, rid, m.get('reason', ''), 0, 0))
                if results:
                    results.sort(key=lambda x: -x[0])
                else:
                    print("ERROR: LLM returned no valid matches", file=sys.stderr)
                    sys.exit(2)
            else:
                raise ValueError("No JSON in LLM response")
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            print(f"WARNING: LLM response parse failed: {e}", file=sys.stderr)
            print("FALLBACK_TO_SESSION_LLM", file=sys.stderr)
            sys.exit(2)
    else:
        print("FALLBACK_TO_SESSION_LLM", file=sys.stderr)
        sys.exit(2)

# Embedding scoring
embed_scores = {}
if args.embedding and EMBEDDING_AVAILABLE:
    embed_scores = compute_embeddings(experts, args.query)
elif args.embedding and not EMBEDDING_AVAILABLE:
    print("WARNING: --embedding requested but sentence-transformers not installed", file=sys.stderr)
    print("Installing: pip install sentence-transformers", file=sys.stderr)

# Hybrid scoring
if embed_scores:
    results = []
    for k_score, role_id, reason in scored:
        e_score = embed_scores.get(role_id, 0)
        h_score = hybrid_score(k_score, e_score)
        if h_score > 0:
            results.append((h_score, role_id, reason, k_score, e_score))
else:
    results = [(k, r, rea, k, 0) for k, r, rea in scored if k > 0]

# Sort by hybrid score descending
results.sort(key=lambda x: -x[0])

# Limit to top N if specified
if args.top > 0:
    results = results[:args.top]

# Output
if args.json:
    output_json(results, args.query, args.pool, bool(embed_scores))
else:
    output_human(results, args.query, args.pool, bool(embed_scores))
