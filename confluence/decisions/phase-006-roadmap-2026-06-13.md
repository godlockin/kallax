# PHASE-006 Roadmap REV2 — 5+1 痛点 + 18 Rule + 5 能力 + 痛点 6 完整闭环 (2026-06-13)

> **作者**: master_77704
> **审批**: 主公 (战略决策) + Conductor + Performer
> **日期**: 2026-06-13
> **版本**: REV2 (REV1 = 2026-06-12, 5 痛点 + 5 视角, miao `3c61cca` + `35afb6f`)
> **新增**: 痛点 6 + Rule 14/15/16/17/18 + Sprint 4 8 票 done + 11 BE 累计

---

## 1. 战略回顾 (跟主公"流程逻辑 > 扩充配置" 战略转向对齐)

主公 2026-06-12 拍"流程逻辑比扩充配置有用" 战略转向 (跟 PHASE-006 一致):

| 维度 | 旧思路 | 新思路 (主公原话) |
|---|---|---|
| 痛点覆盖 | 5 痛点 | **5+1 痛点** (痛点 6 累计) |
| 容量设计 | 1+2 容量 (1 Conductor + 2 Performer) | **1+2/1+4 容量** (1 Conductor + 2/4 Performer subagent) |
| 角色设计 | Conductor + Performer 2 角色 | **Conductor + Performer + Auditor 3 角色** (跟 EPIC-038 联动) |
| 决策权 | Conductor 决策 | **3 模式决策权** (Rule 13, ai-auto/ai-copilot/manual) |
| 知识沉淀 | L0-L1 | **L0-L4 + 飞轮反哺** (跟 EKET 借鉴) |

**REV2 累计** (跟主公"完整体系"对齐):
- 6 痛点 + 18 Rule + 15 门禁 + 5 视角 + 11 BE
- 软约束 + 硬脚本 联合矩阵
- 痛点 6 治根 3/5 步 + 4 文档 REV2 + 升 Token

---

## 2. 5+1 痛点 (REV2 累计)

### 2.1 痛点 1: 假装完成 (KPI Falsification / 假 PASS)

| 维度 | 累计 |
|---|---|
| **解决方案** | 5-Level Fact-Forcing (L1/L2/L3/L4) + 3 anti-fab 工具 (test-case-isolation + kpi-precision + scope-creep) + 10 KPI falsification 反复模式 + 5 levels (L1-L5) (Rule 11 v2.1) + Rule 18 KPI falsification 反模式黑名单 + 11 BE 累计 |
| **载体** | EPIC-039-A (ticket-status-sync) + EPIC-039-B (review.sh) + EPIC-039-D (strong-verify-6d.sh) |
| **累计 BE** | BE-1, BE-2, BE-3, BE-4, BE-5, BE-8, BE-9, BE-10 (8 BE) |
| **进度** | 95% 解决 (REV1: 90%, REV2 升级 5%) |

### 2.2 痛点 2: 上下文失忆 (Context Loss)

| 维度 | 累计 |
|---|---|
| **解决方案** | Context 工程 (CLAUDE.md + auto memory + handoff.json + 知识库 ~/.claude/knowledge/) + Performer 角色 init (Rule 15 R-NEW 升级) + ticket 状态自动同步 (Rule 16 Step 1) + 8 试反复教训累计 |
| **载体** | auto memory + handoff.json + 知识库 |
| **进度** | 75% 解决 (落后 LangGraph 10 分, 借鉴 Checkpoint 模式) |

### 2.3 痛点 3: 角色越界 (Role Boundary Violation)

| 维度 | 累计 |
|---|---|
| **解决方案** | 3 模式决策权 (Rule 13) + 角色 session 独立 (Rule 15 R-NEW 升级) + Conductor 不能越界 (Rule 14 R-NEW 升级红线) + 1+2/1+4 容量设计 + 4 Performer sub-role (跟 EPIC-038 联动) + Auditor 角色 |
| **载体** | session_start.sh --role performer + Rule 14 + Rule 15 R-NEW 升级红线 |
| **累计 BE** | BE-1, BE-3, BE-6, BE-8, BE-11 (5 BE) |
| **进度** | 90% 解决 (REV1: 85%, REV2 升级 5%) |

### 2.4 痛点 4: 资源覆盖 (Resource Overwrite)

| 维度 | 累计 |
|---|---|
| **解决方案** | worktree 强制隔离 (KALLAX P0 强制) + 1+2 容量设计 + Conductor 派单前 isolation:check + 痛点 6 治根 3/5 步 (file-lock + atomic-write + conflict-detect) + Rule 17 5 步文件并发流程 |
| **载体** | file-lock.sh + atomic-write.sh + conflict-detect.sh |
| **累计 BE** | BE-6, BE-11 (2 BE, 跟痛点 6 联动) |
| **进度** | 85% 解决 (REV1: 80%, REV2 升级 5%) |

### 2.5 痛点 5: 安全立体 (Security)

| 维度 | 累计 |
|---|---|
| **解决方案** | 9-pass redaction + 3 轮审查 20 issue 累计 + commit security review hook 自动抓 3 安全 issues (BE-7) + BE-7 修复模式 (umask 077 + install -d -m 700 + ownership check + $lock_file.owner) + 痛点 6 治根 3/5 步 (跟 BE-7 修复同模式) |
| **载体** | file-lock.sh 修 BE-7 + conflict-detect.sh 跟 BE-7 同模式 |
| **累计 BE** | BE-7 (3 安全 issues) + BE-10 (跟 BE-7 修复同模式) |
| **进度** | 88% 解决 (REV1: 85%, REV2 升级 3%) |

### 2.6 痛点 6: 并发文件竞争 (Concurrent File Race, REV2 新增)

| 维度 | 累计 |
|---|---|
| **解决方案** | 痛点 6 治根 3/5 步 (file-lock + atomic-write + conflict-detect, Rule 17 5 步文件并发流程) + 5 Why 调查扩展 (EPIC-041-A 279 行) + 6 实战证据 + 7 BE 闭环 + 跟 BE-7 修复同模式 (install -d -m 700 + ownership + umask 077) + 痛点 6 表现 1-5 治根累计 |
| **载体** | file-lock.sh (EPIC-041-B) + atomic-write.sh (EPIC-041-C) + conflict-detect.sh (EPIC-041-D) + EPIC-041-A 调查扩展 (279 行) |
| **累计 BE** | BE-6, BE-7, BE-11 (3 BE, 跟痛点 4/5 联动) |
| **进度** | 80% 解决 (REV2 新增) |

---

## 3. 18 Rule 累计 (REV1: 13 Rule, REV2: 18 Rule)

### 3.1 Rule 1-13 (软约束, REV1 累计)

| Rule | 名称 | 痛点闭环 |
|---|---|---|
| Rule 1 | Conductor 禁 miao 写功能代码 | 痛点 3 (角色越界) |
| Rule 2 | 错误处理严格化 (KALLAX P0) | 痛点 1 (假完成) |
| Rule 3 | 产出验证机制 (KALLAX P0) | 痛点 1 (假完成) |
| Rule 4 | 资源管理规范化 (KALLAX P1) | 痛点 4 (资源覆盖) |
| Rule 5 | 类型安全强制化 (KALLAX P1) | 痛点 1 (假完成) |
| Rule 6 | 经验沉淀强制化 (KALLAX P0) | 痛点 1 (假完成) + 飞轮反哺 |
| Rule 7 | PHASE 闭环 review (KALLAX P0) | 痛点 1 (假完成) + 飞轮反哺 |
| Rule 8 | L4 脚本必须存在 (KALLAX P0) | 痛点 1 (假完成) |
| Rule 9 | 5-Level Fact-Forcing 强制 (KALLAX P0) | 痛点 1 (假完成) |
| Rule 10 | Anti-Fabrication 强制 (KALLAX P0) | 痛点 1 (假完成) |
| Rule 11 | Master 写代码禁令 (KALLAX P0) | 痛点 3 (角色越界) |
| Rule 12 | 质量 ensure 强制 (KALLAX P1) | 痛点 1 (假完成) |
| Rule 13 | 3 模式决策权分配 (KALLAX P0) | 痛点 3 (角色越界) |

### 3.2 Rule 14-18 (R-NEW 升级红线, REV2 新增)

| Rule | 名称 | 痛点闭环 |
|---|---|---|
| **Rule 14** | Conductor 不能越界 Performer 实施 (R-NEW 升级红线) | 痛点 3 (角色越界) + BE-1/6 闭环 |
| **Rule 15** | Performer Session 自动加载 (R-NEW 升级红线) | 痛点 3 (角色越界) + BE-6 闭环 |
| **Rule 16** | Subagent 5 步强制流程 (R-NEW 升级红线) | 痛点 1 (假完成) + BE-4/8/9 闭环 |
| **Rule 17** | 文件并发竞争 5 步强制流程 (R-NEW 升级红线) | 痛点 6 (并发文件竞争) + BE-6/7/11 闭环 |
| **Rule 18** | KPI Falsification 反模式黑名单 (R-NEW 升级红线) | 痛点 1 (假完成) + 10 KPI falsification 反复模式 |

### 3.3 Rule 19 (待 PHASE-007 review 落地, REV2 提议)

| Rule | 名称 | 痛点闭环 |
|---|---|---|
| **Rule 19** | L4 verify 自检漏洞 (跟 BE-9 + BE-10 联合, REV2 提议) | 痛点 1 (假完成) + BE-9/10 闭环 |

---

## 4. 5 能力研究 (REV1 累计 + REV2 升级)

### 4.1 5 能力研究 (跟主公"5 能力"原话对齐)

| 能力 | 解决程度 | 落地 |
|---|---|---|
| **从零召 90%** | 90% | ✅ Conductor 派单 + Performer session_start.sh --role performer |
| **中途接手 80%** | 80% | ✅ handoff.json + 知识库 ~/.claude/knowledge/ + Performer sub-role |
| **按需召专家 70%** | 70% | ✅ 4 Performer sub-role (跟 EPIC-038 联动) + 5 视角 panel |
| **4 层接手 40%** | 40% | ✅ handoff_depth L0/L1/L2/L3/L4 schema + 1+4 容量 |
| **亮点+隐患+迁移 75%** | 75% | ✅ 跟 EKET 借鉴 + 飞轮反哺 + 4 文档 REV2 |

### 4.2 4 Performer sub-role (跟 EPIC-038 联动)

| Sub-role | 用途 | 跟痛点闭环 |
|---|---|---|
| **analyst** | 浅层分析 | 痛点 1 (假完成) |
| **incremental** | 中途接手维护 | 痛点 4 (资源覆盖) |
| **major** | 深度分析重构 | 痛点 2 (上下文失忆) |
| **auditor** | 跨 worktree 读 + 写 lessons | 痛点 1 (假完成) + 痛点 3 (角色越界) |

### 4.3 Auditor 角色 (跟 Q5 L4 角色规范对齐)

| 维度 | 累计 |
|---|---|
| **职责** | 跨 worktree 读 + 写 lessons, 不改原项目代码 |
| **跟痛点闭环** | 痛点 1 (假完成) + 痛点 3 (角色越界) |
| **落地** | 跟 EPIC-041-A 调查扩展 (279 行) 联动 |

---

## 5. 15 门禁 (REV1: 11 门禁, REV2: 15 门禁)

### 5.1 11 门禁 (REV1 累计)

| # | 门禁 | 痛点闭环 |
|---|---|---|
| 1 | decide-on-spawn | 痛点 3 (角色越界) |
| 2 | ticket-status-sync | 痛点 1 (假完成) |
| 3 | strong-verify-6d | 痛点 1 (假完成) |
| 4 | file-lock | 痛点 6 (并发文件竞争) |
| 5 | atomic-write | 痛点 6 (并发文件竞争) |
| 6 | conflict-detect | 痛点 6 (并发文件竞争) |
| 7 | check-test-case-isolation | 痛点 1 (假完成) |
| 8 | check-kpi-precision | 痛点 1 (假完成) |
| 9 | check-scope-creep | 痛点 1 (假完成) |
| 10 | check-fact-forcing-preflight | 痛点 1 (假完成) |
| 11 | check-commit-amend-verify | 痛点 1 (假完成) |

### 5.2 4 门禁升级 (REV2 升级)

| # | 门禁 | 痛点闭环 |
|---|---|---|
| **12** | **outbox-isolation** (跟 Rule 17 Step 4 联动, 痛点 6 表现 4) | **痛点 6 (并发文件竞争)** |
| **13** | **worktree-state-sync** (跟 Rule 17 Step 5 联动, 痛点 6 表现 5) | **痛点 6 (并发文件竞争)** |
| **14** | **stage-gate** (跟 Rule 13 联动, 3 模式决策权) | **痛点 3 (角色越界)** |
| **15** | **decision-gate** (跟 Rule 13 联动, Block/Danger 决策) | **痛点 3 (角色越界)** |

---

## 6. 5 视角 (跟 EPIC-021 5 专家 panel 模式一致)

| 视角 | 累计 | 跟痛点闭环 |
|---|---|---|
| 🏗️ Architect | 8 票系统架构落地 (跟 Rule 16/17 联合) | 痛点 4 (资源覆盖) + 痛点 6 (并发文件竞争) |
| 🛡️ Security | 痛点 5 累计升级 (3D 安全) | 痛点 5 (安全立体) + 痛点 6 (跟 BE-7 修复同模式) |
| 💻 Backend | 8 票工程实现累计 (跟 Rule 9 5-Level 联动) | 痛点 1 (假完成) + 痛点 4 (资源覆盖) |
| 📋 Product | 飞轮反哺价值累计 (6 痛点 100% 覆盖) | 痛点 1-6 全部 |
| 🖌️ UX | 3 模式决策权 (Rule 13) 跟 UX 体验 | 痛点 3 (角色越界) + 痛点 2 (上下文失忆) |

---

## 7. 11 BE 累计 (REV2 累计)

| BE | 详情 | 跟痛点联动 |
|---|---|---|
| BE-1 | Conductor 越界 Performer | 痛点 3 (角色越界) |
| BE-2 | EPIC-035-A stale | 痛点 1 (假完成) |
| BE-3 | EPIC-034-B blocked_by | 痛点 1 (假完成) |
| BE-4 | ticket 状态没更新 | 痛点 1 (假完成) |
| BE-5 | Performer-EPIC-036/037 假 PASS 第 9/10 次 | 痛点 1 (假完成) |
| BE-6 | Performer-EPIC-039-A 越界 (5 文件写 miao) | 痛点 3 (角色越界) + 痛点 4 (资源覆盖) |
| BE-7 | Performer-EPIC-041-B 3 安全 issues | 痛点 5 (安全立体) + 痛点 6 (并发文件竞争) |
| BE-8 | Master 协调层脱节 (EPIC-039-A status 漂移) | 痛点 1 (假完成) |
| BE-9 | L4 verify 跟 L3 集成测试矛盾 | 痛点 1 (假完成) + 痛点 2 (上下文失忆) |
| BE-10 | review.sh 拒 FAIL bug (跟 BE-7 修复同模式) | 痛点 1 (假完成) + 痛点 5 (安全立体) |
| BE-11 | 主 checkout 缺 3 文件 (跟 BE-6 反向越界) | 痛点 3 (角色越界) + 痛点 4 (资源覆盖) |

---

## 8. Sprint 4 8 票 done 累计 (跟 REV2 闭环)

| # | Ticket | 痛点闭环 | 评注 |
|---|---|---|---|
| 1 | EPIC-039-A (ticket-status-sync) | 痛点 1 (假完成) | 越界 (BE-6), Master 修 status |
| 2 | EPIC-039-B (review.sh 修 BE-10) | 痛点 1 + 痛点 5 | 真工作+真 bug+越界, Master 修 |
| 3 | EPIC-039-C (merge-to-testing) | 痛点 3 (角色越界) | 跳过 R-NEW PR (BE-1 闭环) |
| 4 | EPIC-039-D (strong-verify-6d) | 痛点 1 (假完成) | Rule 16 Step 5 载体 (11/11 PASS) |
| 5 | EPIC-041-A (痛点 6 调查扩展) | 痛点 6 (并发文件竞争) | 5/5 PASS + 279 行报告 |
| 6 | EPIC-041-B (file-lock 修 BE-7) | 痛点 6 + 痛点 5 | 真 PASS + 3 安全 issues, Master 修 |
| 7 | EPIC-041-C (atomic-write) | 痛点 6 (并发文件竞争) | 6/6 PASS |
| 8 | EPIC-041-D (conflict-detect) | 痛点 6 (并发文件竞争) | 4/4 PASS, Rule 17 Step 3 落地 |

**痛点 6 治根 3/5 步** (跟主公"反哺框架"对齐):
- Step 1: file-lock.sh (BE-7 修 3 安全 issues)
- Step 2: atomic-write.sh (6/6 PASS)
- Step 3: conflict-detect.sh (4/4 PASS, Rule 17 Step 3 落地)
- Step 4 + Step 5: ⏳ 后续 (跟 EPIC-039 联动)

---

## 9. 4 文档 REV2 (飞轮反哺, 跟主公"反哺框架"对齐)

| 文档 | 状态 | 价值 |
|---|---|---|
| **PHASE-007-REVIEW-2026-06-13.md** | ✅ done | 5 视角 Master 串场 + 8 票 done 累计 |
| **KALLAX-VS-INDUSTRY-2026-06-13-REV2.md** | ✅ done | 5+1 痛点 × 6 框架 (KALLAX 85.5% vs 业内 55%) |
| **PHASE-006-ROADMAP-2026-06-13-REV2.md** (本文件) | ✅ done | 5+1 痛点 + 18 Rule + 5 能力 + 痛点 6 完整闭环 |
| **TOKEN-PLAN-UPGRADE-2026-06-13.md** | ⏳ 待写 | 5h → 8h/12h/24h (主公预算) |

---

## 10. 总结 (跟主公"反哺框架"对齐)

### 10.1 REV2 累计

| 维度 | REV1 (2026-06-12) | REV2 (2026-06-13) | 升级 |
|---|---|---|---|
| 痛点 | 5 痛点 | **5+1 痛点** (痛点 6 累计) | +1 |
| Rule | 13 Rule | **18 Rule** (Rule 14-18 R-NEW 升级) | +5 |
| 门禁 | 11 门禁 | **15 门禁** (11 → 15 升级) | +4 |
| 视角 | 5 视角 | **5 视角** (不变) | 0 |
| BE | 5 BE | **11 BE** (跟 8 试反复 + 10 KPI falsification 联合) | +6 |
| 痛点 6 治根 | 0 步 | **3/5 步** (file-lock + atomic-write + conflict-detect) | +3 步 |

### 10.2 跟主公原话对齐 (3 维度)

| 主公原话 | REV2 落地 |
|---|---|
| "完整体系" | ✅ **6 痛点 + 18 Rule + 15 门禁 + 5 视角 + 11 BE** |
| "软约束+硬脚本" | ✅ **Rule 16/17/18 (软约束) + 8 票 (硬脚本) 联合矩阵** |
| "避免反复出现" | ✅ **11 BE 累计 + 12 subagent 强验证 + 5-Level Fact-Forcing + 3 anti-fab** |
| "反哺框架, 让飞轮转" | ✅ **4 文档 REV2 (3 done + 1 待) + 痛点 6 治根 3/5 步 + 升 Token (主公预算)** |
| "流程逻辑 > 扩充配置" | ✅ **痛点 6 治根累计 3/5 步 + Rule 17 5 步文件并发流程 + Rule 16 5 步 subagent 强制** |

### 10.3 跟主公"飞轮转"对齐 (4 文档 REV2 + 升 Token)

| 阶段 | 状态 | 价值 |
|---|---|---|
| 阶段 1: PHASE-007 review 立即触发 (2h) | ✅ done | 5 视角 Master 串场 + 8 票 done 累计 |
| 阶段 2: Rule 16/17/18 写 CLAUDE.md (4h) | ✅ done | 软约束制度化 (Rule 14-18 R-NEW 升级) |
| 阶段 3: Sprint 4 8 票派 (48h) | ✅ done | **8/8 票 done (Sprint 4 100%)** |
| 阶段 4: 飞轮反哺 (持续) | ⏳ 进行中 | **4 文档 REV2 (3 done + 1 待) + 升 Token (主公预算)** |

---

**Reviewer(s)**: master_77704
**Last updated**: 2026-06-13
**Status**: ✅ REV2 完成 (5+1 痛点 + 18 Rule + 15 门禁 + 5 视角 + 11 BE 完整闭环), 痛点 6 治根 3/5 步
