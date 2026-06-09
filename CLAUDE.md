# KALLAX - Claude Code Integration

> **K**nowledge-**A**ugmented **L**everaged **L**earning **A**gent e**X**ecutor v1.0.0

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

# 文件范围检查（Conductor 派发前验证）
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
let result = operation()
    .map_err(|e| KallaxError::Operation { source: e })?;
```

**红线**:
- 生产代码禁用 `expect()`/`panic!()`/`unwrap()`
- 所有错误必须通过 `Result<T, E>` 传播
- CI 自动扫描违规

### 3. 产出验证机制 (KALLAX P0)

**教训**: background agent 报告"完成"但实际零产出

```bash
# Conductor 验证 Performer 产出真实性
kallax verify:output TASK-001

# 自动执行:
# 1. ls -la 检查文件存在
# 2. git show 检查实际修改
# 3. npm test 运行真实测试
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
  // 类型收窄后处理
}
```

### 6. 经验沉淀强制化 (KALLAX P0) — EPIC 交付四件套

**教训**: EPIC 完成后只 merge 不沉淀 = 知识黑洞, 下一个 EPIC 重复踩坑. EPIC-016 后期靠 postmortem 才补上 lessons, 太晚.

**红线**: 每个 EPIC 交付**必须**走完 4 步才能 close:

1. **A+B 2-Group 对抗 review**
   - A 组 (Forward): AC 合规 + 代码质量 + 集成 (已落地, 见 EPIC-016-O 案例)
   - B 组 (Attack): 安全 + 边界 + 攻击面 (已落地, 见 EPIC-021-F 案例: 找 2 CRITICAL 注入 + race)
   - 修复后 master 仲裁 APPROVE/REJECT, 留 `review:` 字段在 ticket.json
2. **文档更新**
   - `jira/tickets/EPIC-XXX/README.md` 更新实施记录
   - `jira/epics/EPIC-XXX/epic.json` 更新 ticket 状态
   - 必要时 `confluence/decisions/` 加新决策文档
3. **经验教训草稿**
   - EPIC 实施**最后一次 commit** 必须包含 `jira/epics/EPIC-XXX/LESSONS-LEARNED.md` 草稿
   - 模板见 `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md`
   - 包含: 量化指标, 关键事件时间线, 教训 (按类别), 评估, 下一步
4. **LESSONS-LEARNED 终审**
   - master 审批时检查草稿是否存在且合规
   - master merge 前确认 lessons 已更新 (master 才有权限 merge)

**禁止**:
- ❌ A+B review 跳过, 直接 APPROVE
- ❌ 文档只在 commit message 写, 不更新 README/jira
- ❌ 经验教训放在 commit message (会被淹没), 必须独立 md 文件
- ❌ EPIC 最后 commit 不带 LESSONS-LEARNED 草稿

### 7. PHASE 闭环 review (KALLAX P0) — 经验升级

**教训**: 经验教训只沉淀不升级 = 单点案例, 不形成组织能力. EKET 调研显示, 没有 phase-level review 的知识库, 5 年后翻出来 80% 已经过期.

**触发**: 每完成 3-5 个 EPIC, 或阶段目标达成 (master 决定), 触发 PHASE 闭环 review.

**流程** (跟 EKET Phase 1+2+3 借鉴, KALLAX 加 4-Group 升级):

1. **Phase 1 (Architect)**: 全局扫描
   - 扫本 phase 所有 EPIC 的 LESSONS-LEARNED.md
   - 分类: 量化/流程/技术/治理
2. **Phase 2 (5 专家并行)**:
   - Backend/Frontend/UX/Product: 各自从领域视角找漏洞/纠错/合并
   - Security: 跨 EPIC 安全 attack surface 累积分析
3. **Phase 3 (Master 仲裁 + 升级)**:
   - **查漏补缺**: 哪些 EPIC 经验教训没覆盖, 补 EPIC
   - **纠错**: 哪些经验教训跟事实不符, 改
   - **归纳合并**: 跨 EPIC 相似教训合并 (e.g. "并行冲突" 出现 3 次 → 升级为 KALLAX 规则)
   - **升级**: 沉淀到 `CLAUDE.md` 的"核心原则" (新增/修订), 或 `confluence/architecture/`
4. **Phase 4 (主公审批)**:
   - 升级项需主公决策, master 不能自己升级红线规则

**产出物**:
- `confluence/decisions/PHASE-XXX-REVIEW-XXX.md` (模板见 `PHASE-REVIEW-TEMPLATE.md`)
- `CLAUDE.md` 修订 (如适用)
- `confluence/architecture/` 新文档 (如适用)

**禁止**:
- ❌ 经验教训只 review 不升级
- ❌ 升级到 CLAUDE.md 没经过主公审批
- ❌ 跨 phase 不对比, phase 边界模糊

### 8. L4 脚本必须存在 (KALLAX P0) — ticket close 前置条件

**教训**: EPIC-021 D review P1 CRITICAL — 5 角色 L4 引用 `verify-*.sh` / `test-*.sh` 脚本不存在. Review 时发现 4-Level verification 命令全部指向不存在的脚本, 形成"文档好看, 执行完蛋"局面.

**规则**: 所有 ticket close 前, 对应的 L4 bash脚本必须存在 (可以是 stub, 但必须存在并可执行).

**落地检查**: `check-fact-forcing-preflight.sh` 加 `L4_script_exists` check, 引用不存在脚本的 ticket拒绝 close.

**5 角色 L4 占位脚本** (待 EPIC-022+ 真实实现):
- `scripts/verify/architecture.sh` —架构验证
- `scripts/verify/priority.sh` — 优先级验证
- `scripts/verify/ux-flow.sh` — UX 流程验证
- `scripts/verify/tickets-completed.sh` — Ticket 完成度验证
- `scripts/verify/security.sh` — 安全验证

**红线**:
- ❌ L4 bash 命令引用不存在脚本
- ❌ ticket close 前 L4 脚本缺失

### 9. 4-Level Fact-Forcing 强制 (KALLAX P0) — task:complete 前置

**教训**: EPIC-021 D review CRITICAL — 4-Level 是 documentation, 不是 enforcement. 文档写"存在性/实质性/接线正确/数据流动", 但没有人真的去检查, 形成"review 通过, 部署完蛋"局面. EPIC-024/028 KPI falsification 3 次 (51125b9 假 100% / 6563362 估数 PARTIAL / 33cfc48 build fail) 强化此教训.

**规则**: `task:complete <TICKET>` 前必须运行 `check-fact-forcing-preflight.sh <expert.md>`, 全部 L1/L2/L3/L4 通过才能 close ticket.

**落地检查**: `scripts/check-fact-forcing-preflight.sh` 实现 4 级顺序执行, 任一 FAIL 则 preflight FAIL, ticket 保持 `in_progress`.

**4 级执行顺序**:
1. **L1 存在性**: 文件存在于 diff
2. **L2 实质性**: 真实逻辑, 非 stub
3. **L3 接线正确**: 正确 import/export
4. **L4 数据流动**: 集成测试验证

**Anti-Fabrication 子规则 (9a/9b/9c, EPIC-024/028 教训汇总, 主公 2026-06-08 同意升红线)**:

- **9a [P0] KPI 估数算 FAIL**: "M1 ~60-70%" / "约 80%" / "PARTIAL" / "around" / "approximately" / "估计" / "roughly" / "should" 都算 KPI falsification. 必须精确 X/Y 一位小数 (e.g. "M1: 26/30 = 86.7%"). 防御: `scripts/verify/check-kpi-precision.sh` 必跑
- **9b [P0] Test case verbatim 触发 = FAIL**: 把测试需求整句塞 trigger 字段 = 100% circular match, 假数据. 防御: `scripts/verify/check-test-case-isolation.sh` 跑 trigger vs 30 test case grep 比对, 0 leak
- **9c [P0] Scope creep 必拆 PR**: file_scope.includes 外的文件改动 = scope creep, 必拆 PR. 防御: `scripts/verify/check-scope-creep.sh` git diff --name-only vs ticket.json file_scope.includes, 超界 = FAIL
- **9e [P1] Tier-Domain 一致性 = FAIL**: default tier 必须用 {architect, backend, frontend, ux, product, security, pm} 中之一; generated tier 不在 default 7 域范围 (避免跟 default 重名); extended tier 任意域. 防御: `python3 scripts/expert-quality-audit.py --enforce-tier-domain` 必跑; 来源: EPIC-024 质量 audit 维度 4 揭露 10/15 generated 用 product/ux/finance (跟 default 冲突)

**失败处理**:
- preflight FAIL → ticket 保持 `in_progress`
- `check-fact-forcing-preflight.sh --force-merge` 可 override (需 master 授权)
- 9a/9b/9c 任一 FAIL = 拒绝 close ticket, 不可 override (主公授权例外除外)

**红线**:
- ❌ 跳过 preflight 直接 close ticket
- ❌ preflight FAIL 但仍 close ticket
- ❌ KPI 估数/verbatim/scope creep 任一绕过
- ❌ 3 anti-fab 工具跳过

### 10. Anti-Fabrication 强制 (KALLAX P0) — 全 commit 前置

**教训**: 主公原话 "加上工具和限制保证数据/任务造假的现象不会再出现". EPIC-024/028 出现 3 次 KPI falsification, 工具防御 + 规则升级双管齐下才能根治.

**规则**: 所有 commit 前必跑 3 anti-fab 工具, 集成在 pre-commit hook 强制执行:

| 工具 | 防什么 | 触发 |
|---|---|---|
| `scripts/verify/check-test-case-isolation.sh` | Test case verbatim 在 trigger 字段 | 51125b9 假 100% |
| `scripts/verify/check-kpi-precision.sh` | KPI 估数/模糊报 PASS | 6563362 PARTIAL |
| `scripts/verify/check-scope-creep.sh` | file_scope 超界改动 | 6563362 Arc imports |

**集成**: `.kallax/hooks/pre-commit` 必跑 3 工具, 任一 FAIL = 拒绝 commit. 跟 Rule 9 L1-L4 一起 enforce.

**落地检查**: pre-commit hook 3 工具 + `check-fact-forcing-preflight.sh` 5 工具 (L1-L4 + L4_script_exists) 串联, 共 8 个门禁.

**红线**:
- ❌ 跳过 3 anti-fab 工具
- ❌ pre-commit hook 改 Bypass
- ❌ 估数/verbatim/scope creep 任一造假

### 11. Master 写代码禁令 (KALLAX P0) — 主公原话硬红线

**教训**: 主公 2026-06-09 原话: "除了极端情况, master 不许写代码". 之前 Rule 11 (Master Corrective Integration 兜底) 写得过宽 — "Performer 失败 Master 接管" 是日常失败不是极端, 跟主公原话矛盾. 收回, 写硬红线.

**规则**: **Master 默认禁止写代码** (含 commit / edit / write), 不分场景. 唯一例外是"极端情况", 且必须**主公明确指令** ("你来干"/"你来 fix"/"master 接管 X").

**极端情况定义** (满足任一即触发, 但仍需主公明确指令才执行):
1. **Token Plan 限撞墙**: Token Plan Max 5h cap 9917k/9917k reached, 派不出 Performer, 主公拍"接口好了"或"你来干"
2. **生产事故 (miao 已损坏)**: critical security incident, miao/testing production 不可用, 等不及 Performer 派单
3. **Performer 派单全 fail + 主公拍板接管**: ≥ 3 个 Performer 接连 API error, 主公明确说"master 接管"
4. **主公明确指令**: "你来干" / "你来 fix" / "master 接管 X" — 直接授权

**不构成"极端情况"的反例** (即 Master 不应接管, 走 Performer 派单):
- ❌ Performer 1 次 API error 就接管 (token 重置后重试即可)
- ❌ Performer 跑 4h 仍无 commit (派第 2 个 Performer)
- ❌ Performer 报 PASS 但 Master 验证 FAIL (踢回 Performer 重做)
- ❌ Performer 留半成品 (派新 Performer 接)
- ❌ Master 觉得 Performer 跑太慢 (主公原话明确不许)

**极端情况执行流程**:
1. Master 在主公面前**明确汇报**: "X 任务走极端情况, 接管理由 Y, 接管范围 Z, 估时 W"
2. 主公**明确指令** ("你来干" / "你来 fix")
3. Master 才执行, commit message 写 "Master corrective integration under 主公 explicit 授权: [理由]"
4. 4-Level + A+B review 走 Performer 自审路径 (Master 接管 = 接管自审责任)
5. **事后必须在 LESSONS-LEARNED 标 "极端情况触发"**, 升级是否成 Rule 需主公 Phase X 拍

**已知"极端情况"事件 (历史, 主公事后 review 接受)**:
- 837c9a4 (a3be6648 失败后 Master 修 5 SQL injection): **不符合新标准**, 应走"派新 Performer"而非接管. 但主公 2026-06-09 拍"已修保留"接受, 不撤回. 标"边界事件, 留作教训"
- 0767d81 (a5955cbd token 限失败后 Master 修 4 test + 2 security): **边界符合 (token 限 + 主公拍"接口好了你来干")**, 但当时未经主公明确指令, 应补授权. 主公事后追认
- acf045a (push security 2 issues): **Master 修 (Rule 10 violation)**, 跟 Rule 11 一样越权. 主公事后追认

**bypass 条件** (Performer design阶段专用):
- 设计阶段工作 (Sprint 3 / DeepSeek / Quality audit 等无 ticket.json 的 design任务) 可设 `KALLAX_BYPASS_SCOPE_CHECK=1` 短路 scope 检查
- `check-scope-creep.sh` 检测到此 env var 后直接 `exit 0`, 输出 `BYPASS: design stage work, no ticket.json required`
- 其他3 anti-fab 工具 (test-case-isolation / kpi-precision) 正常跑，不受影响
- Master 自修代码**不受 bypass** (Rule 11 禁令不变)

**红线** (硬, 不可 override):
- ❌ **任何场景下 Master 默认禁写代码** (除主公明确指令)
- ❌ **不因 "Performer 失败" / "Performer 慢" / "Master 觉得简单" 接管**
- ❌ **不接管 > 1 个 Performer 任务 / session** (避免 capacity 警告变成常态)
- ❌ **不创建新 feature 分支 / 改 miao production / 跨 worktree**
- ❌ **不 commit 缺 "Master corrective integration under 主公 explicit 授权" 标识**
- ❌ **不事后默认 "主公同意" — 接管前必须明确** ("主公原话'X'"才算)

**执行检查**:
- git pre-commit hook 扫 commit message, 缺 "Master corrective" 标识 + 缺 "主公 explicit 授权" 标注 → reject
- 跟 Rule 1 (Conductor 禁 miao 写功能代码) 一起 enforce

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

## 详细文档

- [Conductor 规则](template/docs/CONDUCTOR-RULES.md)
- [Performer 规则](template/docs/PERFORMER-RULES.md)
- [反模式集合](template/docs/ANTI-PATTERNS.md)
- [架构白皮书](docs/architecture/FRAMEWORK.md)
- [降级策略](docs/architecture/DEGRADATION-STRATEGY.md)
