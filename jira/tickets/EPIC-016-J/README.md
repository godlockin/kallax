# EPIC-016-J: Lean skill 升 STRICT — 把探索本能从根上掐死

## 状态

⚠️ **ready_for_review** — 上一个 Performer 已完成实施，等待 master 审核 PR

## 需求

把 `~/.claude/skills/kallax/skills/kallax-init.md` 从 v3「HARD STOPS」升级到 v4「EXACT SEQUENCE」，从根本上约束 Claude 的探索本能。

## 接受标准 (AC)

5 条 AC 详见 `ticket.json`。

## 已交付（performer claim）

- **PR**: https://github.com/godlockin/kallax/pull/1
- **Commit**: `e5b7641`
- **Branch**: `feature/EPIC-016-J-lean-strict`
- **Worktree**: `.kallax/worktrees/performer-EPIC-016-J`
- **v4 摘要**: ONE BASH CALL → EXACT SEQUENCE 3-step，Step 2 是 bash literal verbatim

## 待 master 审核项

- [ ] AC1 HARD STOPS 区
- [ ] AC2 EXACT SEQUENCE 3-step + Step 2 bash literal
- [ ] AC3 WHY THIS IS STRICT 区
- [ ] AC4 IF YOU NEED TOOLS 章节
- [ ] AC5 benchmark ≤ 2 calls（**需用户跑一次 `/kallax` 验证**）

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 05:40 UTC | backlog | master_main | 创建 |
| 2026-06-06 15:50 UTC | in_progress | performer_main | claim |
| 2026-06-06 15:53 UTC | ready_for_review | performer_main | 提交 PR #1 |
| 2026-06-06 15:30 UTC | ready_for_review | master_main | 等待 review + 用户验证 |
