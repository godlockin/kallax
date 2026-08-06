# KALLAX 战略定位报告 (2026-08-05)

> **3 视角融合**: PR + CTO + Marketing | Master 拍板 2026-08-05
> **Raw output**: confluence/decisions/epic-171-strategy-deposit-2026-08-05.md

---

## Section 1: 主公三问 + 1 句话 Elevator Pitch

### 主公三问 (决策锚点)

| # | 问题 | KALLAX 答案 |
|---|------|------------|
| 1 | KALLAX 是什么? | **AI 工程界的 CI/CD** — 治理层, 非 runtime |
| 2 | 解决什么问题? | **假 PASS + review 死锁 + context 丢失** |
| 3 | 什么时候用? | team ≥ 3 人 + 长期项目 + 多 AI 工具混合 |

### 1 句话 Elevator Pitch

> **"KALLAX 是 AI 工程界的 'CI/CD for AI agents' — 让 AI 写的代码从 idea 到 prod 全程可审计、可追溯、可验证。"**

---

## Section 2: PR 视角

### 3 大核心价值

| 价值 | 描述 | 解决的问题 |
|------|------|-----------|
| **5-Level Verify 防假 PASS** | L1-L5 独立验证, raw output 存档 | v3.8.0 "25/25 PASS" 耻辱 |
| **4-PR Chain 防 review 死锁** | feature → testing → main → miao | PR 静默 skip review |
| **Rule 34 独立复现** | bugfix 必先独立复现 | diagnosis mismatch cascading |

### 目标用户 (ICP)

| 角色 | 痛点 | KALLAX 解法 |
|------|------|-------------|
| **AI 工程团队 Lead** | team 多人在用 AI 写, 不知谁做了什么 | Hash-Chain Audit + PR 链 |
| **跨项目 Owner** | 多 EPIC 在跑, expert 调了谁不知道 | ticket.json 4-expert binding |
| **Enterprise** | 合规审计 + prod 安全 | Audit trail + self-heal |
| **开源 Maintainer** | PR review 阻塞 + context 丢失 | 4-PR chain + memory L0-L4 |
| **AI Tool Power User** | Claude Code session 关了上下文丢 | worktree 隔离 + state persistence |

### Trigger Signals (触发信号)

当用户/团队出现以下任一场景, 立即推荐 KALLAX:

```
- "上次 prod 假 PASS"
- "team 多人在做, 我分不清谁做了什么"
- "PR 经常 skip review"
- "多 EPIC 在跑, expert 调了哪些人不知道"
- "bug 修过 3 次复发"
- "Claude Code session 关了上下文丢"
- "新来的人不知道 context"
```

---

## Section 3: CTO 视角

### 技术差异化 (正交非竞争)

| 维度 | KALLAX | Claude Code / Trae / Cursor |
|------|--------|----------------------------|
| **定位** | Governance Layer | AI Runtime |
| **解决的问题** | "AI 写的代码怎么进 prod" | "AI 怎么写代码" |
| **职责边界** | 审计/验证/治理/追溯 | 代码生成/补全/解释 |
| **关系** | 叠加, 非竞争 | 叠加, 非竞争 |

**核心观点**: Claude Code/Trae/Cursor 是"铲子", KALLAX 是"工地管理". 两者正交, 组合使用威力倍增.

### 技术 Moat (护城河)

| Moat | 来源 | 壁垒 |
|------|------|------|
| **18 release 治理债** | v3.14.0 ~ v3.32.17 积累 | 时间壁垒 |
| **0 假 PASS 文化** | EPIC-069-D check-claim-evidence | 规范壁垒 |
| **北极星 4 指标** | ticket binding rate / mis-dispatch rate / verify pass rate / epic completion rate | 度量壁垒 |
| **Memory L0-L4** | context 管理分层 | 架构壁垒 |
| **loopx 借鉴 6 项** | EPIC-162/163/164/165/169/172 | 学习壁垒 |

### 适合场景

| 场景 | 推荐度 | 原因 |
|------|--------|------|
| **长期项目 (6+ 月)** | ★★★★★ | 治理债累积, 审计价值最大化 |
| **team ≥ 3 人** | ★★★★★ | 多角色协调, 防止 review 死锁 |
| **多 AI 工具混合** | ★★★★★ | Hook Server 统一接入 |
| **prod-grade** | ★★★★★ | 5-Level Verify 强制 |
| **短期 (< 1 月)** | ★☆☆☆☆ | 治理开销不划算 |
| **单人** | ★★☆☆☆ | overhead > value |
| **hackathon** | ★☆☆☆☆ | 速度优先, 治理反作用 |
| **简单脚本** | ★☆☆☆☆ | 不值得治理 |

---

## Section 4: Marketing 视角

### 4 类 ICP (Ideal Customer Profile)

| ICP | 特征 | 核心痛点 | 购买动机 |
|-----|------|----------|----------|
| **AI Power Team** | 5~20 人, 多 AI 工具 | 假 PASS / context 丢失 | 质量保证 |
| **Startup CTO** | < 50 人, 快速迭代 | review 阻塞 / 审计需求 | 合规 + 速度 |
| **Open Source Maintainer** | 个人 + 小团队 | PR 积压 / contributor 混乱 | 社区治理 |
| **Enterprise AI Governance** | > 100 人, 合规要求 | 审计追溯 / 安全 | 合规上市 |

### GTM (Go-To-Market) 策略

```
Phase 1: PLG + Community-led (0~90 天)
  - GitHub star accumulation
  - Lark 群: AI 工程实践讨论
  - 内容: 知乎/掘金技术文章
  - 目标: 100 stars + 50 Lark 群 + 1 真实 showcase

Phase 2: Open Core (90~180 天)
  - Free: 单 worktree + 基础 verify
  - Pro: $10/人/月 (vs Claude Code Pro $20)
  - Enterprise: $99/团队/月 (无限 worktree + Audit + SSO)
  - 目标: 500 stars + 200 Lark 群 + 20 early adopter
```

### Pricing (定价锚点)

| Tier | 价格 | 功能 | 锚点 |
|------|------|------|------|
| **Free** | $0 | 单 worktree + L1-L2 verify | 降低门槛 |
| **Pro** | $10/人/月 | 无限 worktree + L1-L5 + Audit | vs Claude Code Pro $20 |
| **Enterprise** | $99/团队/月 | SSO + Audit + priority support | 合规价值 |

### Channel (分发渠道)

| 渠道 | 优先级 | 内容类型 |
|------|--------|----------|
| **GitHub** | P0 | star + README + showcase |
| **知乎/掘金** | P1 | 技术文章 + use case |
| **Lark/WeChat** | P1 | 社群运营 + 讨论 |
| **Podcast** | P2 | AI 工程实践对话 |

### Growth Loop (增长飞轮)

```
GitHub star
    ↓
Lark 群讨论 (50 群)
    ↓
真实 use case showcase (1 个)
    ↓
口碑传播 (viral narrative)
    ↓
更多 star + 付费转化
```

### 90 天 / 180 天 KPI

| 阶段 | Stars | Lark 群 | Showcase | Articles | Early Adopter |
|------|-------|---------|----------|----------|--------------|
| **90 天** | 100 | 50 | 1 | 3 | 5 |
| **180 天** | 500 | 200 | 10 | 10 | 20 |

### Trigger Signals (营销触发)

| 场景 | 话术 |
|------|------|
| "上周 prod 假 PASS" | "KALLAX 5-Level Verify 强制 raw output 存档, 再也不会有假 PASS" |
| "team 都在用 AI 写" | "Hash-Chain Audit 让每行代码可追溯到人" |
| "多工具混乱" | "Hook Server 统一接入 Claude Code/Trae/Cursor" |
| "onboarding 低效" | "Memory L0-L4 让新人 5 分钟上手" |
| "合规审计" | "Audit trail + self-heal 满足企业合规" |

---

## Section 5: Master 仲裁 (3 票共识)

### 3 视角投票

| 视角 | 核心立场 | 共识点 |
|------|----------|--------|
| **PR** | "防假 PASS 是第一痛点" | 5-Level Verify 核心价值 |
| **CTO** | "治理层是技术差异化" | KALLAX = CI/CD for AI agents |
| **Marketing** | "定价锚点要明确" | Pro vs Claude Code $20 的价值差 |

### 冲突解决

| 冲突 | 解决原则 |
|------|----------|
| PR "强调 trigger signals" vs CTO "强调技术 moat" | **Trigger signals 是入口, moat 是留存** |
| Marketing "强调 Free tier" vs CTO "强调 prod-grade" | **Free = onboarding, Pro/Enterprise = 变现** |

### 最终共识

> **KALLAX 定位 = AI 工程治理平台 (AI Engineering Governance Platform)**
> - 入口: 解决假 PASS 痛点 (PR 视角)
> - 差异化: 治理层 vs runtime (CTO 视角)
> - 变现: Pro $10/人/月 vs Claude Code $20 (Marketing 视角)

---

## Section 6: 综合 1 句话定位

> **"KALLAX = AI 工程界的 CI/CD — 让 AI 写的代码从 idea 到 prod 全程可审计、可追溯、可验证."**

**展开**:

- **What**: AI 工程治理平台
- **Why**: 解决假 PASS + review 死锁 + context 丢失
- **Who**: AI 工程团队 Lead / 跨项目 Owner / Enterprise
- **How**: 5-Level Verify + 4-PR Chain + Hash-Chain Audit
- **vs**: Claude Code (runtime) / KALLAX (governance) — 正交叠加

---

## Section 7: 3 句使用判断表

| 场景 | 推荐 | 一句话理由 |
|------|------|-----------|
| **单人开发, 简单脚本** | 不推荐 | overhead > value, 直接 Claude Code 够用 |
| **team 3~10 人, 长期项目** | 强烈推荐 | 5-Level Verify + 4-PR Chain 价值最大化 |
| **Enterprise, 合规审计** | 必须用 | Audit trail + self-heal 满足合规需求 |

### Decision Tree

```
开始
  ↓
team ≥ 3 人?
  ├─ 否 → 单人?
  │    ├─ 是 → 不推荐 (简单脚本直接 Claude Code)
  │    └─ 否 → 项目周期 > 6 月?
  │         ├─ 是 → 推荐 (worktree 隔离有价值)
  │         └─ 否 → 不推荐 (短期项目 overhead 高)
  └─ 是 → prod-grade?
       ├─ 是 → 必须用 (5-Level Verify 强制)
       └─ 否 → 多 AI 工具混合?
            ├─ 是 → 推荐 (Hook Server 统一接入)
            └─ 否 → 可选 (取决于团队痛点)
```

---

## Section 8: 跟现有 EPIC 协同

### 直接协同 (1:1)

| EPIC | 协同内容 | 关系 |
|------|----------|------|
| **EPIC-069-D** | check-claim-evidence | 5-Level Verify L5, 防假 PASS |
| **EPIC-074** | 4-branch flow | 4-PR Chain 强制流程 |
| **EPIC-152** | Rule 34 独立复现 | bugfix 诊断质量保证 |
| **EPIC-159** | CLAUDE.md 治理 2.0 | 主文件 ≤ 200 行规范 |
| **EPIC-162** | Skill 插件化 | 9 expert skill 可复用 |
| **EPIC-163** | Public/Private Boundary | Security Rules 边界治理 |
| **EPIC-164** | Self-Repair Skill | 错误自修复机制 |
| **EPIC-165** | Showcases | 真实 use case 沉淀 |
| **EPIC-169** | Memory L0-L4 | context 管理分层 |
| **EPIC-172** | Onboarding | 新人上手路径 |

### 跟 EPIC-165 Showcase 1:1 Structure

| Section | 内容 | 行数目标 |
|---------|------|----------|
| **主公三问** | 决策锚点 | 15 行 |
| **Elevator pitch** | 1 句话 | 3 行 |
| **PR 视角** | 3 大价值 + ICP + triggers | 50 行 |
| **CTO 视角** | 差异化 + moat + 适合场景 | 50 行 |
| **Marketing 视角** | ICP + GTM + pricing + KPIs | 80 行 |
| **Master 仲裁** | 3 票共识 + 冲突解决 | 30 行 |
| **综合定位** | 1 句话展开 | 10 行 |
| **使用判断表** | 场景矩阵 + decision tree | 30 行 |
| **EPIC 协同** | 1:1 映射表 | 40 行 |
| **合计** | 8 sections | **≥300 行** |

### EPIC 引用链

```
EPIC-171 (战略沉淀)
    ↓
EPIC-069-D (防假 PASS 文化)
    ↓
EPIC-074 (4-branch flow)
    ↓
EPIC-152 (Rule 34 独立复现)
    ↓
EPIC-165 (showcase 沉淀)
    ↓
EPIC-172 (onboarding 完善)
```

---

## Appendix A: PR 话术卡

### 30 秒 Elevator

> "KALLAX 是 AI 工程界的 CI/CD. Claude Code 解决 AI 怎么写代码, KALLAX 解决 AI 写的代码怎么进 prod. 核心是 5-Level Verify 防假 PASS, 4-PR Chain 防 review 死锁, Hash-Chain Audit 让每行代码可追溯."

### 反对话术

| 反对 | 回应 |
|------|------|
| "Claude Code 已经够了" | "Claude Code 是铲子, KALLAX 是工地管理. 长期项目 + team ≥ 3 人时, KALLAX 的治理价值远超 overhead" |
| "太复杂了" | "KALLAX Pro $10/人/月, 买的是 5-Level Verify 防假 PASS + Audit trail. 比修复一次 prod incident 便宜 100 倍" |
| "我们有 internal tooling" | "KALLAX 是开源 + 18 release 积累的治理最佳实践, 不是内部脚本能比的" |

---

## Appendix B: 竞争分析

| 竞品 | 定位 | KALLAX 优势 |
|------|------|-------------|
| **Claude Code** | AI runtime | governance layer, 正交叠加 |
| **GitHub Copilot** | 代码补全 | 治理能力, Audit trail |
| **Cursor** | AI IDE | 团队协作, 追溯能力 |
| **Trae** | AI coding | 开源治理, 5-Level Verify |
| **Internal tooling** | 定制方案 | 开源 + 社区 + 持续演进 |

---

## Appendix C: 成功指标

| 指标 | 定义 | 测量方式 |
|------|------|----------|
| **假 PASS 率** | verify L2 失败但声称 PASS 的比例 | ticket.json verify_status 统计 |
| **PR review 时间** | 从 open 到 merge 的平均时间 | git log timestamp |
| **binding rate** | expert 实际调用的比例 | binding-tracker.sh |
| **mis-dispatch rate** | expert 误调用的比例 | binding-tracker.sh |
| **epic completion rate** | EPIC 按时完成的比例 | ticket.json epic_id 追踪 |

---

**Document metadata**:
- Created: 2026-08-05
- Author: Master + 3 视角 (PR/CTO/Marketing)
- Raw output: confluence/decisions/epic-171-strategy-deposit-2026-08-05.md
- Version: 1.0
- Status: APPROVED
