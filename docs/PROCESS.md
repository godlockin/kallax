# KALLAX 流程 (v2.0.0, 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟主公 §2 拍板 联合, 跟 Rule 11/14/15/16 联合, 跟"诚实修正" 联合.

## /kallax-init (项目初始化)

跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合, 跟 v1.3.3 Onramp 模式 一致:

1. 扫路径 (0 LLM)
2. 创建 3 库骨架 (跟"流程逻辑" 战略 一致)
3. 创建 CLAUDE.md 模板
4. 创建 5 default + 5 extended skill 文档
5. LLM 预审 (1 调用)
6. 输出 INIT-REPORT.md
7. 等主公拍 explicit 授权 (跟"独立" 拍 explicit 约束 联合)

## /kallax-takeover (中途接手)

1. 扫 3 库状态 (0 LLM)
2. LLM 预审 (1 调用)
3. 路由器主动给 2 推荐 (跟"反讽" 联合, 跟 v1.3.0 模式 一致)
4. 加载 5 default + 5 extended skill 文档
5. 输出 TAKEOVER-REPORT.md (3 件套)
6. 写入 .kallax/inbox/human_feedback/ 等主公拍板

## Master 节点 (跟 Rule 11 联合, 跟"反讽" 联合)

- ✅ 读 CLAUDE.md + jira/ + scripts/ (只读分析)
- ✅ 派单到 Performer worktree (跟"反讽" 联合, 跟 Rule 16 Step 1 联合)
- ✅ Master 强验证 6 维度 (跟"反讽" 联合, 跟 Rule 11 v2.1 联合)
- ❌ 写 代码 (跟"反讽" 联合, 跟 Rule 11 硬红线 联合)
- ❌ 写 测试 (跟"反讽" 联合, 跟 Rule 11 联合)
- ❌ 写 文档 (除 CLAUDE.md + confluence/decisions/ 边界文件)

## Subagent 完整流程 (跟 Rule 15/16 联合, 跟"反讽" 联合)

```
1. 拆 worktree (Rule 15, 跟"反讽" 联合 — 行为准则第一条)
2. 加载目标 ticket 描述 (Rule 15, 跟"反讽" 联合)
3. 加载 目标专家 profile (v1.3.0 Onramp 模式 一致, 跟"反讽" 联合)
4. 深度分析当前项目状态 + ticket
5. 写 执行计划 (跟"反讽" 联合, 跟 Rule 9 联合)
6. 遵循 TDD 写测试 (跟"反讽" 联合, 跟 Rule 9 L1 联合)
7. 写 代码 (跟"反讽" 联合, 跟 Rule 9 L2 联合)
8. 跑 全套测试 (跟"反讽" 联合, 跟 Rule 9 L3+L4 联合)
9. A 组 正向 review (5 default, 跟"反讽" 联合)
10. B 组 逆袭 review (5 extended, 跟"反讽" 联合)
11. 写 LESSONS-LEARNED.md 草稿 (Rule 6 联合)
12. 报 PASS (Rule 16 5 步 联合, 对策 A 联合)
13. Master 强验证 6 维度 (Rule 11 v2.1 联合)
14. PASS → Conductor merge (Rule 1 联合)
15. FAIL → 退回 Performer 修 (Rule 11 v2.1 联合)
```

## A+B Review (跟"反讽" 联合, 跟 v1.2.4 5 扩展组 联合, 跟"诚实修正" 联合)

详细: `docs/process/A-B-REVIEW.md`

---

**跟主公 §2 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟 Rule 11/14/15/16 联合, 跟"流程逻辑 > 扩充配置" 战略 一致**