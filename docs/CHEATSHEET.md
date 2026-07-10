# KALLAX Cheatsheet (1 页)

## Setup (3 步)
cargo install kallax → kallax init → kallax master:start

## 30 命令速查
**Subagent (3)**: `kallax subagent:register` · `kallax subagent:list` · `kallax subagent:deregister`
**Ticket (8)**: `kallax ticket:create` · `kallax ticket:claim` · `kallax ticket:list` · `kallax ticket:show` · `kallax ticket:complete` · `kallax ticket:assign` · `kallax ticket:transition` · `kallax ticket:history`
**EPIC (4)**: `kallax epic:create` · `kallax epic:add-ticket` · `kallax epic:close` · `kallax epic:status`
**Verify (6)**: `kallax verify l1 TICKET` · `kallax verify l2 TICKET` · `kallax verify l3 TICKET` · `kallax verify l4 TICKET` · `kallax verify l5 TICKET` · `kallax verify all TICKET`
**Audit/Export (5)**: `kallax audit:show` · `kallax audit:verify` · `kallax export:report` · `kallax export:dashboard` · `kallax system:doctor`
**Misc (4)**: `kallax mode:set` · `kallax role:switch` · `kallax worktree:create` · `kallax skill:list`

## 5 Levels 验证 (→ [5-levels.md](5-levels.md))
L1 git log SHA 真变 · L2 test stdout 实质 · L3 4-expert 接线 · L4 independent witness · L5 boundary 边界

## 4 Roles (→ [4-roles.md](4-roles.md))
Conductor (分析/拆解/审核/合并/发布) · Performer (coder/reviewer/tester/docs, 1+4 容量)

## 6 武器 (武器 1-6)
1. **Hash-Chain Audit Log** · 2. **5-Level Fact-Forcing** · 3. **Sub-Role Dispatch** · 4. **EPIC 4 件套** · 5. **Hook Server** · 6. **Dashboard**

## Q18 决策模型
KALLAX 评估+建议, 重大决策者拍 (3 模式: ai-auto / ai-copilot / manual)

## KALLAX vs eket
独立项目, 互取所长 (eket 借 multi-agent 概念, KALLAX 实做 5 levels + 6 武器)
