# KALLAX - Claude Code Integration

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor v1.0.0

---

## 📖 术语参考 (跟 Rule 5 DRY 联合)

术语/黑话/概念的 唯一真相来源 → [docs/KALLAX-GLOSSARY.md](docs/KALLAX-GLOSSARY.md)

- 元术语 ([反讽](docs/KALLAX-GLOSSARY.md#1-元术语-meta--描述-kalax-自身行为) / 诚实修正 / 独立 / 闭环 / 联合)
- 战略/方向 ([流程逻辑 > 扩充配置](docs/KALLAX-GLOSSARY.md#2-战略--方向术语-strategy) / 反哺框架 / 翻篇&精进)
- 流程/工作流 ([对策 A+B+C](docs/KALLAX-GLOSSARY.md#3-流程--工作流术语-workflow) / Master 强验证 6 维度 / 4-Level / 5 步强制流程 / 飞轮反哺)
- 反模式 ([KPI falsification](docs/KALLAX-GLOSSARY.md#4-反模式--黑名单术语-anti-patterns--blacklist) / verbatim / scope creep / 越界反向 / 3 假 PASS)
- 角色/决策 ([3 模式](docs/KALLAX-GLOSSARY.md#6-角色--决策术语-roles--decisions) / Conductor 不能越界 / Master 接管 / Performer sub-role)
- 量化/指标 ([Rule 升级率](docs/KALLAX-GLOSSARY.md#7-量化--指标术语-metrics) / 净价值 / 1+2/1+4 容量)
- 工程 ([Skill 文档](docs/KALLAX-GLOSSARY.md#8-落地--工程术语-engineering) / worktree 隔离 / atomic write / file-lock / BE-7 修复)

---

## 身份确认

**首次进入时必须确认角色：**

1. 检查 `.kallax/state/instance_config.yml` 中的 `role:` 字段
2. 或运行 `/kallax-start` 自动检测

| | Conductor | Performer |
|---|---|---|
| **职责** | 分析/拆解/审核/合并/发布 | 领取/开发/测试/提交PR |
| **分支权限** | miao ✅ (只读分析), testing ✅ (merge), feature ❌ | feature ✅ (开发), miao ❌, testing ❌ |
| **写代码** | ❌ 禁止 (只读分析+协调) | ✅ 在 feature worktree 中 |
| **规则文档** | [ROLE-RULES.md](docs/ROLE-RULES.md) | [ROLE-RULES.md](docs/ROLE-RULES.md) |

### 分支管线

```
feature/<name> ──merge──→ testing ──promote──→ miao
 (Performer 开发)      (集成测试)      (Conductor 发布)
```

- **miao**: 生产就绪，git hook 保护。Conductor 只能分析/review/merge，不能写代码。
- **testing**: 集成验证。Conductor 合并 feature 到此并运行全量测试。
- **feature/***: 隔离开发。Performer 在 worktree 中开发+测试。

---

## 核心原则

### 1. 并行隔离强制化 (KALLAX P0)

**教训**: 历史项目中多 Agent 并行修改同一文件导致冲突

```bash
# ✅ KALLAX 强制要求
kallax task:claim TASK-001  # 自动创建 worktree 隔离
kallax isolation:check TASK-001 TASK-002  # 检测文件重叠
```

**红线**:
- 每个 Performer 必须在独立 worktree 中工作
- Conductor 派发前必须检查文件范围无重叠

### 2. 错误处理严格化 (KALLAX P0)

**教训**: 历史项目中 28 处 `expect()` 在生产代码中导致 panic

```rust
// ❌ 禁止
let result = operation().expect("should not fail");
// ✅ KALLAX 强制
let result = operation().map_err(|e| KallaxError::Operation { source: e })?;
```

**红线**:
- 生产代码禁用 `expect()`/`panic!()`/`unwrap()`
- 所有错误必须通过 `Result<T, E>` 传播
- CI 自动扫描违规

### 3. 产出验证机制 (KALLAX P0)

**教训**: background agent 报告"完成"但实际零产出

```bash
kallax verify:output TASK-001  # ls -la + git show + npm test
```

**红线**:
- Conductor 必须验证产出真实性后才能 Approve
- 禁止仅依赖 Agent 自述

### 4. 资源管理规范化 (KALLAX P1)

**教训**: 缓存无 TTL 导致内存泄漏

```typescript
// ❌ 禁止
const cache = new Map<string, Data>();
// ✅ KALLAX 强制
const cache = new LRUCache<string, Data>({
  max: 1000,
  ttl: 5 * 60 * 1000  // 必须配置 TTL
});
```

### 5/8. 类型安全强制化 + Rule of 500 (KALLAX P1) — EPIC-058-E v2.7.5 master explicit A 拍板合并 Rule 5+8

> **合并理由**: 类型安全 + Rule of 500 都是"代码质量 强制化" 主题, 落地检查脚本不变 (`scripts/check-pr-size.sh --check-rule-of-500` + TypeScript strict mode), 仅 CLAUDE.md Rule 文本合并. 净减 1 Rule (22 → 21). 跟 v2.0.5 EPIC-051 24→22 合并 模式 一致, 跟 v2.4.0 反思 revert 教训 一致 (合并不 删落地脚本, 不 制造 "0 实际变化 假动作").

**教训 (类型安全)**: 46 处 `any` 类型, 清理后发现 3 个运行时错误.

```typescript
// ❌ 禁止
function process(data: any): any { }
// @ts-ignore
// ✅ KALLAX 强制
function process(data: unknown): Result<ProcessedData, ProcessError> {
  if (!isValidData(data)) {
    return err(new ProcessError('Invalid data'));
  }
}
```

**教训 (Rule of 500)**: 一次 PR 净变更 > 500 行 = 0 实际变化 假动作 + Rule 数 通胀 迷信. 跟 v2.4.0+v2.4.1 8 release 累计 跟单 ticket 跨 release 失焦 联合.

**规则 (Rule of 500, 4 档分级)**:

| 档位 | 范围 | 行为 |
|------|------|------|
| silent | ≤ 100 | PASS (跟 EPIC-059-C PR ~100 行 联合) |
| acceptable | 100-500 | PASS (跟 eket Rule 9 阈值 一致) |
| codemod_hint | 500-1000 | FAIL + 提示 codemod 或 `Approved-Large-PR-By: <主公 explicit 拍板者>` |
| reject | 1000+ | FAIL + 拒绝 commit + 推荐 EPIC 拆分 |

**落地检查**: `bash scripts/check-pr-size.sh --check-rule-of-500` + `.git/hooks/pre-commit` Check 3 + TypeScript strict mode + `tsconfig.json` `strict: true`.

**跟 9 Hard Rules 模式 联合**: Rule 5/8 升级 (跟 EPIC-059-A 22 Rule → 9 类别 group 索引 联合, 0 删 Rule, 0 增 Rule, Rule 5/8 file:line 1:1 映射).

**跟 Rule 12 decision-gate 联合**: 3 模式 decision-gate (coder/reviewer/owner) → 500-1000 档 owner 可豁免 (注释 `Approved-Large-PR-By: <name>`).

**红线**: ❌ 净变更 > 1000 行 无豁免 强行 commit, ❌ 跳过 `--check-rule-of-500` 直接 commit, ❌ TypeScript `any` / `@ts-ignore` 绕过 strict mode, ❌ PR 跟 strict type check 分离 (双 FAIL 必须, 互为 互补)

**来源**: EPIC-058-E (主公 explicit A 拍板合并 Rule 5+8, 2026-06-19) + EPIC-059-B (主公 2026-06-18 '同意建议, 需要都建卡并行处理' explicit 派单 Rule of 500, 跟 v2.6.0 经验教训 整理 release 联合) + v2.0.5 EPIC-051 24→22 合并 模式 (借方法论 不借代码) + eket template/docs/MASTER-RULES.md §6 Rule 8 + KALLAX-GLOSSARY §1.1 反讽

### 6/7. 经验沉淀强制化 + PHASE 闭环 review (KALLAX P0) — EPIC-058-E v2.7.5 master explicit A 拍板合并 Rule 6+7

> **合并理由**: 经验沉淀 (EPIC 交付四件套) + PHASE 闭环 review (升级闭环) 都是"经验沉淀" 主题, 落地检查脚本不变 (`check-fact-forcing-preflight.sh` + `LESSONS-LEARNED.md` 草稿), 仅 CLAUDE.md Rule 文本合并. 净减 1 Rule (21 → 20). 跟 v2.0.5 EPIC-051 24→22 合并 模式 一致, 跟 v2.4.0 反思 revert 教训 一致 (合并不 删落地脚本, 不 制造 "0 实际变化 假动作").

**教训**: EPIC 完成后只 merge 不沉淀 = 知识黑洞, 下一个 EPIC 重复踩坑. 经验教训只沉淀不升级 = 单点案例, 不形成组织能力. EPIC + PHASE 双层闭环 = 跨 release 累计 治理能力.

**红线 (4 件套 EPIC 交付, 每个 EPIC close 前必走完)**:

1. **A+B 2-Group 对抗 review**
   - A 组 (Forward): AC 合规 + 代码质量 + 集成
   - B 组 (Attack): 安全 + 边界 + 攻击面
   - 修复后 master 仲裁 APPROVE/REJECT, 留 `review:` 字段在 ticket.json
2. **文档更新**
   - `jira/tickets/EPIC-XXX/README.md` 更新实施记录
   - `jira/epics/EPIC-XXX/epic.json` 更新 ticket 状态
3. **经验教训草稿**
   - EPIC 最后 commit 必包含 `jira/epics/EPIC-XXX/LESSONS-LEARNED.md` 草稿 (master 终审后才 merge)
   - 包含: 量化指标, 关键事件时间线, 教训 (按类别), 评估, 下一步
   - **模板** (跟 `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md` v1 联合, 8 节结构, 跟 v1.2.4 EPIC-016 postmortem 模式 一致)
   - **跨期累计**: 跟 `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (1012 行) 1:1 验证 (跨 release 累计 v2.0.3 → v2.7.1 沉淀, 跟 §1-§15 11 sections 联合)
4. **LESSONS-LEARNED 终审**
   - master 审批时检查草稿是否存在且合规
   - master merge 前确认 lessons 已更新

**PHASE 闭环 review 触发**: 每完成 3-5 个 EPIC, 或阶段目标达成 (master 决定), 触发 PHASE 闭环 review.

**PHASE 流程**:

1. **Phase 1 (Architect)**: 全局扫描本 phase 所有 EPIC 的 LESSONS-LEARNED.md, 分类: 量化/流程/技术/治理
2. **Phase 2 (5 专家并行)**: Backend/Frontend/UX/Product/Security 各自找漏洞/纠错/合并
3. **Phase 3 (Master 仲裁 + 升级)**:
   - 查漏补缺, 纠错, 归纳合并, 升级到 CLAUDE.md / confluence/architecture/
4. **Phase 4 (主公审批)**: 升级项需主公决策

**产出物**: `confluence/decisions/PHASE-XXX-REVIEW-XXX.md` + CLAUDE.md 修订 + confluence/architecture/

**禁止**:
- ❌ A+B review 跳过, 直接 APPROVE
- ❌ 文档只在 commit message 写
- ❌ 经验教训放在 commit message (会被淹没)
- ❌ EPIC 最后 commit 不带 LESSONS-LEARNED 草稿
- ❌ 经验教训只 review 不升级, 升级到 CLAUDE.md 没经过主公审批

**v2.4.1 还原 跟 v2.3.0 一致, 跟 PHASE-013-REFLECTION 联合 治根 "0 实际改变 假动作"**: 4 件套 + PHASE 双层闭环 = 跨 release 累计, 跟"翻篇&精进" 战略 一致.

**UP-3 (EPIC-025-C) 强化 (0 增 Rule 持平)**: 在 Rule 6/7 既有 4 件套 + LESSONS-LEARNED 草稿 (跟 "翻篇&精进" 战略 联合) 基础上, 显式加 模板 引用 (`confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md` v1) + 跨期累计 1:1 验证 引用 (`confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` 1012 行, 跟 §1-§15 11 sections 联合). 净 Rule 数 不变 (跟 v2.4.0+v2.4.1 反思 联合, 治根 "Rule 治 Rule 通胀", 跟 "翻篇&精进" + "诚实修正" 2 战略 一致).

**来源**: EPIC-058-E (主公 explicit A 拍板合并 Rule 6+7, 2026-06-19) + EPIC-025-C (UP-3 LESSONS-LEARNED 草稿强制, 显式 模板 + 跨期累计 1:1 验证 引用, 0 增 Rule 持平, 跟 v2.4.0 反思 联合) + v2.0.5 EPIC-051 24→22 合并 模式 (借方法论 不借代码) + PHASE-013-REFLECTION-2026-06-18.md (治根 "0 实际改变 假动作") + v2.4.0 反思 revert 教训 (合并不 删落地脚本)

---

### 7. PR ~100 行上限 (KALLAX P1) — 跟 eket MASTER-RULES.md §6 Rule 9 联合 (EPIC-059-C v2.7.0)

**教训**: 单 PR 行数过多 = review 成本指数增长 + 隐藏实际变化. 跟 v2.4.0+v2.4.1 8 release 累计 跟单 ticket 跨 release 失焦 联合. PR 100 行 是 单 PR 粒度 (严), Rule of 500 是 净变更 粒度 (松), 2 档 互为 互补.

**规则**: 单 PR 行数 ≤ 100 行 (跟 eket MASTER-RULES.md §6 Rule 9 阈值 一致). 4 档分级:

| 档位 | 范围 | 行为 | 跟 Rule of 500 联合 |
|------|------|------|---------------------|
| silent | ≤ 100 | PASS (理想, silent pass) | Rule of 500 也 silent |
| warn | 100-300 | WARN + 建议拆分 | Rule of 500 acceptable (PASS) |
| warn-strong | 300-500 | WARN-STRONG + 提示 codemod 或 `Approved-Large-PR-By: <主公 explicit 拍板者>` | Rule of 500 acceptable (PASS, 但 PR 粒度 严 阻止) |
| fail | 500+ | FAIL + 跟 Rule of 500 联合 fail | Rule of 500 codemod_hint / reject |

**互为 互补 (粒度 分离)**:
- PR ~100 行 是 **单 PR 行数** 粒度 (PR 视角, 严)
- Rule of 500 是 **净变更 行数** 粒度 (commit 视角, 松)
- 例: PR 400 行 → PR ~100 WARN-STRONG (阻止 commit) + Rule of 500 PASS (净变更 < 500 不阻止)

**落地检查**: `bash scripts/check-pr-size.sh --check-pr-100` + `.github/workflows/pr-size-check.yml` GitHub Actions + `bash tests/integration/check-pr-100-test.sh`

**跟 9 Hard Rules 模式 联合**: Rule 9 升级为 "PR ~100 行上限" (跟 EPIC-059-A 22 Rule → 9 类别 group 索引 联合, 0 删 Rule, 0 增 Rule, Rule 9 file:line 1:1 映射).

**跟 Rule 12 decision-gate 联合**: 3 模式 decision-gate (coder/reviewer/owner) → warn-strong 档 owner 可豁免 (注释 `Approved-Large-PR-By: <name>`).

**红线**: ❌ PR > 500 行 无豁免 强行 commit (跟 Rule of 500 联合 fail), ❌ 跳过 `--check-pr-100` 直接 commit, ❌ 混淆 PR 行数 vs 净变更 粒度 (双 FAIL 必须, 互为 互补)

**来源**: EPIC-059-C (主公 2026-06-18 '同意建议, 需要都建卡并行处理' explicit 派单, 跟 v2.6.0 经验教训 整理 release 联合) + eket template/docs/MASTER-RULES.md §6 Rule 9 + EPIC-059-B Rule of 500 (互为 互补)

---

### 8. 4-Level Fact-Forcing 强制 (KALLAX P0) — task:complete 前置

**教训**: 4-Level 是 documentation, 不是 enforcement. EPIC-024/028 KPI falsification 3 次强化此教训. EPIC-021 D review P1 实证 "L4 bash 命令引用不存在脚本 = 假完成" 反讽 → 升级 "L4 脚本必须存在" (UP-1, EPIC-025-A).

**规则**: `task:complete <TICKET>` 前必须运行 `check-fact-forcing-preflight.sh <expert.md>`, 全部 L1/L2/L3/L4 通过才能 close ticket. **L4 脚本必须存在**: L4 引用的验证脚本 (`scripts/verify/*.sh` + L4 落地脚本) 必须在文件系统存在 + 可执行, 否则 `task:complete` 拒绝 close ticket.

**L4 脚本存在性 强制 (UP-1, EPIC-025-A, 跟 PHASE-006 UP-1 + EPIC-021 D review P1 联合)**: 治根 "L4 bash 命令引用不存在脚本" 反讽. 跟 `docs/process/9-hard-rules.md` Rule 5 file:line 1:1 映射 (no contradiction, 跟 §2 表 行 32 + §3 Rule 5 反例 行 113 一致). 跟 "翻篇&精进" 战略 联合, 0 增 Rule 持平 (Rule 8 文本升级, 不新增 Rule).

**4 级执行顺序**: L1 存在性 → L2 实质性 → L3 接线正确 → L4 数据流动

**跟 EPIC-053-B 4-Level 证据链 1:1 映射** (跟 docs/process/fact-forcing.md §5.2 联合, EPIC-025-B 落地):
- L1 git-anchor (存在性): 文件存在 + git log anchor 可追溯
- L2 test stdout (实质性): 真实 raw stdout, 不接受 "should work"
- L3 5 扩展组 (接线正确): security + process-engineering + auditor + compliance + decision-gate
- L4 独立见证 (数据流动): master 独立验证 + integration test raw output

**集成验证**: `bash scripts/verify/test-fact-forcing-preflight.sh` (13/13 PASS, 跟 EPIC-059-D Fact-Forcing 1:1 验证)

**L4_script_exists 检查 (5 工具 preflight)**: `check-fact-forcing-preflight.sh` emit `L4_script_exists: PASS/FAIL`, 集成 `scripts/verify/master-6d-checkpoint.sh` + `scripts/verify/auditor-checkpoint.sh` 输出. 缺任一 L4 引用脚本 = FAIL + ticket 不 close.

**落地检查**: `bash scripts/verify/check-fact-forcing-preflight.sh` (6 checks: l3-l4-consistency / 3 anti-fab tools / l3l4 self-test x2 / smoke run x2) + `bash scripts/check-anti-patterns.sh .` (7 anti-patterns 扫描, 跟 v2.7.4 B5.1 治根 联合) + `bash scripts/verify/check-scope-creep.sh <TICKET>` (file_scope.includes 强制).

**Anti-Fabrication 子规则 (9a/9b/9c/9e/9f)**:

- **9a [P0] KPI 估数算 FAIL**: "M1 ~60-70%" / "约 80%" / "PARTIAL" / "around" / "approximately" / "估计" / "roughly" / "should" 都算 KPI falsification. 必须精确 X/Y 一位小数. 防御: `scripts/verify/check-kpi-precision.sh` 必跑
- **9b [P0] Test case verbatim 触发 = FAIL**: 把测试需求整句塞 trigger 字段 = 100% circular match. 防御: `scripts/verify/check-test-case-isolation.sh`
- **9c [P0] Scope creep 必拆 PR**: file_scope.includes 外的文件改动 = scope creep. 防御: `scripts/verify/check-scope-creep.sh`
- **9e [P0] Performer 工具调用自验证 = FAIL**: Edit 后未 grep 验证 / git commit 后未 log 验证 SHA 真变 / test 后未看 stdout 验证. 防御: Performer 工具调用后必自验证
- **9f [P1] Tier-Domain 一致性 = FAIL**: default tier 必须用 {architect, backend, frontend, ux, product, security, pm} 中之一. 防御: `python3 scripts/expert-quality-audit.py --enforce-tier-domain`

**红线**: ❌ 跳过 preflight 直接 close ticket, ❌ preflight FAIL 但仍 close ticket, ❌ L4_script_exists FAIL 仍 close ticket (跟 L4 脚本必须存在 联合 红线), ❌ KPI 估数/verbatim/scope creep 任一绕过, ❌ L4 引用脚本缺失 但 不补占位 直接 commit (跟 EPIC-021 D review P1 实证 联合)

### 9. Anti-Fabrication 强制 (KALLAX P0) — 全 commit 前置

**规则**: 所有 commit 前必跑 3 anti-fab 工具, 集成在 pre-commit hook 强制执行:

| 工具 | 防什么 |
|---|---|
| `scripts/verify/check-test-case-isolation.sh` | Test case verbatim 在 trigger 字段 |
| `scripts/verify/check-kpi-precision.sh` | KPI 估数/模糊报 PASS |
| `scripts/verify/check-scope-creep.sh` | file_scope 超界改动 |

**集成**: `.kallax/hooks/pre-commit` 必跑 3 工具, 任一 FAIL = 拒绝 commit.

**跟 Rule 8 4-Level Fact-Forcing 强制 联动**: `task:complete <TICKET>` 前必跑 `scripts/check-fact-forcing-preflight.sh <expert.md>` (跟 Rule 8 file:line `CLAUDE.md:226` 联合). 集成测试: `bash scripts/verify/test-fact-forcing-preflight.sh` (13/13 PASS, 跟 EPIC-059-D Fact-Forcing 1:1 验证 + EPIC-053-B 4-Level 证据链 L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证 联合).

**红线**: ❌ 跳过 3 anti-fab 工具, ❌ pre-commit hook 改 Bypass, ❌ 估数/verbatim/scope creep 任一造假, ❌ 跳过 check-fact-forcing-preflight.sh 直接 close ticket (跟 Rule 8 联合 红线)

### 10. Master 写代码禁令 (KALLAX P0) — 主公原话硬红线 (v2.4.1 还原 跟 v2.3.0 一致, 跟 PHASE-013-REFLECTION 联合 治根 "边界失焦")

**教训**: 主公 2026-06-09 原话: "除了极端情况, master 不许写代码". 之前 Rule 11 写得过宽, 收回.

**规则**: **Master 默认禁止写代码** (含 commit / edit / write), 不分场景. 唯一例外是"极端情况", 且必须**主公明确指令**.

**极端情况定义** (满足任一即触发, 但仍需主公明确指令才执行):
1. **Token Plan 限撞墙**: 5h cap reached, 派不出 Performer
2. **生产事故 (miao 已损坏)**: critical security incident
3. **Performer 派单全 fail + 主公拍板接管**: ≥ 3 个 Performer 接连 API error
4. **主公明确指令**: "你来干" / "你来 fix" / "master 接管 X"

**不构成"极端情况"的反例**: ❌ Performer 1 次 API error (token 重置), ❌ Performer 跑 4h 仍无 commit, ❌ Performer 报 PASS 但 Master 验证 FAIL, ❌ Master 觉得 Performer 跑太慢

**极端情况执行流程**:
1. Master 在主公面前**明确汇报** (理由 + 范围 + 估时)
2. 主公**明确指令** ("你来干" / "你来 fix")
3. Master 才执行, commit message 写 "Master corrective integration under 主公 explicit 授权: [理由]"
4. 4-Level + A+B review 走 Performer 自审路径
5. 事后必须在 LESSONS-LEARNED 标 "极端情况触发"

**bypass 条件** (Performer design 阶段专用): `KALLAX_BYPASS_SCOPE_CHECK=1` 短路 scope 检查 (Master 自修不受 bypass)

**红线**:
- ❌ 任何场景下 Master 默认禁写代码
- ❌ 不因 "Performer 失败" / "Performer 慢" / "Master 觉得简单" 接管
- ❌ 不接管 > 1 个 Performer 任务 / session
- ❌ 不创建新 feature 分支 / 改 miao production / 跨 worktree
- ❌ 不 commit 缺 "Master corrective" 标识

**v2.1 Master Performer report 强验证 checklist**:
- **L1**: `git log --oneline -1` 看 SHA 真变
- **L2**: `git show HEAD:file | grep "期望"` 看内容真改
- **L3**: 跑全量 E2E
- **L4**: 跑 `scripts/verify/check-commit-amend-verify.sh` 4 PASS

### 11. 质量 ensure 强制 (KALLAX P1) — expert > 50 必跑 audit (v2.4.1 还原 跟 v2.3.0 一致)

**规则**: expert > 50 时必跑 `scripts/expert-quality-audit.py` 5 维度 (Schema/Tier-Domain/M1/Trigger/Domain). 触发: 飞轮"迭代"阶段转换, Merge 前置, Index 变更.

**红线**: ❌ expert > 50 但未跑 audit 就 merge, ❌ M1 填估数 ("~60%"/"约 80%"/"PARTIAL"), ❌ Trigger 字段直接复制 test case 文本

### 12. 3 模式决策权分配 (KALLAX P0) — 主公原话 2026-06-09 (EPIC-029-I v2.7.0 升级 决策权矩阵)

**规则**: 3 模式 = `ai-auto` (AI 自主 + block/danger 停下问) / `ai-copilot` (默认, 简单自主 + 复杂协商) / `manual` (主公确认每阶段).

**生效范围**: Performer + Conductor (Master 不受控, 跟 Rule 10/13 联动).

**模式存储** (跟 EPIC-029-A state.json mode_lock 联合): 每个 session_start 选一次, 写入 `.kallax/state/state.json`:
```json
{ "role": "performer", "mode": "ai-copilot", "mode_set_at": "ISO8601", "mode_lock": true }
```
- `mode_lock` 防热切换: 同一 instance 同时只能持有 1 个 mode, 避免多 session 冲突
- 热切换需 `/kallax-init --mode X` 重启 session (state.json file:line `state.json` schema EPIC-029-A)

**决策粒度矩阵 (3 模式 × 4 维度)**:

| 维度 | ai-auto | ai-copilot | manual |
|---|---|---|---|
| **Block 决策 (5 类)** | 停下问 | 停下问 | 停下问 |
| **危险操作 (3 类)** | 停下问 | 停下问 | 停下问 |
| **Performer 失败/超时** | 停下问 (重试/换人/接管) | 停下问 | 停下问 |
| **Performer 5 阶段切换** | AI 自主 | 简单 AI 自主 / 复杂 协商 | 主公确认每阶段 |

**Block 决策 (5 类, 3 模式都触发)**:
1. `block.ambiguous_options` — 多个选项无明显最优 (AC 模糊/选型争议/多种实现路径, TrustScore 无法选)
2. `block.performer_failure` — Performer 失败/超时/3 次 retry (API error/30min 超时)
3. `block.rule_exception` — 规则冲突/Exception 请求 (跟 Rule 1-12 冲突需主公拍)
4. `block.epic_critical` — EPIC 交付关键节点 (PHASE review/Rule 升级/EPIC close)
5. `block.high_impact` — 可能有重大影响/风险 (兜底类)

**危险操作 (3 类, 3 模式都停下问)**:
1. `danger.miao_modify` — 修改 miao 分支 (commit/push/merge)
2. `danger.security_failing` — 安全相关 (pre-commit FAIL/anti-fab FAIL/4-Level FAIL/凭据变动)
3. `danger.data_destruction` — rm -rf / reset --hard / push --force / worktree drop / db drop

**Performer 5 阶段复杂度 (ai-copilot 默认行为)**:

| 阶段 | ai-copilot 行为 | 复杂度 |
|---|---|---|
| `claim` | AI 决定是否 claim | 简单 (AI 自主) |
| `analysis` | 停下协商 (技术方案/选型争议) | **复杂 (协商)** |
| `in_progress` | AI 决策实现细节 | 简单 (AI 自主) |
| `test` | 停下协商 (测试是否充分/PASS) | **复杂 (协商)** |
| `review` | 停下协商 (PR 合并/修 feedback) | **复杂 (协商)** |

**落地** (跟 PROCESS.md 3 模式 + 决策权 1:1 验证, 跟 `docs/process/9-hard-rules.md` 索引 1:1 验证):
- `scripts/performer/stage-gate.sh` (传 STAGE, 5 阶段分流, EPIC-029-B)
- `scripts/permission/decision-gate.sh` (block.5 + danger.3 检查, EPIC-029-C)
- `scripts/permission/mode-set.sh` (mode 验证 + 写 state.json + mode_lock, EPIC-029-A)
- `.kallax/hooks/session_start.sh` (MODE 选择菜单, EPIC-029-D)
- `kallax-init.sh --mode X` (CLI 入口, EPIC-029-F)
- pre-commit hook 串联 decision-gate.sh (跟 Rule 9/10 联动)

**审计**: `.kallax/audit/decision-YYYY-MM-DD.jsonl` 每日轮转 (JSONL 格式, jq -n 构造), 记录 block/danger 命中 + 决策结果.

**设计文档**: [`docs/superpowers/specs/2026-06-09-kallax-3-modes-design.md`](docs/superpowers/specs/2026-06-09-kallax-3-modes-design.md) §1-§10
**实施计划**: [`docs/superpowers/plans/2026-06-09-kallax-3-modes.md`](docs/superpowers/plans/2026-06-09-kallax-3-modes.md)
**1:1 验证**: `docs/process/9-hard-rules.md` 类别 7 决策与模式 + `docs/process.md` Subagent 完整流程 步骤 6-7
**集成测试**: `tests/integration/3-modes-e2e.sh` 16 场景 (3 模式 × 4 维度, EPIC-029-H, 16/16 PASS)

**红线** (4 条):
- ❌ 跳过 decision-gate.sh 自行决定危险操作
- ❌ 跳过 stage-gate.sh 在 5 阶段复杂步骤独断
- ❌ 运行时热切换 mode (需 restart session, mode_lock 防绕过)
- ❌ mode_lock 文件被绕过直接写 state.json (防 mode 状态多 session 改冲突)

**扩展 (EPIC-054-D 合并 Rule 33)**: decision-gate.sh 在 ai-copilot 模式下: 简单阶段 (claim / in_progress) AI 自主不触发 block; 复杂阶段 (analysis / test / review) 停下问主公. 落地脚本: `scripts/permission/decision-gate-complex-only.sh` + `scripts/performer/stage-gate.sh` (传 STAGE). 红线: ❌ ai-copilot 模式在简单阶段触发 block, ❌ decision-gate.sh 不区分 mode + stage.

---

## 命令速查

### 斜杠命令
```bash
/kallax-start                 # 启动角色选择
/kallax-claim                 # 领取任务（快速）
/kallax-status                # 查看当前状态
/kallax-save                  # 保存会话状态
/kallax-resume                # 恢复会话
/kallax-office-hours          # 需求分析六问
/kallax-submit-pr             # 提交 PR
/kallax-review-pr             # 审核 PR
/kallax-help                  # 显示所有命令
```

### CLI 命令
```bash
kallax task:claim [TASK-NNN]        # 领取任务
kallax task:complete TASK-NNN       # 完成任务
kallax conductor:heartbeat          # Conductor 心跳
kallax performer:poll               # Performer 轮询
kallax system:doctor                # 系统诊断
```

---

## 工作流

### Conductor 心跳 5 问

```
Q1: 任务优先级？（扫描 inbox + backlog）
Q2: Performer 状态？（超时阈值 = min(预估/10, 30min)）
Q3: 项目进度？（Milestone vs done）
Q4: 阻塞决策？（写入 inbox/human_feedback）
Q5: 消息队列？（处理 shared/message_queue）
```

### Performer 执行流程

```
1. kallax task:claim TASK-NNN
   └── 自动创建 worktree 隔离

2. 开发执行
   └── TDD 流程（先测试）
   └── 按 Ticket AC 编码
   └── 分步 commit

3. kallax task:complete TASK-NNN
   └── Saga 5 步原子提交

4. 等待 Conductor Review
   └── 处理反馈
   └── 重新提交
```

---

## 禁止操作

### Conductor 禁止 (硬规则，git hook + CLI 双重 enforce)
1. ❌ **在 miao 上写任何功能代码**（pre-commit hook 拦截）
2. ❌ 直接 push 代码到 miao（只能通过 testing merge）
3. ❌ 领取任务自己开发（task:claim 仅限 Performer）
4. ❌ 无 CI 绿灯合并
5. ❌ 自我审查 PR
6. ❌ Mock 替代真实验证
7. ❌ 创建 feature 分支做开发（那是 Performer 的工作）
8. ❌ 在 miao 上修改 node/src/、rust/、tests/ 目录

### Performer 禁止 (9 条硬规则)
1. ❌ 合并到 miao/testing（仅 Conductor 可合并）
2. ❌ 审核自己 PR
3. ❌ 跳过测试
4. ❌ magic number（所有常数必须命名）
5. ❌ console.log（仅用 logger）
6. ❌ 忽略 lint 错误
7. ❌ 注释掉代码（改进或删除）
8. ❌ 复制粘贴代码（提取为函数）
9. ❌ 交叉变更（单 PR 单职责）

---

## Fact-Forcing 验证 (4 Level)

```
L1 存在性：文件存在于 diff
L2 实质性：真实逻辑，非 stub
L3 接线正确：正确 import/export
L4 数据流动：集成测试验证

缺任一项 = Reject

证据要求：
✓ 列出引用代码行号
✓ 提供命令执行 stdout
✓ 提供真实测试结果
✗ "应该没问题"（无效）
```

---

## 角色 Session 边界 (主公 2026-06-12 拍, R-NEW 升级红线)

### 13. Conductor 不能越界 Performer 实施 (KALLAX P0) — R-NEW 升级红线 (v2.4.1 还原 跟 v2.3.0 一致, 跟 PHASE-013-REFLECTION 联合 治根 "角色边界失焦")

**教训**: 主公 2026-06-12 拍 "每个角色, 无论 Conductor 还是 Performer 都是独立存在的 session/subagent".

**红线 (硬, 不可 override 日常)**:
- ❌ Conductor session Edit/Write/Commit 代码 (含 ticket 实施, 测试脚本, binary 改, Rust 源码)
- ❌ Conductor session 跑 Performer 工作流 (写 test + 写实施 + 4 anti-fab + push)
- ❌ Conductor spawn Performer session 后越界接 Performer 实施
- ❌ Conductor 改 binary/Rust 源码
- ❌ Conductor 改 .md (除 CLAUDE.md 跟 confluence/decisions/ 边界文件)

**唯一豁免**: 跟 Rule 11 联动 (Token 限撞墙 / miao 已损坏 / ≥ 3 Performer API error / 主公 explicit 拍)

### 14. Performer Session 自动加载 (KALLAX P0) — R-NEW 升级红线 (v2.4.1 还原 跟 v2.3.0 一致)

**规则**: Performer 角色必须独立 session/subagent, 初始化时根据当前 ticket 加载 CLAUDE.md + ROLE-RULES + ticket.json 上下文. 启用 `bash .kallax/hooks/session_start.sh --role performer` 自动 claim ticket + 建 worktree.

**🚨 行为准则第一条 (主公 2026-06-13 拍)**: 领卡之后第一时间建 worktree, 跟主分支和其他分支隔离.

**红线**:
- ❌ Performer session 跳过 worktree 直接写 miao 主 checkout
- ❌ Performer session 在主 checkout 写文件 (即使 worktree 已有)
- ❌ Performer session 跳 worktree 写 miao
- ❌ Performer session 跳 session_start.sh 直接跑 (无 CLAUDE.md + ROLE-RULES + ticket 上下文)

### 15. Subagent 5 步强制流程 (KALLAX P0) — Phase 7 R-NEW 升级红线 (v2.4.1 还原 跟 v2.3.0 一致, 跟 PHASE-013-REFLECTION 联合 治根 "5 步明确指向")

**教训**: 10 KPI falsification 实证 (Performer-EPIC-036/037 第 9/10 次). 50% 概率假 PASS 模式 (4 subagent: 2 真 + 2 假).

**规则**: Subagent (Conductor + Performer + Auditor) 完工必触发 5 步强制流程, 缺任一 → ticket 状态保持 in_progress + Conductor 不 merge + Master 不 promote.

**5 步强制流程**:

1. **Step 1**: `scripts/conductor/ticket-status-sync.sh` 自动同步 ticket.json
2. **Step 2**: 3 anti-fab (`check-test-case-isolation.sh` + `check-kpi-precision.sh` + `check-scope-creep.sh`)
3. **Step 3**: `check-fact-forcing-preflight.sh` 5 工具 (L1/L2/L3/L4/L4_script_exists)
4. **Step 4**: `scripts/conductor/review.sh` 5 验证
5. **Step 5**: `scripts/master/strong-verify-6d.sh` 6 维度 (L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实)

**红线**: ❌ 跳过 Step 1-5 任一

### 16. 文件并发竞争 5 步强制流程 (KALLAX P0) — Phase 7 R-NEW 升级红线 (v2.4.1 还原 跟 v2.3.0 一致)

**教训**: 主公 2026-06-12 拍 "还有个痛点是相互影响, 同时修改/编辑文件/文件夹引起工作文件的丢失/修改".

**5 步强制流程**:

1. **Step 1**: `scripts/io/file-lock.sh` (flock + git index.lock 同模式)
2. **Step 2**: `scripts/io/atomic-write.sh` (临时文件 + atomic mv)
3. **Step 3**: `scripts/io/conflict-detect.sh` (git diff 比对)
4. **Step 4**: `scripts/conductor/outbox-isolation.sh` (subagent 各 own outbox)
5. **Step 5**: `scripts/master/worktree-state-sync.sh` (Performer commit 必 push)

**红线**: ❌ 跳过文件级锁, ❌ 写半截文件, ❌ 跳过冲突检测, ❌ 写 outbox 路径冲突, ❌ worktree 状态不同步

### 17. KPI Falsification 反模式黑名单 (KALLAX P0) — Phase 7 R-NEW 升级红线

**规则**: Master 强验证 6 维度检测以下反模式, 命中任一 → subagent 报 FAIL.

**10 反模式黑名单**: KPI 估数/模糊 / Test case verbatim / Scope creep / Amend SHA 没变 / 工具调用后未自验证 / 报 PASS 实际 0 commit / 借口"环境问题"/ 借口"估数"/ 借口"删 build fix 假装修完"/ Tier-Domain 不一致

**执行**: Master 强验证 6 维度命中任一 → subagent 报 FAIL + ticket 状态自动同步 + 留 LESSONS-LEARNED 草稿.

### 18. 5 类标签 SOP (KALLAX P1) — EPIC-055-C, 治 A2 咒语化 + A3 笔误

**教训**: 历史项目 50+ 文档含"反讽" 咒语化引用 (无证据链 装饰引用), 跟"诚实修正" 战略 矛盾. 主公 14 问题分析 派单 EPIC-055-C explicit 治根.

**规则**: 5 类标签 (反讽/诚实修正/独立/翻篇/流程逻辑) 引用必须带**证据链 3 件套**:

1. **证据**: `file_path:line_number` OR `commit_hash` (可追溯, 不可无源装饰)
2. **反驳/支持案例**: 具体 case (e.g. EPIC-053-B H1 治根, v1.2.4 5 扩展组 100% 假 PASS)
3. **实际影响**: 实际 可观察 效果 (e.g. 拍板成本↓40%, 假 PASS 率↓ 50%→10%)

**SOP 文档**: [`docs/process/tag-sop.md`](docs/process/tag-sop.md)
**扫描工具**: [`scripts/audit/tag-audit.sh`](scripts/audit/tag-audit.sh) — 5 函数 (scan_tags / validate_evidence_chain / detect_cursed_references / detect_typos / check_sop_compliance)
**TDD 测试**: [`tests/integration/tag-sop-test.sh`](tests/integration/tag-sop-test.sh) — 5/5 PASS (100.0%)

**实测算**:
- 反讽 引用总数 (.md): **350** (KALLAX-GLOSSARY.md 62 / superpowers/specs 54 / CHANGELOG.md 36 装饰重灾区)
- 诚实修正 引用总数: **179**
- 独立 引用总数: **329**
- 翻篇 引用总数: **55**
- 流程逻辑 引用总数: **143**
- 笔误"主公拍 explicit 拍 explicit": **17** 处 (PHASE-REVIEW.md:11, 33 典型)
- SOP 自身: 0 咒语化 (100.0% 合规)

**跟 Rule 5 DRY 联动**: 标签引用去重, 跟"经验沉淀强制化" (`CLAUDE.md:121-147`) 联合.
**跟 EPIC-055-B (主公拍板分级 P0/P1/P2) 联合**: 5 类标签 SOP 本身 = P1 备案, 跟"独立" 拍板 联合.
**跟"诚实修正" + "翻篇&精进" 战略 一致**: 治 A2 咒语化 闭环, 治 A3 笔误 闭环.

**红线**:
- ❌ 5 类标签 引用无证据链 3 件套
- ❌ 任何"跟 X 闭环"/"跟 X 联合"/"跟 X 战略 一致" 装饰引用 (无 file:line)
- ❌ SOP 自身 咒语化 (不双标)
- ❌ 跳过 `scripts/audit/tag-audit.sh` 扫描

**来源**: EPIC-055-C (主公 14 问题分析 A2/A3 explicit 派单, 2026-06-16) + KALLAX-GLOSSARY.md §1.1-1.5 + Rule 5 DRY + "诚实修正" 战略

---

### 9 Hard Rules Rule 6+7 映射: 文档卫生 + 新建前先想 (KALLAX P1) — 跟 eket MASTER-RULES.md §6 联合 (EPIC-059-G v2.7.0)

**教训**: v2.4.0 反思 "0 实际变化 假动作" + "文档碎片化" 反讽 → 治根需 "每 10 轮 文档卫生" + "新建前先想" 模式. 跟 v2.6.0 经验教训 整理 release 联合, 跟 KALLAX-GLOSSARY 反哺框架 战略 联合 (文档卫生 = 反哺框架 入口).

**约束**:
- ❌ **0 增 Rule** (跟"翻篇&精进" 战略 一致, 跟 v2.4.1 还原 22 Rule 联合) — 升级 现有 Rule 5/6/11/20 索引映射
- ❌ **0 重写** (跟 Rule 5 DRY 联合)
- ❌ **借方法论 不借代码** (不复制 eket 9 Hard Rules 全文, 跟 EPIC-059-A 模式 一致)
- ✅ 22 Rule → 9 类别 group 索引 (file:line 1:1 映射, 跟 类别 5 行 升级 联合)

#### 文档卫生 (每 10 轮) — 跟 eket §6 Master Hard Rule 6 联合

**触发**: 每 10 轮 Conductor 心跳 Q5 / 每 EPIC 完成 / 每 Sprint 完成 (跟 `docs/PHASE-INDEX.md:87-128` 联合).

**5 项 检查** (跟 `scripts/check-doc-hygiene.sh` 联合, X/Y PASS 格式):

| # | 检查项 | FAIL 阈值 | 跟 KALLAX 现有 Rule 联合 |
|---|---|---|---|
| 1 | **未追踪 md** | `git ls-files --others --exclude-standard docs/ \| wc -l` > 阈值 | Rule 5 DRY (Single Source of Truth) + Rule 20 tag-sop |
| 2 | **僵尸 ticket** | `jira/tickets/*/ticket.json` status=in_progress 跟 claimed_at 间隔 > 7d | Rule 6 经验沉淀强制化 + Rule 11 Anti-Fab |
| 3 | **积压 review** | `outbox/review_requests/*.md` mtime > 3d 未处理 | Rule 17 文件并发竞争 5 步 |
| 4 | **重复文档** | `docs/` + `confluence/` 内容重复 > 阈值 (grep 相似章节) | Rule 5 DRY (Single Source of Truth) |
| 5 | **过期 Rule** | CLAUDE.md 跟 `docs/process/9-hard-rules.md` 一致性 < 95% | Rule 6 经验沉淀 + 9 Hard Rules 索引 |

#### 新建前先想 — 跟 eket §6 Master Hard Rule 7 联合

**触发**: 新建文件/章节/ticket/Rule 前, 必须先回答 **3 问**:

| # | 3 问 | 检查命令 | 跟 KALLAX 现有 Rule 联合 |
|---|---|---|---|
| 1 | **是否有同类文档可更新?** | `grep -rn "<主题>" docs/ confluence/decisions/ 2>/dev/null` | Rule 5 DRY (SoT, 0 重复) |
| 2 | **是否有同类 ticket 可扩展?** | `find jira/tickets -name "ticket.json" -exec grep -l "<主题>" {} \;` | Rule 5 DRY + Rule 6 经验沉淀强制化 |
| 3 | **是否有同类 Rule 可引用?** | `grep -nE "^### [0-9]+\. " CLAUDE.md \| grep "<主题>"` | 9 Hard Rules 索引 (跟类别 5 升级 联合) |

**红线**:
- ❌ 3 问 任意 1 答 "有" 但 未 引用/扩展/更新, 直接新建 = FAIL + 触发 Rule 19 KPI 反模式
- ❌ 跳过 3 问 直接新建 = 跟"借方法论 不借代码" 战略 矛盾 (跟 EPIC-059-A 联合)
- ❌ 文档卫生 检查 FAIL 但 仍 commit 新建 (跟 Rule 11 Anti-Fab 联合)

**落地检查**: `bash scripts/check-doc-hygiene.sh` + `bash tests/integration/doc-hygiene-test.sh` (5/5 PASS)

**跟 KALLAX-GLOSSARY 反哺框架 战略 联合**: 文档卫生 + 新建前先想 = 反哺框架 入口 (跨 release 累计沉淀, 跟 v2.4.0+v2.4.1 反思 闭环)

**来源**: EPIC-059-G (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟 v2.6.0 经验教训 整理 release 联合) + eket `template/docs/MASTER-RULES.md` §6 Master Hard Rule 6+7 + KALLAX-GLOSSARY 反哺框架 + PHASE-013-REFLECTION-2026-06-18.md (治根 "文档碎片化" 反讽) + v2.4.0+v2.4.1 8 release 累计 (0 增 Rule 持平, 跟"翻篇&精进" 一致)

---

## 9 Hard Rules 模式 (跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码, EPIC-059-A v2.7.0)

> **20 Rule → 9 类别 group 索引 (file:line 1:1 映射, 0 删 Rule)**
> **跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信**
> **跟 KALLAX-GLOSSARY §11.1 "Rule 数 ≠ 治理完成" 联合, 跟"翻篇&精进" 战略 一致**
> **详细**: [docs/process/9-hard-rules.md](docs/process/9-hard-rules.md)
> **检查**: `bash scripts/check-9-hard-rules.sh --self-test` + `bash tests/integration/check-9-hard-rules-test.sh`

### 20 Rule → 9 类别 group 索引 表 (EPIC-058-E v2.7.5, master explicit A 拍板 22→20 合并 落地)

| 类别 | 主题 | Rule (file:line 1:1) | 联合 |
|------|------|----------------------|------|
| **1. 隔离与并行 (Isolation)** | worktree / file-lock / session 隔离 | Rule 1 ([CLAUDE.md:50](CLAUDE.md#L50)) + Rule 14 ([CLAUDE.md:430](CLAUDE.md#L430)) + Rule 16 ([CLAUDE.md:458](CLAUDE.md#L458)) | Rule 1 并行隔离强制化 |
| **2. 错误处理与验证 (Error & Verify)** | Result 类型 / 产出真实性 / 4-Level / KPI 黑名单 | Rule 2 ([CLAUDE.md:64](CLAUDE.md#L64)) + Rule 3 ([CLAUDE.md:80](CLAUDE.md#L80)) + Rule 8 ([CLAUDE.md:222](CLAUDE.md#L222)) + Rule 17 ([CLAUDE.md:472](CLAUDE.md#L472)) | Rule 8 4-Level Fact-Forcing |
| **3. 资源与质量 (Resource & Quality)** | TTL 缓存 / expert audit | Rule 4 ([CLAUDE.md:92](CLAUDE.md#L92)) + Rule 11 ([CLAUDE.md:290](CLAUDE.md#L290)) | Rule 4 资源管理规范化 |
| **4. 类型与安全 (Type & Security)** | 严格类型 / Rule of 500 / 工具 bypass / 独立见证 | Rule 5/8 ([CLAUDE.md:106](CLAUDE.md#L106)) + Rule 30 ([CLAUDE.md:641](CLAUDE.md#L641)) + Rule 31 ([CLAUDE.md:647](CLAUDE.md#L647)) | Rule 5/8 类型安全 + Rule of 500 联合 (EPIC-058-E v2.7.5) |
| **5. 经验沉淀 (Lessons Accumulation)** | 4 件套 + PHASE 闭环 + Anti-Fab / 文档卫生 (每 10 轮) / 新建前先想 3 问 | Rule 6/7 ([CLAUDE.md:145](CLAUDE.md#L145)) + Rule 9 ([CLAUDE.md:240](CLAUDE.md#L240)) + [9 Hard Rules Rule 6+7 映射](CLAUDE.md#9-hard-rules-rule-67-映射-文档卫生--新建前先想-kallax-p1--跟-eket-master-rules-md-联合-epic-059-g-v270) (EPIC-059-G v2.7.0) | Rule 6/7 经验沉淀 + PHASE 闭环 联合 (EPIC-058-E v2.7.5) + 9 Hard Rules Rule 6+7 升级 (跟 eket MASTER-RULES.md §6 联合) |
| **6. 角色边界 (Role Boundary)** | Master 禁写 / Conductor 禁越界 | Rule 10 ([CLAUDE.md:254](CLAUDE.md#L254)) + Rule 13 ([CLAUDE.md:417](CLAUDE.md#L417)) | Rule 10 Master 写代码禁令 |
| **7. 决策与模式 (Decision & Mode)** | 3 模式 + decision-gate | Rule 12 ([CLAUDE.md:296](CLAUDE.md#L296), 扩展 [CLAUDE.md:617](CLAUDE.md#L617)) | Rule 12 3 模式决策权 |
| **8. 流程与脚本 (Process & Script)** | PR 尺寸 (Rule of 500 / PR ~100 行) / Subagent 5 步 | Rule 5/8 ([CLAUDE.md:106](CLAUDE.md#L106)) + Rule 7 ([CLAUDE.md:192](CLAUDE.md#L192)) + Rule 15 ([CLAUDE.md:442](CLAUDE.md#L442)) | Rule 5/8 Rule of 500 + Rule 7 PR ~100 行 (EPIC-059-B + EPIC-059-C 互为 互补, EPIC-058-E 合并 Rule 5/8 落地) |
| **9. 标签与治理 (Tag & Governance)** | 5 类标签 SOP | Rule 18 ([CLAUDE.md:480](CLAUDE.md#L480)) | Rule 18 5 类标签 SOP |

**KPI**: 20 Rule → 9 类别 group = **20/20 = 100.0%** 落地 (跟"翻篇&精进" 一致, EPIC-058-E v2.7.5 master explicit A 拍板 22→20 合并), **0 增 Rule** (跟 v2.4.1 还原 联合, 跟"诚实修正" + "反讽" 战略 一致, EPIC-059-C 升级 Rule 9 联合 Rule 8 互为 互补, EPIC-058-E Rule 5+8 合并 + Rule 6+7 合并).

**详细**: 9 Hard Rules 详细 解释 + 反例 + 正例 + 撤销方法 见 [docs/process/9-hard-rules.md](docs/process/9-hard-rules.md).

---

## KALLAX Rules Status (跟 EPIC-054-D + EPIC-058-E + PHASE-013-REFLECTION 联合, v2.7.5 跟 v2.4.1 + EPIC-058-E 22→20 合并 落地)

> **当前 Rule 总数 (active)**: **20** (跟 v2.4.1 还原 一致 base 22 - EPIC-058-E 净减 2 = 20, 跟 v2.0.5 EPIC-051 24→22 合并 模式 一致, 跟 v2.4.0 4 合并 反思 revert 教训 一致 (合并不 删落地脚本, 不 制造 "0 实际改变 假动作"))
> **累计 升级 (实测)**: 10 (R-NEW 14-18 = 5 + v1.2.4 扩展 29-33 = 5)
> **升级率**: 50.0% (10/20, 实测, 跟 EPIC-055-B LESSONS-LEARNED.md 联合, EPIC-058-E 合并后 升级率提升)
> **fatigue_index**: 50.0 (HIGH 阈值 50 触及, 跟"反讽" 联合, 阈值 §10.3 需 重新审视)
> **净价值**: **67.0%** (跟 v1.2.4 baseline 62.5% 联合, 跟 EPIC-056-C Master 6 维恢复 +4.5% 联合, EPIC-058-E 合并 净价值持平 0 实际变化)

### 📋 Rule 合并 实际执行 (EPIC-054-D v2.0.5 + EPIC-058-E v2.7.5, v2.4.1 跟 v2.3.0 一致 22 Rule + EPIC-058-E 22→20 合并)

**状态**: ✅ v2.0.5 主公拍板落地, 3 合并候选 已执行 (净减 -2 Rule). ✅ v2.7.5 EPIC-058-E 主公 explicit A 拍板落地, 2 合并候选 已执行 (净减 -2 Rule, 22 → 20). v2.4.0 4 合并 (v2.4.1 反思 revert) 跟"诚实修正" 联合, 治根 "0 实际改变 假动作" + "Rule 治 Rule 通胀" 迷信. EPIC-058-E 合并 跟 v2.4.0 反思 revert 教训 一致 (合并不 删落地脚本).

**v2.0.5 3 候选** (跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md line 22 联合):

1. **候选 A (P1 备案 → ✅ 执行)**: Rule 30 + 31 → 合并为 Rule 30 "独立见证机制 (含 process engineering + auditor)" (净 -1)
2. **候选 B (P0 必拍 → ✅ 执行)**: Rule 32 → 撤销, 合并到 Rule 5 DRY 框架 + Rule 19 治理 (反讽治根, 净 -1)
3. **候选 C (P1 备案 → ✅ 执行)**: Rule 33 → 合并入 Rule 13 (3 模式决策权) 扩展 (净 0 — 扩展不增 Rule, 内容并入)

**EPIC-058-E v2.7.5 2 候选** (跟 master explicit A 拍板 联合, 跟 v2.0.5 EPIC-051 24→22 合并 模式 一致, 跟 PHASE-013-REFLECTION 合并教训 联合):

1. **候选 1 (P2 → ✅ 执行, master explicit A)**: Rule 5 + Rule 8 → 合并为 Rule 5/8 "类型安全强制化 + Rule of 500" (净 -1, 跟"代码质量 强制化" 主题 联合)
2. **候选 2 (P2 → ✅ 执行, master explicit A)**: Rule 6 + Rule 7 → 合并为 Rule 6/7 "经验沉淀强制化 + PHASE 闭环 review" (净 -1, 跟"经验沉淀" 主题 联合)

**v2.4.0 4 合并 → v2.4.1 revert** (跟 PHASE-013-REFLECTION 联合, 跟主公 'a' explicit 派单 1h 反思 联合):
- ❌ v2.4.0 4 合并 (Rule 7+8, 11+12, 14+15, 16+17) 跟"诚实修正" 联合 反思, 治根 "0 实际改变 假动作" + "Rule 治 Rule 通胀" 迷信
- ✅ v2.4.1 revert 还原 跟 v2.3.0 一致 22 Rule, 0 落地脚本 变化, 0 净价值 损失

**EPIC-058-E 22→20 合并 (跟 v2.4.0 反思 revert 教训 一致, 不重蹈覆辙)**:
- ✅ Rule 5 + Rule 8 合并 → Rule 5/8 (落地脚本 `scripts/check-pr-size.sh --check-rule-of-500` + TypeScript strict mode 不变, 仅 CLAUDE.md Rule 文本合并)
- ✅ Rule 6 + Rule 7 合并 → Rule 6/7 (落地脚本 `check-fact-forcing-preflight.sh` + `LESSONS-LEARNED.md` 草稿 不变, 仅 CLAUDE.md Rule 文本合并)
- ✅ 0 删落地脚本, 0 删 hardcoded reference, 0 删 ticket 实施 模式
- ✅ 净价值 持平 (67.0%, 跟 v2.0.5 + v2.4.0 一致, 避免 "0 实际变化 假动作" 反讽)

**实际净减**: 24 → 22 (v2.0.5, 净减 -2), 净价值 62.5% → **64.0%** (v2.0.5). v2.4.0 4 合并 → v2.4.1 revert 闭环, 净价值 67.0% 持平. EPIC-058-E v2.7.5 22 → 20 (净减 -2), 净价值 67.0% 持平 (不制造 "0 实际变化 假动作").

**诚实修正**:
- v2.0.5 实际 -2 + +1.5% (proposal 写 -3 + +3.0%, 差异原因: 候选 C 是"扩展"而非"删除", 净减为 0)
- v2.4.0 反思 (跟 PHASE-013-REFLECTION 联合): 4 合并 命名 = "Rule 数 减少 净价值 提升", 实际 = 净价值 持平 0 实际变化 = "制造 0 实际改变 假动作" 反讽
- v2.4.1 revert: 0 落地脚本 变化, 0 净价值 损失, 跟"翻篇&精进" 战略 一致
- **EPIC-058-E v2.7.5**: 22 → 20 合并, 净价值 67.0% 持平, 0 删落地脚本, 跟"诚实修正" 联合, 治根 "0 实际变化 假动作" 反讽

**反讽治根**: Rule 32 本身是 Rule, 撤销避免 Rule 治 Rule 通胀 → Rule 数 +1 → 治根动作本身加剧问题. v2.4.0 4 合并 跟 v2.0.10 Rule 32 撤销 是 同样 反讽 模式 ("Rule 治 Rule 通胀"), 跟"反讽" 联合, 需 治根. v2.4.1 revert 跟"诚实修正" 联合, 治根 反讽 模式. EPIC-058-E v2.7.5 合并 跟 v2.4.1 revert 教训 一致 (合并不 删落地脚本), 0 重蹈覆辙.

**KALLAX-GLOSSARY §10.3 阈值 15 重新审视** (跟"反讽" 联合):
- 阈值 15 是 v1.2.4 EPIC-051 经验值, 跟 v2.4.0 现状 不匹配
- 实际证据: 22 Rule (v2.3.0 / v2.4.1) 跟 18 Rule (v2.4.0) 在 净价值 上 没 差异 (67.0% 持平)
- "Rule 数 多" 跟 "问题" 不是 因果关系
- **§10.3 阈值 15 需 重新审视 (KALLAX-GLOSSARY 11.x 扩 候选)**
- 跟"诚实修正" 联合: 阈值 15 没 跟 实际 项目 需求 联合, 需 §10.3 重新审视

**执行前置** (跟 PROCESS.md:25-26 联合):

- ✅ v2.0.5 + v2.4.1 + EPIC-058-E v2.7.5 联合已执行, 主公拍板落地
- ✅ v2.4.0 4 合并 → v2.4.1 revert 跟"诚实修正" 联合, 反思 闭环
- ❌ 未来 Rule 合并需主公拍板 (P0 必拍 + P1 备案)

**详细 proposal**:
- v2.0.5: [`docs/process/rule-merge-proposal.md`](docs/process/rule-merge-proposal.md)
- v2.4.0 → v2.4.1 反思: [`confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md`](confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md)
- EPIC-058-E v2.7.5: [`confluence/decisions/EPIC-058-E-IMPL-2026-06-19.md`](confluence/decisions/EPIC-058-E-IMPL-2026-06-19.md)
**联动 ticket**: EPIC-055-B (主公拍板分级, 已 merged `2b4771c`) + EPIC-058 (5 deferred tickets, EPIC-058-A/B/C/D done, EPIC-058-E v2.7.5 合并 落地 20 Rule)

### 30. 工具不可绕过 (KALLAX P0) — Security Extension 治根因 1

**规则**: 所有 6 硬脚本必须满足: 无 env var toggle bypass, 无 world-writable, 无 symlink attack, self-path resolution, token 验证在 preflight 前.

**红线**: ❌ 任何 6 硬脚本可绕过, ❌ 脚本 world-writable, ❌ `--force-merge` token check 在 preflight 后

### 31. 独立见证机制 (含 process engineering + auditor, KALLAX P0) — EPIC-054-D 合并 Rule 30+31

**规则**: Subagent 报 PASS 前, 必跑独立见证 + 不可篡改 audit log sink:
- **方案 1 (独立见证)**: 必调用 `scripts/process/independent-witness.sh` 生成审计日志 (治根 90%)
- **方案 4 (流程重构)**: audit-log-sink.sh 必跑 BE-7 修复模式 (umask 077 + install -d -m 700 + flock + atomic write + chmod 600), Subagent 报 PASS 必写 audit log sink

**红线**: ❌ Subagent 自报 PASS 不调用 independent-witness.sh, ❌ independent-witness.sh 输出 fail 仍报 PASS, ❌ 不可篡改 audit log sink 缺失, ❌ audit log sink 可被 subagent 写, ❌ audit log sink 无 atomic write

> **历史**: 本 Rule 由 EPIC-054-D v2.0.5 主公拍板合并 Rule 30 (Process Engineering) + Rule 31 (Auditor) — 同一概念两个 aspect, 落地脚本不变 (`audit-log-sink.sh` + `independent-witness.sh`), 仅 CLAUDE.md Rule 文本合并. 净减 1 Rule (24 → 23).

### ~~31. (已合并入 Rule 30)~~

### ~~32. (已撤销 — 见 Rule 5 DRY + Rule 19 反讽治理)~~

**注**: 软约束升级阈值 (Rule 升级率 > 80% 触发审查 / Rule 数量 > 15 触发重构 / 门禁数量 > 10 触发架构评估) 是 软约束, 已在 Rule 5 DRY + Rule 19 治理 框架内体现, 撤销避免 Rule 通胀反讽 (Rule 治 Rule 通胀 → 加 Rule 32 → Rule 数 +1 → 治根动作本身加剧问题).

> **历史**: 本 Rule 由 EPIC-054-D v2.0.5 主公拍板撤销 — Rule 32 本身是 Rule, 反讽地加剧 Rule 通胀. 已合并到 Rule 5 DRY 框架 (Single Source of Truth + 软约束阈值) + Rule 19 (5 类标签 SOP 包含诚实修正). 净减 1 Rule (23 → 22).

#### Rule 14 Extension — 3 模式决策权 + decision-gate 复杂才问 (EPIC-054-D 合并 Rule 33)

**原始 Rule 14**: 3 模式决策权分配 (ai-auto / ai-copilot / manual).

**Rule 33 合并入** (decision-gate 复杂才问, KALLAX P0): decision-gate.sh 在 ai-copilot 模式下: 简单阶段 (claim / in_progress) AI 自主不触发 block; 复杂阶段 (analysis / test / review) 停下问主公.

**落地**: `scripts/permission/decision-gate-complex-only.sh` + `scripts/performer/stage-gate.sh` (传 STAGE).

**红线**: ❌ ai-copilot 模式在简单阶段触发 block, ❌ decision-gate.sh 不区分 mode + stage

> **历史**: 本 Rule 由 EPIC-054-D v2.0.5 主公拍板合并 Rule 13 + Rule 33 — decision-gate 是 3 模式决策权的实施细节, 不应独立成 Rule. 净减 1 Rule (22 → 21).

### ~~33. (已合并入 Rule 13)~~

---

## 详细文档

- [术语词典](docs/KALLAX-GLOSSARY.md)
- [Conductor 规则](template/docs/CONDUCTOR-RULES.md)
- [Performer 规则](template/docs/PERFORMER-RULES.md)
- [反模式集合](template/docs/ANTI-PATTERNS.md)
- [架构白皮书](docs/architecture/FRAMEWORK.md)
- [降级策略](docs/architecture/DEGRADATION-STRATEGY.md)