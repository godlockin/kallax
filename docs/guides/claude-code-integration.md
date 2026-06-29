# KALLAX × Claude Code Integration Guide (v3.1.0, Track 4)

> **武器 5 (Hook Server) 真实 Claude Code E2E 集成** — 跟 6 phase endpoints 实战
>
> Source: `node/src/hooks/http-hook-server.ts` + `node/src/hooks/hook-events-store.ts`
>
> 跟 `tests/integration/real-claude-code-e2e.sh` 1:1 验证 (4-6 raw stdout PASS)

---

## 1. 架构图

```
┌──────────────────┐     POST /hooks/<phase>      ┌─────────────────────────┐
│   Claude Code    │ ──────────────────────────▶ │  KALLAX Hook Server     │
│  (CLI/Hooks)     │   Bearer <KALLAX_API_KEY>    │  http-hook-server.ts    │
│                  │                              │  port 8787 (default)    │
│  settings.json   │ ◀────────────────────────── │                         │
│  .claude/hooks/  │   200 / 403 / 401            │  ┌─────────────────┐    │
└──────────────────┘                              │  │ HookDispatcher  │    │
                                                 │  │ (武器 5 引擎)   │    │
┌──────────────────┐     POST /hooks/replay       │  └─────────────────┘    │
│  Operator / CLI  │ ──────────────────────────▶ │           │              │
│  (Conductor /    │                              │           ▼              │
│   接手 Performer)│     GET  /hooks/audit        │  ┌─────────────────┐    │
│                  │ ◀────────────────────────── │  │ HookEventsStore │    │
└──────────────────┘                              │  │ (JSONL + chain) │    │
                                                 │  └─────────────────┘    │
                                                 │           │              │
                                                 │           ▼              │
                                                 │  .kallax/audit/          │
                                                 │  hook-events.jsonl       │
                                                 └─────────────────────────┘
```

**关键组件**:
- `node/src/hooks/http-hook-server.ts:80-356` — HTTP server, 8 endpoints (6 phase + replay + audit)
- `node/src/hooks/dispatcher.ts:49-243` — HookDispatcher 引擎 (chain + checks + audit)
- `node/src/hooks/hook-events-store.ts:138-232` — append-only JSONL + sha256 hash-chain

---

## 2. 启动 KALLAX Hook Server

```bash
# 1. 启动 KALLAX hook server (武器 5, port 8787)
KALLAX_API_KEY="<your-secret>" \
node --import tsx \
  node/src/cli/start-hook-server.ts \
  --port 8787 \
  --api-key "$KALLAX_API_KEY" \
  --audit-store .kallax/audit/hook-events.jsonl

# 2. 验证 server 起来
curl -sS http://127.0.0.1:8787/hooks/audit?limit=1
# → {"path":".../hook-events.jsonl","total":0,"events":[]}
```

---

## 3. Claude Code settings.json 实战配置

> 用户级: `$HOME/.claude/settings.json` (不 commit, 本地)
> 项目级: `.claude/settings.local.json` (不 commit, 本地)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/pre-tool-use",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/post-tool-use",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 30
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/compact",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 30
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/permission",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/session-start",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 10
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:8787/hooks/session-end",
            "headers": {
              "Authorization": "Bearer ${KALLAX_API_KEY}",
              "Content-Type": "application/json"
            },
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Endpoint 映射表** (Claude Code event → KALLAX route):

| Claude Code Hook | KALLAX Route | Phase (内部) |
|---|---|---|
| `PreToolUse` | `POST /hooks/pre-tool-use` | `pre-tool-use` |
| `PostToolUse` | `POST /hooks/post-tool-use` | `post-tool-use` |
| `PreCompact` | `POST /hooks/compact` | `post-compact` |
| `PermissionRequest` | `POST /hooks/permission` | `pre-permission` |
| `SessionStart` | `POST /hooks/session-start` | `session-start` |
| `SessionEnd` | `POST /hooks/session-end` | `session-end` |

定义在 `http-hook-server.ts:40-47` (`PHASE_MAP`)。

---

## 4. Bearer Token 认证流程

`http-hook-server.ts:89-94` (`isAuthorized`):

```typescript
function isAuthorized(req: IncomingMessage): boolean {
  if (!config.apiKey) return true;  // 开发模式: 无 apiKey → 全开
  const auth = req.headers['authorization'] ?? '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  return token === config.apiKey;
}
```

**生产部署必设** `--api-key`, 否则 server 接受任何请求 (开发模式)。

---

## 5. /hooks/replay 用例 (新接手 onboarding)

> Source: `http-hook-server.ts:96-180` (`handleReplay`)

**目的**: 把一个 session 的历史 hooks 重放到另一个 session, 用于:
- 新 Conductor 接手 Performer 后的"上下文同步"
- 测试环境复现生产 session 的行为
- 教学 / 培训: 重放资深 Performer 的成功路径

**Request**:
```bash
curl -sS -X POST http://127.0.0.1:8787/hooks/replay \
  -H "Authorization: Bearer $KALLAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "old-session-abc",
    "targetSessionId": "new-session-xyz",
    "fromTimestamp": 1719700000000,
    "toTimestamp":   1719800000000
  }'
```

**Response (200)**:
```json
{
  "targetSessionId": "new-session-xyz",
  "sourceSessionId": "old-session-abc",
  "totalEvents": 7,
  "replayed": 7,
  "results": [
    { "originalSeq": 1, "hookType": "session-start",   "allowed": true },
    { "originalSeq": 2, "hookType": "pre-tool-use",    "toolName": "Bash", "allowed": true },
    { "originalSeq": 3, "hookType": "post-tool-use",   "toolName": "Bash", "allowed": true }
  ]
}
```

**关键**: 重放写入新 audit chain (`hash-chain` 包含 `metadata.replay` 元数据)。

---

## 6. /hooks/audit 用例 (审计 + hash-chain 验证)

> Source: `http-hook-server.ts:182-208` (`handleAuditQuery`)

**基础查询**:
```bash
curl -sS "http://127.0.0.1:8787/hooks/audit?sessionId=alice&limit=10"
```

**过滤维度**:
- `sessionId` — 按 session
- `hookType` — 按 phase (`pre-tool-use` / `post-tool-use` / ...)
- `fromTimestamp` / `toTimestamp` — 按时间范围 (ms epoch)
- `limit` — 倒数 N 条

**Hash-chain 独立验证** (跟 `scripts/audit/audit-verify.sh` 联合):
```bash
# 1. 拉所有 events
curl -sS "http://127.0.0.1:8787/hooks/audit" > events.json

# 2. 独立验证 sha256 chain (genesis → hash → prevHash → hash ...)
node scripts/audit/verify-hook-chain.mjs < events.json
# → ✅ 24 events verified / ❌ broken at seq=12 (expected sha256:xxx, got sha256:yyy)
```

---

## 7. 故障排除 (常见错误)

| 症状 | 原因 | 修复 |
|---|---|---|
| `401 Unauthorized` | API key 不匹配 / 缺失 | 检查 `Authorization: Bearer <key>` 跟 `--api-key` 一致 |
| `404 Unknown hook endpoint` | URL 路径错 | 6 phase endpoints 必须 `POST /hooks/<phase>` (kebab-case) |
| `405 Method not allowed` | 用 GET 调 phase endpoint | 6 phase 端点只接受 POST; audit 接受 GET; replay 接受 POST |
| `403 Blocked by hook` | Hook 拒绝 (policy / rate limit) | 看响应 body `reason` + `warnings` 字段 |
| `500 Internal error` | Dispatcher 内部异常 | 看 server logs (`logger.error` 包含 phase + error msg) |
| `503 audit store not configured` | 调用 `/hooks/replay` 但 server 未配 auditStore | 启动时必传 `--audit-store` 参数 |
| Hash-chain 校验失败 | JSONL 文件被外部工具手动编辑 | 重启 server 让新 append 恢复 chain; 损坏段需手动 rebuild |

---

## 8. 跟 eket 对比 (eket 无 hook server)

| 维度 | KALLAX v3.1.0 (武器 5) | eket (template only) |
|---|---|---|
| **Hook server** | ✅ HTTP server, 8 endpoints | ❌ 无 (e2e tests 是直 mock) |
| **审计日志** | ✅ JSONL + sha256 hash-chain (武器 1) | ❌ 无 |
| **Replay** | ✅ `POST /hooks/replay` (跨 session 重放) | ❌ 无 |
| **Auth** | ✅ Bearer token | ❌ 无 |
| **Conductor / Performer 集成** | ✅ dispatcher.execute + audit 写入 | ❌ eket 是 Master-Slaver, 无 KALLAX 概念 |
| **Test 覆盖** | 13 vitest cases + 1 bash E2E (real-claude-code-e2e.sh) | template only, 无 E2E |

**关键 Gap**: eket 没有 Claude Code hook server, 所有 hook 测试都用 mock; KALLAX 武器 5 是 真实 HTTP server + Claude Code 实战集成 (通过 curl mock 6 phase)。

---

## 9. 跟 6-weapons-e2e-test.sh 联合验证

`tests/integration/6-weapons-e2e-test.sh:372-412` 已经 验证:
- L1 存在性: `http-hook-server.ts` 存在
- L2 实质性: `/hooks/replay` 端点定义存在
- L3 接线正确: `handleReplay` + `auditStore.query` + `replayResults.push`
- L4 数据流动: replay 事件处理逻辑 ≥ 2 个 push

新加 `tests/integration/real-claude-code-e2e.sh` 用 curl 模拟 Claude Code 端, 跟 6 phase + 2 endpoint 端到端 验证 (4-6 raw stdout PASS)。

---

## 10. 安全注意

- **生产必设** `--api-key` (Bearer token 认证)
- **不要 commit** 用户级 `$HOME/.claude/settings.json` 或项目级 `.claude/settings.local.json` (含 API key)
- **审计日志** `.kallax/audit/hook-events.jsonl` 包含完整会话元数据, 注意 `chmod 600`
- **Replay 风险**: 重放可能触发副作用 hooks, 仅在测试环境用, 或 `--dry-run` flag (待实现)