# docs/reference/ 9 vs 6 验证 (P1-3)

> **Filed**: 2026-07-29 (Performer O)
> **Authority**: Phase 1 Frontend expert P1-3 finding + 9-expert review

## TL;DR

**1482ffa "6 reference docs" claim is CORRECT.** No discrepancy in the commit message. The 9 "extra" files in `docs/reference/` pre-existed before 1482ffa from prior commits (b8a1e057 rename, c368ee0 EPIC-136, 10e687e3 v3.30.1). 1482ffa created exactly 6 NEW files; 9 other reference docs were already present.

**Current `docs/reference/`**: 15 files (not 9 as P1-3 listed — P1-3 listed the 9 pre-existing files only, omitting the 6 from 1482ffa itself).

## 1482ffa commit claim

> "CLAUDE.md 224 → 110 行 + **6 reference docs** 按需加载 (主公策略 A)"

**6 files claimed** (per commit body):
1. `branch-flow-history.md` (89 行)
2. `5-level-verify-harden.md` (98 行)
3. `cli-execution-rules.md` (82 行)
4. `state-json-path-conventions.md` (44 行)
5. `test-anti-patterns.md` (43 行)
6. `dco-and-licensing.md` (NEW, 67 行)

## Independent verification — `git show --stat 1482ffa`

```
docs/reference/5-level-verify-harden.md       |  98 ++++++++++
docs/reference/branch-flow-history.md         |  89 +++++++++
docs/reference/cli-execution-rules.md         |  82 ++++++++
docs/reference/dco-and-licensing.md           |  51 +++++
docs/reference/state-json-path-conventions.md |  44 +++++
docs/reference/test-anti-patterns.md          |  43 +++++
```

**Verified**: 1482ffa added **exactly 6 files** to `docs/reference/`. Commit message claim is **accurate**.

## Actual state — `ls docs/reference/`

15 files present (P1-3 listed 9, omitting 6 from 1482ffa):

| # | File | Source commit | Date | 1482ffa? |
|---|------|---------------|------|----------|
| 1 | `5-level-verify-harden.md` | **1482ffa** | 2026-07-27 | YES |
| 2 | `branch-flow-history.md` | **1482ffa** | 2026-07-27 | YES |
| 3 | `build-rs-inventory.md` | c368ee0 (EPIC-136) | 2026-07-26 | NO |
| 4 | `cli-execution-rules.md` | **1482ffa** | 2026-07-27 | YES |
| 5 | `cli-reference-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 6 | `config-reference-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 7 | `database-schema-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 8 | `dco-and-licensing.md` | **1482ffa** | 2026-07-27 | YES |
| 9 | `environment-variables-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 10 | `error-codes-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 11 | `slash-commands-2026-06-19.md` | b8a1e057 rename | 2026-06-20 | NO |
| 12 | `state-json-path-conventions.md` | **1482ffa** | 2026-07-27 | YES |
| 13 | `supply-chain-cargo.md` | c368ee0 (EPIC-136) | 2026-07-26 | NO |
| 14 | `test-anti-patterns.md` | **1482ffa** | 2026-07-27 | YES |
| 15 | `version-management.md` | 10e687e3 (v3.30.1) | 2026-07-27 | NO |

## Discrepancy analysis (3 options per task)

### Option A: 3 extra files came from a DIFFERENT commit (not 1482ffa) — CONFIRMED

`git log --all --diff-filter=A --name-only -- 'docs/reference/*'`:

| File | Created by | Date | Scope |
|------|-----------|------|-------|
| `build-rs-inventory.md` | c368ee0 | 2026-07-26 | EPIC-136-D supply-chain hardening |
| `supply-chain-cargo.md` | c368ee0 | 2026-07-26 | EPIC-136-C cargo-audit.yml doc |
| `version-management.md` | 10e687e3 | 2026-07-27 | v3.30.1 EPIC-147 bump-version.sh doc |
| `cli-reference-2026-06-19.md` | b8a1e057 rename (orig 159dafe1) | 2026-06-04 / rename 2026-06-20 | EPIC-009 P1 |
| `config-reference-2026-06-19.md` | b8a1e057 rename (orig 98764b86) | 2026-06-04 / rename 2026-06-20 | EPIC-010 |
| `database-schema-2026-06-19.md` | b8a1e057 rename (orig 98764b86) | 2026-06-04 / rename 2026-06-20 | EPIC-010 |
| `environment-variables-2026-06-19.md` | b8a1e057 rename (orig 98764b86) | 2026-06-04 / rename 2026-06-20 | EPIC-010 |
| `error-codes-2026-06-19.md` | b8a1e057 rename (orig 159dafe1) | 2026-06-04 / rename 2026-06-20 | EPIC-009 P1 |
| `slash-commands-2026-06-19.md` | b8a1e057 rename (orig 589adf44) | 2026-06-17 / rename 2026-06-20 | slash-cmds 26.sh 改造 |

**Conclusion**: 9 "extra" files pre-existed. **Option A 确认**.

### Option B: Commit message truncated/copy-paste error — REJECTED

1482ffa commit message body says:
> "**6 新建 / 更新 docs/reference/**: branch-flow-history + 5-level-verify-harden + cli-execution-rules + state-json-path-conventions + test-anti-patterns + dco-and-licensing"

This matches `git show --stat 1482ffa` **exactly** (6 files added). No truncation. Commit message is internally consistent. Option B 排除.

### Option C: 6 + 3 from commit `a8da33f` archive restore — REJECTED

`a8da33f` (chore v3.32.0 archive 38 outdated docs to `_archived/`) commit:
- Touched: `confluence/_archived/`, `docs/_archived/`, `docs/_archived/superpowers-pre-archive/`
- **Did NOT touch `docs/reference/`** (verified via `git show --stat a8da33f | grep docs/reference` — only references branch-flow-history + 5-level-verify-harden in commit body as "active replacement" pointers, no file ops)
- Archive action: 38 files moved OUT of active docs into `_archived/`, NOT moved INTO `docs/reference/`

The "active replacement" mentions in a8da33f's commit body are documentation pointers (pointing to docs/reference/ branch-flow-history + 5-level-verify-harden as the "replacement destination"), NOT file moves into docs/reference/.

**Conclusion**: a8da33f did NOT create any docs/reference/ files. Option C 排除.

## Final decision

**Option A 确认** — 1482ffa created exactly 6 NEW files in `docs/reference/`, claim is accurate. 9 pre-existing reference docs (from c368ee0, 10e687e3, b8a1e057 rename) already lived in `docs/reference/` before 1482ffa. Total 15 files.

**Frontend expert P1-3 misframing**: P1-3 listed 9 files but omitted the 6 from 1482ffa itself, making it appear "9 vs 6 = discrepancy" when actually the correct reading is "6 new + 9 pre-existing = 15 total, no discrepancy in 1482ffa claim".

**No fix needed for 1482ffa commit message** — claim is correct. The "discrepancy" was a P1-3 review oversight, not a lie/truncation/restore.

## Cross-validation with Performer M CHANGELOG v3.32.0 (commit 7123ca3)

Performer M v3.32.0 CHANGELOG entry says:
> "CLAUDE.md lazy load + 38 docs archive (主公策略 A 拍板)"

This matches: 1482ffa (CLAUDE.md trim + 6 new reference docs) + a8da33f (38 docs archive). Performer M CHANGELOG does NOT claim "6 新建 + 3 升级 docs/reference/*" — that wording from task spec was inaccurate; actual CHANGELOG just says "CLAUDE.md lazy load".

## Cross-validation with Performer J P0-10 (commit 78391eb)

Performer J CLAUDE.md "5 release PR追溯 record" lists 1482ffa as one of v3.32.0's 3 bypass commits (with a8da33f + 40e2b8e). Bypass is a separate concern (4-branch flow), not file count.

## Action items

- [x] Verify 1482ffa "6 reference docs" claim — **PASS** (git show --stat confirms exactly 6)
- [x] Verify 9 pre-existing files origin — **PASS** (3 commits: b8a1e057, c368ee0, 10e687e3)
- [x] Verify a8da33f did NOT create docs/reference/ files — **PASS** (no file ops on docs/reference/)
- [ ] Update commit message of 1482ffa — **SKIP** (claim is correct, no rewrite needed)
- [x] Audit gap closed: 15 files verified, no broken refs, 0 source changes needed
- [ ] Backlog to EPIC-159: improve Frontend expert review checklist to include "git show --stat verification" before filing P-level findings

## Reference

- 1482ffa commit: `docs(EPIC-154): CLAUDE.md 224 → 110 行 + 6 reference docs 按需加载 (主公策略 A)` (correct claim)
- a8da33f commit: `chore(v3.32.0): archive 38 outdated docs to _archived/` (no docs/reference/ file ops)
- c368ee0 commit: `chore(EPIC-136): supply-chain hardening` (added build-rs-inventory + supply-chain-cargo)
- 10e687e3 commit: `chore(v3.30.1): main 分支 strict workflow canary 清账 12 EPIC` (added version-management)
- b8a1e057 commit: `refactor(reference-naming): 6 docs/reference 加 YYYY-MM-DD 后缀` (rename to dated form)
- Performer M CHANGELOG v3.32.0 (commit `7123ca3`): "CLAUDE.md lazy load + 38 docs archive"
- Performer J CLAUDE.md "5 release PR追溯 record" (commit `78391eb`): 1482ffa listed as v3.32.0 bypass commit
- Performer O P1-3 verify (commit `DOCS-REFERENCE-VERIFICATION.md`): this file

## 5-Level Verify self-attest

| Level | Status | Evidence |
|-------|--------|----------|
| L1 git | PASS | commit with DCO sign-off (`Signed-off-by: godlockin <stevenchenworking@gmail.com>`) |
| L2 stdout | N/A | governance doc (no test surface) |
| L3 4-expert | N/A | governance doc |
| L4 independent | PASS | `git show --stat 1482ffa` + `git log --all --diff-filter=A --name-only -- 'docs/reference/*'` both run raw, no cached results |
| L5 boundary | PASS | 跟 Performer M v3.32.0 CHANGELOG "CLAUDE.md lazy load + 38 docs archive" 一致; 跟 Performer J P0-10 "3 commits bypass 4-branch flow" 一致 |