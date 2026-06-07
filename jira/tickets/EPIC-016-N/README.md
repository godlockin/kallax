# EPIC-016-N: INBOX card 标注「per-instance」 — 文档化避免误用

## 需求

session_start.sh 的 ASCII card 当前 `INBOX ▸ [N] .`，用户误以为是项目全局 inbox。实际是当前 instance 的个人队列（`inbox/<instance_id>/`）。加标注避免误用。

## 接受标准 (AC)

详见 `ticket.json`。3 条 AC：
1. ASCII card 把 `INBOX` 改为 `INBOX (you)` 或加 footnote
2. kallax-init.md 文档化 inbox 路径：`inbox/<instance_id>/` 个人 vs `inbox/<role>/` 全局
3. README/quickstart 加一行示例说明两个 inbox 区别

## 技术要点

- 一行 sed 改 ASCII card
- 文档：加 5 行解释 personal vs global inbox
- 视觉：footnote 形式如 `INBOX ▸ [0] .¹` ¹=per-instance

## 测试计划

- [ ] ASCII card 显示 `INBOX (you)`
- [ ] skill 文档含 personal vs global inbox 区别
- [ ] README/quickstart 含示例

## 依赖

无

## 文件范围

- `~/.claude/skills/kallax/skills/kallax-init.md` (update)
- `.kallax/hooks/session_start.sh` (update)

## ⚠️ 阻塞说明

file_scope 与 **EPIC-016-R** (session_start.sh) 和 **EPIC-016-J/K/P** (kallax-init.md) 都重叠，**必须等 R 和 J 合并**才能开始。

## 预估工时

0.3 小时

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 05:55 UTC | ready | master_main | 创建 |
| 2026-06-06 15:30 UTC | backlog | master_main | 降级 backlog（等 R/J 释放 file_scope）|
