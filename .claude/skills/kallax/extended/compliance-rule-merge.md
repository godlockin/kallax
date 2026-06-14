---
name: compliance-rule-merge
description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 4 (14 Rule 升级率 100%). 跟 Rule 32 联合, 跟"循环论证" 联合.
triggerKeywords: [compliance, rule-merge, 软约束升级阈值, 治根因 4, EPIC-051, 18 Rule 升级率 100%, 撤销冗余 Rule, 5 release 软约束]
filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/compliance-rule-merge.md
---

# KALLAX Extended Expert — Compliance: 治根因 4 (14 Rule 升级率 100%)

> **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合**

## 任务

治 3 假 PASS 根因 4: 14 Rule 升级率 100% (跟 5 release 软约束 → 5 R-NEW 升级 联合, 跟"循环论证" 联合)

## 跟"反讽" 闭环 联合 (跟 5 战略建议 5.1 反讽 联合)

- **反讽**: 5 release 软约束 → 5 R-NEW 升级 (升级率 100%, 跟"治标不治本" 联合)
- **根因**: 18 Rule + 15 门禁 = 治理复杂度替代架构设计 (跟 5 视角 Architect 联合)
- **根因**: KALLAX 85.5% - 18 Rule = 67.5% 净价值 (跟 5 视角 Product 联合)
- **结论**: 软约束失效, 治 root cause 需软约束升级阈值

## 4 方案对比 (跟 compliance-design.md 一致)

- 方案 1 (重构 3-5 架构原则): 治本, 目标 ≤10 Rule ✅
- 方案 2 (撤销冗余 Rule 定期扫描): 治标 ✅
- 方案 3 (软约束升级阈值): 治本 ✅
- 方案 4 (compliance 治理流程重构): 治标 ✅

**决策**: 方案 1 + 方案 2 + 方案 3 组合, 治根 90%

## 跟 Rule 32 联合 (KALLAX P0)

- **Rule 升级率 > 80%**: 触发冗余 Rule 审查
- **Rule 数量 > 15**: 触发重构审查
- **门禁数量 > 10**: 触发架构评估

## 落地

- `docs/process/COMPLIANCE-DESIGN.md` (263 lines): 4 方案对比
- `scripts/audit/rule-redundancy-audit.sh` (4391 bytes): 撤销冗余 Rule 定期扫描
- `tests/integration/compliance-test.sh` (214 lines): 4-Level 集成测试
- CLAUDE.md Rule 32: 软约束升级阈值 (KALLAX P0)

## 跟对策 C 联合 (跟"诚实修正" 联合, 跟主公"同意" explicit 授权 联合)

- 5 扩展组 治 root cause, 但 5 扩展组 自身假 PASS (BE-15)
- Master 接管 = 对策 C 落地 (跟 Rule 11 联合)
- 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"反讽" 闭环

## 跟"独立" 拍 explicit 约束 联合

- 跟 Auditor-Token 模式 一致, 跟"目标专家" 拍 explicit 约束 联合
- 独立 session / 独立角色 / 独立路径 / 独立报告

## 跟 14 BE 累计 联合

- BE-1 ~ BE-14: 8 试反复 + 10 KPI falsification + Token 限撞墙 + 越界反向
- BE-15: 3 假 PASS (跟 14 subagent = 21.4% 瞒报率 联合)
- 9 Security Review Issues

## 跟 v1.2.4 release 联合

miao HEAD `5192c79` + tag `v1.2.4`

---

**跟对策 C 联合, 跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"诚实修正" 联合, 跟 Rule 32 联合, 跟 5 战略建议 反讽 闭环 联合**
