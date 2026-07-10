# SOP: Instance Cleanup & Rollback (Phase 0.3 + 0.4)

> **Ticket**: EPIC-027-B (P0, 3h, 1 ticket 1 subagent 串行)
> **Author**: performer-EPIC-027-B
> **Status**: implemented (commit pending)
> **联动**: EPIC-027-A (Phase 0.1 tracking) + 48 worktree cleanup pattern (v2.4.0 P1-2) 0 NEW

## 0. 背景

`scripts/kallax-cleanup.sh` 原先只覆盖 2 道防线：

1. STALE state.json 标记 → ZOMBIE (last_beat > 5min)
2. Orphan heartbeat-daemon kill (instance_dir 缺失 + etime > 1h)

EPIC-022 启动前，`.kallax/instances/` 累积 **21 个 CLOSING instance**（含历史 Performer 退出但状态卡 CLOSING/ZOMBIE 的残留）。这些 instance 不再活跃、daemon 多半已死，但 instance_dir + state.json 残留占空间 + 干扰状态机判断。

EPIC-027-B 引入 **Phase 0.3 (pre-clean 识别+归档)** + **Phase 0.4 (rollback SOP)**，让 21 CLOSING instance 在误判情况下 5min 内可恢复。

## 1. 何时清（Phase 0.3 触发条件）

| 条件 | 默认值 | 覆盖方式 | 说明 |
|------|--------|----------|------|
| instance status ∈ {CLOSING, ZOMBIE} | `CLOSING,ZOMBIE` | `--include-status STATUS[,STATUS]` | 仅清理 CLOSING/ZOMBIE，不动 ACTIVE/STALE |
| 距 last state change > N 天 | `30` 天 | `--age-days N` | 30d 安全边界（避免误杀"最近刚合并"的活跃 instance） |
| heartbeat last_beat (fallback) | 同上 | 同上 | 当 state.json 无 `.state.last_state_change` 时用 `.heartbeat.last_beat` |

**关键安全约束**：
- ACTIVE / CREATED / RUNNING 永远不动（状态机保护）
- < 30d 的 CLOSING instance 跳过（容错窗口）
- 默认 dry-run；只有 `--force` 才会真正归档

## 2. 怎么清（3 步走流程）

### Step 1: Audit（仅识别，不改）

```bash
# 列出所有会被归档的 instance（dry-run 自动）
bash scripts/kallax-cleanup.sh --age-days 30
```

输出示例：
```
── KALLAX cleanup (DRY RUN) ──
  Phase 0.3 age threshold: 30d (--age-days)
  Phase 0.3 include statuses: CLOSING,ZOMBIE
  PRE-CLEAN performer_001_old status=CLOSING age=45d (would archive)
  PRE-CLEAN performer_002_old status=ZOMBIE age=62d (would archive)
── done: 0 stale marked ZOMBIE, 0 orphans killed, 2 pre-clean identified (0 archived) ──
```

### Step 2: Dry-run 验证

```bash
# 调小阈值测试，验证识别逻辑
bash scripts/kallax-cleanup.sh --age-days 7 --include-status ZOMBIE
# 或调大阈值跳过 active 周边
bash scripts/kallax-cleanup.sh --age-days 90
```

确认 21 个目标 instance 都在预览里 → 进入 Step 3。

### Step 3: Force 归档

```bash
bash scripts/kallax-cleanup.sh --force --age-days 30
```

归档目录结构：
```
.kallax/instances/.archive/
└── 20260625_143022_performer_001_old/
    ├── state.json.bak      # ← rollback 入口（Phase 0.4）
    ├── heartbeat.log       # 原始日志
    └── ...                 # 其他 instance 文件
```

**归档 ≠ 删除**：所有原文件都在 `.archive/<TS>_<ID>/` 里，30d 内可恢复（参见 §3 rollback）。

### 全程审计

每次归档写一行 JSONL 到 `.kallax/logs/pre_clean.jsonl`：

```json
{"ts":"2026-06-25T14:30:22Z","event":"pre_clean_archive","instance_id":"performer_001_old","status":"CLOSING","age_days":45,"age_threshold_days":30,"archive_path":".kallax/instances/.archive/20260625_143022_performer_001_old","source":"kallax-cleanup.sh"}
```

可 grep / 统计 / 告警。

## 3. Rollback 路径（Phase 0.4 SOP）

### 何时 rollback

- 误杀：被归档的 instance 后来发现是 ACTIVE / 还在跑
- 状态损坏：归档后业务方报"这个 instance 数据丢了"
- 误判：Phase 0.3 阈值设错了，重新评估

### Rollback 步骤（单个 instance）

```bash
# 1. 找到归档目录
ARCHIVE_PATH=".kallax/instances/.archive/20260625_143022_performer_001_old"
INSTANCE_ID="performer_001_old"

# 2. 验证 archive 内容完整
ls -la "${ARCHIVE_PATH}"
# 确认 state.json.bak 存在 + 内容可读
jq . "${ARCHIVE_PATH}/state.json.bak"

# 3. 重建 instance_dir
mkdir -p ".kallax/instances/${INSTANCE_ID}"

# 4. 恢复所有原文件
mv "${ARCHIVE_PATH}"/* ".kallax/instances/${INSTANCE_ID}/"

# 5. 验证 state.json
cat ".kallax/instances/${INSTANCE_ID}/state.json"
# 应看到原始 status（CLOSING/ZOMBIE）+ last_beat 等

# 6. 写 rollback 审计
printf '{"ts":"%s","event":"pre_clean_rollback","instance_id":"%s","archive_path":"%s","operator":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INSTANCE_ID" "$ARCHIVE_PATH" "${USER:-manual}" \
  >> ".kallax/logs/pre_clean.jsonl"
```

### Rollback 步骤（批量恢复）

```bash
# 恢复同一批次所有 instance（timestamp 前缀匹配）
TS_PREFIX="20260625_143022"
for ARCHIVE_PATH in .kallax/instances/.archive/${TS_PREFIX}_*; do
  INSTANCE_ID="$(basename "${ARCHIVE_PATH}" | sed "s/^${TS_PREFIX}_//")"
  mkdir -p ".kallax/instances/${INSTANCE_ID}"
  mv "${ARCHIVE_PATH}"/* ".kallax/instances/${INSTANCE_ID}/"
  printf '{"ts":"%s","event":"pre_clean_rollback_batch","instance_id":"%s","archive_path":"%s","batch_ts":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INSTANCE_ID" "$ARCHIVE_PATH" "$TS_PREFIX" \
    >> ".kallax/logs/pre_clean.jsonl"
done
```

### Rollback 边界

| 边界 | 说明 |
|------|------|
| `.archive/` 还在 → 100% 可恢复 | state.json + heartbeat.log + 所有原文件都在 |
| `.archive/` 被人工 rm → 不可恢复 | 建议 cron 30d 后再清理 `.archive/`（见 §4） |
| archive 期间 instance 被新启动 → 覆盖 | archive 路径含 `YYYYMMDD_HHMMSS_`，同名会 SKIP（保护） |

## 4. Cron 建议

```cron
# 每日 3am 跑 dry-run + force（生产建议 force=true 离线清理）
0 3 * * * cd /path/to/kallax && bash scripts/kallax-cleanup.sh --force --age-days 30 >> .kallax/logs/cron_cleanup.log 2>&1
```

**为什么 3am**：
- 业务低峰，daemon 残留概率最高（用户退出但 instance 未清理）
- 不会跟人工 `--dry-run` 撞（避免审计混乱）
- 跨时区友好：UTC 3am ≈ 北京时间 11am / 美东 11pm / 美西 8pm

**Cron 配套要求**：
- `.archive/` 目录 disk 配额 ≥ 5GB（21 instance × ~200KB 平均 ≈ 4MB，5GB 给 30d 滚动）
- 30d 后清理 `.archive/`：`find .kallax/instances/.archive/ -mtime +30 -name 'state.json.bak' -delete`（仅删 .bak，主文件保留）

## 5. 监控告警

### 告警条件

| 条件 | 阈值 | 告警级别 | 含义 |
|------|------|----------|------|
| CLOSING instance 总数 | > 30 | WARN | 可能有 Performer 退出路径异常累积 |
| ZOMBIE instance 总数 | > 50 | WARN | cleanup 失败 / cron 未跑 |
| 单次 pre-clean 归档数 | > 100 | WARN | 阈值设错 / 状态机异常 |
| `.archive/` 体积 | > 5GB | WARN | 30d 滚动失败，需人工清理 |
| `.archive/` 单 instance | > 100MB | INFO | 该 instance 异常大（可能含 log 爆炸） |

### 监控查询

```bash
# 当前 CLOSING + ZOMBIE 数量（实时）
jq -r '.status' .kallax/instances/*/state.json 2>/dev/null \
  | sort | uniq -c | sort -rn

# 最近 24h 归档数
jq -r 'select(.event=="pre_clean_archive") | .ts' .kallax/logs/pre_clean.jsonl 2>/dev/null \
  | grep "$(date -u -d '24 hours ago' +%Y-%m-%d)" | wc -l

# .archive/ 体积
du -sh .kallax/instances/.archive/

# 找 > 100MB 单 instance
find .kallax/instances/.archive/ -maxdepth 2 -type d -size +100M
```

## 6. 联合模式（0 NEW）

| 联合项 | 来源 | 复用方式 |
|--------|------|----------|
| EPIC-027-A (Phase 0.1 tracking) | jira/tickets/EPIC-027-A | ticket 结构 + status metadata 已落地，本 SOP 是实施层 |
| 48 worktree cleanup 模式 | v2.4.0 P1-2 (commit fd9d0d9) | archive-not-delete 哲学复用（保留 .archive/ 30d 可回滚） |
| cleanup-zombies.sh 既有逻辑 | scripts/cleanup-zombies.sh | 复用 .archive/YYYYMMDD_HHMMSS_<ID>/ 命名约定 + mv + rmdir pattern |
| Orphan heartbeat cleanup runbook | confluence/runbooks/orphan-heartbeat-cleanup.md | 复用 3 道防线叙事（session_start + cleanup.sh + audit） |
| BE-23 从根源修复 (commit 7347ae6) | pre-commit hook branch-aware | 本 SOP 不涉及 commit，无需 hook 联动 |
| BE-25 / BE-26 留待 | check-scope-creep TICKET_ID + staged 检测 | 本 SOP 不修改 hook，无需联动 |

## 7. 测试

### 单元测试（dry-run）

```bash
# 准备 fixture
mkdir -p /tmp/kallax-test/.kallax/instances/test_inst
echo '{"status":"CLOSING","state":{"last_state_change":"2026-05-01T00:00:00Z"},"heartbeat":{"last_beat":"2026-05-01T00:00:00Z"}}' \
  > /tmp/kallax-test/.kallax/instances/test_inst/state.json

# dry-run 验证
KALLAX_ROOT=/tmp/kallax-test/.kallax bash scripts/kallax-cleanup.sh --age-days 30
# 应输出: PRE-CLEAN test_inst status=CLOSING age=Nd (would archive)

# force 验证
KALLAX_ROOT=/tmp/kallax-test/.kallax bash scripts/kallax-cleanup.sh --force --age-days 30
# 应: archive 到 .archive/YYYYMMDD_HHMMSS_test_inst/

# rollback 验证
KALLAX_ROOT=/tmp/kallax-test/.kallax ls .kallax/instances/.archive/
# 找到 test_inst，mv 回去，验证 state.json 完整
```

### 集成测试（real instance）

```bash
# 真实环境 dry-run 一次，确认 21 instance 都在预览
bash scripts/kallax-cleanup.sh --age-days 30
# 期望: 21 PRE-CLEAN identified, 0 archived

# 再用 --age-days 1 验证边界
bash scripts/kallax-cleanup.sh --age-days 1
# 期望: 0 PRE-CLEAN（所有 instance 都不超过 1d）

# 用 --include-status 缩小范围测试
bash scripts/kallax-cleanup.sh --include-status ZOMBIE
# 期望: 仅 ZOMBIE 在预览
```

## 8. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 误杀 ACTIVE instance | 低 | 高 | 状态机白名单（仅 CLOSING/ZOMBIE）+ 30d 阈值 |
| Rollback 路径不工作 | 低 | 中 | §3 步骤明确 + `state.json.bak` 备份 |
| `.archive/` 累积爆盘 | 中 | 中 | §4 cron 30d 清理 + §5 体积告警 |
| cron 与人工并发冲突 | 低 | 低 | 归档路径含 TS，同名 SKIP |
| jq 不可用 / 解析失败 | 低 | 低 | fallback 到 `stat` mtime + 跳过 |

## 9. 退出条件 (Acceptance)

- [x] AC1: `scripts/kallax-cleanup.sh` supports pre-clean for 21 CLOSING instances
- [x] AC2: Phase 0.3 identifies CLOSING instances older than 30 days
- [x] AC3: Phase 0.4 rollback SOP documented in `docs/SOP-cleanup.md` (this file)
- [x] AC4: 跟 EPIC-027-A 跟踪 (Phase 0.1) 联合（ticket 结构 + estimated_hours metadata 已落地）
- [x] AC5: 跟 48 worktree cleanup 模式 联合 0 NEW（archive-not-delete 哲学复用）

---

> **变更日志**
> - 2026-06-25: v1.0 落地（EPIC-027-B performer-EPIC-027-B）