# KALLAX ACP — Agent Communication Protocol

> **版本**: 1.0
> **日期**: 2026-07-18
> **来源**: grok-build xai-acp-lib 简化版
> **状态**: EPIC-122-H 设计

---

## 一、概述

KALLAX ACP 是轻量版 JSON-over-stdin/stdout 协议，用于：
- **CI/Headless 模式**：Daemon 不需要 TTY
- **Pipeline**：工具串成管道
- **外部调用**：第三方工具调用 KALLAX expert

**对比 grok-build ACP**：
| 维度 | grok-build ACP | KALLAX ACP |
|------|---------------|------------|
| 语言 | Rust trait system | Bash + JSON |
| 传输 | ACP over stdio | JSON-RPC 2.0 over stdio |
| 方法数 | 30+ | 5 个核心 |
| Session 模型 | 有状态，多 session | 单 session（headless） |
| Subagent | SubagentCoordinator | 无（用 cancel/query 替代） |

---

## 二、Wire 格式

### 2.1 请求

```json
{
  "method": "method_name",
  "params": { ... },
  "id": 1
}
```

### 2.2 响应

```json
{
  "result": { ... },
  "error": null,
  "id": 1
}
```

### 2.3 错误

```json
{
  "result": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message"
  },
  "id": 1
}
```

---

## 三、方法定义

### 3.1 session_open

打开新 session。

```json
// Request
{"method": "session_open", "params": {}, "id": 1}

// Response
{"result": {"session_id": "1752850000-1234", "status": "active", "protocol": "1.0"}, "error": null, "id": 1}
```

### 3.2 session_close

关闭 session。

```json
// Request
{"method": "session_close", "params": {"session_id": "1752850000-1234"}, "id": 2}

// Response
{"result": {"session_id": "1752850000-1234", "status": "closed"}, "error": null, "id": 2}
```

### 3.3 invoke_expert

调用 expert，返回 invocation_id。

```json
// Request
{"method": "invoke_expert", "params": {"session_id": "...", "expert_id": "backend", "ticket_id": "TASK-001"}, "id": 3}

// Response
{"result": {"invocation_id": "inv-1", "status": "pending", "expert_id": "backend", "ticket_id": "TASK-001"}, "error": null, "id": 3}
```

### 3.4 query_invocations

查询 invocation 状态。

```json
// Request
{"method": "query_invocations", "params": {"session_id": "...", "invocation_ids": []}, "id": 4}
// invocation_ids 为空 = 返回所有

// Response
{"result": [{"id": "inv-1", "expert_id": "backend", "ticket_id": "TASK-001", "status": "running"}], "error": null, "id": 4}
```

### 3.5 cancel_invocation

取消 running invocation。

```json
// Request
{"method": "cancel_invocation", "params": {"invocation_id": "inv-1"}, "id": 5}

// Response
{"result": {"invocation_id": "inv-1", "status": "cancelled"}, "error": null, "id": 5}
```

---

## 四、错误码

| 错误码 | 含义 | 对应场景 |
|--------|------|---------|
| `INVALID_METHOD` | 未知方法名 | 发送了不支持的 method |
| `INVALID_PARAMS` | 参数缺失 | 缺少必填字段 |
| `SESSION_NOT_FOUND` | session 不存在 | 用已关闭的 session 发起请求 |
| `INVOCATION_NOT_FOUND` | invocation 不存在 | 查询不存在的 invocation_id |
| `ALREADY_CANCELLED` | 已取消 | 重复 cancel |
| `INTERNAL_ERROR` | 内部错误 | 系统级异常 |

---

## 五、实现

**入口**: `scripts/lib/kallax-acp.sh`

```bash
# 单次调用
bash scripts/lib/kallax-acp.sh invoke_expert '{"expert_id":"backend","ticket_id":"TASK-001"}'

# Pipeline 模式
echo '{"method":"invoke_expert","params":{"expert_id":"backend","ticket_id":"TASK-001"},"id":1}' \
  | bash scripts/lib/kallax-acp.sh
```

---

## 六、与 grok-build ACP 的差距

| 功能 | grok-build | KALLAX ACP |
|------|-----------|------------|
| 多 session 并发 | ✅ | ❌ (单 session) |
| Subagent 生命周期 | ✅ (SubagentCoordinator) | ❌ (fire-and-forget) |
| MCP 协议桥接 | ✅ | ❌ |
| Streaming 输出 | ✅ (SSE) | ❌ (全量返回) |
| Permission 提示 | ✅ | ❌ |
