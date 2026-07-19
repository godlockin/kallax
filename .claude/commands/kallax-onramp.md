---
description: Multi-level project analyzer (L1 simple / L2 deep / L3 full audit + 3-piece output). REQUIRES 2 args — both `project_path` (绝对路径) and `user_need` (主公诉求). 路由前必须先有这 2 个, 不然会撞参数缺失。
argument-hint: <project_path> <user_need> (2 required)
---

# /kallax-onramp

用法: `/kallax-onramp <project_path> <user_need>`

例:
- `/kallax-onramp /path/to/proj 轻量了解`
- `/kallax-onramp /path/to/proj 接手重构`
- `/kallax-onramp /path/to/proj 完整审计并抽 guidance`

详细: docs/superpowers/specs/2026-06-14-kallax-onramp-design.md