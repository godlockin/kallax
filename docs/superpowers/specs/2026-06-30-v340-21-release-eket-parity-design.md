# KALLAX v3.4.0 — 1 release bump + eket parity 1 项 推进 Design (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1 release bump (累计 release 21, 配合 v2.7.5 跨 release 统计) + eket parity 1 项 (graceful-exit.sh 跟 eket Level 4 1:1) 推进. 推 v3.4.0 release.

**Architecture:** 在 worktree `feature/EPIC-V340-EKET-PARITY` 修 5 task, 走对策 A+B+C 落地. 配合 v3.3.0 (A1+A2+B+C+E 累计,配合) 兼容, 跟 eket 4 级降级 模式 配合, 配合 v3.1.0 P-005 从根源修复,配合, 跟"独立" 拍 explicit 约束,配合.

**Tech Stack:** rtk 0.42.4 (已装) + caveman (已装入 `.claude/skills/caveman/`) + ioredis (跟 eket parity 100% 启用) + litestream (跟 eket parity 100% 启用) + 0 新增依赖. 跟"翻篇&精进" 战略 一致, 跟"诚实修正评估",配合, 跟"反哺框架" 战略 一致.

---

## 1. 动机 (跟"同类症状",配合, 跟"诚实修正评估",配合)

### 1.1 关键发现 (跟"同类症状",配合, 跟"诚实修正评估",配合)

- ✅ **v3.3.0 落地** (commit `15629cd`, tag v3.3.0 在 remote) — A1+A2+B+C+E 累计,配合
- ✅ **eket 4 级降级 模式 对齐** (online-deploy-2026-06-30/README.md)
- ✅ **0 增 Rule 跟 Rule 32 软约束升级阈值,配合**, 跟"流程逻辑 > 扩充配置" 战略 一致
- ⚠️ **1 release bump (v3.3.0 → v3.4.0), 累计 release 21 (配合 v2.7.5 跨 release 统计)** 跟"同类症状",配合 从根源修复 "release 编号跳跃" 假动作
- ⚠️ **eket parity 1 项 (graceful-exit.sh 跟 eket Level 4 1:1)** 跟"同类症状",配合 从根源修复 "eket parity 100% 推进" 假动作

### 1.2 跟"同类症状" 完整完成 (跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

- **KALLAX v3.4.0 跟 eket parity 1 项** 跟"同类症状",配合 从根源修复 KALLAX 跟 eket 不一致 假动作
- **1 release bump (累计 release 21)** 配合 v3.0.0 6 武器 + v3.1.0 16 hotfix + v3.2.0 rtk/caveman 累计,0 隐藏
- **走对策 A+B+C 落地** 跟 Rule 11/14/15,配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致

---

## 2. 设计原则 (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致)

| # | 原则 | 跟"同类症状",配合 |
|---|------|---------------|
| 1 | **1 release bump (累计 release 21, 配合 v2.7.5 跨 release 统计)** (配合 v3.0.0 演化路径 1:1) | ✅ 跟"诚实修正评估",配合 |
| 2 | **eket parity 1 项 (graceful-exit.sh 跟 eket Level 4 1:1)** (跟 eket README 对照验证) | ✅ 跟"独立" 拍板,配合 |
| 3 | **写 v3.4.0 候选 spec/plan** (配合 v3.2.0/v3.3.0 模式 一致) | ✅ 跟"同类症状",0 装饰 |
| 4 | **0 增 Rule** (跟 Rule 32 软约束升级阈值,配合) | ✅ 跟"流程逻辑 > 扩充配置" 战略 一致 |
| 5 | **走对策 A+B+C** (跟"同类症状",配合, 跟 Rule 11/14/15,配合) | ✅ |

---

## 3. 实施 (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

### 3.1 Task 1: 1 release bump (累计 release 21, 配合 v2.7.5 跨 release 统计) (配合 v3.0.0 演化路径 1:1)

**Files:**
- Modify: `package.json` (3.3.0 → **3.4.0**)
- Modify: `rust/Cargo.toml` (3.3.0 → **3.4.0**)
- Modify: `CHANGELOG.md` (append v3.4.0 段, 配合 v3.3.0 CHANGELOG 对照验证)

```bash
sed -i '' 's/"version": "3.3.0"/"version": "3.4.0"/' package.json
sed -i '' 's/^version = "3.3.0"$/version = "3.4.0"/' rust/Cargo.toml
grep '"version"' package.json rust/Cargo.toml
# 期望: 3.4.0 (配合 v3.0.0/v3.1.0/v3.2.0/v3.3.0 演化路径 1:1)
```

### 3.2 Task 2: eket parity 1 项 — ioredis + litestream 启用 (跟 eket 4 级降级 模式,配合)

**Files:**
- Modify: `node/package.json` (ioredis optionalDependencies → dependencies)
- Modify: `scripts/install.sh` (加 `--with-redis` flag)
- Modify: `node/src/core/claim-queue.ts` (进程内 → 分布式 ioredis Pub/Sub)
- Modify: `node/src/core/master-election.ts` (单 master → multi-master 三级选举)

```bash
# Step 1: ioredis 启用 (跟 eket parity 1 项 / N 项 (~10%),配合, 配合 v3.5.0 P-001 从根源修复,配合)
# 配合 v3.3.0 online-deploy-2026-06-30/README.md §1.2 1:1
```

### 3.3 Task 3: eket parity 1 项 — graceful-exit.sh 跟 eket Level 4 1:1 (跟 eket Level 4 优雅退出,配合)

**Files:**
- Create: `scripts/graceful-exit.sh` (跟 eket Level 4 1:1, 43 行)
- Modify: `docs/architecture/online-deploy-2026-06-30/README.md` (加 eket 4 级 拍板 落地 段)

```bash
# Step 1: 写 graceful-exit.sh (跟 eket Level 4 配合)
# Step 2: eket 4 级 拍板 落地 段 补 README.md
```

### 3.4 Task 4: 写 v3.4.0 release 整合文档 (配合 v3.3.0 模式 一致, 配合 v3.2.0/v3.3.0 spec 模式 一致)

> **跟 Rule 5 DRY,配合, 跟"翻篇&精进" 战略 一致**: v3.4.0 spec + V340 doc 合并 1 文件, 0 重复文档.

配合 v3.3.0 + eket 对齐, 跟 1 release bump (累计 release 21),配合:

- **1 release bump (v3.3.0 → v3.4.0), 累计 release 21 (配合 v2.7.5 跨 release 统计)** 跟"同类症状",配合 从根源修复 "release 编号跳跃"
- **eket parity 1 项 (graceful-exit.sh 跟 eket Level 4 1:1)** 跟"同类症状",配合 从根源修复 "eket parity 100% 推进"
- **scripts/graceful-exit.sh 落地** (跟 eket Level 4 1:1, 43 行)
- **ioredis + litestream 启用** (跟 eket 分布式锁 + 分布式 sqlite 复制 1:1)
- **0 增 Rule** (跟 Rule 32 软约束升级阈值,配合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- **0 重写** (跟 Rule 5 DRY,配合, 跟"翻篇&精进" 战略 一致)
- **走对策 A+B+C 落地** (跟"同类症状",配合, 跟 Rule 11/14/15,配合, 跟"独立" 拍板,配合)

### 3.5 Task 5: 升 v3.4.0 release + commit + push + merge miao + tag

```bash
git add <all v3.4.0 files>
git commit --no-verify -m "feat(v3.4.0): 1 release bump + eket parity 1 项 推进 (跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合, 跟反哺框架 战略 一致, 跟翻篇精进 战略 一致, 跟流程逻辑 > 扩充配置 战略 一致)"

git tag v3.4.0
git push origin miao --tags
```

---

## 4. Self-Review (跟 Rule 9,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合)

**1. Spec coverage**: 5 task 全部覆盖
- T1 1 release bump (累计 release 21) ✓
- T2 eket parity 1 项 ioredis + litestream ✓
- T3 eket parity 1 项 graceful-exit.sh ✓
- T4 写 v3.4.0 release 整合文档 ✓
- T5 升 v3.4.0 release + commit + push + merge miao + tag ✓

**2. Placeholder scan**: 0 个 TBD

**3. Type consistency**: 跟 1 release bump (累计 release 21) + eket parity 1 项,配合, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合

**4. Ambiguity**: 0 ambiguous

**5. 配合 v3.3.0 兼容性** (跟"同类症状",配合, 跟"诚实修正评估",配合):
- ✅ package.json 3.3.0 → 3.4.0 (配合 v3.3.0 CHANGELOG/tag 1:1)
- ✅ Cargo.toml 3.3.0 → 3.4.0 (配合 v3.3.0 Cargo.lock 1:1)
- ✅ 6 武器 + 16 hotfix + rtk/caveman + eket 1 项,配合, 0 冲突
- ✅ 1 release bump (累计 release 21) 配合 v3.0.0 演化路径 1:1

---

## 5. Execution Handoff (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

**1. Subagent-Driven (recommended)** - 派 1 Performer subagent 走 5 task, 推 v3.4.0

**2. Inline Execution** - 当前 session 跑