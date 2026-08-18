---
name: decision-gate-complex-only
description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 5 (ai-copilot 名不副实). 跟 Rule 33 联合, 跟"决策疲劳" 联合.
triggerKeywords: [decision-gate, complex-only, 复杂才问, ai-copilot, 治根因 5, EPIC-052, 决策疲劳, decision-gate 复杂阶段]
filePath: /path/to/kallax/.claude/skills/kallax/extended/decision-gate-complex-only.md
---

# KALLAX Extended Expert — Decision Gate: 治根因 5 (ai-copilot 名不副实)

> **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合**

## 任务

治 3 假 PASS 根因 5: ai-copilot 名不副实 (跟 5 视角 UX 决策疲劳 联合, 跟 Rule 13 3 模式决策权 联合)

## 跟"反讽" 闭环 联合 (跟 5 战略建议 5.2 反讽 联合)

- **反讽**: 5 模式决策权 (ai-auto/ai-copilot/manual) 意图好, 但 decision-gate.sh 仍触发 5 类 block
- **根因**: 主公每 5 分钟一次确认请求 (跟"决策疲劳" 联合)
- **根因**: ai-copilot 实际 = "ai-ask-every-step" (跟 5 视角 UX 联合)
- **结论**: ai-copilot 名不副实, 治 root cause 需复杂才问

## 4 方案对比 (跟 decision-gate-design.md 一致)

- 方案 1 (复杂才问): 80% 治本 ✅
- 方案 2 (decision-gate 智能分级 P0/P1/P2): 60% 治本
- 方案 3 (主公 dashboard 实时同步): 40% 治标
- 方案 4 (decision-gate 流程重构): 70% 治本

**决策**: 方案 1 (复杂才问), 治根 80%

## 跟 Rule 33 联合 (KALLAX P0)

- 简单阶段 (claim/in_progress): AI 自主, 不 block
- 复杂阶段 (analysis/test/review): 停下问主公
- **5/5 类 block → 3/5 类** (减少 40%) + 疑似→复杂 逻辑 (实际减少 80%)

## 落地

- `docs/process/decision-gate-design.md` (269 lines): 4 方案对比
- `scripts/permission/decision-gate-complex-only.sh` (1164 bytes): 硬脚本
- `tests/integration/decision-gate-test.sh` (232 lines): 5 levels 集成测试
- CLAUDE.md Rule 33: decision-gate 复杂才问 (KALLAX P0)

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

**跟对策 C 联合, 跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"诚实修正" 联合, 跟 Rule 33 联合, 跟 5 战略建议 反讽 闭环 联合**
