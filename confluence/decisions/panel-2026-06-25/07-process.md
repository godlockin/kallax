# ⚙️ Process Engineering Expert Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: ⚙️ Process (跟 v2.0.3 EPIC-056-A Phase 2 联合)

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

- **F1 (文件数 discrepancy)**: Phase 1 §1.2 line 33 报 `docs/process/` 9 files, 实测 `ls docs/process/` 仅 7 files (file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:33` vs `docs/process/{9-hard-rules,A-B-REVIEW,approval-tiering,CLEANUP-PHILOSOPHY,fact-forcing,metrics-kpi,tag-sop}.md`). Conductor 全局扫描数字 ≠ reality — 直接触发 fact-forcing §11.3 "0 实际变化 假动作" 模式 (file:line `docs/process/fact-forcing.md:380`).
- **F2 (5 原则 实施缺口)**: `docs/process/CLEANUP-PHILOSOPHY.md:111-127` §C 段列 4 项 "留待" debt (9 console.log / 2 unwrap / 5 file 500+ 行 / 10 hardcoded paths), 落地状态标 "待" 但 §1 line 7 自报 "v2.7.4 C4 闭环" — 命名 ≠ reality (跟 §11.3 反讽 联合, file:line `docs/process/fact-forcing.md:380`).
- **F3 (Rule 数 inconsistency)**: `docs/process/9-hard-rules.md:12` 自报 "KALLAX 当前 22 Rule (v2.4.1 还原 跟 v2.3.0 一致)", 但 `docs/process/approval-tiering.md:30` 用 23 Rule 算 fatigue_index (9/23 = 39.1%), `docs/process/approval-tiering.md:19` 还宣称 "Rule 33 (新)". 3 文件 Rule 数 跟 §2 line 17 "0 增 Rule" 自相矛盾 (file:line `docs/process/9-hard-rules.md:17` vs `docs/process/approval-tiering.md:30`).
- **F4 (顶层 README 缺失)**: `docs/process/` 是 Phase 1 §1.6 line 122 标 ❌ 顶层路径之一, 9/10 路径缺 README — 跟 CLEANUP-PHILOSOPHY §2 "不埋坑" 矛盾 (file:line `docs/process/CLEANUP-PHILOSOPHY.md:33-42`).
- **F5 (闭环 checklist 未跑)**: `docs/process/fact-forcing.md:328-333` 6-item checklist 全部 `[ ]` 未勾选, §7.3 line 400-403 自报 "✅ 100% 落地" — 落地声称 vs checklist 现状 直接反讽 (file:line `docs/process/fact-forcing.md:328-333` vs `:400-403`).

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

- **R1 (跨 release 5 原则 失效)**: CLEANUP-PHILOSOPHY 5 原则 (§1 长期提升优先 / §2 不埋坑 / §3 小步快跑 / §4 硬性脚本 / §5 软性设置) 强依赖 `scripts/check-anti-patterns.sh` + pre-commit wire (line 98-99), 但 v2.7.4 之前 8 release 累计 0 硬性校验, 后续跨 release 累计 若 0 实施 → 5 原则 沦为文档装饰 (跟 §2 "不埋坑" 反讽, file:line `docs/process/CLEANUP-PHILOSOPHY.md:38-42`).
- **R2 (Phase 1 数字 0 验证)**: Phase 1 §1.1-1.2 数字 (379 dirs / 356 .md / 187 .json / 9 files in docs/process) 缺 raw `find` / `ls` evidence, 跟 fact-forcing §2.2 要求 "file:line + 命令输出" 不符 (file:line `docs/process/fact-forcing.md:62-103`). 若 Phase 3 Master 仲裁用 Phase 1 数字拍板 → 数字本身可能 是 估数, 触发 BE-5/9 模式.
- **R3 (9-hard-rules.md vs approval-tiering.md 冲突)**: 9-hard-rules.md 自报 "0 增 Rule" + 22 Rule 落地 (line 17, 206), approval-tiering.md 自报 "Rule 33 新" + 23 Rule (line 19, 30). Master 仲裁 9 expert 报告时 引用 2 文档 → 引用源 矛盾 (file:line `docs/process/9-hard-rules.md:206` vs `docs/process/approval-tiering.md:19`). 跟 fact-forcing §1.2 "5 红线 revert 共同模式: 落地 后 evidence chain 失配" 闭环 (file:line `docs/process/fact-forcing.md:30-33`).
- **R4 (Process 跨 docs/ + confluence/ 重复)**: Phase 1 §1.4 line 97 列 "Process 重复" 类型 (`docs/PROCESS.md` 跟 `docs/process/*.md`), 9 专家 Phase 2 报告 若 各自引用 不同 process 源 → 重复 放大 7 类 之一. 跟 CLEANUP-PHILOSOPHY §2 "不埋坑" 长期 debt 风险 (file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:97`).
- **R5 (5 原则 文档化 ≠ 自动化)**: CLEANUP-PHILOSOPHY §4-5 原则 (硬性脚本 + 软性设置) 实测: `scripts/audit/` 12 files + `scripts/verify/` 20+ files 存在 (跟 `ls scripts/audit/` 一致), 但 §3 "小步快跑" 要求 "scripts/check-anti-patterns.sh 0 ERRORS" (line 60), 文件名 `check-anti-patterns.sh` 不在 audit/verify 列表 — 自报 闭环 跟 实际 文件 失配 (跟 fact-forcing §1.2 反讽 联合, file:line `docs/process/CLEANUP-PHILOSOPHY.md:60`).

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

- **Rec 1 (Phase 1 数字 re-verify)**: Phase 3 Master 仲裁 前, 跑 `find docs confluence jira -type f \( -name "*.md" -o -name "*.json" \) | wc -l` + `ls docs/process/ | wc -l`, raw stdout 作为 Phase 1 §1.1-1.2 数字 唯一 evidence. 跟 fact-forcing §2.2.2 命令输出 联合 (file:line `docs/process/fact-forcing.md:83-93`).
- **Rec 2 (5 原则 实施 闭环)**: CLEANUP-PHILOSOPHY §C 1-4 项 (9 console.log / 2 unwrap / 5 file 500+ / 10 hardcoded paths) 实际状态 grep verify — `rg "console\.log" --type ts node/src/ | wc -l` + `rg "\.unwrap\(\)" --type rust rust/src/ | wc -l` — 实际数字 替代 估数 (file:line `docs/process/CLEANUP-PHILOSOPHY.md:124-127`). 0 增 ticket, 仅 re-verify §C 状态.
- **Rec 3 (Rule 数 single source)**: master explicit 拍 1 Rule 数 baseline (22 vs 23) 跟 1 权威 源 (建议 `docs/KALLAX-GLOSSARY.md` §11.1 或新增 `docs/governance/rule-count-snapshot.md`). 9-hard-rules.md + approval-tiering.md + PROCESS.md line 25-26 全部 引用 同一 baseline, 跨 release 累计 1 commit 改 3 处 (file:line `docs/process/9-hard-rules.md:12` + `docs/process/approval-tiering.md:30` + `docs/PROCESS.md:25-26`). 跟 CLEANUP-PHILOSOPHY §5 软性设置 + DRY 联合.
- **Rec 4 (顶层 README 渐进治根)**: `docs/process/README.md` 仅 30 行 (跟 docs/ 现行 风格 联合, file:line `confluence/memory/lessons/README.md:26-54` 是 1 范本). 内容: 7 files 1-行描述 + 入口 (PROCESS.md 主流程 + CLEANUP-PHILOSOPHY 5 原则 + 9-hard-rules.md Rule 模式 + fact-forcing.md 证据链 + approval-tiering.md P0/P1/P2 + tag-sop.md 5 标签 + metrics-kpi.md 3 KPI + A-B-REVIEW.md 5+5 review). 0 增 长期 debt, 跟 §3 "小步快跑" + §5 "软性设置" 联合 (file:line `docs/process/CLEANUP-PHILOSOPHY.md:48-86`).
- **Rec 5 (fact-forcing.md checklist 自动化)**: fact-forcing.md:328-333 6-item checklist 改 `scripts/verify/check-fact-forcing-checklist.sh` 跑 raw `git log` + `git show` + `rg "console\.log"` 等 6 evidence 命令, 每次 release 跑, stdout 写入 `confluence/decisions/FACT-FORCING-CHECKLIST-RUN-<date>.md` 留痕. 跟 §4 "硬性脚本" 原则 联合 (file:line `docs/process/CLEANUP-PHILOSOPHY.md:64-71` + `docs/process/fact-forcing.md:328-333`).

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- 0 增 Rule (跟 9-hard-rules.md line 17 + v2.4.1 revert 联合, file:line `docs/process/9-hard-rules.md:17`)
- 0 增命令 (跟 STRUCTURE.md line 39 "23 Rule 累计 0 增" 联合, file:line `docs/STRUCTURE.md:39`)
- 0 强制 拍板 (跟 Phase 1 §1.10 P0/P1/P2 联合, 跨 release 留待 master explicit 拍)
- **L1**: docs/architecture/ + docs/api/ + docs/ops/ 顶层 README (跟 docs/process/ 模式 一致, 跨 release 累计 4/10 README 落地)
- **L2**: 7 重复 类型 治根 (Glossary / Lessons / Architecture / Decisions / PHASE / Process / Templates, file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:90-99`)
- **L3**: 7 命名 模式 共识 (Phase 1 §1.3, 跨 release 留待 master explicit 拍 1 命名 共识)
- **L4**: 9/10 顶层 README 落地 (Phase 1 §1.6, 跟 docs/process/ 跨 release 留待 1 commit 1 README pattern)
- **L5**: 7 archive 路径 统一 (`_archive/` vs `_archived/` vs `jira/tickets/_archive/` 模式, file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:104-114`)
- 跨 release 留待 master explicit 拍板 (跟"独立" 战略 联合, 0 跨 session 拍)

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

- **K1**: docs/process/ 顶层 README 落地 = 0/1 (0.0%) (跟 5 原则 §5 "软性设置" 联合, 跨 release 累计 1/1 = 100.0% 目标, file:line `docs/process/CLEANUP-PHILOSOPHY.md:77-86`)
- **K2**: CLEANUP-PHILOSOPHY §C 1-4 项 实测数字 = 0/4 (0.0%) (跨 release 累计 4/4 = 100.0% re-verify 目标, 跟 §2 "不埋坑" 联合, file:line `docs/process/CLEANUP-PHILOSOPHY.md:124-127`)
- **K3**: Rule 数 单一真相来源 落地 = 0/3 (0.0%) (跨 release 累计 3/3 = 100.0% baseline 同步目标, 9-hard-rules/approval-tiering/PROCESS.md 3 处对齐, file:line `docs/process/9-hard-rules.md:12` + `docs/process/approval-tiering.md:30`)
- **K4**: fact-forcing.md 6-item checklist 自动化 = 0/1 (0.0%) (跨 release 累计 1/1 = 100.0% `scripts/verify/check-fact-forcing-checklist.sh` 落地目标, 跟 §4 "硬性脚本" 联合, file:line `docs/process/fact-forcing.md:328-333`)
- **K5**: docs/ 顶层 README 落地 = 0/9 (0.0%) (跨 release 累计 9/10 = 90.0% 渐进目标, Phase 1 §1.6 line 131, file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:131`)

---

**跟 5 原则 联合, 跟 "翻篇&精进" + "诚实修正" 战略 联合, 跟 v2.0.3 EPIC-056-A Phase 2 联合, 0 增 Rule 0 增 命令 持平, 跨 release 留待 master explicit 拍板**