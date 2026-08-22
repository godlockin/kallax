# EPIC-283 Snapshot Exemption Scope — Decision (2026-08-22)

> **Decision type**: scope-lock (NOT feature-add).
> **Status**: LOCKED 2026-08-22 by 队伍 K Performer. Frozen until EPIC-283 sprint closed.
> **Author**: master (Performer 队伍 K, B 组红蓝对抗 blocker 闭环)
> **Sign-off**: master + 主公 (待 PR review 时)

## 0. TL;DR

PR #479 (`5c6b6429`) added a snapshot exemption list to `check-claim-evidence.sh` — but
the list could in principle contain ANY path, including `README.md` / `CHANGELOG.md`,
which would silently neuter the L5 boundary defense (EPIC-069-D, v3.8.0 fake-PASS
regression).

This decision **strictly limits** the exemption scope to snapshot expected JSON files
only, with fail-closed enforcement at three layers:

1. **Exemption list itself** — comments explicitly forbid extending to non-snapshot paths.
2. **`check-snapshot-exemption.sh`** — regex `^node/tests/integration/snapshot/expected/[^[:space:]]+\.json$` rejects any out-of-scope entry. Exits 1 with explicit "L5 boundary defense engaged" message.
3. **`check-claim-evidence.sh`** — defense-in-depth: refuses to load any non-snapshot path from the exemption list at startup. Exits 1 immediately.

Layer 2 is the canonical gate. Layer 3 is belt-and-suspenders so an accidental
exemption-list edit cannot bypass the boundary even if layer 2 were temporarily
disabled.

## 1. Background

### 1.1 What #479 did

PR #479 (`chore(EPIC-283): check-claim-evidence snapshot exemption`) added:

- `scripts/verify/.snapshot-exemption-list.txt` — list of paths to skip X/Y PASS numeric check
- `scripts/verify/check-snapshot-exemption.sh` — verifier that listed paths exist
- `scripts/hooks/check-claim-evidence.sh` — consumer that reads the list at hook time

The exemption was defensive — snapshot expected JSON contains real slash command output
(e.g., `"Core Experts (5)"`, `"Skills (16)"`) that could in theory match an evolving regex.

### 1.2 B 组 red-blue blocker

During A/B 2-Group review, B 组 flagged:

> "exemption list 是全局旁路 L5 boundary — 任何 future edit 加 README.md 进 list,
> 5-Level Verify 防线自毁, 等于 v3.8.0 假 PASS 复发."

The exemption mechanism was correct in intent (snapshot JSON needs defensive skips),
but the scope was under-specified. A maintainer adding `README.md` to the list
six months from now would silently disable the decorative-claim check.

### 1.3 Why this matters

`check-claim-evidence.sh` is **immutable #5** (EPIC-069-D, see `.claude/rules/immutable-scripts.md`).
It is the last gate against the v3.8.0 regression where README claimed "25/25 PASS" with
zero test output. Bypassing this gate for any non-snapshot path re-creates the original
failure mode.

## 2. Decision

### 2.1 Strict scope (locked)

The exemption list is **STRICTLY LIMITED** to paths matching:

```
^node/tests/integration/snapshot/expected/[^[:space:]]+\.json$
```

Concrete allowlist (current state, may extend with new snapshot paths but cannot widen the prefix):

- `node/tests/integration/snapshot/expected/kallax-list.json`
- `node/tests/integration/snapshot/expected/kallax-help.json`

### 2.2 Forbidden extensions (frozen)

The list **CANNOT** be extended to:

| Path class | Why forbidden |
|------------|---------------|
| `README.md` / `README*.md` | Primary target of v3.8.0 fake-PASS regression. |
| `CHANGELOG.md` / `docs/**/*.md` | Equivalent risk — versions claim "X/Y" without raw output. |
| `confluence/decisions/*.md` | Decision docs use X/Y format extensively (e.g., "ab_hit_rate=12/100 PASS"). Exempting them defeats the boundary. |
| `CLAUDE.md` / `.claude/rules/*.md` | Governance files. Already exempt by hardcoded `[[ "$file" == CLAUDE.md ]] && continue` in hook. Adding to list is redundant + risky. |
| Any `*.ts` / `*.rs` / `*.sh` outside snapshot | Non-test code should never have decorative claims. |

### 2.3 Three-layer fail-closed enforcement

#### Layer 1: Exemption list header (documentation)

`.snapshot-exemption-list.txt` has an explicit comment block stating:

```
# EPIC-283-scope (L5 boundary defense, 2026-08-22):
# This list is STRICTLY LIMITED to snapshot expected JSON files. check-claim-
# evidence.sh rejects any exemption path that does not match `^node/tests/
# integration/snapshot/expected/.*\.json$`. Cannot be extended to README /
# CHANGELOG / confluence/decisions — that would bypass the L5 boundary
# (v3.8.0 fake-PASS defense, EPIC-069-D).
```

Future maintainer reading the file sees the constraint before editing.

#### Layer 2: `check-snapshot-exemption.sh` (canonical gate)

Two modes:

- **Default (no arg)**: validates the configured exemption list. Any out-of-scope entry
  exits 1 with `REJECTED: N/M path(s) out of strict scope`.
- **Single-arg**: validates one path against the strict regex. Exits 0 if in scope,
  exits 1 if out of scope. This is for follow-up tests.

#### Layer 3: `check-claim-evidence.sh` (defense-in-depth)

At exemption list load time:

```bash
if [[ "$line" =~ ^node/tests/integration/snapshot/expected/[^[:space:]]+\.json$ ]]; then
  SNAPSHOT_EXEMPTIONS+=("$line")
else
  echo "❌ REJECT exemption path out of strict scope (L5 boundary 自毁防御): $line" >&2
  exit 1
fi
```

If layer 2 is bypassed (e.g., `.snapshot-exemption-list.txt` manually edited without
re-running layer 2 verify), layer 3 still rejects at hook startup.

### 2.4 Why three layers, not one

| Scenario | Layer 2 catches? | Layer 3 catches? |
|----------|------------------|------------------|
| Maintainer adds `README.md` to exemption list | YES (verify rejects, exit 1) | YES (hook rejects at load) |
| Layer 2 script temporarily disabled / removed | NO | YES (hook rejects at load) |
| Maintainer edits exemption list, runs layer 2 only | YES | — (no need) |
| Hook called via `--no-verify` or whitelist bypass | NO | NO (out of design scope) |

Layer 3 is intentional redundancy — when the L5 boundary itself is the asset, a single
point of enforcement is not enough.

## 3. What this decision does NOT change

- The original #479 mechanism (read exemption list, skip X/Y check for listed files) is unchanged.
- The defensive rationale (snapshot expected JSON may contain numbers) is unchanged.
- The existing 2 paths are unchanged.
- No code outside the three locked files is modified.

## 4. Acceptance criteria (Rule 34 reproduction)

| Field | Value |
|-------|-------|
| `reproduction_command` | `bash scripts/verify/check-snapshot-exemption.sh README.md` |
| `reproduction_exit_code` | 1 |
| `reproduction_raw_output` | `REJECT: path 不在 snapshot/expected/* 范围, L5 boundary 防线自毁防御` |

Verified during development (2026-08-22):
- Default mode (valid list): `OK: 2 exempted snapshot file(s) all exist + within strict scope` exit 0
- Single-arg valid snapshot path: `OK: path in scope: node/tests/integration/snapshot/expected/kallax-list.json` exit 0
- Single-arg `README.md`: `REJECT` exit 1
- Single-arg `CHANGELOG.md`: `REJECT` exit 1
- Polluted list (replace contents with `README.md`) + layer 2: `REJECTED: 1/1 path(s) out of strict scope` exit 1
- Polluted list + layer 3 hook: `❌ REJECT exemption path out of strict scope` exit 1

## 5. Rollback

If this decision proves wrong (e.g., legitimate need arises for non-snapshot exemption):

1. Open new EPIC (≥ EPIC-284) with proper narrative — **never** widen the list silently.
2. Master + 主公拍板 required (immutable #5 protection).
3. Update this decision doc with amendment section.
4. New mechanism must replace the exemption list entirely (e.g., per-file metadata), not
   extend it (EPIC-283 alternative was Path B, rejected as too heavy).

## 6. Reference

- **EPIC-069-D** — `check-claim-evidence.sh` origin (v3.8.0 → v3.8.1 fix)
- **PR #479** — original exemption mechanism (merged 2026-08-22)
- **EPIC-283** — snapshot harness (DSH Path B)
- **`.claude/rules/immutable-scripts.md`** — canonical immutable scripts list and gate policy
- **`jira/tickets/.jargon-blacklist.json`** — jargon-grep avoidance for new content
- **CLAUDE.md §2** — 5-Level Verify definition; L5 boundary is `check-claim-evidence.sh`
