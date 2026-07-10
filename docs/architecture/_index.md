# Architecture 索引 (v3.6.0 极简)

> 5 release 累计 0 跳 + 0 装饰 (Q12 战略 配合) | 跟 eket 借鉴

## §1 1 主文档
docs/ARCHITECTURE.md (423 行, 12 章节) — 唯一 architecture 入口

## §2 0 子文档
跟 v3.6.0 简化哲学 配合 (14 → 0)
- 删: framework / three-repo / workflow-engine / verification-protocol
- 删: degradation-strategy / agent-protocol / dag-scheduler / election-system
- 删: heartbeat-observability / hook-pipeline / isolation-strategy
- 删: recommender-system / roadmap / 3-MODES

## §3 详细 见 git history
- commit SHA 1:1 引用 (子文档 全部 git history 保留)
- 重构 时 git log --follow docs/ARCHITECTURE.md 可追溯

## §4 跟 eket 借鉴
- eket 模式: 1 主文档 + 0 sub-doc sprawl
- KALLAX 模式: docs/ARCHITECTURE.md 唯一入口
- 0 装饰 引用 + 0 估数 + 0 narrative

## §5 5 release 累计
- v3.0.0 → v3.5.0: 0 architecture 跳 (主文档 稳定)
- v3.6.0: 14 sub-doc → 0 (1 主文档 入口)
- 例外: online-deploy-2026-06-30/ (P-004 ERRATA 待主公拍)
