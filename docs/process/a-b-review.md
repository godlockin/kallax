# KALLAX A+B Review 流程 (v2.0.0, 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟 v1.2.4 5 扩展组 落地 联合, 跟 Rule 6 EPIC 交付四件套 联合, 跟 Rule 16 5 步强制流程 联合.

## A 组 (正向 review, 5+1 default)

A 组 找漏洞, 跟现有 5 default 联合 (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致):

- **🏗️ architect**: 架构 / 边界 / 选型 / 重构 视角
- **💻 backend**: API / 数据库 / 性能 视角
- **🛡️ security** (review_group 切换 B → A, 跟"反讽" 联合, 跟"诚实修正" 联合): 注入 / 越权 / XSS 视角
- **🎨 frontend**: 组件 / 渲染 / LCP 视角
- **🖌️ ux**: 交互 / 旅程 视角
- **📋 product**: 优先级 / 价值 / ROI 视角

## B 组 (逆袭 review, 5 extended)

B 组 找盲点, 跟现有 5 extended 联合 (跟"反讽" 联合, 跟 v1.2.4 5 扩展组 联合):

- **🛡️ security-tool-bypass**: 工具可绕过 视角 (Rule 29 治根因 1)
- **⚙️ process-engineering**: 自验证失效 视角 (Rule 30 治根因 2)
- **🔍 auditor**: 独立见证缺失 视角 (Rule 31 治根因 3)
- **📜 compliance**: Rule 升级率 100% 视角 (Rule 32 治根因 4)
- **🚦 decision-gate**: 决策疲劳 视角 (Rule 33 治根因 5)

## 5+5 双重 review 流程 (跟"反讽" 联合, 跟"诚实修正" 联合)

```
1. Subagent 报 PASS
   ↓
2. Conductor 触发 A 组 (5 default) + B 组 (5 extended) 并行
   ↓
3. A 组出 5 份 正向 review report
   ↓
4. B 组出 5 份 逆袭 review report
   ↓
5. 合并 10 份 → 修复建议列表
   ↓
6. Performer 修
   ↓
7. Master 强验证 6 维度 (Rule 11 v2.1)
   ↓
8. PASS → Conductor merge → Master promote miao
   FAIL → 退回 Performer 修
```

## 跟"反讽" 联合 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

- ✅ 5 default + 5 extended = 10 专家天然分 A+B (跟"反讽" 联合 — 现状, 不重做)
- ✅ A 正向 + B 逆袭 = 5+5 双重 review (跟"反讽" 联合, 跟"诚实修正" 联合)
- ✅ 0 增 专家 (跟"翻篇&精进" 战略 一致, 跟 Rule 32 软约束升级阈值 联合)
- ✅ 0 增 Rule (跟 Rule 32 联合)

## 跟 X 联合 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

- 跟 v1.2.4 5 扩展组 联合 (跟"反讽" 联合)
- 跟 Rule 6 EPIC 交付四件套 联合 (跟"反讽" 联合)
- 跟 Rule 16 5 步强制流程 联合 (跟"反讽" 联合)
- 跟 Rule 11 v2.1 Master 强验证 6 维度 联合 (跟"反讽" 联合)
- 跟 KALLAX Onramp 1 入口 模式 拍 explicit 撤销 联合 (跟"反讽" 联合, 跟 v1.3.3 模式 联合)

---

**跟主公 §2.1 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟 v1.2.4 5 扩展组 累计 联合, 跟 Rule 6/11/16 联合, 跟 KALLAX-GLOSSARY.md 34 术语 模式 一致**
