# KALLAX Scope / Mission / Vision / 价值观

> **来源**: 主公 2026-08-08 拍板 (EPIC-206), 跟 EPIC-171 + EPIC-172 战略沉淀 1:1 联合
> **状态**: 当前 truth (跟 ARCHITECTURE.md §14 文化 + 法律 配合 1:1)

## Scope (范围)

KALLAX 是 **Claude Code 治理框架**, 不是产品:

| 在范围内 ✅ | 不在范围内 ❌ |
|------------|--------------|
| Claude Code 工作流治理 | 0 跟 eket / Claude Code 同质产品竞争 |
| 4-PR / 5-Level Verify / immutable scripts | 0 主动重构 Claude Code 内部 |
| Rules 体系 (36 条 + path-scoped) | 0 跨平台 (Cursor / Windsurf 等) 适配 |
| 4 北极星指标 + 北极星 dashboard | 0 业务 SaaS / 商业化产品 |
| 心跳 daemon + Conductor/Performer | 0 跟 Anthropic API / 模型训练 |
| 公开化路径 (Lark/WeChat/README.en) | 0 营销自动化 / 用户增长工具 |
| install.sh Omnibus (95 files deploy) | 0 IDE 插件 / 编辑器集成 |

## Mission (使命)

**让 Claude Code 在工程团队里变成可治理、可量化、可持续的工程团队成员**.

3 个核心问题:
1. **可治理**: 5 immutable scripts + 36 Rule + 4-PR 流程, 不靠个人信任, 靠系统约束
2. **可量化**: 4 北极星指标 (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch), 0 主观判断
3. **可持续**: eket 极简哲学 + immutable scripts 不变 + 跨 EPIC 复用 ≥ 60%, 0 装饰性宣称

## Vision (愿景)

**Q4 2026 目标**: KALLAX 成为 Claude Code 用户的默认治理扩展, 月活 100+ 团队.

3 阶段:
1. **2026-Q3**: Sprint 时间盒 + 4 北极星指标闭环 (Rule 35 + Rule 36, 当前在 EPIC-194/204)
2. **2026-Q4**: 公开化路径完成 (Lark/WeChat 群 + hosted frontstage + growth loop, EPIC-169/172)
3. **2027-Q1**: 跨平台 0 适配 (保持 Claude Code 单一焦点, 拒绝 scope creep)

## 价值观 (跟 eket 极简哲学 1:1)

### 1. 0 装饰性宣称 (跟 check-decorative-claim.sh 联合)

```diff
- ❌ "生产级 / 25/25 PASS / 治根"
+ ✅ "8/8 PASS (test output: tests/integration/foo.test.sh)"
```

**Why**: v3.8.0 "25/25 假 PASS" 教训, README/CHANGELOG 数字必带 raw_output 引用 (EPIC-069-D).

### 2. 0 估数字 (跟 EPIC-152 + EPIC-205 跑批 1:1)

```diff
- ❌ "约 80% 覆盖率 / 大约 100 行"
+ ✅ "78.3% (8/12 files) / 104 行 (含 24 行测试)"
```

**Why**: 估数 = 假 PASS 入口, 必须 ground truth 验证 (跟 EPIC-203 retrospective 4 false positive 教训一致).

### 3. 0 narrative 包装 (跟 check-narrative.sh 联合)

```diff
- ❌ "作为下一代 AI 协作框架, 我们相信..."
+ ✅ "5 immutable scripts 强制 fail-closed"
```

**Why**: narrative 掩盖实际行为, 让 reviewer 难抓真 bug.

### 4. 0 跳流程 (跟 EPIC-074 4-PR 强制 + EPIC-155 历史债 联合)

```diff
- ❌ "这次紧急, 我们 bypass 4-PR 直接 merge miao"
+ ✅ "走 4-PR 全程, --no-verify 需主公明确批准 (主公拍板 备案)"
```

**Why**: v3.8.0 形式通过实质失败 (跟 CLAUDE.md §2 起源 1:1).

### 5. 0 元层自嘲 (跟 EPIC-171 战略沉淀 联合)

```diff
- ❌ "我们其实也不知道有没有用, 试试看"
+ ✅ "8 release 累计, 5 immutable scripts, 22 DEPRECATED index entries"
```

**Why**: 数据说话, 0 自嘲 = 0 自我怀疑暴露.

## 跟 EPIC-171 + EPIC-172 战略沉淀 1:1 联合

| 视角 | 文档 | 1:1 联合 |
|------|------|---------|
| **PR** | EPIC-171 PR 视角 | "3 视角定位" — 跟本文价值观 #1-#3 1:1 |
| **CTO** | EPIC-171 CTO 视角 | "技术债务 + 治理债" — 跟 Scope 表 1:1 |
| **Marketing** | EPIC-171 + EPIC-172 | "Why vs Claude Code?" + growth loop — 跟 Vision 1:1 |

## Reference

- [01-top-design.md](01-top-design.md) — 顶层设计
- [03-timeline.md](03-timeline.md) — 时间线
- [05-best-practices.md](05-best-practices.md) — 最佳实践
- [confluence/research/kallax-positioning-2026-08-05.md](../research/kallax-positioning-2026-08-05.md) — EPIC-171 3 视角
- [confluence/research/kallax-growth-loop-2026-08-05.md](../research/kallax-growth-loop-2026-08-05.md) — EPIC-172 growth loop