# MCP Bridge Backlog (2026-08-07)

> **起源**: EPIC-124 设计 (2026-07-18) 至今未实施,EPIC-196 标注 PENDING
> **状态**: Backlog (未排期)

## 范围

KALLAX 工具 (bash scripts) 通过 MCP 协议暴露给 MCP 客户端 (Cursor/Claude Desktop),实现 `MCP tool call → ACP invoke_expert` 转发。

## 已有基础设施

- ACP 协议: `kallax-acp.sh` (JSON-RPC 2.0 over stdio)
- MCP lazy loading: `adr-016-a-mcp-lazy-loading-2026-06-06.md`
- 工具注册: 26 commands + scripts/

## 待办

1. MCP server stub (`node/src/mcp/server.ts` 或 `scripts/mcp-server.sh`)
2. Tool registry: 扫描 `scripts/*.sh` + `.claude/skills/` → MCP tool schema
3. invoke 转发: `MCP tool_call` → `kallax-acp.sh invoke_expert`

## 估算

~3-5 天 (1 人)。优先级 P2 (跟 ADR-016 lazy loading 互补,但非阻塞)。