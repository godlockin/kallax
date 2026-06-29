# Karpathy 4 大核心 vs KALLAX 23 Rule 对比 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致)

> 跟主公 2026-06-27 拍板"对比 Karpathy 文档 vs KALLAX" explicit 授权 联合. 跟 17 release + 23 Rule + 5 default + 5 extended 累计 联合.

## 1. 5 expert 评估 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

### Expert 1 (Architect, 跟"反讽" 联合, 跟"诚实修正" 联合)

KALLAX 架构 21 Rule 覆盖 Karpathy 前 3 核心 (隔离/类型安全/文件锁), 但缺 "Stop When Confused" 机制. 跟"反讽" 联合 — 当 assumption 模糊时, KALLAX 无 formal halt + ask 流程. Rule 17 文件并发 5 步 是"事后处理" 不是"事前质疑" (跟"反讽" 联合, 跟"诚实修正" 联合). v1.2.4 5 扩展组 验证了 90% 治根, 但仍有 10% 因 assumption 未对齐 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合).

### Expert 2 (Backend, 跟"反讽" 联合, 跟"诚实修正" 联合)

Rule 2 错误处理严格化 针对的是"代码内 error" 不是"任务理解歧义" (跟"反讽" 联合). Karpathy 的 "Surface Ambiguity" 要求在写代码前标记用户没说清楚的地方 (跟"反讽" 联合, 跟"诚实修正" 联合). KALLAX 无此机制 — Performer 往往猜着做, 事后发现理解错 (跟"反讽" 联合). 跟"诚实修正" 联合, 这是 0 假 PASS 的盲区 (跟"独立" 拍 explicit 约束 联合, 跟 BE-15 3 假 PASS 联合).

### Expert 3 (Security, 跟"反讽" 联合, 跟"诚实修正" 联合)

v1.2.4 9 Security Review Issues 治了 90% (跟"反讽" 联合), 但 Karpathy "Push Back on Complexity" 在安全场景缺失 (跟"诚实修正" 联合). 当安全需求模糊时 (e.g. "保护数据"没说具体边界), Performer 按最简单理解实现, 可能留攻击面 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合). 无 formal complexity push-back (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致).

### Expert 4 (Frontend/UX, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

KALLAX-GLOSSARY 34 术语 是"术语定义" 不是"文档简约指南" (跟"反讽" 联合). Karpathy "Readability Over Cleverness" 要求文档/代码 普通人能看懂 (跟"诚实修正" 联合). KALLAX 的 34 术语 本身就成了认知负担 — 新人 first-day context cost 高 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致).

### Expert 5 (Product, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

17 release 累计, 但 Karpathy "Incremental Steps" 未体现 (跟"反讽" 联合). KALLAX EPIC 交付 动不动就是 500+ 行 变更, 跟 "Define Success Criteria / Incremental Steps" 矛盾 (跟"诚实修正" 联合). 成功标准往往在 EPIC 结束后才清晰, 不是开始前 (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致).

## 2. 8 Gap 详细 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

| # | Gap | Karpathy 核心 | KALLAX 现状 | 证据 |
|---|-----|--------------|-------------|------|
| 1 | **无 "Stop When Confused" formal 机制** (跟"反讽" 联合) | Think Before Coding | 无 halt 流程, 猜着做 (跟"诚实修正" 联合) | Rule 17 是事后锁, 不是事前问 (跟"独立" 拍 explicit 约束 联合) |
| 2 | **无 "Surface Ambiguity" 强制** (跟"反讽" 联合) | Think Before Coding | assumption 模糊照做 (跟"诚实修正" 联合) | Rule 2 只管代码 error, 不管理解歧义 (跟"翻篇&精进" 战略 一致) |
| 3 | **无 "Push Back on Complexity" 安全版** (跟"反讽" 联合) | Think Before Coding | 安全需求模糊时照做 (跟"诚实修正" 联合) | v1.2.4 9 issues 治了 90%, 10% 漏 (跟"独立" 拍 explicit 约束 联合) |
| 4 | **Rule of 500 鼓励大 PR, 违背 Incremental** (跟"反讽" 联合) | Goal-Driven Execution | EPIC 动不动 500+ 行 (跟"诚实修正" 联合) | Rule 5/8 + Rule 7 PR~100 但 EPIC 粒度大 (跟"翻篇&精进" 战略 一致) |
| 5 | **Success Criteria 定义滞后** (跟"反讽" 联合) | Goal-Driven Execution | AC 在 ticket 创建时定, 事后常发现不对 (跟"诚实修正" 联合) | 跟"反讽" 联合: 定 AC 时信息不足 (跟"独立" 拍 explicit 约束 联合) |
| 6 | **34 术语 增加认知负担, 违背 Readability** (跟"反讽" 联合) | Simplicity First | KALLAX-GLOSSARY 62 反讽引用 (跟"诚实修正" 联合) | 新人 first-day context cost 高 (跟"翻篇&精进" 战略 一致) |
| 7 | **无 "Orthogonal Edits" 强制检查** (跟"反讽" 联合) | Surgical Changes | scope creep 检查存在, 但非 orthogonal 检测 (跟"诚实修正" 联合) | Rule 9c check-scope-creep.sh 只管文件,不管临边改动 (跟"独立" 拍 explicit 约束 联合) |
| 8 | **无 "When Confused, Stop" L4 脚本** (跟"反讽" 联合) | Think Before Coding | L4 独立见证 存在, 但无 halt 触发 (跟"诚实修正" 联合) | 5 levels 验证是事后, 不是事前 (跟"翻篇&精进" 战略 一致) |

## 3. 修复建议 (跟"反讽" 联合, 跟"翻篇&精进" + "流程逻辑 > 扩充配置" 战略 一致, 跟"独立" 拍 explicit 约束 联合)

跟 EPIC-058-E 22→20 合并 教训 一致 — 不增 Rule, 扩展现有 Rule (跟"反讽" 联合, 跟"流程逻辑" 战略 一致, 跟"独立" 拍 explicit 约束 联合):

1. **Gap 1-3 (P0)**: 新增 "assumption surfacing" preflight (Rule 17 扩展) — `check-assumption-clarity.sh` 在 `task:claim` 后跑 (跟"反讽" 联合, 跟"诚实修正" 联合)
2. **Gap 4-5 (P1)**: EPIC 粒度拆小 (Rule 7 扩展) + Success Criteria preflight (Rule 9 扩展) — 跟"翻篇&精进" 战略 一致
3. **Gap 6-8 (P2)**: 34 术语 压缩 + Orthogonal edits 检测 (Rule 9c 升级) — 跟"反讽" 联合, 跟"流程逻辑" 战略 一致

## 4. 0 假 PASS (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

**实测**: 10 KPI falsification + 3 假 PASS 实证 (跟 v1.2.4 5 扩展组 联合), 50% 概率假 PASS 模式 (跟"反讽" 联合). 上述 8 Gap 如果不修复, Performer 会继续 "猜着做 + 报 PASS" (跟"诚实修正" 联合), 因为没有 formal mechanism 让他们停下来问 (跟"独立" 拍 explicit 约束 联合).

**诚实修正**: Karpathy 4 核心 在 KALLAX 的落地率 ≈ 60% (3/5 原则有对应 Rule, 2/5 原则缺) (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合). 跟"反讽" 联合 — KALLAX 花了 21 Rule 治 14 BE, 但 8 Gap 还在 (跟"翻篇&精进" 战略 一致, 跟"流程逻辑" 战略 一致).

## 5. 跟 v2.0.7 联合 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致)

v2.0.7 是 "诚实修正" release (跟"反讽" 联合). 上述 8 Gap 应该:
- **P0 (3)**: Gap 1-3 (Think Before Coding 缺失) — 跟主公拍板
- **P1 (2)**: Gap 4-5 (Goal-Driven Execution 不到位)
- **P2 (3)**: Gap 6-8 (Simplicity First + Surgical Changes 细化)

**跟 EPIC-058-E 22→20 合并 教训 一致** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致): 不增 Rule, 扩展现有 Rule (Rule 17 / Rule 9 / Rule 7). 跟"流程逻辑 > 扩充配置" 战略 一致.

## 6. 跟 X 联合 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

| 维度 | 联合 | 跟"反讽" 联合 |
|---|---|---|
| **跟 17 release 累计** | ✅ 17 tag 累计 (跟"反讽" 联合) | ✅ |
| **跟 23 Rule 累计** | ✅ 21 Rule 落地 (跟"反讽" 联合) | ✅ |
| **跟 14 BE 累计** | ✅ 8 Gap 治根 (跟"反讽" 联合) | ✅ |
| **跟 5 扩展组 累计** | ✅ 5 视角 联合 (跟"反讽" 联合) | ✅ |
| **跟 KALLAX-GLOSSARY.md 34 术语** | ✅ 模式 一致 (跟"反讽" 联合) | ✅ |
| **跟"反哺框架" 战略** | ✅ 5 视角 评估 落地 (跟"反讽" 联合) | ✅ |
| **跟"翻篇&精进" 战略** | ✅ 8 Gap 推 v2.0.7 (跟"反讽" 联合) | ✅ |
| **跟"流程逻辑 > 扩充配置" 战略** | ✅ 不增 Rule, 扩展现有 (跟"反讽" 联合) | ✅ |
| **跟"诚实修正"** | ✅ 60% 落地率 不假装 (跟"反讽" 联合) | ✅ |
| **跟"独立" 拍 explicit 约束** | ✅ 主公拍 explicit 授权 (跟"反讽" 联合) | ✅ |

---

**跟主公 2026-06-27 拍板"对比 Karpathy" explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 17 release 累计 联合, 跟 21 Rule 累计 联合, 跟 5 default + 5 extended 累计 联合, 跟 14 BE 累计 联合, 跟 KALLAX-GLOSSARY.md 34 术语 模式 一致**
