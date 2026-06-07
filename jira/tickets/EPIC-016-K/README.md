# EPIC-016-K: ASCII card 验证 — 加 stdout hash 比对,禁止幻觉渲染

## 需求

Claude Code 在 init 流程中可能"幻觉"渲染 ASCII card（不基于脚本输出，凭模型记忆拼凑）。加 stdout hash 比对机制防止。

## 接受标准 (AC)

详见 `ticket.json`。4 条 AC：
1. skill 增加「REPORT ONLY SCRIPT OUTPUT」条款
2. `benchmark-init.sh` 输出 session_start.sh stdout 的 sha256 hash
3. 用户在 init 后粘贴 ASCII card 人工对比 hash（一次性 SOP）
4. 未来自动化：claude-mem 记录「agent output hash != script output hash = deviation」

## 技术要点

- 关键防御：**verbatim 复制脚本 stdout**，禁止任何"美化"
- hash 用 `sha256sum`，输出格式 `expected_sha256: <hash>`
- SOP 写进 skill 文档顶部「HARD STOPS」区
- 未来自动化用 claude-mem observation 记录 deviation

## 测试计划

- [ ] benchmark-init.sh 跑 5 次，hash 稳定（同一脚本版本 hash 应一致）
- [ ] skill 文档「REPORT ONLY SCRIPT OUTPUT」措辞明确
- [ ] SOP 描述清晰：用户拿到 card 后对比 hash 的步骤

## 依赖

- `EPIC-016-J`（STRICT mode 落地）— J 在 ready_for_review，需等合并后开始

## 文件范围

- `~/.claude/skills/kallax/skills/kallax-init.md` (update)
- `scripts/benchmark-init.sh` (update)

## 预估工时

0.5 小时

## ⚠️ 阻塞说明

file_scope 与 EPIC-016-J 重叠（都改 kallax-init.md），**必须等 J 合并**才能开始，避免 worktree 冲突。

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 05:40 UTC | backlog | master_main | 创建 |
| 2026-06-06 15:30 UTC | ready | master_main | 提升 P1 ready（但需等 J 合并）|
