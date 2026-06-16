# EPIC-054-B — LESSONS LEARNED

> instance 目录 LRU + 7d TTL 自动清理 (治 A7 instance 僵尸)
> 跟 Rule 4 (事后复盘) 联合, 跟 AGENTS.md §Resource Management 联合, 跟 EPIC-053-A (L3↔L4) 联合

---

## L1 — Resource Management 硬要求不是建议, 是约束

**问题**: A7 (instance 僵尸) 根因是 `.kallax/instances/` 88 个目录 95% 僵尸, 跟 AGENTS.md §"Cache TTL Requirement" 硬要求矛盾. 老 `instance-registry.ts` 用 TTL=30s (只覆盖运行时 cache, 不覆盖持久化的 instance dir), 留下僵尸死角.

**根因**: TTL 只覆盖了内存 cache (LRU), 没覆盖持久化目录. 持久化层的 instance dir 永不过期, 累积成 88 个僵尸.

**修法**: 双层 TTL 覆盖 — (1) 内存 cache TTL 30s → 7d, (2) 持久化目录加 `cleanup.sh` 定期扫描. 两层协同, 任何一层失效另一层兜底.

**Rule 联动**: AGENTS.md §Cache TTL Requirement — 所有 cache 必须有 TTL, 不可豁免.

---

## L2 — LRU 排序的"oldest first" 跟"最近最少使用"语义统一

**洞察**: 多数人混淆 LRU 跟 FIFO. LRU 是按"最近一次使用"排序, 越久没动越优先淘汰. 在 instance 场景下, "最近一次使用" ≈ `last_heartbeat`. 所以 LRU 排序 = `last_heartbeat` 升序.

**应用**: `lru_sort_instances()` 按 epoch 升序, 最久没心跳在前. 清理时按这个顺序遍历, 最早心跳的最先被踢.

**反模式**: 按"创建时间"排序 = FIFO, 不是 LRU. 跟 cache 语义不一致. 创建时间早的 instance 可能心跳很新 (e.g., conductor 长时间未重启), 不能误清.

---

## L3 — Protected roles 白名单是 anti-mis-deletion 的关键

**洞察**: instance 自动清理的最大风险是误删活跃 conductor / master. 这些 role 启动了 14 卡治理 / 派单系统, 一旦被清 = 整个 agent 协作停摆.

**修法**: 双层保护 —
1. **白名单**: `PROTECTED_ROLES = {conductor, master}` — 这两个 role 走"heartbeat within TTL 才清"路径, 不会因为单纯超 TTL 被踢
2. **TTL 双重保险**: 即使被踢, 也只 mark as `status=error`, 不物理删除 (跟 EPIC-016-R 教训联动)
3. **dry-run 默认**: `cleanup.sh` 默认 dry-run, Master 确认后才 `--apply`

**Rule 联动**: Rule 4 (no magic numbers — TTL=7 是常量, 不写魔法值), Rule 18 (fail-fast — protected roles 必须有显式定义).

---

## L4 — 边界 fallback chain 解决 schema 不兼容

**洞察**: `.kallax/instances/*/state.json` 有 5 种 timestamp 字段位置:
1. `.heartbeat.last_beat` (legacy, EPIC-016-R 时期)
2. `.heartbeat.last_heartbeat` (新 schema)
3. `.last_beat` (顶层)
4. `.last_heartbeat` (顶层)
5. `.started_at` / `.created_at` (注册时间兜底)

老 conductor dir 用 schema 1, 新 performer 用 schema 2-4, 完全没 timestamp 的视作僵尸 (epoch=0).

**修法**: 5 层 fallback — `read_last_beat_epoch()` 依次尝试, 找不到就 epoch=0 (最老 = 最先清). 不抛错, 优雅降级.

**反模式**: 一刀切读 `.lastHeartbeat` 字段, 老 dir 全部视为 epoch=0 → 全部立即被清. 治标不治本, 一运行就把历史 conductor 全干掉.

**Rule 联动**: DRY (single source of truth — 但实际多 source, 用 fallback chain 兼容).

---

## L5 — Boundary 语义: `age < ttl` 比 `age <= ttl` 更稳健

**洞察**: TTL 边界测试 TC3 暴露了 timing race. `is_within_ttl()` 内部调 `date +%s`, 测试 setup 也调 `date +%s`, 两次调用差几秒, 导致 `age = ttl` 边界值 (e.g., 7d exact = 604800s) 漂移到 `age = 604801` 变成 expired.

**修法**:
1. 用 exclusive 边界 `age < ttl` (语义上更直观: "within TTL" = 年龄严格小于阈值)
2. `is_within_ttl` 接受可选 `now` 参数, 测试可显式传入避免 race
3. 测试预期从 `7d = yes (≤)` 改成 `7d = no (boundary expired)`, 跟代码语义一致

**教训**: 测试边界条件时, 时间相关的 helper 必须可注入 `now`, 否则 timing race 导致 flaky tests.

**Rule 联动**: Rule 9 (KPI 精确 — 5/5 = 100.0%, 不可有 flaky pass), DRY (边界定义要统一).

---

## L6 — Performer 边界: 只交付机制, 不实际清理

**洞察**: A7 instance 僵尸 (88 → ≤5) 治根需要 2 步: (1) 实现清理机制 (本 ticket), (2) 实际跑清理 (Master 后执行). Performer 越界清理 = 写运行时状态, 违反 Rule 9 (隔离).

**修法**:
1. `cleanup.sh` 默认 `--dry-run`, 不修改 fs
2. `instance-ttl.sh` hook 也只调 `--dry-run`, session 启动不阻塞
3. `instance-registry.ts` 升级 register 时扫描 stale 但只 mark `status=error`, 不物理删
4. pass-report 明确标 `boundary_violations=0` + `instance_count_target_after_cleanup: "≤5 (95% 清理)"` + `next_action: "Master 后执行 cleanup.sh --apply"`

**Rule 联动**: Rule 9 (隔离), Rule 18 (no background hallucination), EPIC-053-A L6 (类似 scope-creep 边界教训).

---

## L7 — Node 层 + Shell 层双覆盖

**洞察**: 清理机制只在 Shell 层 (`cleanup.sh`) 不够, 因为 node 启动新 instance 时也会写 `instance-registry`. 必须 Node 层同步升级 `instanceCache` TTL + register 时扫 stale.

**修法**:
- Shell 层: `scripts/instance/cleanup.sh` (周期扫描 + 归档)
- Node 层: `instance-registry.ts`:
  - `instanceCache` TTL 30s → 7d
  - `register()` 前扫 db list, 超 TTL 自动 mark `status=error`
  - 新增 `markInstancesByTTL(thresholdMs)` (LRU 排序 + unregister)

**Rule 联动**: Defense in depth (多层防御), DRY (语义一致: Shell 和 Node 都用 7d + protected roles + LRU 排序).

---

## 与 EPIC-053-A / EPIC-054-A / EPIC-054-C 的接口

| Ticket | 责任 | 跟 EPIC-054-B 联动 |
|--------|------|--------------------|
| EPIC-053-A | L3↔L4 一致性 | 用 `l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS` 验证 (本 ticket 用过) |
| EPIC-054-A | worktree 根目录统一 | 跟本 ticket parallel, 不依赖实际迁移 |
| EPIC-054-C | .kallax/state/* 重构 | 本 ticket 不动 state (boundary), 由 EPIC-054-C 处理 |

---

## 防 A7 复发 checklist

- [x] `scripts/instance/cleanup.sh` 可执行, sourceable (`run_cleanup`, `lru_sort_instances`, `is_within_ttl`)
- [x] `scripts/hooks/instance-ttl.sh` session-start hook, exit=0 不阻塞
- [x] `node/src/core/instance-registry.ts` TTL 30s → 7d, 新增 `markInstancesByTTL`
- [x] `tests/integration/instance-ttl-test.sh` 5/5 PASS = 100.0%
- [x] 所有 7 anti-fab 工具 PASS
- [x] `boundary_violations=0` (实际清理由 Master 后执行)
- [x] 5 个文件全部在 file_scope.includes

---

## 给 Master 的后续 ticket 建议

1. **Master 跑清理**: `bash scripts/instance/cleanup.sh --apply --ttl-days=7` 真正归档 83 僵尸
2. **加 cron / daemon**: 每周一凌晨自动跑 `cleanup.sh --apply`
3. **监控告警**: `.kallax/instances/` 数量 > 10 时告警
4. **跟 EPIC-054-C 联动**: 清理 state 层的僵尸字段 (performer 不再用但还在 list)
