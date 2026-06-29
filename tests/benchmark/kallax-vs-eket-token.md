# Token Benchmark: KALLAX v3.0.0 vs eket v2.9.2

> **Test**: Real `wc -c` measurement, no estimation.
> **Date**: 2026-06-29
> **Worktree**: `/Users/steven.chen/working/sourcecode/research/v31-t3-token`
> **Branch**: `feature/v31-t3-token` (5eb1b6a, v3.0.0 base)
> **Author sub-role**: v3.1.0 Track 3 / Performer/tester
> **Approximation**: `1 token ≈ 4 chars` (Anthropic guidance, includes code blocks + markdown overhead).

---

## 1. Raw Measurement (stdout, verbatim)

### 1.1 KALLAX v3.0.0

```
=== KALLAX cold start (always load) ===
61 CLAUDE.md
27 docs/CHEATSHEET.md
Σ 88
3304 CLAUDE.md
1711 docs/CHEATSHEET.md
Σ 5015
=== KALLAX lazy load (按需) ===
143 docs/5-levels.md
181 docs/4-roles.md
Σ 324
4075 docs/5-levels.md
5451 docs/4-roles.md
Σ 9526
=== KALLAX total (all loaded) ===
     412
   14541
=== KALLAX per-session (cold + 1 ticket + 1 lazy doc) ===
    9090
```

### 1.2 eket v2.9.2 (from `~/.claude/skills/eket/`)

```
=== eket cold start files ===
66 SKILL.md
79 META-GUIDELINES.md
66 SKILL-INDEX.md
Σ 211
3293 SKILL.md
1841 META-GUIDELINES.md
2680 SKILL-INDEX.md
Σ 7814
=== eket SKILL-DETAIL (lazy?) ===
189
6619
=== eket total (SKILL + DETAIL + META + INDEX) ===
     400
   14433
```

---

## 2. Token Conversion (`bytes / 4`)

| Item | KALLAX bytes | KALLAX tokens | eket bytes | eket tokens |
|------|--------------|---------------|------------|-------------|
| **Cold start (always load)** | 5015 (CLAUDE.md + CHEATSHEET.md) | **1254** | 3293 (SKILL.md only, per skill spec) | **823** |
| Cold start (full skill bundle) | 5015 | 1254 | 7814 (SKILL.md + META + INDEX) | 1954 |
| **Per session (cold + 1 ticket + 1 lazy)** | 9090 (CLAUDE.md + CHEATSHEET.md + 5-levels.md) | **2273** | 9912 (SKILL.md + SKILL-DETAIL.md) | 2478 |
| Total (everything loaded) | 14541 | 3635 | 14433 | 3608 |

---

## 3. Ratio (KALLAX / eket)

| Scenario | KALLAX | eket | Ratio | Verdict |
|----------|--------|------|-------|---------|
| **Pure cold start (load skill description only)** | 1254 | 823 | **1.52x** | KALLAX larger |
| Cold start (full always-loaded bundle) | 1254 | 1954 | **0.64x** | KALLAX smaller |
| **Per session (cold + 1 ticket + 1 lazy doc)** | 2273 | 2478 | **0.92x** | Roughly equal |
| Total everything | 3635 | 3608 | **1.01x** | Roughly equal |

---

## 4. Verifying the v3.0.0 "1.5-2x" Claim

**Finding**: There is **NO explicit `1.5-2x` claim** in any current v3.0.0 document file. Grep evidence:

```
$ grep -rniE "1\.5|1\.5x|1\.5-2|token.*benefit|token.*saving" CLAUDE.md README.md docs/CHEATSHEET.md docs/5-levels.md docs/4-roles.md
(no match)
```

The only token-related claim in v3.0.0 docs is:

- **README.md:235**: "CLAUDE.md (3.3KB cold start / 16.4x reduction)" — compares to PRIOR 54KB CLAUDE.md, not to eket.
- **README.md:284**: "CLAUDE.md size | 54KB | 3.3KB | 16.4x reduction" — same.
- **README.md:55**: "CLAUDE.md 3.3KB + 5KB cold start | CLAUDE.md 精简 | 一致" — comparison is "consistent" not "1.5-2x smaller".

**Honest mark** (跟"诚实修正" 战略 联合): The Track 3 task brief mentions a "1.5-2x claim" but it is NOT in the v3.0.0 doc set. The actual measured relationship is:

| Metric | Result |
|--------|--------|
| KALLAX cold start vs eket SKILL.md only | **1.52x LARGER** (1254 vs 823 tokens) |
| KALLAX full bundle vs eket full bundle | **0.64x (smaller)** (1254 vs 1954) |
| KALLAX per-session vs eket per-session | **0.92x (rough parity)** (2273 vs 2478) |

If a future doc wants to claim "1.5-2x smaller", it must reference the **full bundle comparison** (cold start bundle for KALLAX = 5015B, full eket bundle = 7814B → **0.64x**, **NOT 1.5-2x**). The claim as briefed in Track 3 does not pass empirical verification.

---

## 5. Architectural Insight (raw observation)

The 1.52x cold-start disadvantage KALLAX carries (CLAUDE.md + CHEATSHEET always loaded together, vs eket's SKILL.md alone) is **paid back** when:

1. **Lazy-load kicks in** (5-levels.md / 4-roles.md only loaded on demand).
2. **Full session workflow** invokes 1+ ticket contexts.

eket has no lazy-load distinction — `SKILL.md` references `SKILL-DETAIL.md` as a sibling but the SKILL.md body itself is only 3293B. Adding `SKILL-DETAIL.md` (6619B) for "lazy detail" balloons to 9912B, matching KALLAX per-session 9090B.

**Conclusion**: KALLAX v3.0.0 and eket v2.9.2 deliver **parity on per-session token cost** (0.92x) once a real workflow starts. KALLAX is ~50% larger at true cold start (SKILL.md only) but this is the cost of denser rule coverage (21 Rules vs 9 Hard Rules) in an explicitly-named "always load" file.

---

## 6. Reproducibility

```bash
cd /Users/steven.chen/working/sourcecode/research/v31-t3-token

# KALLAX
wc -c CLAUDE.md docs/CHEATSHEET.md docs/5-levels.md docs/4-roles.md

# eket
wc -c ~/.claude/skills/eket/SKILL.md ~/.claude/skills/eket/SKILL-DETAIL.md \
       ~/.claude/skills/eket/META-GUIDELINES.md ~/.claude/skills/eket/SKILL-INDEX.md
```

---

## 7. Findings & Action Items

1. **No 1.5-2x claim found in v3.0.0 docs** — Track 3 brief assumed a claim that does not exist. Future briefs should `grep -ni "<claim>"` before assigning verification tasks.
2. **KALLAX cold start IS larger** than eket's SKILL.md description (1.52x). This is acceptable for the v3.1.0 packaging profile (rules + cheatsheet must always be loaded) but should be acknowledged in any "minimal" claim.
3. **Per-session parity** (0.92x) suggests v3.0.0 lazy-load design (CHEATSHEET vs 5-levels.md / 4-roles.md split) is working as designed.
4. **Action**: If a "1.5-2x smaller" claim is desired, it must be hedged as "KALLAX per-session is 0.92x of eket per-session (roughly equal), not 1.5-2x smaller". Recommend removing the implicit token-comparison framing from Track 3 / future marketing.
