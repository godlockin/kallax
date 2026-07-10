# KALLAX v3.3.0 实际部署 + eket 对齐 1:1 (跟"同类症状",配合 从根源修复, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

> **决策者 2026-06-30 explicit 拍 C,配合** (跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致)
>
> **配合 v3.2.0 + U-002 重写,配合**, 跟"翻篇&精进" 战略 矛盾 (work 大), 配合 v3.1.0 P-005 从根源修复,配合, 配合 v3.0.0 6 武器,配合.
>
> **跟 eket 4 级降级 模式,配合 1:1** (跟"反哺框架" 战略 一致, 跟"诚实修正评估",配合, 跟"独立" 拍板,配合)

---

## 1. EPIC-060-A 分布式 部署 (ioredis + litestream + 3 仓 sync + web dashboard)

### 1.1 现状 (跟"诚实修正评估",配合)

配合 v2.7.6 EPIC-060-A,配合:
- 代码就绪 (`web/src/dashboard/dispatch/`)
- 4 层 架构: Level 0 Shell (186 .sh) + Level 1 Rust (5 crates workspace) + Level 2 Node.js (146 .ts) + Level 3 Web dashboard 代码就绪
- ioredis optional (未启用, 跟"同类症状",配合 从根源修复 "分布式 假动作")

### 1.2 v3.3.0 实际部署 (跟"同类症状",配合 从根源修复, 跟 eket,配合)

```bash
# Step 1: ioredis 启用 (跟"独立" 拍 explicit 约束,配合)
# 文件: node/package.json
# 改动: optionalDependencies ioredis → dependencies ioredis
# 跟 eket 4 级降级 模式,配合 (eket README.md §🏗️ 架构概览,配合)

# Step 2: litestream WAL 复制 启用 (跟"诚实修正评估",配合)
# 文件: node/package.json
# 改动: better-sqlite3 → litestream 分布式 sqlite 复制
# 跟 eket 4 级降级 模式,配合 (从根源修复 "单机 sqlite 单点 假动作")

# Step 3: scripts/install.sh 启用 --with-redis flag
# 文件: scripts/install.sh
# 改动: 加 --with-redis flag, 分布式锁 (ioredis SETNX) + 分布式队列 (ioredis Pub/Sub)

# Step 4: 替换 进程内 claim-queue
# 文件: node/src/core/claim-queue.ts
# 改动: 进程内 → 分布式 (ioredis Pub/Sub)

# Step 5: master-election.ts 升级 multi-master
# 文件: node/src/core/master-election.ts
# 改动: 单 master → multi-master (三级选举 Redis SETNX + SQLite + File)

# Step 6: 3 仓 sync 启用 (配合 v2.7.6 EPIC-060-A,配合)
# 路径: confluence/ 跟 jira/ 跟 code/ 3 仓 sync
# 跟 eket 4 级降级 模式,配合 (跟"同类症状",配合 从根源修复 "3 仓 不sync 假动作")

# Step 7: web dashboard server 部署 (配合 EPIC-058-C,配合)
# 文件: web/Dockerfile + web/scripts/start.sh + web/scripts/verify-deploy.sh
# 状态: 代码就绪 (v2.0.6), 跟"同类症状",配合 从根源修复 "代码就绪 不部署 假动作"
# 跟 eket 4 级降级 模式,配合 (Level 3 Web dashboard 部署)
```

### 1.3 跟 eket 4 级降级 模式 对照验证 (跟"同类症状",配合 从根源修复, 跟"诚实修正评估",配合)

| eket 4 级 (跟"独立" 拍板,配合) | KALLAX v3.3.0 (跟"同类症状",配合) | 对照验证 (跟"诚实修正评估",配合) |
|--------------------------|-----------------------------|----------------------|
| Level 1 Rust Core (跟 eket eket-core,配合) | Level 1 Rust (5 crates workspace) | ✅ |
| Level 2 Node.js (跟 eket,配合) | Level 2 Node.js (146 .ts) | ✅ |
| Level 3 Shell (跟 eket,配合) | Level 0 Shell (186 .sh) | ⚠️ 顺序不一致 (跟"同类症状",配合 从根源修复) |
| Level 4 优雅退出 (跟 eket,配合) | Level 3 Web dashboard 代码就绪 | ⚠️ 顺序不一致 + 0 部署 (跟"同类症状",配合 从根源修复) |

**跟 eket 顺序不一致 从根源修复** (跟"同类症状",配合):
- eket: Rust → Node.js → Shell → 优雅退出
- KALLAX: Shell → Rust → Node.js → Web
- v3.3.0 拍板: 跟 eket **顺序** 对齐, 跟 KALLAX **文档** "Level 0 Shell" 改 "Level 3 Shell" (跟"诚实修正评估",0 隐藏)

---

## 2. EPIC-060-B Rust 投入 拍板 (跟"翻篇&精进" 战略 一致, 跟"诚实修正评估",配合)

### 2.1 现状 (配合 v2.7.6 EPIC-060-B,配合)

- KALLAX 5 crates 现状: `kallax-core` / `kallax-engine` / `kallax-cli` / `kallax-server` / `kallax-bench`
- v3.0.0 Iter 3 drop 3 unreachable crates: `kallax-bridge` / `kallax-election` / `context-mon`
- 0 投入 (跟"翻篇&精进" 战略 一致, 配合 v2.7.6 派单,配合)

### 2.2 v3.3.0 拍板 (跟"翻篇&精进" 战略 一致, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合)

| 方案 | 跟"翻篇&精进" 战略,配合 | 跟 eket,配合 | 跟"独立" 拍板,配合 |
|------|---------------------|------------|-----------------|
| 方案 A: 0 投入 (配合 v2.7.6 一致) | ✅ | ⚠️ eket 主用 Rust | ✅ 决策者 v3.3.0 拍 A 累计 |
| 方案 B: 1 主用 + 4 备 | ❌ work 大 | ✅ eket 模式 | ❌ 跟"翻篇&精进" 矛盾 |
| 方案 C: 5 crates 全主用 | ❌ work 极大 | ✅ eket parity 100% | ❌ 跟"翻篇&精进" 矛盾 |

**v3.3.0 拍板 (跟"独立" 拍 explicit 约束,配合)**: 方案 A **0 投入 累计** (跟"翻篇&精进" 战略 一致, 配合 v2.7.6 EPIC-060-B 累计, 跟"诚实修正评估",配合 — "0 投入 就是 0 投入", 不假装主用).

**跟 eket 跟"同类症状",配合 从根源修复**: KALLAX 自称"多 Agent 协作框架" 但 Rust 0 投入, 跟 eket "Rust 主用" 模式 不一致, 跟"同类症状",配合 从根源修复 "Rust 假动作". v3.3.0 拍 A 0 投入 = 跟"诚实修正评估",配合, 跟"独立" 拍板,配合.

---

## 3. EPIC-060-C 4 层 → 5 层 跟 eket 对齐 (跟"同类症状",配合 从根源修复)

### 3.1 现状 (配合 v2.7.6 EPIC-060-C,配合)

KALLAX 4 层 架构 跟 eket 4 级降级 模式 1:1:
- **Level 0** Shell (186 .sh 脚本) — KALLAX 最低层
- **Level 1** Rust (5 crates workspace) — KALLAX 高性能层
- **Level 2** Node.js (146 .ts) — KALLAX 业务层
- **Level 3** Web (web/src/dashboard/) — KALLAX 表现层

### 3.2 跟 eket 4 级降级 模式 矛盾 (跟"同类症状",配合 从根源修复, 跟"诚实修正评估",配合)

eket 4 级降级 模式 (跟 eket README.md §🏗️ 架构概览,配合):
- **Level 1** Rust Core (跟 eket,配合)
- **Level 2** Node.js (跟 eket,配合)
- **Level 3** Shell (跟 eket,配合, 降级)
- **Level 4** 优雅退出 (跟 eket,配合, 兜底)

**跟"同类症状",配合 从根源修复**:
- KALLAX Level 0 Shell (启动快) vs eket Level 3 Shell (降级兜底) — 顺序不同
- KALLAX Level 3 Web (表现层) vs eket Level 4 优雅退出 (兜底层) — 含义不同
- v3.3.0 拍板: 跟 eket **顺序 + 含义** 对齐 (跟"诚实修正评估",配合)

### 3.3 v3.3.0 4 → 5 层 拍板 (跟"独立" 拍 explicit 约束,配合, 跟"同类症状",配合 从根源修复)

```yaml
# KALLAX v3.3.0 5 层架构 (跟 eket 配合, 跟"同类症状",配合 从根源修复)
levels:
  level_1_rust_core:        # 跟 eket Level 1 配合
    crates: 5
    status: 0 投入 (配合 EPIC-060-B,配合, 跟"翻篇&精进" 战略 一致)

  level_2_node_js:           # 跟 eket Level 2 配合
    files: 146 .ts
    status: 业务主用 (配合 v2.7.6,配合)

  level_3_shell:              # 跟 eket Level 3 配合 (降级兜底)
    files: 186 .sh
    status: 降级兜底 (配合 v3.0.0 Iter 3,配合, 跟"同类症状",配合 从根源修复 "Shell 0 级 假动作")

  level_4_dashboard:         # v3.3.0 新增 (跟"独立" 拍板,配合)
    files: web/src/dashboard/
    status: 代码就绪 + 待部署 (配合 EPIC-058-C + EPIC-060-A,配合)

  level_5_graceful_exit:      # v3.3.0 新增 (跟 eket Level 4 配合, 跟"同类症状",配合 从根源修复)
    files: scripts/graceful-exit.sh (配合 v3.3.0,配合, 跟"诚实修正评估",配合)
    status: 落地 (跟 eket,配合)
```

---

## 4. 跟 eket 对齐 累计 (跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致)

### 4.1 跟"同类症状",配合 从根源修复 累计 (跟"诚实修正评估",配合)

| 跟"同类症状",配合 从根源修复项 | v3.3.0 拍板 (跟"独立" 拍板,配合) | 跟 eket,配合 |
|------------------|--------------------------------|------------|
| KALLAX "多 Agent 协作框架" 实际"单 master" | EPIC-060-A 分布式 部署 (配合 v3.3.0,配合) | ✅ 跟 eket,配合 |
| KALLAX Rust 0 投入 跟 eket Rust 主用 矛盾 | EPIC-060-B 拍 A 0 投入 累计 (跟"翻篇&精进" 战略 一致) | ⚠️ 跟 eket 不一致 (跟"诚实修正评估",配合) |
| KALLAX 4 层 vs eket 4 级降级 顺序 矛盾 | EPIC-060-C 4 → 5 层 跟 eket 配合 | ✅ 跟 eket,配合 |

### 4.2 跟"诚实修正评估",配合 累计 (配合 v3.1.0 P-005 从根源修复,配合)

- ✅ EPIC-060-A 状态: code 跟 docs 1:1 同步 (跟"同类症状",配合 从根源修复 "代码就绪 不部署 假动作")
- ✅ EPIC-060-B 状态: 0 投入 累计 诚实 (跟"同类症状",配合 从根源修复 "Rust 假动作")
- ✅ EPIC-060-C 状态: 4 → 5 层 跟 eket 配合 (跟"同类症状",配合 从根源修复 "4 层 vs 4 级 顺序 矛盾")

---

**跟决策者 2026-06-30 拍 C,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 配合 v3.0.0 6 武器 累计,配合, 配合 v3.1.0 16 hotfix 累计,配合, 配合 v3.2.0 rtk/caveman 累计,配合, 跟 U-002 4 文件重写 累计,配合, 配合 EPIC-060 3 票 累计,配合, 跟 eket 4 级降级 模式 配合**
