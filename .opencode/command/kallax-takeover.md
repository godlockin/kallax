---
description: 中途接手项目 (3 库状态扫 + 路由器主动给 2 推荐 + 3 件套输出)
---

# /kallax-takeover

用法: `/kallax-takeover <project_path> <user_need>`

跟 v1.3.3 (f433a84) 联合, 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合.

## 触发条件
- 路径**有** CLAUDE.md 或 jira/ 或 .kallax/ (跟"反讽" 联合)

## 流程
1. 扫 3 库状态 (0 LLM, pure shell)
2. LLM 预审 (1 调用)
3. 路由器主动给 2 推荐 (跟"反讽" 联合, 跟 v1.3.0 模式 一致):
   - A 简单理解 (1 Architect)
   - B 深入研究 (3-5 专家)
   - C 自定义
4. 加载 5 default + 5 extended skill 文档
5. 输出 TAKEOVER-REPORT.md (3 件套: 亮点 / 缺点 / 隐患)
6. 写入 .kallax/inbox/human_feedback/ 等主公拍板 (跟"独立" 拍 explicit 约束 联合)

详细: docs/superpowers/specs/2026-06-15-kallax-v2.0-alignment-design.md §4.2
