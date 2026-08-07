# EPIC-117 — 简洁性反哺 (Anthropic Building Effective Agents 借鉴)

> Date: 2026-07-14 | Master explicit 派单 | 5 ticket

## 起源

主公 2026-07-14 派单: 研究 Anthropic《Building Effective Agents》后 "开 epic 做所有这些"。

**Anthropic 三原则**:
1. **Simplicity** — 从最简开始, 只在证明有效时加复杂度
2. **Transparency** — 显式暴露 planning 步骤
3. **ACI** — 像 HCI 一样投入到工具接口设计

**KALLAX 自查**:
- 26 命令 / 11 类 / 9 专家 / 5 记忆层 / 11 派遣项 / 11 post-process 步 / 34+ hard-rule → **complexity via accretion**
- v3.22.0 本 session 修 10 个 check 脚本 ACI 不一致 → **没做 ACI 统一**
- wrapper 层层封装, 出问题时根因藏在 5 层 shell 调用 → **抽象黑盒**

## 5 ticket 边界

| Ticket | 主题 | 主要文件 | 借鉴点 |
|--------|------|---------|--------|
| A | claim-evidence 扫描扩容 | `scripts/hooks/check-claim-evidence.sh` | Ground truth from env |
| B | verify 脚本 ACI 统一 | `scripts/verify/CONTRACT.md` + audit | ACI 优先 |
| C | 每 release 砍 1 | `scripts/verify/check-release-budget.sh` | Simplicity |
| D | verify-pr iterate | `scripts/verify-pr-iterate.sh` | Evaluator-Optimizer |
| E | wrapper --explain | `scripts/audit/*.sh` + `scripts/memory-promote.sh` 等 | Transparency 破黑盒 |

## 验收

每 ticket 独立 PR, master 5-Level Verify 后 squash-merge 到 testing。

## 联动

- Anthropic 文章: https://www.anthropic.com/engineering/building-effective-agents
- 4-PR flow (EPIC-074), fact-forcing (EPIC-069-D), 诚实修正战略
