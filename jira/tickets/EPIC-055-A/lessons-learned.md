# EPIC-055-A Lessons Learned — CLAUDE.md + KALLAX-GLOSSARY.md 去重 (单一 SoT)

> **Ticket**: EPIC-055-A (CLAUDE.md + KALLAX-GLOSSARY 去重, 治 A5 重复知识, Rule 5 DRY 落地)
> **Performer**: performer-EPIC-055-A
> **Date**: 2026-06-17
> **Status**: ✅ DONE — 6/6 PASS (100.0%), boundary 0 越界
> **联动**: Rule 5 DRY (Single Source of Truth) + Immutable Principle #5 + EPIC-054-D Rule 合并 proposal (候选 B 反讽治根) + EPIC-055-B 主公拍板分级

---

## TL;DR

**A5 重复知识 闭环**: CLAUDE.md (Rule SoT) + KALLAX-GLOSSARY.md (术语 SoT) 互链, Rule 定义不再复制. 体量 70035 → 34001 bytes (-51.5%, 超过 -50% 目标). 6/6 PASS (100.0%, Rule 9 X/Y 精确格式).

**6/6 PASS** (跟 Rule 9 X/Y 精确格式 联合):
- TC1: 重复章节扫描 (4/4 sub-checks: 7 links to GLOSSARY + 2 inline refs)
- TC2: 外链完整性 (3/3 sub-checks: 7/7 anchors + 31 back-links)
- TC3: 体量减少 (3/3 sub-checks: CLAUDE.md=-46.0%, GLOSSARY=-59.2%, total=-51.5%)
- TC4: 章节唯一性 (3/3 sub-checks: 23 Rules + 34 术语 + 无 ### Rule N in GLOSSARY)
- TC5: 死链检测 (4/4 sub-checks: GLOSSARY.md + PHASE-INDEX link + relative path + 📖 SoT section)
- TC6: 一致性校验 (6/6 sub-checks: Rule 9/11/16 编号 在 CLAUDE.md 跟 GLOSSARY 一致)

---

## Lesson 1: SoT 设计 — 双向 顶部章节锚定 (跟 Rule 5 DRY 联合)

**洞察**: 单一 SoT 不能只单向锚定 — 必须双向. CLAUDE.md 顶部 `📖 术语参考` 链到 GLOSSARY, GLOSSARY 顶部 `📖 规则参考` 链到 CLAUDE.md. 单向的话, 用户从 Rule 找不到术语, 从术语找不到 Rule.

**实施**:
```markdown
# CLAUDE.md 顶部
## 📖 术语参考 (跟 Rule 5 DRY 联合)
术语/黑话/概念的 唯一真相来源 → [docs/KALLAX-GLOSSARY.md](docs/KALLAX-GLOSSARY.md)
- 元术语 ([反讽](docs/KALLAX-GLOSSARY.md#1-...) / 诚实修正 / 独立 / 闭环 / 联合)
- ...

# GLOSSARY 顶部
## 📖 规则参考 (跟 Rule 5 DRY 联合)
KALLAX 规则 (Rule 1-18 + 29-33) 的唯一真相来源 → [CLAUDE.md](../CLAUDE.md)
- 核心原则: Rule 1-13 → [CLAUDE.md #核心原则](../CLAUDE.md#核心原则)
- ...
```

**应用**: 后续 SoT dedup ticket (e.g. PROCESS.md vs PHASE-REVIEW.md) 都用双向锚定模式. 跟 Rule 5 DRY 联合, 跟"流程逻辑 > 扩充配置" 战略 一致 (改流程, 不加 Rule).

**跟"诚实修正" 战略 联合**: 主公 2026-06-16 14 问题分析 A5 explicit 派单, 不能只看 "减少体量" — 必须从 SoT 边界 设计, 否则只是表面修剪, 实际重复还在.

---

## Lesson 2: 外链策略 — Rule 引用形式 (跟 Rule 5 DRY + 跟 Rule 11 v2.1 联合)

**洞察**: GLOSSARY 的 Rule 引用有 3 种形式:
1. ❌ `[CLAUDE.md #11-master-写代码禁令](../CLAUDE.md#11-master-写代码禁令-kallax-p0--主公原话硬红线)` — 长路径, anchor 跟 title 必须匹配
2. ✅ `Rule 11 (Master 写代码禁令) — [CLAUDE.md](../CLAUDE.md)` — 短 + Rule 编号 + 名称
3. ✅ `Rule 11 — [CLAUDE.md](../CLAUDE.md)` — 极简

**实施**: 用形式 2 (Rule 编号 + 短描述 + 链) — 让 grep "Rule 11" 能找到, 又不强制 anchor 必须匹配 (避免 anchor 链接失效).

**应用**: 后续 Subagent 5 步 文档 / A+B review 模板 / Master 强验证 文档 都用形式 2 引用. 跟 Rule 11 v2.1 5 levels (L1-L5) 联合 (L2 git show 看内容真改).

---

## Lesson 3: Rule 5 DRY 落地 — inline 哲学化 prose 是 SoT 重复的 真凶 (跟"诚实修正" 战略 联合)

**洞察**: CLAUDE.md 跟 GLOSSARY 重复 不是因为 Rule 定义复制, 而是因为 **`跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合`** 这种 inline 哲学化 prose — 这些短语在 CLAUDE.md 出现 200+ 次, 在 GLOSSARY 出现 100+ 次, 加起来 ~300+ 次同样的"反讽/诚实修正/独立" 描述.

**实测数据**:
- CLAUDE.md 改前: `跟 X 联合` 出现 200+ 次 (line 1-782 全文)
- CLAUDE.md 改后: 2 次 (顶部 `## 📖 术语参考` + 详细文档链接)

**应用**: 后续 dedup 类 ticket (e.g. PROCESS.md vs NEW-PROCESS-2026-06-13.md, 重复内容 1000+ 行) 用同样模式 — 不是删内容, 是把 inline 哲学化 prose 抽到顶部 SoT 章节. 跟 Rule 5 DRY 联合.

**跟"翻篇&精进" 战略 联合**: 14 BE → 1 份 ACCUMULATED-LESSONS-2026-06-13.md 是同一模式 (沉淀, 不反复). 当前 SoT dedup 是同模式的轻量级应用.

---

## Lesson 4: 跟 EPIC-054-D Rule 合并 proposal 联动 — 候选 B 反讽治根 (跟 Rule 32 联合)

**洞察**: EPIC-054-D 候选 B (Rule 32 撤销/合并到 Rule 5 DRY) 跟 EPIC-055-A (CLAUDE.md + GLOSSARY 去重) 是同一治根的 2 个表现:
- EPIC-054-D: Rule 32 (软约束升级阈值) 本身是 Rule → 反讽地 加剧 Rule 通胀 → 应撤销/合并到 Rule 5 DRY
- EPIC-055-A: CLAUDE.md 跟 GLOSSARY 都是 KALLAX 文档的 SoT → 反讽地 都定义同一 Rule → 应去重, 让 Rule 只在 CLAUDE.md 定义

**联动**: 本 ticket 给 EPIC-054-D 候选 B 提供 实证 — Rule 32 → Rule 5 DRY 合并后, "Rule 升级阈值"概念只在 Rule 5 章节出现一次, 不再有反讽的 Rule 32 独立章节. 净价值 +3.0% (跟 EPIC-054-D 测算 联合).

**应用**: 后续 ticket 跟 EPIC-054-D 联动时, 主公拍板 Rule 32 → Rule 5 合并后, CLAUDE.md Rule 5 章节加 "软约束升级阈值 (>80% 触发审查 / >15 Rule 触发重构 / >10 门禁 触发架构评估)" 子条款, Rule 32 章节撤销.

---

## Lesson 5: Test 6 case 设计 — 6 维度闭环 (跟 Rule 9 X/Y 精确格式 联合)

**洞察**: 本 ticket 测试 6/6 覆盖:
- TC1 (重复章节扫描): 验证 SoT 边界识别 — 7 links to GLOSSARY, 2 inline refs (was 200+)
- TC2 (外链完整性): 验证双向锚定 — 7/7 anchors + 31 back-links
- TC3 (体量减少): 验证 SoT 边界效果 — total 34001 ≤ 35000 (-51.5%)
- TC4 (章节唯一性): 验证 Rule 在 CLAUDE.md / 术语在 GLOSSARY — 23 Rules + 34 术语 + 无交叉
- TC5 (死链检测): 验证 link target 存在 — 4/4 sub-checks
- TC6 (一致性校验): 验证 Rule 编号两边一致 — Rule 9/11/16 在两边都引用

**实测反讽**: 写 TC4 时, 我误把 `TC4_PASS=$((TC1_PASS))` 当 placeholder 留在代码里, 导致 TC4 计数 +1 来自 TC1. 写测试时跑 5/6 = 83.3%, 跟"诚实修正" 战略 联合 — **不能跳过这个 bug**, 改完跑 6/6 = 100.0%. 跟 Rule 9e (Performer 工具调用自验证 = FAIL) 联合, 自验证重要.

**应用**: 后续 ticket 测试设计 都用 "边界 + 完整性 + 效果 + 唯一性 + 死链 + 一致性" 6 维度闭环. 跟 Rule 9 5-Level Fact-Forcing 联合 (L1 存在 → L2 实质 → L3 接线 → L4 数据流).

---

## Lesson 6: 体量减少 -51.5% 超过 -50% 目标 — 反讽诊断 (跟"诚实修正" 联合)

**洞察**: 目标 -50% (CLAUDE.md + GLOSSARY ≤ 35000 bytes from 70035). 实际 -51.5% (34001 bytes). 表面看"超额完成", 实际有反讽:

1. **GLOSSARY 减幅 (-59.2%) 远大于 CLAUDE.md (-46.0%)**: 因为 GLOSSARY 大量 `跟 X 联合` inline 解释, 改 Rule 引用后变很短. CLAUDE.md Rule 定义本身不能大幅压缩, 只能去 inline noise.
2. **CLAUDE.md 仍有 22130 bytes**: 含 23 Rule + 顶部 SoT 章节 + 命令速查 + 工作流 + 5-Level, 这些不能减. Rule 5 (类型安全) / Rule 6 (经验沉淀) / Rule 11 (Master 禁令) / Rule 14-18 (R-NEW) / Rule 29-33 (5 扩展组) 都是 KALLAX 核心, 不能砍.
3. **下一步优化空间**: 跟 EPIC-054-D 候选 B 合并 Rule 32 → Rule 5 后, CLAUDE.md 可能再减 300-500 bytes (-2%). 但本 ticket 不动 (跟 PROCESS.md:25-26 Master 不能自己升级红线 联合).

**应用**: 后续 ticket 不要再追求 "更小" — -51.5% 已经达上限. 优化方向应转向 "SoT 边界更清晰" (e.g. PHASE-INDEX vs ACCUMULATED-LESSONS-2026-06-13.md 是否重复).

---

## 7 anti-fab tool PASS 记录 (跟 Rule 9 9a/9b/9c + Rule 32 联合)

| 工具 | 结果 | 验证 |
|---|---|---|
| `check-test-case-isolation.sh` | PASS (0/50 leaked) | Rule 9b 防御 |
| `check-kpi-precision.sh` | PASS (0 estimate) | Rule 9a 防御 |
| `check-scope-creep.sh EPIC-055-A` | PASS (5 files in scope) | Rule 9c 防御 |
| `check-fact-forcing-preflight.sh` | PASS | Rule 9 L1-L4 强验证 |
| `l3-l4-consistency.sh` | PASS (L3/L4 一致) | BE-9 自检漏洞防御 |
| `kpi-evidence-chain.sh` | PASS | Rule 18 防御 |
| `tool-self-check.sh all` | PASS (8/8 = 100.0%) | Rule 29 工具不可绕过 |

---

## Boundary 0 越界 (跟 file_scope 联合)

**已改 (5 文件)**:
- `jira/tickets/EPIC-055-A/IMPLEMENTATION-PLAN.md` (新, 跟 ticket spec 联合)
- `tests/integration/doc-dedup-test.sh` (新, TDD 6/6 PASS)
- `CLAUDE.md` (改, 留下规则/红线/必读 + glossary 章节外链)
- `docs/KALLAX-GLOSSARY.md` (改, 只保留术语表 + 链接到 CLAUDE.md)
- `docs/PHASE-INDEX.md` (改, 同步 SoT 索引)

**未改 (跟 file_scope 边界 联合, 0 越界)**:
- docs/PROCESS.md (跟 EPIC-056-A 边界)
- docs/STRUCTURE.md (跟 EPIC-054-D 边界)
- docs/process/approval-tiering.md (跟 EPIC-055-B 边界)
- docs/process/metrics-kpi.md (跟 EPIC-056-B 边界)
- AGENTS.md (跟 KALLAX 核心边界)
- 其他 EPIC ticket

---

## KPI 精确 X/Y 格式 (跟 Rule 9a 联合)

- **6/6 PASS** (100.0%, Rule 9 X/Y 精确格式)
- **体量减少**: 70035 → 34001 bytes (-51.5%, 超过 -50% 目标)
- **CLAUDE.md**: 40970 → 22130 bytes (-46.0%)
- **GLOSSARY**: 29065 → 11871 bytes (-59.2%)
- **boundary 越界**: 0
- **anti-fab tool**: 7/7 PASS

---

**跟 Rule 5 DRY (Single Source of Truth) 联合, 跟 Immutable Principle #5 联合, 跟 EPIC-054-D Rule 合并 proposal 联动 (候选 B 反讽治根), 跟"诚实修正" + "流程逻辑 > 扩充配置" 战略 一致, 跟 Rule 9 X/Y 精确格式 联合, 跟 Rule 16 5 步强制流程 联合 (5/5 步), 跟"翻篇&精进" 战略 一致**