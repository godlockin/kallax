# KALLAX ticket.json Schema Evolution Decisions (P1-1)

> **Filed**: 2026-07-30 (post-v3.32.1 ship, Performer N)
> **Authority**: Phase 3 Master 拍板 (P1-1)

## Decision 1: `5_level_verify_status` schema → **BLESS as new standard**

**Rationale**:
- 跟 v3.32.1 5-Level Verify 硬化 (EPIC-069-D) 1:1 路径 — `L1_git` / `L2_stdout` / `L3_4_expert` / `L4_independent` / `L5_boundary` 是 5-Level Verify 永久 5 levels (CLAUDE.md:27-36 跟 EPIC-069-D 5-Level Verify 新规)
- Per-ticket 记录 "L3 PENDING" / "L5 N/A" 跟 Master 拍板一致 (P0-1 Performer B 修 EPIC-154 已 0 改这个 schema)
- Flattening 到单一 string 字段会 loss 5 cell 信息 (L1 git vs L5 boundary 是不同 type 验证)
- 跟 v3.32.0 doc-only release 的 "5-Level Verify 5 个 levels = L1-L5" 1:1

**Action**:
- ✅ Accept 现有 5_level_verify_status schema (EPIC-154 v3.32.1 已是 v1)
- 📋 Follow-up: 在 `docs/reference/5-level-verify-harden.md` 加 1 段 `5_level_verify_status schema v1` 文档 (template)
- 📋 Follow-up EPIC-157: 给其他 6 个 EPIC tickets (EPIC-149/150/151/152/153) 补 5_level_verify_status (backward compatibility)

**跟 v3.32.0 CLAUDE.md 1:1**: "L2: PASS (cargo test 115/115 + vitest 959/964, validated in prior PRs)" + "L5: PASS (CHANGELOG added with raw output citations)" 模式 1:1.

## Decision 2: `premise_check` + `after_fix_evidence` + `bug_locations` → **Add to Rule 34 spec**

**Rationale**:
- `premise_check` (EPIC-153 + EPIC-154): 9-expert consensus "this is useful, should be standard"
- `after_fix_evidence` (EPIC-154): Rule 34 process rule #2 (Performer 独立复现 first) 跟 after_fix_evidence 1:1 (fix 落地 proof)
- `bug_locations` + `fix_locations` (EPIC-154): machine-parseable structured data, 适合 lint/script consumption

**Action**:
- 📋 Follow-up EPIC-158: 加进 `docs/reference/5-level-verify-harden.md` 跟 `docs/process/fact-forcing.md` 1:1
- 📋 Follow-up EPIC-158: 更新 CLAUDE.md Rule 34 section 加 3 field (跟 v3.32.0 lazy load pattern 一致: link 到 docs/reference)
- 📋 Schema 不强 backward compat — future tickets 用新 schema, old tickets 保留原状 (Performer B P0-1 已 0 改 schema, 0 breaking)

## Decision 3: state.json path convention → **No change needed**

**Per CLAUDE.md "state.json 路径约定 (EPIC-068-A)"**:
- 主写: `.kallax/state/state.json` (authz 9 脚本读)
- 备份: `.kallax/instances/<id>/state.json` (历史/audit 兼容)
- 现状: v3.32.1 ship 跟 EPIC-068-A 1:1 兼容, 0 breaking change
- 已知: Performer L P0-8 创 `.kallax/inbox/human_feedback/REQUEST-P0-EPIC-154.md` 路径, 跟 `.kallax/state/` 是 sibling 关系 0 冲突

**Action**:
- ✅ No change
- 📋 Follow-up: 验证 P0-8 创 doc 后 authz 9 脚本仍读 `.kallax/state/state.json` (应该 PASS — 跟 inbox/ 独立)
- 📋 Follow-up: 未来 REQUEST-P0-*.md 创在 `.kallax/inbox/human_feedback/` 路径 (已 established P0-8)

## Summary (跟 v3.32.0 + v3.32.1 CHANGELOG 1:1)

| Decision | Status | Follow-up EPIC |
|----------|--------|---------------|
| 5_level_verify_status | ✅ BLESS (current schema is v1) | EPIC-157 (backward compat) |
| premise_check + after_fix_evidence + bug_locations | 📋 Add to Rule 34 spec | EPIC-158 (CLAUDE.md + docs update) |
| state.json path | ✅ No change (EPIC-068-A 1:1) | None |

## Reference

- EPIC-154/ticket.json (Performer B P0-1, commit `6c9feca`): schema exemplar
- EPIC-156/ticket.json (Performer K P0-9, commit `33f6599`): retrospective ID collision doc
- Performer B P0-1: line 78-90 N/A reframe (4 L5 PENDING → N/A)
- Compliance expert Phase 1 finding: ticket.json schema 矛盾点
- CLAUDE.md "state.json 路径约定" (跟 v3.32.0 docs/reference/state-json-path-conventions.md 1:1)

🤖 Filed by Conductor (Phase 3 Master 仲裁 + Performer N 派单)
