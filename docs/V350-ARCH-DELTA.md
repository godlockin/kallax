# v3.5.0 Architecture Delta (跟 B 组 U-001 治根 联合)

> **跟主约束联合**: ❌ 不改 docs/ARCHITECTURE.md / docs/CHEATSHEET.md / CLAUDE.md (Iter 2 锁定)
> **B 组 U-001 治根方案**: 本 DELTA 文档 (新) 显式 list v3.5.0 增量, 待 v3.6.0 整合到 ARCHITECTURE.md
> **跟 V310-B U-005 / U-007 1:1 联合**

## v3.5.0 ARCHITECTURE.md 应增量 (待 v3.6.0 整合)

### §11 武器 1 Hash-Chain Audit (增量)

- **v3.5.0 ioredis Pub/Sub** (跟 eket 分布式队列 1:1 验证):
  - `node/src/core/redis-pubsub.ts` (新增 2026-06, EPIC-060-A Phase 1)
  - `createRedisPubSubBus` + `createInMemoryPubSubBus` (1 interface + 2 implementations, 跟 Rule 5 DRY 联合)
  - **v3.5.0 hotfix (B 组 S-003)**: logger.error / logger.warn 全 redact password (跟 redact-secret.ts 1:1 联合)

### §11 武器 1 master-election.ts (增量)

- **v3.5.0 redisPool fd leak 治根** (B 组 S-005):
  - overwrite 旧 connection 前先 quit
  - registerCleanupHandler Node.js exit 时 close 全部 pool

### §12 武器 6 Web Dashboard (增量)

- 跟 v3.5.0 0 增量 (跟 v3.0.0 + v3.1.0 一致)

### §13 实战 (增量)

- **v3.5.0 graceful-exit.sh** (跟 eket Level 4 优雅退出 1:1):
  - 加 `--dry-run` / `--actual` flag (B 组 S-001 治根)
  - 加 SIGTERM/SIGINT trap handler (B 组 S-002 治根)
  - pid_file (.kallax/pid/*.pid) 优先 + pgrep -o 兜底 (B 组 S-002 治根)
  - verify_killed step (TERM 后 sleep 1, 仍活 escalate KILL)

### §14 recovery-manager (增量)

- **v3.5.0 probeRedis 实际探测** (B 组 S-004): `redis-cli PING` expect `PONG`
- **v3.5.0 start() async + await** (B 组 S-006): throw on fatal 而非 fire-and-forget

## v3.5.0 CHEATSHEET.md 应增量

```
**Degradation (5)**: `kallax graceful-exit --dry-run|--actual` · `kallax redis status` · `kallax recovery status` · `kallax election state` · `kallax level probe`
```

## v3.5.0 CLAUDE.md 应增量 (跟 U-004 联合)

```
## 13. caveman mode (跟 v3.2.0 rtk + caveman 整合 联合, 75% token 节省)
   - /caveman 切换简化输出
   - /caveman + /kallax-* 兼容
```

## 跟 B 组 U-001 治根 联合

Iter 2 锁定 docs/ARCHITECTURE.md / docs/CHEATSHEET.md / CLAUDE.md, 本 DELTA 文档 1:1 列 增量, 待主公拍板 v3.6.0 整合. 跟 V310-B U-002 / U-005 / U-007 1:1 联合: 留待主公 拍板, 不擅自改 locked docs.

---

Co-Authored-By: Claude <noreply@anthropic.com>