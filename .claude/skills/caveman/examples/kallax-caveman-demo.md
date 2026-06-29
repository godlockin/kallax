# KALLAX ↔ caveman 实战 demo (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟主公 2026-06-29 拍板 explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致.

## 1. Conductor → Performer caveman 模式 派单 demo

```
[Conductor]
  派 TASK-001 → Performer-coder.
  4 task. T1 装 X. T2 测 Y. T3 写 Z. T4 升 v.
  边界: 不改 CLAUDE.md. 跟 v3.2.0 联合.
  [next: 派 1 Performer subagent.]

[Performer]
  [TASK-001] done.
  T1: cp X. SHA 4ebcea7c.
  T2: test Y. 4/4 PASS.
  T3: 写 Z. 137 行.
  T4: 升 v3.2.0. tag 落地. push 成功.
  [next: 等 Conductor verify.]
```

**节省 token**: 30+ 行 → 10 行 (~67% 节省, 跟 75% 声称 一致).

## 2. Performer → Auditor caveman 模式 报告 demo

```
[Performer]
  [TASK-002] PASS.
  L1 git log: SHA 6eee94b 真.
  L2 git show: version 3.2.0 真.
  L3 跑全量 E2E: 4/4 PASS.
  L4 preflight: push 成功, tag 在 remote.
  L5 边界: U-002 留待主公, 0 越界.
  L6 诚实: 0 KPI falsification.
  [next: Auditor 独立见证.]

[Auditor]
  [TASK-002] witness OK.
  audit hash: 4ebcea7c (sha256 8 字符).
  independent-witness.sh 6/6 PASS.
  0 假 PASS.
  [next: Master 强验证 6 维度.]
```

**跟 v3.1.0 武器 1 Hash-Chain Audit 联合**.

## 3. Conductor 心跳 5 问 caveman 模式 demo

```
[Conductor]
  [Q1 优先级] inbox 0. backlog TASK-001.
  [Q2 Performer 状态] in_progress 30min. timeout 阈值 30min.
  [Q3 项目进度] miao v3.2.0 (跟 origin 同步).
  [Q4 阻塞决策] U-002 留待主公. 写 inbox/human_feedback.
  [Q5 消息队列] 0 pending.
  [next: 派 Performer TASK-001.]
```

**跟 KALLAX PROCESS.md:25-26 心跳 5 问 联合**.

## 4. Performer sub-role 派单 caveman 模式 demo (跟 EPIC-038-A 联合)

```
[Conductor]
  [TASK-003] 派 Performer-tester.
  写 5 集成测试. 跟 L2/L4 联合.
  边界: 不改生产代码. 0 越界.
  [next: 派 1 Performer-tester subagent.]

[Performer-tester]
  [TASK-003] done.
  5 集成测试. 4-Level stdout 真实.
  raw output: 8/8 PASS. 0 silent fallback.
  [next: 推 PR.]
```

**跟 Rule 15 Performer sub-role schema (coder/reviewer/tester/docs) 联合, 跟"独立" 拍 explicit 约束 联合**.

## 5. eket 团队 VETO 后 补救 commit 模式 demo

```
[Conductor]
  [TASK-004] eket VETO 补救.
  3 evidence 落地.
  - docs/evidence/v3.2.0/rtk-*.txt 4 文件 (rtk stdout 真实)
  - .claude/skills/caveman/KALLAX-INTEGRATION.md (跟 KALLAX 6 command + 3 角色 显式绑定)
  - docs/evidence/v3.2.0/U-002-DECISION-MATRIX.md (4 候选 决策矩阵, 留主公拍)
  [next: 补救 commit + push, 0 amend, 0 删 tag.]
```

**跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合**.

## 6. 跟"反讽" 闭环 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

- ✅ **Conductor → Performer 派单** 走 caveman 模式 (跟"反讽" 联合, 跟"诚实修正" 联合)
- ✅ **Performer → Auditor 报告** 走 caveman 模式 (跟"独立" 拍 explicit 约束 联合)
- ✅ **Conductor 心跳 5 问** 走 caveman 模式 (跟"翻篇&精进" 战略 一致)
- ✅ **Performer sub-role 派单** 走 caveman 模式 (跟 EPIC-038-A 联合)
- ✅ **eket VETO 补救 commit 模式** 走 caveman 模式 (跟"反讽" 联合 治根, 跟"诚实修正" 联合)
- ✅ **0 增 KALLAX Rule** (跟 Rule 32 软约束升级阈值 联合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- ✅ **走对策 A+B+C 落地** (跟"反讽" 联合, 跟 Rule 11/14/15 联合, 跟"独立" 拍 explicit 约束 联合)

---

**跟主公 2026-06-30 拍 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致**
