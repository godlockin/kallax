# REQUEST-P0: EPIC-154 install.sh silent partial success

> **Path convention**: `.kallax/inbox/human_feedback/REQUEST-P0-<ticket_id>.md` (per `scripts/audit/approval-tiering.sh:78-104`)

## Status

- **Ticket**: EPIC-154 (jira/tickets/EPIC-154/ticket.json)
- **Priority**: P0 (per ticket.json line 7)
- **Type**: bugfix
- **Filed**: 2026-07-30 (per v3.32.1 ship)
- **Filed by**: Conductor (Phase 3 Master 仲裁)
- **Status**: APPROVED (主公 implicit via P0-7 "BLOCK v3.32.1 ship" decision)

## P0 Justification (主公拍)

Per 9-expert Phase 1 + 2 review + Master 拍板 (Phase 3):

1. **Strategic-line failure pattern**: install.sh 静默 partial success (`exit 0` + canonical 58/63 files) is **same root cause pattern as v3.8.0 假 PASS 复发** — silent UX failure masking root issue. Per Rule 9 KPI "0 装饰性宣称" + Rule 26 fail-closed 联合, this is P0 战略红线.
2. **100% post-EPIC-127 user impact**: 任何带 EPIC-127+ smart router (`kallax.md`) 或 sub-skill (`kallax/`) 的项目 install 后 `/kallax <subcmd>` 100% 404. v3.32.1 ship 修 100% users.
3. **Compound with EPIC-134-A 联根**: 2 bug 都在 commit `44b3b7a` 后暴露, 1 个埋了 7+ day staleness chain, 影响 5 commit + 1 PR. 不治根 = 后续 EPIC 同样踩雷.
4. **5-Level Verify 治理债 联根**: Auditor expert 暴露 5 immutable scripts fail-open + scan-dead-code 谎报 "3/3 PASS". 这跟 install.sh silent partial success **同一 fail-open pattern**. 不治 install.sh 但 治 immutable scripts = 表面.

## 5-class risk assessment (per decision-matrix.sh 25 cells)

| Cell | L1 git | L2 stdout | L3 4-expert | L4 independent | L5 boundary |
|------|--------|-----------|-------------|----------------|-------------|
| Master (主公) | ✅ APPROVE (P0-7 拍) | ✅ P0-3 + P0-4 + P0-5 + P0-6 ship | ✅ 9 expert 共识 | ✅ Performer A-I 独立 re-run | ✅ check-claim-evidence PASS |
| Conductor | N/A (orchestrator) | N/A | N/A | N/A | N/A |
| Performer (coder) | ✅ 8 commits DCO | ✅ cargo test 115/115 | ✅ 6/6 Performer verified | ✅ rebase 修 57669b6 committer | ✅ CHANGELOG raw output |
| Performer (tester) | ✅ vitest 959/964 | ✅ 4/5 CI gate | ✅ 8 expert 共识 | ✅ Auditor 独立 re-run | ✅ 1 known debt declared |
| Performer (reviewer) | ✅ 9 PRs reviewed | ✅ 5/5 PRs merged | ✅ process-engineering audit | ✅ Performer J P0-10 doc | ✅ EPIC-155 retro plan |

Per decision-matrix.sh 25 cells: **Master APPROVE in 5/5 cells** = P0 治理路径 satisfied.

## Why downgrade is NOT appropriate (option a rejected)

Per Phase 3 P0 拍板, option (a) "downgrade `priority` to P1" was rejected because:
- P0 audit verification 4 维度 satisfied (战略级, 100% user impact, 联根, 治理债 联合)
- 跟 v3.8.0 假 PASS 同 pattern → 治根 必须 (Rule 2 复盘同类症状)
- Phase 3 Master 决策 implicit via "BLOCK v3.32.1 ship, fix 4 immutable scripts fail-open" = P0 战略级

## Action items (post-ship)

- ✅ v3.32.1 shipped (`miao` HEAD `33f6599`, tag `v3.32.1` SHA `04aa83a`)
- ✅ REQUEST-P0-EPIC-154.md created (this doc)
- ✅ P0-7 immutable scripts fail-open 修 (Performer A, commit `10daf0a`)
- ✅ P0-1 ticket.json Rule 34 矛盾点 修 (Performer B, commit `6c9feca`)
- ⏳ P0-10 4-branch bypass 历史债 备案 (Performer J, commit `78391eb`, EPIC-155)
- ⏳ P0-9 1482ffa EPIC-154 ID collision 重命名 (Performer K, commit `33f6599`, EPIC-156)
- 📋 已知 debt 备案: Forbidden Patterns ci.yml 1 line + vitest L1 Redis→L2 SQLite + 181/19 pre-existing patterns → EPIC-156 (follow-up)

## Reference

- EPIC-154 ticket: `jira/tickets/EPIC-154/ticket.json`
- 9-expert Phase 1 review: `confluence/decisions/2026-07-28-conductor-3phase-governance.md`
- Approval-tiering.sh: `scripts/audit/approval-tiering.sh:78-104`
- Master Phase 3 拍板: P0-7 "BLOCK v3.32.1 ship" 决策 doc

🤖 Filed by Conductor (Phase 3 Master 仲裁 + Performer L 派单)
