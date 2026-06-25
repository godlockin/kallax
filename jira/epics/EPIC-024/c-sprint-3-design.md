# EPIC-024-C Sprint 3 L3 Generation Design

> **L3**: Auto-generate 50+ new expert candidates via LLM

## 1. L3 Generation Objective

**Goal**: Expand expert library from 97 (7 default + 90 extended) to 200+ via LLM-driven generation.

| Metric | Current | Target | Delta |
|--------|---------|--------|-------|
| Expert count | 97 | 200+ | +103 |
| M1 Recall | TBD | ≥85.0% | TBD |
| M6 Coverage | TBD | ≥80.0% | TBD |
| M7 Precision | TBD | ≥90.0% | TBD |

## 2. L3 Inputs

### 2a. Existing Expert Inventory

**7 Default Experts** (`.kallax/experts/default/*.md`):
| ID | Name | Domain |
|----|------|--------|
| kallax.architect.001 | 🏗️ 架构 | architecture |
| kallax.backend.001 | 💻 后端 | backend |
| kallax.frontend.001 | 🎨 前端 | frontend |
| kallax.product.001 | 📋 产品 | product |
| kallax.pm.001 | 🧭 PM | pm |
| kallax.security.001 | 🛡️ 安全 | security |
| kallax.ux.001 | 🖌️ UX |ux |

**90 Extended Experts** (worktree-EPIC-024-B extended/INDEX.md):
- Domains: tech (dominant), security, business, consulting, hr, knowledge, marketing, ops, pr, training, design, ai, data

### 2b. Domain Gap Analysis

**Current domain distribution** (inferred from extended INDEX):
- tech: ~40 (over-represented)
- security: ~8
- business: ~5
- consulting: ~3
- hr: ~3
- knowledge: ~2
- marketing: ~2
- ops: ~2
- pr: ~1
- training: ~1
- design: ~1
- ai: ~1
- data: ~1

**Top-5 Missing/Underrepresented Domains**:
1. **legal** — 合同法务/知识产权/监管合规 (0 experts)
2. **finance** — 财务分析/预算管理/投资评估 (0 experts)
3. **data** — 数据分析/BI报表/数据挖掘 (1 expert, gap)
4. **product** — 产品增长/用户研究/数据分析 (1 expert, gap)
5. **marketing** — 数字营销/增长黑客/内容运营 (2 experts, gap)

## 3. L3 Output Schema

Each new expert candidate follows this YAML frontmatter:

```yaml
---
id: kallax.extended.XXX
name_cn: <Chinese name,2-6 chars>
role: <job title>
emoji: <single emoji>
domain: <legal|finance|data|product|marketing|...>
tier: extended
description: <1-2 sentence value proposition>
trigger: <24+ pipe-separated keywords, no verbatim test cases>
---
```

## 4. L3 Process

### Phase 1: Gap Analysis (this task)
1. Parse all 97 existing experts
2. Count domain distribution
3. Identify top-5 gaps
4. Output: `TOP5_GAPS.md`

### Phase 2: LLM Generation (1-2 Performer)
1. For each gap domain, prompt LLM to generate 5-10 candidates
2. Validate: schema check + dedup against existing 97
3. Output candidates to `/tmp/l3-candidates-<domain>.md`

### Phase 3: Merge + KPI Verification (Conductor)
1. Merge validated candidates to `.kallax/experts/extended/INDEX.md`
2. Re-build index
3. Run M1/M6/M7 KPI validation
4. If recall<85.0%, iterate Phase 2

## 5. L3 Anti-Fabrication Tools

Run these **before** any LLM call or merge:

| Tool | Check | Pass Criteria |
|------|-------|---------------|
| `check-test-case-isolation.sh` |30 test cases NOT in trigger fields | 0/30 leaked |
| `check-kpi-precision.sh` | KPI numbers are X/Y format | 0 estimate patterns |
| `check-scope-creep.sh` | Files within ticket scope | All files in scope |

## 6. L3 Risks

### Risk 1: LLM Hallucination (HIGH)
- **Symptom**: Expert candidate with fake trigger fields, non-existent role
- **Mitigation**: Schema validation + human review spot-check (10% sample)
- **Detection**: trigger field token count <24 → auto-reject

### Risk 2: Verbatim Test Case Leakage (HIGH)
- **Symptom**: 30 test cases appear verbatim in trigger fields
- **Mitigation**: Run `check-test-case-isolation.sh` before merge
- **Detection**: Any leak → preflight FAIL

### Risk 3: Scope Creep (MEDIUM)
- **Symptom**: LLM generation changes unrelated files (INDEX.md, default experts)
- **Mitigation**: `check-scope-creep.sh` per file
- **Detection**: Any out-of-scope file → preflight FAIL

### Risk 4: Capacity Overrun (MEDIUM)
- **Symptom**: Performer task too large (>3h)
- **Mitigation**: Split into 3 phases, each phase is a separate ticket
- **Capacity**: Phase 1 (this task) ≤2h; Phase 2 (LLM integration) 1-2h; Phase 3 (E2E test) 1h

## 7. L3 Capacity Split

| Phase | Task | Owner | Time Budget |
|-------|------|-------|-------------|
| 1 | Gap analysis + design (THIS TICKET) | EPIC-024-C | ≤2h |
| 2 | LLM integration + 50 candidates | EPIC-024-D | 1-2h |
| 3 | E2E test + 5 KPI validation | EPIC-024-E | 1h |

## 8. Verification (4-Level)

### L1 存在性
```bash
# Design doc exists
test -f jira/epics/EPIC-024/C-SPRINT-3-DESIGN.md && echo "L1 PASS"

# Demo script exists
test -f scripts/expert-generate-l3.py && echo "L1 PASS"
```

### L2 实质性
```bash
# Design doc > 200 bytes
[ $(wc -c < jira/epics/EPIC-024/C-SPRINT-3-DESIGN.md) -gt 200 ] && echo "L2 PASS"

# Demo script > 200 bytes
[ $(wc -c < scripts/expert-generate-l3.py) -gt 200 ] && echo "L2 PASS"
```

### L3 接线正确
```bash
# Python syntax valid
python3 -c "import ast; ast.parse(open('scripts/expert-generate-l3.py').read())" && echo "L3 PASS"
```

### L4 数据流动
```bash
# Demo generates 5 mock experts
python3 scripts/expert-generate-l3.py > /tmp/l3-demo-output.md
grep -c "^id:" /tmp/l3-demo-output.md | [ $(wc -l) -eq 5 ] && echo "L4 PASS"
```

## 9. Deliverables

- [x] `C-SPRINT-3-DESIGN.md` — this document
- [ ] `scripts/expert-generate-l3.py` — mock demo (EPIC-024-C task)
- [ ] `TOP5_GAPS.md` — gap analysis output (integrated in design)
- [ ] 50+ expert candidates (Phase 2)
- [ ] M1/M6/M7 KPI validation (Phase 3)

## 10. Dependencies

- EPIC-024-B (extended INDEX, 90 experts) — must be merged before Phase 2
- EPIC-024-A (default experts fix) — must be stable
- Anti-fab tools (check-test-case-isolation.sh, check-kpi-precision.sh, check-scope-creep.sh) — already exist