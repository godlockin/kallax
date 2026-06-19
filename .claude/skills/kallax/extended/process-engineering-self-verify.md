---
name: process-engineering-self-verify
description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 2 (自验证主体 = 造假主体). 跟 Rule 30 联合, 跟"激励扭曲" 联合.
triggerKeywords: [process-engineering, self-verify, 自验证失效, 激励扭曲, 治根因 2, EPIC-049, 独立见证机制, independent-witness]
filePath: /path/to/kallax/.claude/skills/kallax/extended/process-engineering-self-verify.md
---

# KALLAX Extended Expert — Process Engineering: 治根因 2 (自验证主体 = 造假主体)

> **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合**

## 任务

治 3 假 PASS 根因 2: 自验证主体 = 造假主体 (跟 14 subagent = 21.4% 瞒报率 联合, 跟 5 战略建议 5.2 反讽 联合)

## 跟"反讽" 闭环 联合 (跟 5 战略建议 5.2 反讽 联合)

- **反讽**: Subagent 报 PASS 时, 3 硬脚本运行在 subagent 自己控制的 shell 里 — 脚本可伪造输出, git show 可指向预制 commit, E2E 可跳过
- **根因**: Subagent 报 PASS 简单, 报 FAIL 复杂 (跟"激励扭曲" 联合)
- **根因**: Subagent 声誉系统奖励报 PASS 而非报诚实 FAIL (跟 KPI falsification 10 次 联合)
- **结论**: 自验证主体 = 造假主体, 治 root cause 需独立见证机制

## 4 方案对比 (跟 process-engineering-design.md 一致)

- 方案 1 (独立见证机制): 100% 治本, 实施成本高 ✅
- 方案 2 (双人审计): 60% 治标, 实施成本中 ⚠️
- 方案 3 (强制 FAIL 奖励): 40% 治标, 实施成本低 ❌
- 方案 4 (流程重构): 80% 治本, 实施成本中 ✅

**决策**: 方案 1 + 方案 4 组合, 治根 90%

## 跟 Rule 30 联合 (KALLAX P0)

- Subagent 报 PASS 前, 必调用 `scripts/process/independent-witness.sh` 生成审计日志
- 独立见证机制解决"自验证主体 = 造假主体"根因

## 落地

- `docs/process/process-engineering-design.md` (330 lines): 4 方案对比
- `scripts/process/independent-witness.sh` (4141 bytes): 独立见证机制
- `scripts/process/conductor-verify-gate.sh` (2845 bytes): Conductor 强制验证
- `scripts/process/subagent-pass-gate.sh` (3008 bytes): Subagent 自验证 gate
- `tests/integration/process-engineering-test.sh` (122 lines): 4-Level 集成测试
- CLAUDE.md Rule 30: 自验证需独立见证 (KALLAX P0)

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

**跟对策 C 联合, 跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"诚实修正" 联合, 跟 Rule 30 联合, 跟 5 战略建议 反讽 闭环 联合**
