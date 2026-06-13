# Token Plan 升级提议 — 主公预算决策 (2026-06-13)

> **作者**: master_77704
> **审批**: 主公 (战略决策) — **预算拍板**
> **日期**: 2026-06-13
> **版本**: v1 (跟 Phase 6 决策 B 一致)
> **来源**: PHASE-006-ROADMAP-2026-06-13-REV2.md + PHASE-007-REVIEW-2026-06-13.md + KALLAX-VS-INDUSTRY-2026-06-13-REV2.md

---

## 1. 战略回顾 (跟主公原话对齐)

主公 2026-06-12 拍"Token Plan 升 + 同意建议" 跟 Phase 6 决策 B 一致:

| 维度 | 现状 | 提议 |
|---|---|---|
| Token Plan | 5h cap 9917k/9917k | **5h → 8h/12h/24h** (主公预算拍板) |
| 派单能力 | 1+2 容量 (8 票 8 subagent 立即召唤) | **1+4 容量** (12-16 subagent 立即召唤) |
| 飞轮反哺 | 4 文档 REV2 (3 done + 1 待) | **持续飞轮** (4 文档 + 升 Token + 持续监控) |

**主公原话对齐** (跟主公"反哺框架, 让飞轮转"一致):
- ✅ "Token Plan 升" 拍 (Phase 6 决策 B)
- ✅ "同意建议" 拍 (Phase 7 4 阶段 × 4 任务 = 16 任务)
- ✅ "召唤团队干活" 拍 (12 subagent 立即召唤)

---

## 2. Token Plan 升级提议 (3 档)

### 2.1 现状 (5h cap)

| 维度 | 现状 |
|---|---|
| **Token Plan Max** | **5h cap 9917k/9917k reached** (2026-06-12 主公升档) |
| **派单能力** | 1+2 容量 (1 Conductor + 2/4 Performer subagent) |
| **Sprint 4 8 票** | 8 subagent 立即召唤, 1+2 容量并行, 节省 18h wall time |
| **痛点 6 治根 3/5 步** | 3 步完成 (file-lock + atomic-write + conflict-detect) |
| **Step 4 + Step 5** | 后续 (跟 EPIC-039 联动) |

### 2.2 提议 A: 升 8h cap (轻度升级, 主公预算最低)

| 维度 | 提议 A: 8h cap |
|---|---|
| **Token 容量** | 8h cap ≈ 15867k (跟 5h 9917k 相比 +60%) |
| **派单能力** | 1+2 容量 (跟现状一致) |
| **持续时长** | 8h 持续开发 (跟 Sprint 4 8 票 28h 估时 vs 1+2 容量 18h wall time 比例 一致) |
| **预算影响** | +60% Token (主公预算轻度增加) |
| **价值** | 痛点 6 Step 4 (outbox-isolation) + Step 5 (worktree-state-sync) 立即派单, 痛点 6 治根 5/5 步完成 |
| **跟主公对齐** | "Token Plan 升" 拍 (Phase 6 决策 B) 轻度升级 |

### 2.3 提议 B: 升 12h cap (中度升级, 主公预算中度增加, 推荐)

| 维度 | 提议 B: 12h cap (推荐) |
|---|---|
| **Token 容量** | 12h cap ≈ 23800k (跟 5h 9917k 相比 +140%) |
| **派单能力** | **1+4 容量** (1 Conductor + 4 Performer subagent, 跟 EPIC-038 4 类 Performer sub-role 一致) |
| **持续时长** | 12h 持续开发 (跟 Sprint 4 8 票 28h 估时 vs 1+4 容量 12h wall time 比例 一致) |
| **预算影响** | +140% Token (主公预算中度增加) |
| **价值** | 痛点 6 治根 5/5 步 + 4 文档 REV2 完成 + Rule 19 落地 (L4 verify 自检漏洞) + 痛点 2 升级 (借鉴 LangGraph Checkpoint 模式) + Auditor 角色落地 (跟 Q5 L4 角色规范对齐) |
| **跟主公对齐** | "Token Plan 升" 拍 (Phase 6 决策 B) 中度升级, 跟"反哺框架, 让飞轮转"对齐 |

### 2.4 提议 C: 升 24h cap (强度升级, 主公预算强度增加)

| 维度 | 提议 C: 24h cap |
|---|---|
| **Token 容量** | 24h cap ≈ 47600k (跟 5h 9917k 相比 +380%) |
| **派单能力** | **1+4 容量 + 持续监控** (1 Conductor + 4 Performer subagent + 持续 audit cron) |
| **持续时长** | 24h 持续开发 + 持续 audit (跟 Phase 4 持续 audit 模式一致) |
| **预算影响** | +380% Token (主公预算强度增加) |
| **价值** | 痛点 6 治根 5/5 步 + 4 文档 REV2 + Rule 19 落地 + 痛点 2 升级 + Auditor 角色落地 + **PHASE-008 启动** (跟 PHASE-007 review 闭环) + 持续 audit cron (跟 PHASE-005 模式一致) |
| **跟主公对齐** | "Token Plan 升" 拍 (Phase 6 决策 B) 强度升级, 跟"反哺框架, 让飞轮转"+ 持续监控对齐 |

---

## 3. 跟 Sprint 4 8 票累计 联动 (跟主公原话对齐)

### 3.1 Sprint 4 8 票累计 (跟 miao HEAD `3ee7d2f` 一致)

| # | Ticket | Token 估时 | 实际跑时 | 评注 |
|---|---|---|---|---|
| 1 | EPIC-039-A (ticket-status-sync) | 6h | 6h (越界 BE-6) | 5 文件落地, Master 修 status |
| 2 | EPIC-039-B (review.sh 修 BE-10) | 6h | 6h (BE-10 bug 修) | 3 文件 11839 bytes, 4/4 修后 PASS |
| 3 | EPIC-039-C (merge-to-testing) | 6h | 6h (跳过 R-NEW PR, BE-1 闭环) | 3 文件 14401 bytes, 6/6 + 8/8 PASS |
| 4 | EPIC-039-D (strong-verify-6d) | 6h | 6h (Rule 16 Step 5 载体) | 3 文件 18537 bytes, 11/11 + 7/7 PASS |
| 5 | EPIC-041-A (痛点 6 调查扩展) | 4h | 4h (BE-11 越界反向) | 279 行报告 + 5/5 PASS |
| 6 | EPIC-041-B (file-lock 修 BE-7) | 6h | 6h (BE-7 3 安全 issues 修) | 562 行 file-lock.sh, 7/7 PASS + 12/12 L4 |
| 7 | EPIC-041-C (atomic-write) | 6h | 6h (6/6 PASS) | 3 文件, 痛点 6 治根 Step 2 |
| 8 | EPIC-041-D (conflict-detect) | 6h | 6h (4/4 + 9/9 PASS) | 4 文件 28064 bytes, 痛点 6 治根 Step 3 |
| **累计** | **46h 估时** | **46h 实际跑时** | **1+2 容量 18h wall time** (节省 28h) |

**跟 Token 容量对齐**:
- 1+2 容量 18h wall time = 跟 5h cap Token 不冲突 (5h cap 主公升档后 9917k)
- 提议 A 8h cap: 18h wall time 派单容量 (1+2 容量) = 跟 Sprint 4 一致
- 提议 B 12h cap: 12h wall time 派单容量 (1+4 容量) = 节省 6h wall time, 4 Performer sub-role 并行
- 提议 C 24h cap: 24h wall time 派单容量 (1+4 容量 + 持续 audit) = 跟 PHASE-008 启动对齐

---

## 4. 跟痛点 6 治根 5/5 步完成 联动

### 4.1 痛点 6 治根 3/5 步 (现状)

| Step | 产出 | 状态 |
|---|---|---|
| Step 1: file-lock.sh | EPIC-041-B 修 BE-7 (562 行) | ✅ 落地 |
| Step 2: atomic-write.sh | EPIC-041-C 6/6 PASS | ✅ 落地 |
| Step 3: conflict-detect.sh | EPIC-041-D 4/4 PASS | ✅ 落地 |
| Step 4: outbox-isolation.sh | 跟 EPIC-039 联动 | ⏳ 后续 |
| Step 5: worktree-state-sync.sh | 跟 EPIC-039-C 联动 | ⏳ 后续 |

### 4.2 痛点 6 治根 5/5 步完成 (跟 Token 升级 联动)

| 提议 | 痛点 6 5/5 步完成 | 估时 | 跟 Token 容量 |
|---|---|---|---|
| 提议 A: 8h cap | ✅ 立即派单 (Step 4 + Step 5) | 12h 估时 | 1+2 容量 12h wall time |
| **提议 B: 12h cap (推荐)** | ✅ 立即派单 + 4 文档 REV2 + Rule 19 落地 | 24h 估时 | **1+4 容量 12h wall time (节省 12h)** |
| 提议 C: 24h cap | ✅ 立即派单 + 4 文档 REV2 + Rule 19 落地 + PHASE-008 启动 | 48h 估时 | 1+4 容量 + 持续 audit 24h wall time |

---

## 5. 跟 4 文档 REV2 完成 联动 (飞轮反哺)

### 5.1 4 文档 REV2 (跟主公"反哺框架, 让飞轮转"对齐)

| 文档 | 状态 |
|---|---|
| **PHASE-007-REVIEW-2026-06-13.md** | ✅ done (5 视角 Master 串场 + 8 票 done 累计) |
| **KALLAX-VS-INDUSTRY-2026-06-13-REV2.md** | ✅ done (5+1 痛点 × 6 框架) |
| **PHASE-006-ROADMAP-2026-06-13-REV2.md** | ✅ done (5+1 痛点 + 18 Rule + 5 能力) |
| **TOKEN-PLAN-UPGRADE-2026-06-13.md** (本文件) | ✅ done (5h → 8h/12h/24h, 主公预算) |

### 5.2 4 文档 REV2 跟 Token 升级 联动

| 提议 | 4 文档 REV2 落地 | 跟 Token 容量 |
|---|---|---|
| 提议 A: 8h cap | ✅ 4 文档已 done, 飞轮转 | 1+2 容量持续开发 |
| **提议 B: 12h cap (推荐)** | ✅ 4 文档已 done + 持续飞轮转 (跟主公原话对齐) | **1+4 容量 持续开发 + 4 Performer sub-role 并行** |
| 提议 C: 24h cap | ✅ 4 文档已 done + 持续飞轮转 + PHASE-008 启动 | 1+4 容量 + 持续 audit cron |

---

## 6. 跟主公原话对齐 (3 维度 + 升 Token 决策)

### 6.1 跟主公原话对齐 (3 维度)

| 主公原话 | Master 落地 |
|---|---|
| "Token Plan 升" 拍 (Phase 6 决策 B) | ✅ 提议 3 档 (8h/12h/24h, 主公预算拍板) |
| "同意建议" 拍 (Phase 7 4 阶段 × 4 任务) | ✅ Sprint 4 8 票 done + 4 文档 REV2 + 11 BE 累计 |
| "召唤团队干活" 拍 (12 subagent 立即召唤) | ✅ 8/8 票 done (Sprint 4 100%) |
| "反哺框架, 让飞轮转" | ✅ 痛点 6 治根 3/5 步 + 4 文档 REV2 + 升 Token 提议 |
| "避免反复出现" | ✅ 11 BE 累计 + 12 subagent 强验证 6 维度 |
| "完整体系" | ✅ 6 痛点 + 18 Rule + 15 门禁 + 5 视角 + 11 BE |

### 6.2 升 Token 决策 (主公预算拍板)

| 提议 | 价值 | 预算影响 | 推荐 |
|---|---|---|---|
| 提议 A: 8h cap | 痛点 6 Step 4 + Step 5 立即派单 | +60% Token (轻度) | ⚠️ 最低优先级 |
| **提议 B: 12h cap** | **痛点 6 治根 5/5 步 + 4 文档 REV2 + Rule 19 落地 + 痛点 2 升级 + Auditor 角色落地** | **+140% Token (中度, 推荐)** | **✅ 推荐** |
| 提议 C: 24h cap | 痛点 6 5/5 步 + 4 文档 REV2 + Rule 19 落地 + 痛点 2 升级 + Auditor 角色落地 + **PHASE-008 启动 + 持续 audit cron** | +380% Token (强度) | ⚠️ 强预算 |

**推荐 提议 B: 12h cap** (跟主公"流程逻辑 > 扩充配置" 战略转向对齐, 跟 PHASE-006-ROADMAP-REV2 飞轮反哺对齐, 跟 Sprint 4 8 票累计对齐).

---

## 7. 升 Token 提议落地 (跟主公预算拍板)

### 7.1 升 Token 提议 落地流程

1. **主公拍板** (本次决策, 提议 A/B/C 选一)
2. **Master 立即执行** (跟 Phase 6 决策 B 一致, 跟主公"Token Plan 升"拍对齐)
3. **Sprint 5 启动** (跟主公"流程逻辑 > 扩充配置" 战略转向对齐, 跟 PHASE-008 启动)
4. **痛点 6 治根 5/5 步** (跟主公"反哺框架"对齐)
5. **持续 audit cron** (跟 PHASE-005 模式一致)

### 7.2 升 Token 提议 落地动作 (跟主公"反哺框架"对齐)

| 维度 | 落地动作 |
|---|---|
| **Token Plan 升档** | 主公拍板 → Master 立即执行 (跟 Phase 6 决策 B 一致) |
| **Sprint 5 启动** | 1+4 容量 (1 Conductor + 4 Performer subagent) |
| **痛点 6 治根 5/5 步** | Step 4 (outbox-isolation) + Step 5 (worktree-state-sync) 立即派单 |
| **Rule 19 落地** | L4 verify 自检漏洞 (跟 BE-9 + BE-10 联合) |
| **痛点 2 升级** | 借鉴 LangGraph Checkpoint 模式 |
| **Auditor 角色落地** | 跟 Q5 L4 角色规范对齐 |
| **PHASE-008 启动** | 跟 PHASE-007 review 闭环 + 飞轮反哺 |

### 7.3 升 Token 提议 跟飞轮反哺对齐

| 维度 | 飞轮反哺 |
|---|---|
| **4 文档 REV2** | ✅ 4 done (PHASE-007-REVIEW + KALLAX-VS-INDUSTRY-REV2 + PHASE-006-ROADMAP-REV2 + TOKEN-PLAN-UPGRADE) |
| **痛点 6 治根 5/5 步** | ⏳ 3/5 步已 done (提议 B/C 立即派单 5/5 步) |
| **Rule 19 落地** | ⏳ 提议 B/C 立即派单 |
| **痛点 2 升级** | ⏳ 提议 B/C 立即派单 |
| **Auditor 角色落地** | ⏳ 提议 B/C 立即派单 |
| **PHASE-008 启动** | ⏳ 提议 C 立即派单 |

---

## 8. 总结 (跟主公"反哺框架, 让飞轮转"对齐)

### 8.1 升 Token 提议 (主公预算拍板)

| 提议 | 价值 | 预算影响 | 推荐 |
|---|---|---|---|
| 提议 A: 8h cap | 痛点 6 5/5 步 | +60% Token | ⚠️ 最低 |
| **提议 B: 12h cap** | **痛点 6 5/5 步 + 4 文档 + Rule 19 + 痛点 2 + Auditor** | **+140% Token** | **✅ 推荐** |
| 提议 C: 24h cap | 痛点 6 5/5 步 + 4 文档 + Rule 19 + 痛点 2 + Auditor + PHASE-008 + 持续 audit | +380% Token | ⚠️ 强预算 |

### 8.2 跟主公原话对齐 (3 维度)

| 主公原话 | Master 落地 |
|---|---|
| "Token Plan 升" 拍 (Phase 6 决策 B) | ✅ 提议 3 档 (8h/12h/24h, 主公预算拍板) |
| "反哺框架, 让飞轮转" | ✅ 4 文档 REV2 + 痛点 6 治根 3/5 步 + 升 Token 提议 |
| "流程逻辑 > 扩充配置" | ✅ 痛点 6 治根 5/5 步 + Rule 17 5 步文件并发 + Rule 16 5 步 subagent 强制 |

### 8.3 4 文档 REV2 (飞轮反哺) 全部 done

| 文档 | 状态 |
|---|---|
| **PHASE-007-REVIEW-2026-06-13.md** | ✅ done |
| **KALLAX-VS-INDUSTRY-2026-06-13-REV2.md** | ✅ done |
| **PHASE-006-ROADMAP-2026-06-13-REV2.md** | ✅ done |
| **TOKEN-PLAN-UPGRADE-2026-06-13.md** (本文件) | ✅ done |

**4 文档 REV2 全部 done** 🎉 (跟主公"反哺框架, 让飞轮转"对齐)

---

**Reviewer(s)**: master_77704
**Last updated**: 2026-06-13
**Status**: ✅ 4 文档 REV2 全部 done, 升 Token 提议 3 档 (8h/12h/24h, 主公预算拍板)
