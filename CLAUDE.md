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

### 6. 经验沉淀强制化 (KALLAX P0) — EPIC 交付三件套

**教训**: EPIC 完成后只 merge 不沉淀 = 知识黑洞, 下一个 EPIC 重复踩坑. EPIC-016 后期靠 postmortem 才补上 lessons, 太晚.

**红线**: 每个 EPIC 交付**必须**走完 3 步才能 close:

1. **A+B 2-Group 对抗 review**
   - A 组 (Forward): AC 合规 + 代码质量 + 集成 (已落地, 见 EPIC-016-O 案例)
   - B 组 (Attack): 安全 + 边界 + 攻击面 (已落地, 见 EPIC-021-F 案例: 找 2 CRITICAL 注入 + race)
   - 修复后 master 仲裁 APPROVE/REJECT, 留 `review:` 字段在 ticket.json
2. **文档更新**
   - `jira/tickets/EPIC-XXX/README.md` 更新实施记录
   - `jira/epics/EPIC-XXX/epic.json` 更新 ticket 状态
   - 必要时 `confluence/decisions/` 加新决策文档
3. **经验教训总结**
   - 写 `jira/epics/EPIC-XXX/LESSONS-LEARNED.md` (模板见 `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md`)
   - 包含: 量化指标, 关键事件时间线, 教训 (按类别), 评估, 下一步
   - 跟 EPIC 实施 commit 同一 PR 提交

**禁止**:
- ❌ A+B review 跳过, 直接 APPROVE
- ❌ 文档只在 commit message 写, 不更新 README/jira
- ❌ 经验教训放在 commit message (会被淹没), 必须独立 md 文件

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
