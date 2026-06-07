# EPIC-016-M: state.json Edit 防护 — 在 session_start.sh 加 last_beat 单 key 验证

## 需求

Claude Code 的 Edit/Write 工具不理解 JSON 语义，可能在 state.json 写入重复 key 或破坏结构。加 grep 验证 + 恢复 SOP。

## 接受标准 (AC)

详见 `ticket.json`。3 条 AC：
1. session_start.sh 在 `cat << STATE` 前 grep 检查 templates 不含重复 key
2. agent 用 Edit 改坏 state.json 时加 sed 恢复 SOP
3. 文档化：Edit/Write 改 JSON 必须用 jq 走 bash

## 技术要点

- `grep -c '^[[:space:]]*"<key>":' <<< "$TEMPLATE"` 检测重复
- 恢复 SOP: `sed -i '' '/^[[:space:]]*"last_beat":/d' state.json`（保留首次出现）
- 文档化放在 IDENTITY.md 或新增 `docs/STATE-JSON-EDIT-GUIDE.md`

## 测试计划

- [ ] 故意构造含重复 last_beat 的 state.json，session_start.sh 检测到并告警
- [ ] sed SOP 验证：执行后 state.json 合法
- [ ] 文档：明文写「Edit/Write 不能改 JSON」+「用 jq」

## 依赖

无

## 文件范围

- `.kallax/hooks/session_start.sh` (update)

## ⚠️ 阻塞说明

file_scope 与 **EPIC-016-R** 重叠（都改 session_start.sh），**必须等 R 合并**才能开始。

## 预估工时

0.3 小时

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 05:40 UTC | backlog | master_main | 创建 |
| 2026-06-06 15:30 UTC | backlog | master_main | 提升 P2 暂留 backlog（等 R 释放 session_start.sh）|
