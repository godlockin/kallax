# EPIC-016-P: per-project 脚本自举 — lean skill 缺脚本时单调用完成 install + run

## 需求

`/kallax 初始化为master` 在 my_projects 触发时：5 tool calls = 4 探索 + 1 bash install+run。理想 ≤ 2 tool calls。Lean skill 缺脚本时不能 1-call 完成。

## 接受标准 (AC)

详见 `ticket.json`。6 条 AC：
1. 识别根因：lean skill 在 per-project 缺脚本时不能 1-call
2. 方案 A：lean skill 1-call + 内含 if ! exist then install else run
3. 方案 B：写 `scripts/install-hooks.sh`，lean skill 检测缺失时调它（1 call）
4. 方案 C：session_start.sh 移回 `~/.claude/skills/kallax/hooks/`
5. **推荐 A**（最小改动）
6. 验证：干净 my_projects 跑 `/kallax 初始化为master`，tool calls = 1

## 技术要点

- 方案 A 核心：lean skill 文档里直接给完整 bash heredoc，自带 install + run
- 备选 B：单独脚本，lean skill 检测后 1-call invoke
- 关键 metric: 验证 `tool calls` 计数（用 benchmark-init.sh 测）

## 测试计划

- [ ] 干净 my_projects 目录克隆
- [ ] 跑 `/kallax 初始化为master`
- [ ] 断言 tool calls ≤ 2

## 依赖

- `EPIC-016-J`（STRICT 模式落地）

## 文件范围

- `~/.claude/skills/kallax/skills/kallax-init.md` (update)
- `~/.claude/skills/kallax/scripts/install-hooks.sh` (new)

## ⚠️ 阻塞说明

file_scope 与 **EPIC-016-J/K/N** (kallax-init.md) 重叠，**必须等 J 合并**才能开始。

## 预估工时

2 小时

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 06:00 UTC | ready | master_main | 创建 |
| 2026-06-06 15:30 UTC | backlog | master_main | 降级 backlog（等 J 合并）|
