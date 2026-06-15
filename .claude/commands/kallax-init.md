---
description: 项目初始化 (3 库分离 + CLAUDE.md + 5 default + 5 extended skill + INIT-REPORT)
---

# /kallax-init

用法: `/kallax-init <project_path>`

跟 v1.3.3 (f433a84) 联合, 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合.

## 触发条件
- 路径**无** CLAUDE.md + 无 jira/ + 无 .kallax/ (跟"反讽" 联合)

## 流程
1. 扫路径 (0 LLM)
2. 创建 3 库骨架 (docs/ + jira/ + scripts/ + .kallax/)
3. 创建 CLAUDE.md 模板 (复用 template/CLAUDE-TEMPLATE.md)
4. 创建 5 default + 5 extended skill 文档 (复用 template/.claude/skills/kallax/)
5. LLM 预审 (1 调用)
6. 输出 INIT-REPORT.md
7. 等主公拍 explicit 授权 (跟"独立" 拍 explicit 约束 联合)

详细: docs/superpowers/specs/2026-06-15-kallax-v2.0-alignment-design.md §4.1