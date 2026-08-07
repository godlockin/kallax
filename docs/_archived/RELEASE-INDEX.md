# KALLAX 5 release 累计 INDEX (跟 B 组 U-002 从根源修复,配合)

> **DEPRECATED (2026-08-07, EPIC-199)**: v3.1-v3.5 release 索引, GitHub Releases tab 提供更好体验。
> **现代替代**: GitHub Releases (https://github.com/godlockin/kallax/releases) + `CHANGELOG.md`
> **保留原因**: 历史 reference (evidence 路径引用), 0 删 (跟 EPIC-196 v2 1:1 archive-not-delete)

> v3.5.0 hotfix (跟 B 组 Attack Review U-002 从根源修复,配合, 跟 V310-B U-002 配合):
> 5 release 累计 release doc 散落 (V350 / V340 / V330 / V320 / V310 / V300), 跟踪困难.
> 本 INDEX 给 user 1 页入口 (配合 v3.1.0 P-006 "12 Operational Summaries" 模式 1:1).

## 5 release 累计 release doc 索引

| Release | 主 release doc | spec | LESSONS-LEARNED | evidence |
|---------|---------------|------|----------------|----------|
| **v3.5.0** (实战 eket 1 次) | [V350-RELEASE-2026-06-30.md](./V350-RELEASE-2026-06-30.md) | [spec](../docs/superpowers/specs/2026-06-30-v350-eket-parity-实战-design.md) | [v350-实战-eket-1次-2026-06-30.md](../confluence/decisions/v350-实战-eket-1次-2026-06-30.md) | [evidence/v3.5.0/](../evidence/v3.5.0/) |
| **v3.4.0** (21 release 累计 + eket parity 1 项) | (v340-21-release-eket-parity-2026-06-30.md 在 confluence/) | [v340 spec](../docs/superpowers/specs/2026-06-30-v340-21-release-eket-parity-design.md) | [v340 LESSONS](../confluence/decisions/v340-21-release-eket-parity-2026-06-30.md) | [evidence/v3.4.0/](../evidence/v3.4.0/) |
| **v3.3.0** (A1+A2+B+C+E 根治 + eket 对齐) | (docs/_archived/ 或 confluence/decisions/15629cd + 03c0e7f) | — | — | — |
| **v3.2.0** (rtk + caveman + U-002 重写 4 DEPRECATED) | (RTK-CAVEMAN-KALLAX-2026-06-29.md) | [rtk-caveman spec](../docs/superpowers/specs/2026-06-29-rtk-caveman-kallax-integration-design.md) | — | [evidence/v3.2.0/](../evidence/v3.2.0/) |
| **v3.1.0** (16 hotfix + Iter 12 不删) | [RELEASE-v3.1.0-2026-06-29.md](../confluence/decisions/RELEASE-v3.1.0-2026-06-29.md) (在 confluence/decisions/ 或 docs/_archived/) | — | [v310 LESSONS](../confluence/decisions/V310-B-REVIEW-2026-06-29.md) | — |
| **v3.0.0** (6 武器 + Iter 11 整合) | (配合 v3.0.0 1 release 入口 doc,配合) | — | — | — |

## 5 release 累计 引用 入口 doc

| 入口 doc | 用途 | 配合 v3.5.0 hotfix,配合 |
|---------|------|---------------------|
| [4-roles.md](./4-roles.md) (5.3K) | master + Conductor + Performer + 1+4 容量 | ✅ 跟 U-004,配合 (caveman 入口) |
| [5-levels.md](./5-levels.md) (4.0K) | 5-Level Fact-Forcing (L1 git SHA / L2 stdout / L3 4-expert / L4 witness / L5 boundary) | ✅ 跟 S-001 / P-002,配合 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) (20.8K) | 主架构 doc (跟"独立" 拍板,配合, Iter 2 锁定, 不在本 hotfix 范围) | ⚠️ U-001 stale (P1, 下个 sprint 修) |
| [CHEATSHEET.md](./CHEATSHEET.md) (1.7K) | 1 页 cheatsheet | ⚠️ U-001 stale (P1, 下个 sprint 修) |
| [RTK-CAVEMAN-KALLAX-2026-06-29.md](./RTK-CAVEMAN-KALLAX-2026-06-29.md) (3.5K) | rtk + caveman + KALLAX 整合 doc | ✅ 跟 U-004 / P-005,配合 (caveman README) |
| [V350-RELEASE-2026-06-30.md](./V350-RELEASE-2026-06-30.md) (3.0K) | v3.5.0 release 整合 | ✅ 跟 U-003 自打脸,配合 (ERRATA 段 待 加) |

## 5 release 累计 ad-hoc release doc (跟 U-002 sprawl,配合, 部分待整合)

| ad-hoc doc | 大小 | 来源 | 配合 v3.5.0 hotfix,配合 |
|-----------|------|------|---------------------|
| docs/V350-RELEASE-2026-06-30.md | 3.0K | v3.5.0 | ✅ INDEX 入口 |
| docs/RTK-CAVEMAN-KALLAX-2026-06-29.md | 3.5K | v3.2.0 | ✅ 整合 (跟 INDEX,配合) |
| docs/KARPATHY-VS-KALLAX-2026-06-27.md | 8.7K | v3.0.0 | 待整合 (下个 sprint) |
| docs/architecture/online-deploy-2026-06-30/README.md | (v3.3.0) | v3.3.0 C 拍板 | ⚠️ U-005 nested dir (P2, 待整合到 degradation-strategy.md) |
| docs/V340-RELEASE-2026-06-30.md | (v3.4.0) | 缺 | ⚠️ 缺, 待 V350-INDEX 入口,配合 |

## 跟 B 组 U-002 从根源修复,配合

v3.1.0 U-002 P1 (commit fbea0aa) 留待决策者拍板, v3.2.0 决策者拍 C 重写 (commit 08f2393), 但 commit 仅重写不删 — 4 × ~32KB DEPRECATED 仍.

本 INDEX 不删 4 DEPRECATED (配合 v3.2.0 拍 C "重写 留 ref history" 一致), 只给 user 1 页入口 — user 不用 在 docs/architecture/ 17 文件 找 release doc.

## 跟 B 组 U-005 从根源修复,配合

docs/architecture/online-deploy-2026-06-30/ 是 nested dir, 唯一在 docs/architecture/ — _index.md 0 引用. 本 INDEX §"ad-hoc release doc" 表 第 4 行 列 出, user 可从 INDEX 入口 跳.

## 跟"独立" 拍 explicit 约束,配合

决策者 v3.5.0 拍 "v3.4.0 已 align eket + 开始 v3.5.0" (commit 096eafe) — 本 INDEX 显式 list v3.4.0 + v3.5.0 入口, 跟决策者拍板 配合.

---

Co-Authored-By: Claude <noreply@anthropic.com>