# EPIC-171 战略沉淀拍板记录 (2026-08-05)

> **Master 拍板**: 2026-08-05
> **参与者**: Master + PR 视角 + CTO 视角 + Marketing 视角
> **目标**: 把 3 视角战略报告沉淀到 confluence/research/

---

## 拍板背景

EPIC-171 是战略沉淀 EPIC, 需要把 3 视角 (PR + CTO + Marketing) 的战略讨论结果固化为文档, 指导后续 GTM 和产品方向.

---

## 3 视角 Raw Output 摘要

### PR 视角 Raw Output

```
Elevator pitch: "KALLAX 是 AI 工程界的 'CI/CD for AI agents'"

3 大核心价值:
1. 5-Level Verify 防假 PASS
2. 4-PR Chain 防 review 死锁
3. Rule 34 独立复现

Trigger signals:
- "上次 prod 假 PASS"
- "team 多人在做, 我分不清谁做了什么"
- "PR 经常 skip review"
- "多 EPIC 在跑, expert 调了哪些人不知道"
- "bug 修过 3 次复发"
- "Claude Code session 关了上下文丢"
- "新来的人不知道 context"

目标用户:
- AI 工程团队 Lead
- 跨项目 Owner
- Enterprise
- 开源 Maintainer
- AI Tool Power User
```

### CTO 视角 Raw Output

```
KALLAX = Governance Layer (解决"AI 写的代码怎么进 prod")
Claude Code/Trae/Cursor = AI Runtime (解决"AI 怎么写代码")

两者正交, 非竞争, 而是叠加.

技术 moat:
- 18 release 治理债
- 0 假 PASS 文化
- 北极星 4 指标
- Memory L0-L4
- loopx 借鉴 6 项

适合场景:
- 长期项目 (6+ 月) ✓✓✓✓✓
- team ≥ 3 人 ✓✓✓✓✓
- 多 AI 工具混合 ✓✓✓✓✓
- prod-grade ✓✓✓✓✓

不适合场景:
- 短期 (< 1 月) ✓☆☆☆☆
- 单人 ★★☆☆☆
- hackathon ★☆☆☆☆
- 简单脚本 ★☆☆☆☆
```

### Marketing 视角 Raw Output

```
ICP 4 类:
1. AI Power Team — 5~20 人, 假 PASS 痛点
2. Startup CTO — < 50 人, review 阻塞
3. Open Source Maintainer — PR 积压
4. Enterprise AI Governance — 合规审计

GTM:
Phase 1: PLG + Community-led (0~90 天)
  - GitHub star + Lark 群 + 知乎/掘金文章
  - 目标: 100 stars + 50 Lark 群 + 1 真实 showcase

Phase 2: Open Core (90~180 天)
  - Free / Pro $10/人/月 / Enterprise $99/团队/月
  - 目标: 500 stars + 200 Lark 群 + 20 early adopter

Channel: GitHub (P0) + 知乎/掘金 (P1) + Lark/WeChat (P1)

Growth loop:
GitHub star → Lark 群 → hosted showcase → 真实 use case → viral narrative
```

---

## Master 仲裁

### 3 票共识

| 共识点 | 票数 | 说明 |
|--------|------|------|
| 5-Level Verify 核心价值 | 3/3 | PR/CTO/Marketing 一致认可 |
| KALLAX = CI/CD for AI agents | 3/3 | 定位明确 |
| 正交叠加关系 | 3/3 | 不是竞争, 是组合 |

### 冲突解决

| 冲突 | 解决 |
|------|------|
| PR "trigger signals" vs CTO "技术 moat" | Trigger signals 是入口, moat 是留存 |
| Marketing "Free tier" vs CTO "prod-grade" | Free = onboarding, Pro/Enterprise = 变现 |

---

## 最终决议

### 文档结构

```
confluence/research/kallax-positioning-2026-08-05.md
├── Section 1: 主公三问 + 1 句话 elevator pitch
├── Section 2: PR 视角 (3 大核心价值 + 目标用户 + trigger signals)
├── Section 3: CTO 视角 (技术差异化 + moat + 适合/不适合)
├── Section 4: Marketing 视角 (4 ICP + GTM + channel + growth loop + KPIs)
├── Section 5: Master 仲裁 (3 票共识 + 冲突解决)
├── Section 6: 综合 1 句话定位
├── Section 7: 3 句使用判断表
├── Section 8: 跟现有 EPIC 协同
└── Appendix: PR 话术卡 + 竞争分析 + 成功指标

≥300 行, 8 sections
```

### README 增强

```
README.md 加 "Why KALLAX vs Claude Code?" 段:
├── 5 维度对比表
├── 1 句话 elevator pitch
├── 3 句使用判断
├── Trigger signals
└── 链接到 confluence/research/kallax-positioning-2026-08-05.md
≥30 行
```

---

## 实施清单

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 1 | 创建 research 文档 | DONE | `confluence/research/kallax-positioning-2026-08-05.md` |
| 2 | README 加段 | DONE | `README.md` |
| 3 | CHANGELOG entry | DONE | `CHANGELOG.md` |
| 4 | CLAUDE.md 更新 | DONE | `CLAUDE.md` |
| 5 | 拍板记录 | DONE | `confluence/decisions/epic-171-strategy-deposit-2026-08-05.md` |
| 6 | 集成测试 | DONE | `tests/integration/strategy-deposit-assets.test.sh` |

---

## 验收标准

- [x] confluence/research/kallax-positioning-2026-08-05.md ≥300 行
- [x] README.md 含 "Why KALLAX vs Claude Code?" ≥30 行
- [x] CHANGELOG [3.32.17] entry 存在
- [x] CLAUDE.md Section 6 含 EPIC-171
- [x] 拍板记录存在
- [x] 集成测试 ≥5 case PASS
- [x] 0 source code change

---

**Document metadata**:
- Created: 2026-08-05
- Author: Master
- Status: APPROVED
- Version: 1.0
