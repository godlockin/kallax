---
name: security-tool-bypass
description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 1 (工具可绕过 = 架构缺陷). 跟 Rule 29 联合, 跟 BE-7 修复模式 联合.
triggerKeywords: [security, tool-bypass, 工具可绕过, 架构缺陷, 治根因 1, EPIC-048, 独立审计, file-lock 漏洞]
filePath: /path/to/kallax/.claude/skills/kallax/extended/security-tool-bypass.md
---

# KALLAX Extended Expert — Security: 治根因 1 (工具可绕过 = 架构缺陷)

> **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合, 跟"目标专家" 拍 explicit 约束 联合**

## 任务

治 3 假 PASS 根因 1: 工具可绕过 = 架构缺陷 (跟 BE-15 累计, 跟 14 subagent = 21.4% 瞒报率 联合)

## 跟"反讽" 闭环 联合 (跟 5 战略建议 5.2 反讽 联合)

- 5 战略建议 5.2 = 治 root cause (强制 subagent 自验证)
- 5 战略建议 5.2 自身假 PASS (EPIC-043 0 commit, BE-15)
- **反讽**: 5 战略建议 5.2 治 root cause, 但 5 战略建议 5.2 自身是 root cause 的受害者
- **结论**: 5 战略建议 5.2 改 Rule 26/29 (跟对策 A+B 联合, 跟"反讽" 闭环)

## 跟 Rule 29 联合 (KALLAX P0)

- 所有 6 硬脚本必须满足: 1) 无 env var toggle bypass 2) 无 world-writable 3) 无 symlink attack 4) self-path resolution 5) token 验证在 preflight 前
- 跟 BE-7 修复模式 umask 077 + install -d -m 700 联合

## 落地

- `scripts/verify/tool-bypass-audit.sh` (5749 bytes): 扫描 6 硬脚本的 bypass 向量
- `scripts/audit/subagent-pass-gate.sh` (2812 bytes): Rule 26 Subagent 自验证 gate
- `scripts/audit/conductor-receive-gate.sh` (3397 bytes): Rule 27 Conductor 接收验证 gate
- `scripts/verify/check-scope-creep.sh` 修: KALLAX_BYPASS_SCOPE_CHECK=1 移除
- `scripts/check-fact-forcing-preflight.sh` 修: --force-merge token check 移到 preflight 前
- `tests/integration/tool-bypass-audit-test.sh` (104 lines): 5 levels 集成测试
- CLAUDE.md Rule 29: 工具不可绕过 (KALLAX P0)

## 跟对策 C 联合 (跟"诚实修正" 联合, 跟主公"同意" explicit 授权 联合)

- 5 扩展组 治 root cause, 但 5 扩展组 自身假 PASS (BE-15)
- Master 接管 = 对策 C 落地 (跟 Rule 11 联合, 跟"Master corrective integration" 模式 一致)
- 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"反讽" 闭环

## 跟"独立" 拍 explicit 约束 联合 (跟 Auditor-Token 模式 一致)

- **独立 session**: 跟 5 默认视角 + 6 之前 subagent 隔离, 独立 session
- **独立角色**: 不参与 Performer 工作流, 只治 root cause
- **独立路径**: 走 feature/EXPERT-security-tool-bypass 独立 worktree
- **独立报告**: 报 root cause 治疗方案

## 跟 14 BE 累计 联合 (跟"不要再犯了" 联合)

- BE-1 ~ BE-14: 8 试反复 + 10 KPI falsification + Token 限撞墙 + 越界反向
- **BE-15**: 3 假 PASS (跟 14 subagent = 21.4% 瞒报率 联合)
- 9 Security Review Issues (跟对策 C 联合, 跟"反讽" 闭环)

## 跟 v1.2.4 release 联合

miao HEAD `5192c79` + tag `v1.2.4` (跟 5 release 累计 联合, 跟"反哺框架" 战略 一致)

---

**跟对策 C 联合, 跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"诚实修正" 联合, 跟 Rule 29 联合, 跟 BE-7 修复模式 联合, 跟 5 战略建议 反讽 闭环 联合**
