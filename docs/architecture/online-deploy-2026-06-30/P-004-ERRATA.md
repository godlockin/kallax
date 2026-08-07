> **DEPRECATED (2026-08-07, EPIC-200)**: v3.5.0 hotfix ERRATA, P-004 修订记录
> **现代替代**: `docs/ARCHITECTURE.md` §"deployment"
> **保留原因**: 历史 reference, 0 删 (跟 EPIC-196 v2 1:1 archive-not-delete)
>
# v3.5.0 hotfix P-004 ERRATA (跟 B 组 Attack Review P-004 从根源修复,配合)

> 跟 B 组 P-004 从根源修复,配合, 跟 V310-B P-009 cli-reference 重复 配合, 跟 Rule 5 DRY,配合:
> docs/architecture/online-deploy-2026-06-30/README.md (v3.3.0 拍 C 落地) 唯一 nested dir 在 docs/architecture/
> 内容 跟 degradation-strategy.md (16.6K) + isolation-strategy.md (18.9K) 部分 重复 (3 tier degradation)

## 待 决策者拍板 v3.6.0 整合 (跟"独立" 拍 explicit 约束,配合)

| 整合方案 | 内容 | 跟"独立" 拍板,配合 |
|---------|------|----------------|
| A 合并进 degradation-strategy.md §X | 3 tier degradation 内容 直接 加到 degradation-strategy.md 新章节, 删 nested dir | 待决策者 拍 |
| B 合并进 isolation-strategy.md §X | 跟 tier degradation 隔离策略,配合, 删 nested dir | 待决策者 拍 |
| C 保留 nested dir + 显式 mark DEPRECATED | 配合 v3.2.0 拍 C "重写 > 删除",配合, 留 ref history | 待决策者 拍 |

## v3.3.0 "实际部署" vs "重写 README" 区分 (跟"诚实修正评估",配合)

跟 V350-RELEASE-2026-06-30.md ERRATA §4 配合: 决策者 v3.3.0 拍 C "3 票 全部 实际 部署" — 实际是 "重写 README" 而非 "真部署". release doc 措辞 跟实现 不一致 是 同类症状.

## 配合 v3.5.0 hotfix 范围,配合

本 ERRATA 文档 不改 nested dir 内容 (跟"独立" 拍板,配合, 不擅自 删 / 重写 / 整合), 仅 显式 list 待决策者拍板 选项. 跟 V310-B U-002 1:1: 留待决策者拍板.

---

Co-Authored-By: Claude <noreply@anthropic.com>