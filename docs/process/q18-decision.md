# Q18 决策 索引 (v3.6.0 极简)

> 5 release 累计 32 findings 100% 治根 闭环 | 跟 eket 1:1 借鉴 0 增 Rule

## §1 5 levels × 4 roles = 25 cells
- L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary
- 跟 eket 1:1 借鉴 (5 levels 验证 机制)
- 4 roles: Conductor + Performer (coder/reviewer/tester/docs)

## §2 5 类 block + 3 类 danger
- 5 类 block: scope_creep / kpi_falsification / auth_fail / etc
- 3 类 danger: data_destruction / force_push / reset_hard
- 跟 Rule 14 (3 模式) + Rule 18 (KPI 黑名单) 联合

## §3 实现在 scripts/permission/decision-matrix.sh (the law)
- --self-test 输出 25/25 cells covered + 5 L4 主公拍
- --check <role> <level> 输出 mode (自主/推荐/主公拍)
- 0 文档化 0 narrative 包装

## §4 跟 eket 1:1 借鉴 0 增 Rule
- eket 1 主文档 + 0 sub-doc sprawl (跟 KALLAX docs/architecture/_index.md 1:1)
- eket 25 cells 决策 模式 (跟 KALLAX 5 levels × 5 roles 1:1)

## §5 5 release 累计 32 findings 100% 治根 闭环
- v3.0.0: 6 武器 起点
- v3.1.0: 16 hotfix 治根
- v3.2.0: rtk + caveman 整合
- v3.3.0: 4→5 层 升级
- v3.5.0: 16 findings 治根
- v3.6.0: 4 immutable scripts (法律) + 极简 哲学 (文化)
