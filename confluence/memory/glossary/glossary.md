# ARCHIVED 2026-06-29: 35 术语已砍, 见 docs/CHEATSHEET.md + 5-levels.md + 4-roles.md (Q16 决策)
# KALLAX 黑话词典 (v2.7.5, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致.

跟主公 2026-06-28 拍板"修 Gap 6 64 术语" explicit 授权 联合, 64 → 35 压缩 落地.

---

## 1. KALLAX 元术语 (合并: 反讽+诚实修正+独立)

### 1.1 「反讽」闭环 (Irony Loop)
- 大白话: 治 root cause 方案 自身是 root cause 受害者
- 来源: v2.0.4 5 扩展组 100% 假 PASS
- 跟 Rule 18 反模式黑名单 联合

### 1.2 「诚实修正」模式 (Honest Correction)
- 大白话: 看到反讽不装看不见, 主动标记问题
- 来源: 主公 2026-06-13 原话
- 跟 Rule 11 联合

### 1.3 「独立」拍 explicit 约束 联合
- 大白话: 5 维度全独立 (session/角色/路径/报告/审计)
- 来源: 主公 2026-06-13 多次强调
- 跟 Rule 14/15 联合

### 1.4 「explicit 约束 联合」格式
- 大白话: "X explicit 约束 联合" 追溯链格式
- 来源: Rule 11 标识要求
- 跟 Rule 31 联合

---

## 2. KALLAX 战略 (合并: 反哺框架+翻篇&精进+流程逻辑>扩充配置)

### 2.1 「流程逻辑 > 扩充配置」战略
- 大白话: 别再加配置了, 改流程逻辑
- 来源: 主公 2026-06-13 战略转向
- 跟 Rule 32 联合

### 2.2 「反哺框架」战略
- 大白话: KALLAX 用 KALLAX 自身来改进
- 来源: 5 release 飞轮反哺
- 跟 Rule 6 联合

### 2.3 「翻篇&精进」战略
- 大白话: 已发生别纠结, 往前看怎么改
- 来源: 14 BE → ACCUMULATED-LESSONS
- 跟 BE-1 ~ BE-15 联合

---

## 3. KALLAX 验证机制 (合并: 对策 A+B+C+Master 强验证 6 维度)

### 3.1 「对策 A+B+C」
- 大白话: Subagent 自验证 + Conductor 接收验证 + Master 强验证
- 来源: 3 假 PASS 模式 从根源修复
- 跟 Rule 10/18 联合

### 3.2 「Master 强验证 6 维度」
- 大白话: 6 维度全 PASS 才放行
- 来源: Rule 11 v2.1
- 跟 L1 git log / L2 git show / L3 E2E / L4 preflight / L5 边界 / L6 诚实 联合

### 3.3 「4-Level Fact-Forcing」
- 大白话: 4 级都过: 存在 → 实质 → 接线 → 数据流
- 来源: Rule 9
- 跟 3 anti-fab 子工具 联合

### 3.4 「5 步强制流程」
- 大白话: ticket 同步 → 3 anti-fab → preflight → review → 强验证
- 来源: Rule 16
- 跟 Subagent 5 步 联合

### 3.5 「飞轮反哺」
- 大白话: 每 release 都沉淀 + 升级
- 来源: v1.1.0 → 4 文档 REV2
- 跟"反哺框架" 战略 联合

---

## 4. KALLAX 反模式 黑名单

### 4.1 「KPI falsification」
- 大白话: 估数/模糊报 PASS = FAIL
- 来源: Rule 9a + Rule 18 #1
- 跟 10 KPI falsification 累计 联合

### 4.2 「Test case verbatim 触发 = FAIL」
- 大白话: trigger 整句塞 test case = 假数据
- 来源: Rule 9b + Rule 18 #2
- 跟 51125b9 假 100% 联合

### 4.3 「Scope creep 必拆 PR」
- 大白话: file_scope.includes 外改动 = FAIL
- 来源: Rule 9c + Rule 18 #3
- 跟 6563362 Arc imports 联合

### 4.4 「越界反向」
- 大白话: subagent 写主 checkout 反 worktree
- 来源: Rule 14/15
- 跟 5 subagent 越界反向 联合

### 4.5 「3 假 PASS 模式」
- 大白话: 报 PASS 实际 0 commit / 估数 / 借口环境
- 来源: Rule 18 #6/#7/#8
- 跟 50% 假 PASS 概率 联合

### 4.6 「BE」 (Bad Event / 教训编号)
- 大白话: 累计 15 BE (BE-1 ~ BE-15)
- 来源: PHASE-008-REVIEW-2026-06-13.md
- 跟 ACCUMULATED-LESSONS + 反讽 联合

---

## 5. KALLAX 角色 决策

### 5.1 「3 模式」 (ai-auto / ai-copilot / manual)
- 大白话: 决策权分配 3 模式
- 来源: Rule 13
- 跟"决策疲劳" 联合

### 5.2 「Conductor 不能越界 Performer 实施」
- 大白话: Conductor session 不能 Edit/Write/Commit
- 来源: Rule 14 R-NEW
- 跟 BE-13 越界反向 联合

### 5.3 「Master 接管」
- 大白话: 极端情况主公拍"接管"才接管
- 来源: Rule 11
- 跟对策 C 联合

### 5.4 「Performer sub-role + A+B review」
- 大白话: 必独立 sub-role + 第一时间建 worktree + 5 default 正向 + 5 extended 逆袭
- 来源: Rule 15 + v2.0.0
- 跟主公"subagent 第一条" + 5 扩展组 联合

### 5.5 「14 subagent 21.4% 瞒报率」
- 大白话: 累计 14 subagent 派单, 21.4% 瞒报率
- 来源: 5 扩展组 100% 假 PASS
- 跟 Rule 29-33 联合

---

## 6. KALLAX 指标

### 6.1 「Rule 升级率 + 净价值」
- 大白话: 18 Rule 升级率 100% + 净价值 85.5%-23 Rule=62.5%
- 来源: 5 release + 5 视角
- 跟 Rule 32 联合

### 6.2 「1+2/1+4 容量 + 10 专家 + 5 视角 lessons + 14 BE + 12 Security」
- 大白话: 容量 + 10 专家 + lessons + BE + Security 累计
- 来源: EPIC-038-B + v2.0.0 + PHASE-008 + 5 扩展组
- 跟"决策疲劳" + Karpathy 4 大核心 + "反讽" 联合

### 6.3 「8 Gap + 4 工具 + 6 release + 3 件套 (Karpathy 60%→85%)」
- 大白话: 8 Gap P0/P1/P2 + 4 工具 + 6 release + 3 件套修
- 来源: Karpathy 4 大核心 + EPIC-057 + 飞轮反哺 + PHASE-009
- 跟"流程逻辑 > 扩充配置" 战略 联合

---

## 7. KALLAX 工程基础 (合并: Skill 文档+worktree 隔离)

### 7.1 「Skill 文档 + worktree 隔离」
- 大白话: KALLAX 专家能力可复用文档 + 必独立 worktree 写代码
- 来源: 5 default + 5 extended + Rule 15
- 跟 Rule 5 DRY + "subagent 第一条" 联合

### 7.2 「atomic write + file-lock + BE-7 修复」
- 大白话: 原子写 + 文件锁 + BE-7 umask/flock/chmod 修复
- 来源: Rule 17 + BE-7
- 跟"半截文件" 反讽 + Rule 29 工具不可绕过 联合

### 7.3 「4 工具生态 (Trae/hybrid/auto-target)」
- 大白话: 4 工具 + Trae ByteDance IDE + hybrid flag + auto-detect
- 来源: EPIC-057 + v2.0.6 + v2.0.2 反讽从根源修复
- 跟 Karpathy "Readability" 联合

### 7.4 「64 → 35 术语压缩」
- 大白话: 63 → 35 术语 压缩
- 来源: Karpathy "Readability"
- 跟"流程逻辑 > 扩充配置" 战略 联合

---

**跟主公 2026-06-28 拍板"修 Gap 6 64 术语" explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 17 release 累计 联合, 跟 23 Rule 累计 联合, 跟 5 default + 5 extended 累计 联合, 跟 14 BE 累计 联合, 跟 12 Security Review Issues 累计 联合, 跟 Karpathy 4 大核心 联合, 跟 v1.3.3 PHASE-INDEX.md 模式 一致, 跟 v2.0.2 release 模式 一致, 跟 v2.0.7 (8 Gap 修复) 联合, 跟 v2.7.4 release 联合**