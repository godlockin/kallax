# KALLAX 流程 (v2.0.3, 跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 配合 EPIC-056-A 3 阶段治理,配合)

> 跟决策者 §2 拍板,配合, 跟 Rule 11/14/15/16,配合, 跟"诚实修正评估",配合.
> 配合 EPIC-056-A 5→3 阶段治理,配合, 配合 EPIC-055-B 拍板分级 P0/P1/P2,配合, 配合 v1.2.4 5 扩展组,配合.

## /kallax-init (项目初始化)

跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 配合 v1.3.3 Onramp 模式 一致:

1. 扫路径 (0 LLM)
2. 创建 3 库骨架 (跟"流程逻辑" 战略 一致)
3. 创建 CLAUDE.md 模板
4. 创建 5 default + 5 extended skill 文档
5. LLM 预审 (1 调用)
6. 输出 INIT-REPORT.md
7. 等决策者拍 explicit 授权 (跟"独立" 拍 explicit 约束,配合)

## /kallax-takeover (中途接手)

1. 扫 3 库状态 (0 LLM)
2. LLM 预审 (1 调用)
3. 路由器主动给 2 推荐 (跟"同类症状",配合, 配合 v1.3.0 模式 一致)
4. 加载 5 default + 5 extended skill 文档
5. 输出 TAKEOVER-REPORT.md (3 件套)
6. 写入 .kallax/inbox/human_feedback/ 等决策者拍板

## Master 节点 (跟 Rule 11,配合, 跟"同类症状",配合)

- ✅ 读 CLAUDE.md + jira/ + scripts/ (只读分析)
- ✅ 派单到 Performer worktree (跟"同类症状",配合, 跟 Rule 16 Step 1,配合)
- ✅ 5 levels (L1-L5) (跟"同类症状",配合, 跟 Rule 11 v2.1,配合)
- ❌ 写 代码 (跟"同类症状",配合, 跟 Rule 11 硬红线,配合)
- ❌ 写 测试 (跟"同类症状",配合, 跟 Rule 11,配合)
- ❌ 写 文档 (除 CLAUDE.md + confluence/decisions/ 边界文件)

## Subagent 完整流程 (跟 Rule 15/16,配合, 跟"同类症状",配合, 配合 EPIC-056-A 3 阶段,配合)

> v2.0.3 改造: 15 步 → 10 步 (跟"流程效果 > 流程表演",配合, 配合 EPIC-056-A 5→3 阶段,配合)

```
1. 拆 worktree + 加载 ticket (Rule 15, 跟"同类症状",配合 — 行为准则第一条, 合并原 1+2)
2. 加载 目标专家 profile + 深度分析 (v1.3.0 Onramp 模式, 合并原 3+4, 跟"同类症状",配合)
3. Phase 1 Conductor 全局扫描 (原 Architect + Conductor 合并, 配合 EPIC-056-A,配合)
4. 写 执行计划 (跟"同类症状",配合, 跟 Rule 9,配合, 跟 IMPLEMENTATION-PLAN.md,配合)
5. TDD 写测试 + 写 代码 (合并原 6+7, 跟"同类症状",配合, 跟 Rule 9 L1+L2,配合)
6. 跑 全套测试 (跟"同类症状",配合, 跟 Rule 9 L3+L4,配合, 配合 EPIC-056-B 3 KPI,配合)
7. Phase 2: 4 default 专家 + 5 extended 扩展 并行 review (合并原 9+10, 配合 v1.2.4 5 扩展组,配合)
8. Phase 3: Master 仲裁 + 写 LESSONS-LEARNED.md (合并原 11+13, 跟 Rule 11 v2.1,配合)
9. 报 PASS (配合 EPIC-055-B 3 级路由 联动, P0/P1/P2 分流, 写 pass-report JSON)
10. Conductor merge / 退回修 (合并原 14+15, 跟 Rule 1,配合)
```

### 3 阶段治理说明 (配合 EPIC-056-A,配合, 跟"诚实修正评估",配合)

- **Phase 1 Conductor 全局扫描**: 原 5 阶段 Phase 1 (Architect) + Phase 3 (Conductor 汇总) 合并, 治协调开销. 1 份全局扫描报告.
- **Phase 2 4+5 专家并行**: 4 default (Backend/Frontend/UX/Product) + 5 extended (security-tool-bypass/process-engineering/auditor/compliance/decision-gate) 0 增 0 删, 并行执行.
- **Phase 3 Master 仲裁 + 决策者拍板**: Master 收 9 份报告 → 合并 → 仲裁 → 决策者按 055-B 拍板分级 P0/P1/P2 拍板.

**15→10 步净价值**: 62.5% → 65%+ (配合 EPIC-056-B 3 KPI 完整完成).

## A+B Review (跟"同类症状",配合, 配合 v1.2.4 5 扩展组,配合, 跟"诚实修正评估",配合, 配合 EPIC-056-A 3 阶段,配合)

详细: `docs/process/A-B-REVIEW.md`

## Smoke Retention Policy (EPIC-174, 配合)

**来源**: loopx AGENTS.md Smoke Retention Policy (借鉴)
**拍板**: 主公 2026-08-05 Phase 5 D

**5 条保留规则** (详细: `docs/process/smoke-retention-policy.md`):

1. **Rule 1**: 保留 shipped CLI/runtime behavior
2. **Rule 2**: 保留 reusable control-plane contract
3. **Rule 3**: 保留 public/private boundary enforcement
4. **Rule 4**: 保留 regression that stranded automation
5. **Rule 5**: >=500 行 smoke 拆 / aggregate 替代

**Scanner**: `scripts/check-smoke-retention.sh` (exit 0=PASS/1=FAIL/2=BLOCKED-env)
**Report**: `scripts/audit/smoke-size-report.sh`

> v2.0.3 EPIC-056-A 改造: A+B review 合并为 Phase 2 (4+5 专家并行), 不再是"先 A 后 B" 串行.

---

**跟决策者 §2 explicit 拍板,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟 Rule 11/14/15/16,配合, 跟"流程逻辑 > 扩充配置" 战略 一致, 配合 EPIC-055-B 拍板分级,配合, 配合 EPIC-056-A 3 阶段,配合, 配合 EPIC-056-B 3 KPI,配合**