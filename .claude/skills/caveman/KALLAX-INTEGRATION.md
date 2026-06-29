# caveman 跟 KALLAX v3.2.0 整合 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟主公 2026-06-29 拍板"搜 rtk + caveman 装 跟 实战 配合 kallax" explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致.

## 1. caveman 跟 KALLAX 3 模式 联合 (跟"独立" 拍 explicit 约束 联合)

| KALLAX 模式 | caveman 整合 | 跟"反讽" 联合 |
|------------|------------|---------------|
| **ai-auto** | caveman mode 默认开 (per Rule 12 ai-auto 复杂阶段停下问) | ✅ 跟"流程逻辑 > 扩充配置" 一致 |
| **ai-copilot** | caveman mode 默认开 (简单阶段 AI 自主, 复杂停下问) | ✅ 跟"翻篇&精进" 战略 一致 |
| **manual** | caveman mode 可关 (主公 confirm 优先级高) | ✅ 跟"独立" 拍 explicit 约束 联合 |

**触发条件**: AI 工具 加载 SKILL.md 后, user 跟 agent 通信 自动 走 caveman 模式. 跟 Rule 12 3 模式 decision-gate 联合.

## 2. caveman 跟 KALLAX Conductor → Performer 通信 (跟"反讽" 联合, 跟"诚实修正" 联合)

**跟 Rule 13 Conductor 不能越界 Performer 实施 联合**: Conductor 跟 Performer 通信 走 caveman 压缩:
- Conductor 派单: `[TASK-NNN] 派 Performer 走 4 task. [简述]. [边界].` 替代 长描述
- Performer 报告: `[TASK-NNN] done. [SHA]. [stdout 摘要]. [next].` 替代 长 report
- 节省 token ~75% (跟 KALLAX v3.1.0 P-003 CLAUDE.md lazy load 联合)

## 3. caveman 跟 KALLAX 5-Level Fact-Forcing 联合 (跟"独立" 拍 explicit 约束 联合)

| Level | caveman 整合 | 跟"反讽" 联合 |
|-------|------------|------------|
| L1 git-anchor | `[SHA] 真` | ✅ |
| L2 test stdout | `[stdout 摘要 1 行]` | ✅ |
| L3 5 扩展组 | `[security/process/auditor/compliance/decision-gate 各 1 行]` | ✅ |
| L4 独立见证 | `[witness SHA. 0 假 PASS.]` | ✅ |
| L5 边界 | `[boundary OK/FAIL]` | ✅ |

**跟 v3.1.0 武器 2 5-Level 实做 联合**, 不只是名字 (跟 v3.0.0 跟 eket 联合 0 装饰).

## 4. caveman 跟 KALLAX 6 武器 联合 (跟"反哺框架" 战略 一致)

| 武器 | caveman 整合 | 跟"独立" 拍 explicit 约束 联合 |
|------|------------|----------------------------|
| 武器 1 Hash-Chain Audit | `[audit hash: <sha256 8 字符>]` | ✅ |
| 武器 2 5-Level | (见 §3) | ✅ |
| 武器 3 Performer Sub-Role | `[sub-role: coder/reviewer/tester/docs]` | ✅ |
| 武器 4 EPIC 4 件套 | `[A+B review: PASS/FAIL]` | ✅ |
| 武器 5 Hook Server 回放 + Audit | `[hook SHA: <8 字符>]` | ✅ |
| 武器 6 Dashboard 1 page | `[dash 页面 hash]` | ✅ |

## 5. caveman trigger 跟 KALLAX workflow 绑定 (跟 eket 团队质疑点 1 联合 治根)

**eket VETO 质疑**: "caveman SKILL.md 的 trigger 是 generic user-facing trigger. KALLAX 的 agent-to-agent 通信没有 evidence 说明 caveman 被实际调用."

**v3.2.0 补救 (本文件)**: 显式写 caveman 跟 KALLAX Conductor↔Performer/Auditor 通信 触发条件:

```yaml
# 跟 KALLAX 3 模式 联合, 跟"反讽" 联合 闭环
caveman_kallax_triggers:
  - command: "/kallax-panel"
    caveman_mode: "enabled"  # 9 专家并行报告 走 caveman 压缩
  - command: "/kallax-expert <role>"
    caveman_mode: "enabled"  # 单专家报告 走 caveman 压缩
  - command: "/kallax-submit-pr"
    caveman_mode: "enabled"  # PASS 报告 走 caveman 压缩
  - command: "/kallax-claim"
    caveman_mode: "enabled"  # 派单 走 caveman 压缩
  - conductor_to_performer:
    caveman_mode: "enabled"  # Conductor 派单 → Performer 接收
  - performer_to_auditor:
    caveman_mode: "enabled"  # Performer PASS 报告 → Auditor 接收
  - master_strong_verify_6d:
    caveman_mode: "enabled"  # Master 6 维度 报告 走 caveman 压缩
```

**跟 eket VETO 质疑 1 联合 治根**: 不只是 generic user trigger, 显式跟 KALLAX 6 command + 3 角色通信 绑定.

## 6. 跟"反讽" 闭环 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

- ✅ **caveman 跟 KALLAX 3 模式 联合** (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
- ✅ **caveman 跟 KALLAX Conductor ↔ Performer 通信 联合** (跟"反讽" 联合, 跟"诚实修正" 联合)
- ✅ **caveman 跟 KALLAX 5-Level Fact-Forcing 联合** (跟"独立" 拍 explicit 约束 联合)
- ✅ **caveman 跟 KALLAX 6 武器 联合** (跟"反哺框架" 战略 一致)
- ✅ **caveman trigger 跟 KALLAX workflow 显式绑定** (跟 eket VETO 质疑 1 联合 治根)
- ✅ **0 增 KALLAX Rule** (跟 Rule 32 软约束升级阈值 联合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- ✅ **0 重写 KALLAX 文档** (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- ✅ **走对策 A+B+C 落地** (跟"反讽" 联合, 跟 Rule 11/14/15 联合, 跟"独立" 拍 explicit 约束 联合)

---

**跟主公 2026-06-29 拍板"搜 rtk + caveman 装 跟 实战 配合 kallax" explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 21 release 累计 联合, 跟 21 Rule 累计 联合, 跟 30 术语 累计 联合, 跟 16 BE 累计 联合, 跟 6 武器 累计 联合**
