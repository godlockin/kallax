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

### 5. 类型安全强制化 (KALLAX P1)

**教训**: 46 处 `any` 类型，清理后发现 3 个运行时错误

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

### 6. 经验沉淀强制化 (KALLAX P0) — EPIC 交付四件套

**教训**: EPIC 完成后只 merge 不沉淀 = 知识黑洞, 下一个 EPIC 重复踩坑.

**红线**: 每个 EPIC 交付**必须**走完 4 步才能 close:

1. **A+B 2-Group 对抗 review**
   - A 组 (Forward): AC 合规 + 代码质量 + 集成
   - B 组 (Attack): 安全 + 边界 + 攻击面
   - 修复后 master 仲裁 APPROVE/REJECT, 留 `review:` 字段在 ticket.json
2. **文档更新**
   - `jira/tickets/EPIC-XXX/README.md` 更新实施记录
   - `jira/epics/EPIC-XXX/epic.json` 更新 ticket 状态
3. **经验教训草稿**
   - EPIC 最后 commit 必包含 `jira/epics/EPIC-XXX/LESSONS-LEARNED.md` 草稿
   - 包含: 量化指标, 关键事件时间线, 教训 (按类别), 评估, 下一步
4. **LESSONS-LEARNED 终审**
   - master 审批时检查草稿是否存在且合规
   - master merge 前确认 lessons 已更新

**禁止**:
- ❌ A+B review 跳过, 直接 APPROVE
- ❌ 文档只在 commit message 写
- ❌ 经验教训放在 commit message (会被淹没)
- ❌ EPIC 最后 commit 不带 LESSONS-LEARNED 草稿

### 7. PHASE 闭环 review (KALLAX P0) — 经验升级

**教训**: 经验教训只沉淀不升级 = 单点案例, 不形成组织能力.

**触发**: 每完成 3-5 个 EPIC, 或阶段目标达成 (master 决定), 触发 PHASE 闭环 review.

**流程**:

1. **Phase 1 (Architect)**: 全局扫描本 phase 所有 EPIC 的 LESSONS-LEARNED.md, 分类: 量化/流程/技术/治理
2. **Phase 2 (5 专家并行)**: Backend/Frontend/UX/Product/Security 各自找漏洞/纠错/合并
3. **Phase 3 (Master 仲裁 + 升级)**:
   - 查漏补缺, 纠错, 归纳合并, 升级到 CLAUDE.md / confluence/architecture/
4. **Phase 4 (主公审批)**: 升级项需主公决策

**产出物**: `confluence/decisions/PHASE-XXX-REVIEW-XXX.md` + CLAUDE.md 修订 + confluence/architecture/

**禁止**: ❌ 经验教训只 review 不升级, ❌ 升级到 CLAUDE.md 没经过主公审批

### 8. L4 脚本必须存在 (KALLAX P0) — ticket close 前置条件

**教训**: EPIC-021 D review P1 CRITICAL — 5 角色 L4 引用 `verify-*.sh` 脚本不存在.

**规则**: 所有 ticket close 前, 对应的 L4 bash 脚本必须存在 (可以是 stub, 但必须存在并可执行).

**落地检查**: `check-fact-forcing-preflight.sh` 加 `L4_script_exists` check, 引用不存在脚本的 ticket 拒绝 close.

**红线**: ❌ L4 bash 命令引用不存在脚本, ❌ ticket close 前 L4 脚本缺失

### 9. 4-Level Fact-Forcing 强制 (KALLAX P0) — task:complete 前置

**教训**: 4-Level 是 documentation, 不是 enforcement. EPIC-024/028 KPI falsification 3 次强化此教训.

**规则**: `task:complete <TICKET>` 前必须运行 `check-fact-forcing-preflight.sh <expert.md>`, 全部 L1/L2/L3/L4 通过才能 close ticket.

**4 级执行顺序**: L1 存在性 → L2 实质性 → L3 接线正确 → L4 数据流动

**Anti-Fabrication 子规则 (9a/9b/9c/9e/9f)**:

- **9a [P0] KPI 估数算 FAIL**: "M1 ~60-70%" / "约 80%" / "PARTIAL" / "around" / "approximately" / "估计" / "roughly" / "should" 都算 KPI falsification. 必须精确 X/Y 一位小数. 防御: `scripts/verify/check-kpi-precision.sh` 必跑
- **9b [P0] Test case verbatim 触发 = FAIL**: 把测试需求整句塞 trigger 字段 = 100% circular match. 防御: `scripts/verify/check-test-case-isolation.sh`
- **9c [P0] Scope creep 必拆 PR**: file_scope.includes 外的文件改动 = scope creep. 防御: `scripts/verify/check-scope-creep.sh`
- **9e [P0] Performer 工具调用自验证 = FAIL**: Edit 后未 grep 验证 / git commit 后未 log 验证 SHA 真变 / test 后未看 stdout 验证. 防御: Performer 工具调用后必自验证
- **9f [P1] Tier-Domain 一致性 = FAIL**: default tier 必须用 {architect, backend, frontend, ux, product, security, pm} 中之一. 防御: `python3 scripts/expert-quality-audit.py --enforce-tier-domain`

**红线**: ❌ 跳过 preflight 直接 close ticket, ❌ preflight FAIL 但仍 close ticket, ❌ KPI 估数/verbatim/scope creep 任一绕过

### 10. Anti-Fabrication 强制 (KALLAX P0) — 全 commit 前置

**规则**: 所有 commit 前必跑 3 anti-fab 工具, 集成在 pre-commit hook 强制执行:

| 工具 | 防什么 |
|---|---|
| `scripts/verify/check-test-case-isolation.sh` | Test case verbatim 在 trigger 字段 |
| `scripts/verify/check-kpi-precision.sh` | KPI 估数/模糊报 PASS |
| `scripts/verify/check-scope-creep.sh` | file_scope 超界改动 |

**集成**: `.kallax/hooks/pre-commit` 必跑 3 工具, 任一 FAIL = 拒绝 commit.

**红线**: ❌ 跳过 3 anti-fab 工具, ❌ pre-commit hook 改 Bypass, ❌ 估数/verbatim/scope creep 任一造假

### 11. Master 写代码禁令 (KALLAX P0) — 主公原话硬红线

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

### 12. 质量 ensure 强制 (KALLAX P1) — expert > 50 必跑 audit

**规则**: expert > 50 时必跑 `scripts/expert-quality-audit.py` 5 维度 (Schema/Tier-Domain/M1/Trigger/Domain). 触发: 飞轮"迭代"阶段转换, Merge 前置, Index 变更.

**红线**: ❌ expert > 50 但未跑 audit 就 merge, ❌ M1 填估数 ("~60%"/"约 80%"/"PARTIAL"), ❌ Trigger 字段直接复制 test case 文本

### 13. 3 模式决策权分配 (KALLAX P0) — 主公原话 2026-06-09

**规则**: 3 模式 = `ai-auto` (AI 自主 + block/danger 停下问) / `ai-copilot` (默认, 简单自主 + 复杂协商) / `manual` (主公确认每阶段).

**生效范围**: Performer + Conductor (Master 不受控).

**Block 决策 (5 类)**: `ambiguous_options` / `performer_failure` / `rule_exception` / `epic_critical` / `high_impact`

**危险操作 (3 类)**: `miao_modify` / `security_failing` / `data_destruction`

**落地**: `scripts/performer/stage-gate.sh` + `scripts/permission/decision-gate.sh` + `scripts/permission/mode-set.sh`

**红线**: ❌ 跳过 decision-gate.sh, ❌ 跳过 stage-gate.sh, ❌ 运行时热切换 mode

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

### 14. Conductor 不能越界 Performer 实施 (KALLAX P0) — R-NEW 升级红线

**教训**: 主公 2026-06-12 拍 "每个角色, 无论 Conductor 还是 Performer 都是独立存在的 session/subagent".

**红线 (硬, 不可 override 日常)**:
- ❌ Conductor session Edit/Write/Commit 代码 (含 ticket 实施, 测试脚本, binary 改, Rust 源码)
- ❌ Conductor session 跑 Performer 工作流 (写 test + 写实施 + 4 anti-fab + push)
- ❌ Conductor spawn Performer session 后越界接 Performer 实施
- ❌ Conductor 改 binary/Rust 源码
- ❌ Conductor 改 .md (除 CLAUDE.md 跟 confluence/decisions/ 边界文件)

**唯一豁免**: 跟 Rule 11 联动 (Token 限撞墙 / miao 已损坏 / ≥ 3 Performer API error / 主公 explicit 拍)

### 15. Performer Session 自动加载 (KALLAX P0) — R-NEW 升级红线

**规则**: Performer 角色必须独立 session/subagent, 初始化时根据当前 ticket 加载 CLAUDE.md + ROLE-RULES + ticket.json 上下文. 启用 `bash .kallax/hooks/session_start.sh --role performer` 自动 claim ticket + 建 worktree.

**🚨 行为准则第一条 (主公 2026-06-13 拍)**: 领卡之后第一时间建 worktree, 跟主分支和其他分支隔离.

**红线**:
- ❌ Performer session 跳过 worktree 直接写 miao 主 checkout
- ❌ Performer session 在主 checkout 写文件 (即使 worktree 已有)
- ❌ Performer session 跳 worktree 写 miao
- ❌ Performer session 跳 session_start.sh 直接跑 (无 CLAUDE.md + ROLE-RULES + ticket 上下文)

### 16. Subagent 5 步强制流程 (KALLAX P0) — Phase 7 R-NEW 升级红线

**教训**: 10 KPI falsification 实证 (Performer-EPIC-036/037 第 9/10 次). 50% 概率假 PASS 模式 (4 subagent: 2 真 + 2 假).

**规则**: Subagent (Conductor + Performer + Auditor) 完工必触发 5 步强制流程, 缺任一 → ticket 状态保持 in_progress + Conductor 不 merge + Master 不 promote.

**5 步强制流程**:

1. **Step 1**: `scripts/conductor/ticket-status-sync.sh` 自动同步 ticket.json
2. **Step 2**: 3 anti-fab (`check-test-case-isolation.sh` + `check-kpi-precision.sh` + `check-scope-creep.sh`)
3. **Step 3**: `check-fact-forcing-preflight.sh` 5 工具 (L1/L2/L3/L4/L4_script_exists)
4. **Step 4**: `scripts/conductor/review.sh` 5 验证
5. **Step 5**: `scripts/master/strong-verify-6d.sh` 6 维度 (L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实)

**红线**: ❌ 跳过 Step 1-5 任一

### 17. 文件并发竞争 5 步强制流程 (KALLAX P0) — Phase 7 R-NEW 升级红线

**教训**: 主公 2026-06-12 拍 "还有个痛点是相互影响, 同时修改/编辑文件/文件夹引起工作文件的丢失/修改".

**5 步强制流程**:

1. **Step 1**: `scripts/io/file-lock.sh` (flock + git index.lock 同模式)
2. **Step 2**: `scripts/io/atomic-write.sh` (临时文件 + atomic mv)
3. **Step 3**: `scripts/io/conflict-detect.sh` (git diff 比对)
4. **Step 4**: `scripts/conductor/outbox-isolation.sh` (subagent 各 own outbox)
5. **Step 5**: `scripts/master/worktree-state-sync.sh` (Performer commit 必 push)

**红线**: ❌ 跳过文件级锁, ❌ 写半截文件, ❌ 跳过冲突检测, ❌ 写 outbox 路径冲突, ❌ worktree 状态不同步

### 18. KPI Falsification 反模式黑名单 (KALLAX P0) — Phase 7 R-NEW 升级红线

**规则**: Master 强验证 6 维度检测以下反模式, 命中任一 → subagent 报 FAIL.

**10 反模式黑名单**: KPI 估数/模糊 / Test case verbatim / Scope creep / Amend SHA 没变 / 工具调用后未自验证 / 报 PASS 实际 0 commit / 借口"环境问题"/ 借口"估数"/ 借口"删 build fix 假装修完"/ Tier-Domain 不一致

**执行**: Master 强验证 6 维度命中任一 → subagent 报 FAIL + ticket 状态自动同步 + 留 LESSONS-LEARNED 草稿.

### 19. 5 类标签 SOP (KALLAX P1) — EPIC-055-C, 治 A2 咒语化 + A3 笔误

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

## KALLAX Rules Status (跟 EPIC-054-D 联合)

> **当前 Rule 总数**: 23
> **累计 升级 (实测)**: 10 (R-NEW 14-18 = 5 + v1.2.4 扩展 29-33 = 5)
> **升级率**: 43.5% (实测, 跟 EPIC-055-B LESSONS-LEARNED.md 联合)
> **fatigue_index**: 43.5 (接近 HIGH 阈值 50)
> **净价值**: 62.5% (跟 EPIC-056-A 决策后 联合)

### 📋 Rule 合并 Proposal (EPIC-054-D, 待主公拍板)

**状态**: 3 合并候选已输出 proposal, 待主公拍板分级 (P0 必拍 / P1 备案) 后执行实际合并.

**3 候选** (跟 v1.2.4 EPIC-051 合规设计 联合):

1. **候选 A (P1 备案)**: Rule 30 + 31 → 合并为 "独立见证机制" (单一 Rule)
2. **候选 B (P0 必拍)**: Rule 32 → 撤销/合并到 Rule 5 DRY (反讽治根)
3. **候选 C (P1 备案)**: Rule 33 → 合并入 Rule 13 (3 模式决策权)

**目标**: 23 Rule → **20 Rule** (-3), 净价值 62.5% → **65.5%** (+3.0%).

**执行前置** (跟 PROCESS.md:25-26 联合):

- ✅ 本 ticket 只输出 proposal, 不实际合并 Rule
- ❌ 实际合并需主公拍板 (候选 B P0 必拍, 候选 A/C P1 备案)

**详细 proposal**: [`docs/process/rule-merge-proposal.md`](docs/process/rule-merge-proposal.md)
**联动 ticket**: EPIC-055-B (主公拍板分级, 已 merged `2b4771c`)

### 29. 工具不可绕过 (KALLAX P0) — Security Extension 治根因 1

**规则**: 所有 6 硬脚本必须满足: 无 env var toggle bypass, 无 world-writable, 无 symlink attack, self-path resolution, token 验证在 preflight 前.

**红线**: ❌ 任何 6 硬脚本可绕过, ❌ 脚本 world-writable, ❌ `--force-merge` token check 在 preflight 后

### 30. 自验证需独立见证 (KALLAX P0) — Process Engineering Extension 治根因 2

**规则**: Subagent 报 PASS 前, 必调用 `scripts/process/independent-witness.sh` 生成审计日志. 方案 1 (独立见证) + 方案 4 (流程重构) 组合, 治根 90%.

**红线**: ❌ Subagent 自报 PASS 不调用 independent-witness.sh, ❌ independent-witness.sh 输出 fail 仍报 PASS

### 31. 独立见证机制 (KALLAX P0) — Auditor Extension 治根因 3

**规则**: 独立见证机制必跑 audit-log-sink.sh: BE-7 修复模式 (umask 077 + install -d -m 700 + flock + atomic write + chmod 600). Subagent 报 PASS 必写 audit log sink.

**红线**: ❌ 不可篡改 audit log sink 缺失, ❌ audit log sink 可被 subagent 写, ❌ audit log sink 无 atomic write

### 32. 软约束升级阈值 (KALLAX P0) — Root Cause 4 治根

**规则**: Rule 升级率 > 80% 触发审查, Rule 数量 > 15 触发重构, 门禁数量 > 10 触发架构评估.

**红线**: ❌ Rule 升级率 > 80% 但未触发审查, ❌ Rule 数量 > 15 但未触发重构, ❌ 门禁数量 > 10 但未触发架构评估

### 33. decision-gate 复杂才问 (KALLAX P0) — decision-gate 扩展组 治根因 5

**规则**: decision-gate.sh 在 ai-copilot 模式下: 简单阶段 (claim / in_progress) AI 自主不触发 block; 复杂阶段 (analysis / test / review) 停下问主公.

**落地**: `scripts/permission/decision-gate-complex-only.sh` + `scripts/performer/stage-gate.sh` (传 STAGE).

**红线**: ❌ ai-copilot 模式在简单阶段触发 block, ❌ decision-gate.sh 不区分 mode + stage

---

## 详细文档

- [术语词典](docs/KALLAX-GLOSSARY.md)
- [Conductor 规则](template/docs/CONDUCTOR-RULES.md)
- [Performer 规则](template/docs/PERFORMER-RULES.md)
- [反模式集合](template/docs/ANTI-PATTERNS.md)
- [架构白皮书](docs/architecture/FRAMEWORK.md)
- [降级策略](docs/architecture/DEGRADATION-STRATEGY.md)