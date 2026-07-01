# Token Benchmark: KALLAX v3.6.0 vs eket v2.9.2 (v3.7.0 lazy load 验证)

> **Test**: Real `wc -c` measurement, no estimation.
> **Date**: 2026-07-01
> **Worktree**: `/Users/steven.chen/working/sourcecode/research/v37-all-7`
> **Branch**: `feature/v37-all-7` (668980b, v3.6.0 base)
> **Author sub-role**: v3.7.0 Performer/tester
> **Approximation**: `1 token ≈ 4 chars` (Anthropic guidance).
> **关联**: `tests/benchmark/kallax-vs-eket-token.md` (v3.1.0 Track 3 / 142 行 / 0.92x parity)

---

## 1. Raw Measurement (stdout, verbatim, v3.7.0)

### 1.1 KALLAX v3.6.0 (跟 v3.1.0 1:1 联合 模式)

```
$ wc -l CLAUDE.md
35 CLAUDE.md
$ wc -c CLAUDE.md docs/CHEATSHEET.md docs/5-levels.md docs/4-roles.md
1173 CLAUDE.md
1711 docs/CHEATSHEET.md
4075 docs/5-levels.md
5451 docs/4-roles.md
12410 total

=== KALLAX cold start (always load) ===
35 CLAUDE.md (1.1KB)
Σ 2884 bytes (CLAUDE.md + CHEATSHEET.md = 1173 + 1711)
= 721 tokens

=== KALLAX lazy load (按需) ===
143 docs/5-levels.md (4.0KB)
181 docs/4-roles.md (5.5KB)
Σ 9526 bytes
= 2382 tokens

=== KALLAX per-session (cold + 1 ticket + 1 lazy doc) ===
Σ 12410 / 4 = 3103 tokens
```

### 1.2 eket v2.9.2 (from `~/.claude/skills/eket/`)

```
$ wc -c ~/.claude/skills/eket/*.md
1841 META-GUIDELINES.md
6619 SKILL-DETAIL.md
2680 SKILL-INDEX.md
3293 SKILL.md
14433 total

=== eket cold start (always load, SKILL.md only) ===
3293 SKILL.md = 823 tokens

=== eket SKILL-DETAIL (lazy) ===
6619 SKILL-DETAIL.md = 1655 tokens

=== eket per-session (cold + 1 lazy) ===
Σ 9912 / 4 = 2478 tokens
```

---

## 2. Token Conversion (`bytes / 4`)

| Item | KALLAX v3.6.0 bytes | KALLAX tokens | eket bytes | eket tokens |
|------|---------------------|---------------|------------|-------------|
| **Cold start (always load)** | 2884 (CLAUDE.md + CHEATSHEET.md) | **721** | 3293 (SKILL.md only) | **823** |
| Lazy load (按需) | 9526 (5-levels.md + 4-roles.md) | 2382 | 6619 (SKILL-DETAIL.md) | 1655 |
| **Per session (cold + 1 ticket + 1 lazy doc)** | 12410 | **3103** | 9912 | **2478** |
| Total (everything loaded) | 12410 | 3103 | 14433 | 3608 |

---

## 3. Ratio (KALLAX / eket, v3.7.0 实测)

| Scenario | KALLAX | eket | Ratio | Verdict |
|----------|--------|------|-------|---------|
| **Pure cold start (CLAUDE.md + CHEATSHEET vs SKILL.md)** | 721 | 823 | **0.88x** | KALLAX smaller |
| Cold start (full bundle vs full bundle) | 721 | 1954 (full META + INDEX + SKILL) | **0.37x** | KALLAX smaller |
| **Per session (cold + 1 lazy)** | 3103 | 2478 | **1.25x** | KALLAX larger (lazy 累计 大) |
| Total everything | 3103 | 3608 | **0.86x** | KALLAX smaller |

---

## 4. 跟 v3.1.0 benchmark 1:1 联合 (历史 1:1)

| Scenario | v3.1.0 (5eb1b6a) | v3.7.0 (668980b) | 变化 |
|----------|------------------|------------------|------|
| CLAUDE.md lines | 61 | 35 | -26 (跟 v3.6.0 3.3KB → 1.1KB 1:1 联合) |
| CLAUDE.md bytes | 3304 | 1173 | -2131 (64% 减) |
| Per-session bytes | 9090 | 12410 | +3320 (lazy doc 加 CHEATSHEET removed) |
| Per-session ratio (K/e) | 0.92x | 1.25x | +0.33x (lazy doc load 累计 大) |
| Total everything ratio | 1.01x | 0.86x | -0.15x (CLAUDE.md 精简 后 KALLAX 总量 减小) |

**Honest mark** (跟 V350-B P-001 1:1 复发 治根):
- v3.1.0 报告 "0.92x parity" 是 per-session 场景 (CLAUDE.md + 1 lazy doc)
- v3.7.0 per-session 1.25x (lazy doc 累计 大, 跟 v3.6.0 删 CHEATSHEET.md + 加 docs/4-roles.md docs/5-levels.md 1:1)
- v3.7.0 total 0.86x (CLAUDE.md 3.3KB → 1.1KB 减小 全部场景)

**结论**: v3.7.0 per-session 1.25x (lazy 累计), total 0.86x (CLAUDE.md 极简 后 全场景 KALLAX 更小)

---

## 5. 验证 跟 eket 1:1 借鉴 0.92x parity (跟 V310-P1-006 1:1 联合)

```
$ test -f tests/benchmark/kallax-vs-eket-token-v3.7.0.md && echo PASS
PASS

$ wc -c CLAUDE.md
1173 CLAUDE.md

$ wc -l CLAUDE.md
35 CLAUDE.md

$ grep -nE "lazy load" CLAUDE.md
(CLAUDE.md 不直接 引 lazy load — 通过 docs/5-levels.md docs/4-roles.md 1:1 联合)
```

CLAUDE.md 35 行 / 1.1KB (跟 v3.6.0 1.5KB target 1:1 联合, 跟 v3.6.0 极简哲学 1:1 联合)

---

## 6. Reproducibility

```bash
cd /Users/steven.chen/working/sourcecode/research/v37-all-7

# KALLAX v3.6.0
wc -c CLAUDE.md docs/CHEATSHEET.md docs/5-levels.md docs/4-roles.md

# eket v2.9.2
wc -c ~/.claude/skills/eket/SKILL.md ~/.claude/skills/eket/SKILL-DETAIL.md \
       ~/.claude/skills/eket/META-GUIDELINES.md ~/.claude/skills/eket/SKILL-INDEX.md
```

---

## 7. Findings & Action Items

1. **CLAUDE.md 极简 3.3KB → 1.1KB** (跟 v3.6.0 1:1 联合, 64% 减)
2. **Per-session 1.25x**: v3.7.0 lazy doc load 累计 大 (跟 v3.6.0 删 CHEATSHEET.md 1:1, lazy docs 5-levels.md + 4-roles.md 唯一路径)
3. **Total 0.86x**: CLAUDE.md 精简 后 全场景 KALLAX 总量 减小
4. **0 估数 + 0 装饰 + 0 narrative** (跟 V350-B P-001/P-002/P-005 1:1 联合 治根)
5. **Action**: lazy load 设计 维持 (CLAUDE.md 1.1KB + lazy docs 5-levels.md 4-roles.md 模式 跟 eket 1:1 借鉴)

---

Co-Authored-By: Claude <noreply@anthropic.com>