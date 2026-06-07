# EPIC-016-G: Layer A 平台级提案 — 写 ADR 文档

## 需求

EPIC-016 节省 60-80% token 的 Layer A（平台级）方向写两份 ADR：
- **ADR-016-A**: MCP server 标 lazy（github/playwright 默认不加载，按需启用）
- **ADR-016-B**: skill metadata 改为「按需发现」（只注入 description 摘要，full content 按需 Read）

## 接受标准 (AC)

详见 `ticket.json`。4 条 AC：
1. ADR-016-A 含 context/decision/consequences/alternatives
2. ADR-016-B 含 context/decision/consequences/alternatives
3. 两个 ADR 完整结构
4. `confluence/decisions/index` 同步更新

## 技术要点

- ADR 模板参考现有 `confluence/decisions/` 结构
- 节省估算要有数据支撑（基于 v0-v2 benchmark 实际节省）
- "alternatives considered" 必须真实：列出至少 2 个被否决的备选

## 测试计划

- [ ] 文本长度 ≥ 200 行/ADR
- [ ] index.md 包含两个 ADR 链接
- [ ] markdown 链接全部锚点存在

## 依赖

- `EPIC-016-I`（按需发现机制设计文档）— 已在 done 状态，可开始

## 文件范围

- `confluence/decisions/ADR-016-A-mcp-lazy-loading.md` (new)
- `confluence/decisions/ADR-016-B-skill-metadata-discovery.md` (new)
- `confluence/decisions/index.md` (update)

## 预估工时

2 小时

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 04:45 UTC | backlog | master_main | 初始创建 |
| 2026-06-06 15:30 UTC | ready | master_main | 提升 ready，建卡 |
