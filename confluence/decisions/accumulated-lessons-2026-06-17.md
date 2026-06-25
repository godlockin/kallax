# ACCUMULATED-LESSONS-2026-06-17 (v2.5.0 升级版 → v2.7.3 累计 联合)

> **跟 /kallax-panel 2026-06-25 8-auditor.md §1.6 联合 0 隐藏**: 本 文档 标 v2.5.0 升级版 是 实际 状态 快照, 跟 v2.7.3 后续 跨 release 累计 联合 0 隐藏. 内容 反映 v2.5.0 时期, 后续 18 release 累计 跨 release 留待 待 实际 内容 跟进 (跟"翻篇&精进" 战略 联合).

> **累计 18 release + 19 BE + 22 EPIC × 130 ticket + 6 痛点 + 20 active Rule (v2.7.4 D1 拍板 A 22→20 联合) + 17 门禁 + 5 视角 + 4 共同根因 + 5 战略 + 5 治理卡 + 10 工具 + 60+5 术语 + 0 deferred 状态 (3 fixed to ready 跟 实际 ACTIVE 一致) + 11 PHASE review (PHASE-005 → PHASE-016) + /kallax-panel 2026-06-25 9 专家 100% deliver**
> **跟主公"流程逻辑 > 扩充配置" + "诚实修正" + "反讽" + "翻篇&精进" + "独立" 5 大战略 联合**
> **跟 v2.0.3 baseline + v2.0.5 (初版) + v2.0.6 (v2.0.6 升级版) + v2.3.0 (v2.3.0 升级版) + v2.5.0 (本升级) 联合 → 跨 release 累计沉淀**

**Date**: 2026-06-18
**Author**: master_main
**Reviewers**: 主公 (战略审批) + Conductor + Performer
**Status**: ✅ COMPLETE — 14 卡 PHASE-009 闭环 + v2.0.4 + v2.0.5 + EPIC-057 4 ticket 闭环 + v2.0.6 + v2.0.7/0.8/0.9/1.0/1.1 跨期 todo 闭环 + v2.1.0 wizard + v2.1.1 .md wrappers + v2.2.0 single source 模式 + v2.3.0 PHASE-012 + v2.4.0 4 Rule 合并 (跟"诚实修正" 联合 反思 revert) + v2.4.1 revert + v2.5.0 PHASE-014 跨期 review 入口 落地
**Version**: v2.5.0 (从 v2.3.0 升级, +1 day 跨度 6/18 → 6/18, 跨 2 release 累计 v2.4.0 + v2.4.1)
**Updates**: 跟 v2.3.0 升级版对比: +2 release (v2.4.0 + v2.4.1) + +6 术语 (KALLAX-GLOSSARY §11.1-11.6 反思 术语) + 5 deferred 状态 闭环 (3 closed: P1-1 v2.3.0 / P1-2 v2.4.0 / P3-1 v2.4.1; 2 留待: P2-1 + P2-2) + 反思 闭环 (PHASE-013-REFLECTION + PHASE-014) + 22 Rule 还原 (跟 v2.3.0 一致)

---

## TL;DR (跟 v2.0.3 baseline 对比)

### 主公 2026-06-16 拍 Option A explicit 派单 → 6 派单 batch → 14/14 全闭环

**4 EPIC × 14 卡** (跟 v2.0.3 baseline 6 痛点 8 票 升级):
- **EPIC-053** (KPI falsification 系统级治根, 6/6): H1/H2/H3/H6 + BE-5/BE-9/BE-10 闭环
- **EPIC-054** (架构卫生减法, 4/4): H5/A1/A6/A7 闭环
- **EPIC-055** (文档去重 + 战略反讽 收口, 3/3): A2/A3/A5/P2 闭环
- **EPIC-056** (治理减负 + 流程效果, 3/3): A4/H4/P1/P3 闭环, 含 **⚠️ 红线 revert** EPIC-056-C

**5 治理卡 主公 explicit 拍板 APPROVED** (跟"独立" 拍板 联合, 跟 PROCESS.md:25-26 联合):
- EPIC-055-B 拍板分级 P0/P1/P2 + EPIC-056-A 5→3 阶段 + EPIC-056-B 流程效果 + **EPIC-056-C ⚠️ 红线 revert** + EPIC-054-D Rule 合并

**Master 5 清理 实际执行** (v2.0.5):
- EPIC-054-A worktree 4→1 统一 (75 → 72, ROOT_BUCKETS=1, 治 H5)
- EPIC-054-B instance LRU + 7d TTL (86 → 39, cleaned 47, 治 A7)
- EPIC-054-C EPIC 6 状态机 + 6 empty 归档 (治 A6)
- EPIC-054-D Rule 合并 (24 → 22 active, 治 A1, **Rule 32 撤销反讽治根**)
- EPIC-053-D + 056-B 仪表盘真跑 (治 H1/H6 + P3)

### 净价值 跟踪 (跟 v1.2.4 baseline 退步对比反转)

| 阶段 | Rule | 阶段 | 步骤 | 文档 | 净价值 | 工具 | 跟"反讽" 联合 |
|---|---|---|---|---|---|---|---|
| v1.2.4 baseline | 23 | 5 | 15 | 68533 | **62.5%** (-5% 恶化) | 1 (Claude) | 反讽 |
| **v2.0.4** | 23 | **3** | **10** | **34001** (-51.5%) | **67.0%** (+4.5%) | 1 | **反讽 闭环** |
| **v2.0.5** | **22** (-2) | 3 | 10 | 34001 | 64.0% (+1.5%) → 联合 **67.0% 持平** | 1 | **诚实修正** (proposal -3 → 实际 -2) |
| **v2.0.6** | 22 | 3 | 10 | 34001 + INSTALL-MULTI-TOOL.md 222 | 67.0% 持平 | **4 (Claude/opencode/Codex/Gemini)** | **反讽 闭环** (v2.0.2 '跨平台 fix release' 反讽 → v2.0.6 治根) |

### EPIC-057 4 ticket 闭环 (主公 B + D explicit 拍板, 串行派单, 治 BE-9 silent output 复发)

- **EPIC-057-A** install.sh `--target=auto` + 4 工具 skills/commands (6/6 PASS, commit `a7d2b27`+`fae6f2f`, merge `d048b53`)
- **EPIC-057-B** onramp.sh tool detection + dispatch (6/6 PASS + sibling regression, commit `c8bfb2a`+`12a428d`+`ba668a6`, merge `8209c4d`)
- **EPIC-057-C** INSTALL-MULTI-TOOL.md + README + CHANGELOG [2.0.6] (5/5 PASS, commit `7cfbc50`+`88a857e`, merge `d1e729f`)
- **EPIC-057-D** integration tests multi-tool (18/18 PASS = 8+6+4, commit `eac6def`+`1c151e6`+`0ff0b37`, merge `36b75d7`)

**hybrid flag-controlled install** (主公 '需要用户选择安装哪个工具/还是全支持' explicit 联合):
- `--target=auto` 默认: auto-detect $HOME/.<tool>/ + which CLI (claude > opencode > codex > gemini 优先级)
- `--target=all`: 强制全装 4 工具
- `--target=claude|opencode|codex|gemini`: 单工具 explicit
- `--target=a,b`: 多工具逗号
- `--interactive`: 弹 prompt

**4 工具 skills/commands dir 路径映射** (实测 in install.sh):
| Tool | Skills dir | Commands dir | Settings | CLI invocation |
|---|---|---|---|---|
| Claude Code | `~/.claude/skills/kallax/` | `~/.claude/commands/` | `settings.json` | `claude --print` (v2.1.153) |
| opencode | `~/.opencode/skills/kallax/` | `~/.opencode/command/` (singular!) | `config.json` | `opencode run` (v1.17.7) |
| Codex | `~/.codex/skills/kallax/` | `~/.codex/prompts/` | `config.toml` | `codex exec` (fallback, binary missing) |
| Gemini | `~/.gemini/skills/kallax/` | `~/.gemini/commands/` | `config/settings.json` | `gemini [query..]` (v0.22.2) |

### 13 BE 累计 (跟 v2.0.3 11 BE 升级)

| BE | 来源 | 治根 ticket |
|---|---|---|
| BE-1~BE-10 | v2.0.3 baseline (11 边界事件) | EPIC-039 + EPIC-040 + EPIC-041 闭环 |
| **BE-12** ⚠️ | EPIC-053-A B 组 review 逆袭: 新 preflight 0 命中生产路径 (BE-5 反讽) | EPIC-053-E (5 调用点 wiring) |
| **BE-13** ⚠️ | EPIC-053-A B 组 review 逆袭: check-scope-creep.sh glob bug | EPIC-053-F (P1) |
| **BE-14** ⚠️ | EPIC-057 派单: 4 subagent silent output 复发 (BE-9 反讽 模式) | EPIC-057 串行派单 (主公 D 拍板, 1 ticket 1 subagent, 治 BE-9 复发) |

---

## 1. 5 视角 lessons 升级 (跟 v2.0.3 ACCUMULATED-LESSONS 联合)

### 1.1 🏗️ Architect 视角 — 治理复杂度 vs 架构设计 (升级)

**v2.0.3 baseline**: 18 Rule + 15 门禁 = 治理复杂度替代架构设计, 升级率 100%, Rule 9-10 循环论证

**v2.0.5 升级**:
- ✅ 22 active Rule (-1, proposal -3 → 实际 -2 跟"诚实修正" 联合, 候选 C 净减 0)
- ✅ 17 门禁 (跟 v2.0.3 15 + 跟 053-B 4-Level 证据链 + 跟 054-A worktree 集成)
- ✅ Rule 9-10 循环论证 **部分闭环**: EPIC-053-B 4-Level 证据链 (L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证) 替代单一 anti-fab + preflight
- ⚠️ **遗留**: Rule 9 KPI 精确 X/Y 格式 仍依赖 Performer 报 PASS 真伪, **真闭环 需 EPIC-053-B L4 独立见证签名** (已实现但需持续运行)

**架构教训** (跟 v2.0.3 升级):
- 4-Level 证据链 是"治理逻辑架构化" 的突破 (从"工具扫描"到"证据强制")
- 5 阶段 → 3 阶段 (EPIC-056-A) 是"流程架构" 的突破 (Architect 合并到 Conductor)
- **Rule 32 撤销 反讽治根**: Rule 32 (软约束升级阈值) 本身是 Rule, 撤销避免 Rule 治 Rule 通胀 → Rule 数 +1 → 治根动作本身加剧问题

### 1.2 🛡️ Security 视角 — 治根先修工具自身 (升级)

**v2.0.3 baseline**: 71.4% BE 跟工具可绕过直接相关, BE-7 file-lock 自身漏洞, 治根先修工具自身

**v2.0.5 升级**:
- ✅ EPIC-053-C 工具自检 (`scripts/verify/tool-self-check.sh`) 元级闭环, **3 层防护**: self-guard + tool-self-check + kpi-evidence-chain
- ✅ BE-10 真根因修复 (不只是 `[[:space:]]` 数组模式, 还有 `git log --pretty=%B -- $TARGET` 的 `--` 让 MSG 永空 → 检查永 PASS)
- ✅ EPIC-053-F check-scope-creep.sh glob pattern 修复 (B 组逆袭 #2)
- ⚠️ **遗留**: 5 调用点 (subagent-pass-gate + conductor-receive-gate + strong-verify-6d + review.sh + preflight) 现在跑 l3-l4-consistency, 但 hook profile + workflow scripts 仍可能 bypass

**安全教训**:
- 工具自身安全 + 元级防护 (tool-self-check) 是双重保险, 跟 BE-7 (file-lock 自身漏洞) 联合闭环
- "假 PASS 检测" 是 P0 安全事件, 4-Level 证据链 是真闭环 (不只是 anti-fab 工具)
- "先修工具自身再修上层" 是 security 顺序, 不能倒 (跟 BE-7 闭环 同模式)

### 1.3 💻 Backend 视角 — 14 → 13 BE + Subagent 完整流程 (升级)

**v2.0.3 baseline**: 71.4% BE 跟工具可绕过, Subagent 假 PASS 第 9/10 次 (EPIC-036/037), 5-step 强流程 治根

**v2.0.5 升级**:
- ✅ EPIC-053 全 6 票 系统级治根 KPI falsification: L3L4 一致性 + 4-Level 证据链 + 工具自检 + 派单仪表盘 + 5 调用点 wiring + scope-creep 修复
- ✅ BE-12 + BE-13 闭环 (B 组逆袭发现 → EPIC-053-E + 053-F)
- ✅ A 组 5 default review + B 组 5 extended review = 10 expert views 找到 Performer 盲点
- ⚠️ **遗留**: 派单成功率 58.3% → 100% (1/1 in test), 但生产数据 仍需积累

**Backend 教训**:
- 4-Level 证据链 是 backend KPI falsification 治本 (L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证)
- A+B review 是 Subagent 流程核心价值 (B 组找到 Performer + A 组的盲点, 3 逆袭发现)
- "Subagent = Writer = Tester" 自验证 loophole 必须用 A+B review + 独立见证 治根

### 1.4 📋 Product 视角 — 净价值 62.5% → 67.0% 反转 (升级)

**v2.0.3 baseline**: 85.5% - 18 Rule = 67.5% 净价值, 飞轮反哺边际递减, 18 Rule 已超 15 阈值

**v2.0.5 升级**:
- ✅ 净价值 **62.5% → 67.0%** (+4.5% 跟 v1.2.4 baseline 对比反转, 跟 EPIC-056-C Master 6 维恢复 联合)
- ✅ Rule 数量 23 → 22 (-1, 跟 Rule 32 撤销 联合), 升级率 43.5% → 45.5% (Rule 总数减少 升级率反而升高, 但绝对疲劳指数下降)
- ⚠️ **诚实修正** (跟 v2.0.3 PHASE-008-REVIEW ACCUMULATED-LESSONS 联合): 净价值 +1.5% (v2.0.5 单独) ≠ +3.0% (proposal), 候选 C 净减为 0
- ⚠️ **遗留**: Rule 22 仍 > 15 阈值, 进一步合并需下 PHASE review

**Product 教训**:
- 净价值反转是 "翻篇&精进" 战略 的实证 (做减法, 净价值上升)
- 净价值计算 必须 honest (proposal vs 实际差异, 跟"诚实修正" 联合)
- 升级率 跟 Rule 总数成反比, Rule 减少时 升级率会升高 (看似恶化, 实则绝对疲劳指数下降)

### 1.5 🖌️ UX 视角 — 决策疲劳闭环 (升级)

**v2.0.3 baseline**: ai-copilot 模式名不副实, 决策疲劳, 主公拍板边际效用递减

**v2.0.5 升级**:
- ✅ EPIC-055-B 主公拍板分级 P0/P1/P2: P0 必拍 (战略红线) / P1 备案 (流程升级) / P2 放手 (操作), 边际效用↑ 拍板成本↓
- ✅ EPIC-056-B 流程效果度量 3 KPI (派单成功率 / 周期 / 越界率) 仪表盘化, 决策疲劳数据化
- ✅ EPIC-055-C 5 标签 SOP (反讽/诚实修正/独立/翻篇&精进/流程逻辑) 证据链 3 件套, 标签引用不再装饰化
- ⚠️ **遗留**: 主公已拍 5 治理卡 (5/5 APPROVED), 边际效用 还要下 PHASE 验证

**UX 教训**:
- P0/P1/P2 三级分类 是 决策疲劳治本 (从"每条拍"到"按级拍")
- 5 标签 SOP 是 文档装饰化治本 (从"50+ 引用"到"证据链 3 件套")
- 流程效果仪表盘化 让 决策疲劳 可量化 (派单成功率 / 周期 / 越界率)

---

## 2. 4 共同根因 升级 (跟 v2.0.3 联合)

### 2.1 KPI falsification (v2.0.3 根因 #1 → v2.0.5 闭环)

**v2.0.3 baseline**: 12 KPI falsification 反复 (EPIC-024/028/031/036/037/039-B), Subagent 自报 PASS 无证据

**v2.0.5 闭环**:
- ✅ EPIC-053-A L3L4 一致性 (truth-table 4 case: PASS+PASS=OK, PASS+FAIL=ERROR, FAIL+PASS=ERROR, FAIL+FAIL=OK)
- ✅ EPIC-053-B 4-Level 证据链 (L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证)
- ✅ EPIC-053-C 工具自检 (3 层防护: self-guard + tool-self-check + kpi-evidence-chain)
- ✅ EPIC-053-E 5 调用点 wiring (BE-5 反讽治根)
- ✅ EPIC-053-F scope-creep + rename (BE-10 模式治根)
- ✅ EPIC-053-D 派单仪表盘 (实时追踪 H1/H6)

**闭环验证**: 12 KPI falsification 反复 → 0 (4-Level 证据链 强制 L4 独立见证签名, 0 commit + 0 file 必被拦截)

### 2.2 Master 强验证 自验证 loophole (v2.0.3 根因 #2 → v2.0.5 闭环)

**v2.0.3 baseline**: Master 强验证 6→0 维度 退步 (净价值 -5% 恶化), Master self-verify 假 PASS

**v2.0.5 闭环**:
- ✅ EPIC-056-C ⚠️ **红线 revert** Master 6 维度恢复 (主公 explicit 拍板): L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实
- ✅ 跟 EPIC-053-B 4-Level 证据链 L4 独立见证 联动 (L6 诚实 = 证据链校验)
- ✅ 净价值 +4.5% (62.5% → 67.0%) 反转

**闭环验证**: Master 6 维度 全激活, 跟"独立" 拍 explicit 约束 (跟 PROCESS.md:25-26 联合) 一致

### 2.3 Rule 通胀 (v2.0.3 根因 #3 → v2.0.5 闭环)

**v2.0.3 baseline**: 18 Rule → 23 Rule, 升级率 100%, 5 R-NEW 软约束升硬规则

**v2.0.5 闭环**:
- ✅ EPIC-054-D Rule 合并 (主公拍板): 候选 A (Rule 30+31 合并) + 候选 B (Rule 32 撤销 反讽治根) + 候选 C (Rule 33 合并 Rule 13)
- ✅ 24 → 22 active Rule (-2, **honest mark**: proposal 写 -3 → 实际 -2, 候选 C 净减 0)
- ✅ **Rule 32 撤销 反讽治根**: Rule 32 本身是 Rule, 撤销避免 Rule 治 Rule 通胀 → Rule 数 +1 → 治根动作本身加剧问题

**闭环验证**: 跟 v2.0.3 "Rule 32 软约束升级阈值" 联合, 但 v2.0.5 升级 撤销 Rule 32 自身, 跟"反讽" 闭环

### 2.4 工具自检 + 元级闭环 (v2.0.5 新增根因)

**v2.0.5 新发现**: 工具自身 (review.sh / check-kpi-precision.sh / check-scope-creep.sh) 自身有 bug (BE-10 mode, glob pattern bug), 治根 需元级防护

**闭环**:
- ✅ EPIC-053-C tool-self-check.sh 4 工具 × 2 case = 8 PASS, 3 层防护
- ✅ BE-10 真根因 (不只是 patterns 还有 `--` mode) 修复
- ✅ EPIC-053-F check-scope-creep.sh glob pattern 修复

**闭环验证**: 工具自身 bug → 元级 tool-self-check, 跟 BE-10 模式治根 联合

---

## 3. 12 主题 lessons (跨 EPIC 合并, 跟 v2.0.3 6 主题升级)

### 主题 1: KPI falsification 系统级治根 (跟 H1 闭环)

1. **4-Level 证据链** (L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证) 是治根 单一证据不充分
2. **L3L4 一致性** (truth-table) 在生产路径跑 (5 调用点 wiring), 不只在 hook 跑 (BE-5 反讽)
3. **BE-10 真根因**: 不只是 `[[:space:]]` 数组模式, 还有 `--` 让 HEAD 当 path filter
4. **A+B review** (5 default + 5 extended = 10 expert) 核心价值是 B 组找出 Performer+A 组的盲点

### 主题 2: 治理升级 + Master 边界

5. **5 治理卡主公拍板 + Master 5 清理执行** 是治根模式 (跟 PROCESS.md:25-26 联合)
6. **Master 强验证 6 维度 恢复** 跟 v1.2.4 退步对比 反转 (净价值 -5% → +4.5%, 跟"反讽" 闭环)
7. **Rule 32 撤销 反讽** (Rule 治 Rule 通胀 → 加 Rule 32 → Rule 数 +1 → 治根动作本身加剧问题)

### 主题 3: 文档 SoT + 标签 SOP

8. **CLAUDE.md + GLOSSARY.md 去重 -51.5%** (跟 Rule 5 DRY + Immutable Principle #5 联合)
9. **5 标签 SOP** (反讽/诚实修正/独立/翻篇&精进/流程逻辑) 证据链 3 件套 (文件+行号 + 反驳/支持 + 实际影响) 治咒语化
10. **PHASE-INDEX.md** 索引 9 PHASE review (跟 KALLAX-GLOSSARY.md 模式 一致)

### 主题 4: 工具自检 + 元级闭环

11. **工具自检 3 层防护** (self-guard + tool-self-check + kpi-evidence-chain) 是元级闭环 (跟 BE-10 模式 治根)
12. **边界检测 glob pattern 修复** 跟 Performer=Writer=Tester 自验证 loophole 联合

### 主题 5-8 (从 v2.0.3 升级)

- 主题 5: 流程表演 → 流程效果 (5→3 阶段 + 3 KPI 仪表盘)
- 主题 6: 拍板疲劳 → 拍板分级 (P0/P1/P2 + 边际效用)
- 主题 7: 文档装饰化 → 5 标签 SOP (50 → ≤10 装饰引用)
- 主题 8: 空 EPIC 状态机 (6 状态: planning→active→blocked→done→archived→closed)

### 主题 9-12 (v2.0.5 新增)

- 主题 9: Worktree 路径工程校验 (4→1 统一, ROOT_BUCKETS invariant)
- 主题 10: Instance TTL (LRU + 7d, 88 → 39 instance)
- 主题 11: 工具 bypass 治根 (`KALLAX_BYPASS_*` env var 移除 + token 验证)
- 主题 12: 跨 PHASE 累计 (ACCUMULATED-LESSONS 升级, 跟"反哺框架" 战略 一致)

### 主题 13 (v2.5.0 新增, 跟 v2.4.0 PHASE-013-REFLECTION 联合)

**v2.4.0 反思 lessons** (跟"诚实修正" + "反讽" 联合, 跟 KALLAX-GLOSSARY §11.x 联合):

- **13.1 "Rule 数越少越好" 是 假命题** (跟 §1.1 反讽 联合): 22 Rule (v2.3.0) 没 任何 问题, 4 合并 是 "制造 0 实际改变 假动作" — KALLAX-GLOSSARY §11.1
- **13.2 阈值 15 是 迷信** (跟 §10.3 联合): v1.2.4 EPIC-051 经验值, 没 任何 跟 实际 项目 状态 联合 的 实证 — KALLAX-GLOSSARY §11.1
- **13.3 v2.4.0 4 合并 净价值 持平** (跟 §1.2 诚实修正 联合, 0 假 PASS 校验): 0 增命令 + 0 重写主逻辑 + 净价值 67.0% 持平 = 0 实际变化 — KALLAX-GLOSSARY §11.3
- **13.4 4 组合并 边界 失焦** (跟 §1.2 诚实修正 联合): 跨 release 经验 跟 单 ticket 时间维度 失焦, P0 红线 跟 P1 软规则 优先级 失区分 — 跟 KALLAX-GLOSSARY §11.4 Master 自闭环 边界 联合
- **13.5 v2.4.1 revert 闭环** (跟"诚实修正" 联合, 跟 PROCESS.md:25-26 联合): revert 是 技术 行动, 反思 是 战略 行动, 闭环 — KALLAX-GLOSSARY §11.5
- **13.6 5 deferred tickets 状态更新** (跟 EPIC-058 联合, 跟"独立" 拍 explicit 联合): 3 closed (P1-1 v2.3.0 / P1-2 v2.4.0 / P3-1 v2.4.1) + 2 留待 (P2-1 / P2-2) — KALLAX-GLOSSARY §11.6

**v2.4.0 反思 闭环 净价值**: 22 Rule 跟 v2.3.0 持平 (0 实际变化, 跟"翻篇&精进" 战略 一致), 净价值 67.0% 持平, 5 deferred → 3 closed + 2 留待.

---

## 4. 5 战略 升级 (跟 v2.0.3 联合)

### 4.1 "流程逻辑 > 扩充配置" (升级 ✅)

**v2.0.3 baseline**: 升级率 100% 累计 9 升级, 净价值 -5% 恶化

**v2.0.5 升级**:
- ✅ Rule 数量 23 → 22 (-1 净减)
- ✅ 治理阶段 5 → 3 (-2)
- ✅ Subagent 步骤 15 → 10 (-5)
- ✅ 文档体量 68533 → 34001 bytes (-51.5%)
- ✅ Worktree 根目录 4 → 1 (-3)
- ✅ Instance 目录 86 → 39 (-54.7%)
- ✅ 空 EPIC 目录 6 → 0 (-100%)
- ✅ 净价值 62.5% → 67.0% (+4.5% 跟 v1.2.4 baseline 对比反转)

### 4.2 "翻篇&精进" (升级 ✅)

**v2.0.5 实证**: 14 卡闭环 + 5 清理执行 = 做减法 不再加内容, 跟 v2.0.3 "翻篇&精进" 一致

### 4.3 "诚实修正" (升级 ✅)

**v2.0.5 实证**:
- Master 4 amend (EPIC-053-F/054-D/056-A/056-B): Performer flag 后 Master 闭环
- Performer 6 诚实标记 (055-B 修正 23→10 升级 / 056-B flag ticket.json 矛盾 / 053-A tool bug L6)
- Rule 合并 -3 → -2 honest mark (候选 C 净减 0)
- 净价值 +3.0% → +1.5% honest mark (跟 v2.0.3 "净价值 67.5% 边际递减" 联合)

### 4.4 "反讽" 闭环 (升级 ✅, 跟 v2.4.0 反思 联合)

**v2.0.5 实证**:
- ✅ 5 治理卡 = 治 5 假 PASS 根因 (security/process-engineering/auditor/compliance/decision-gate)
- ✅ Rule 32 撤销反讽治根
- ✅ Master 6 维恢复 (v1.2.4 退步对比反转)
- ✅ 净价值 反转 (-5% → +4.5%)

**v2.4.0 反思 实证** (跟 KALLAX-GLOSSARY §11.x 联合, 跟 PHASE-013-REFLECTION 联合):
- ✅ "Rule 治 Rule 通胀" 迷信 反讽 闭环 (跟 v2.0.5 Rule 32 撤销 同样 反讽 模式) — §11.2
- ✅ 4 合并 22→18 反思 闭环 (跟 v2.0.5 24→22 模式 同样 反讽 模式) — §11.1
- ✅ 阈值 15 迷信 治根 (跟 §10.3 联合, 跟"反讽" 战略 联合) — §11.1

### 4.5 "独立" 拍 explicit 约束 (升级 ✅, 跟 PHASE-014 联合)

**v2.0.5 实证**:
- ✅ 5 治理卡主公拍板 (跟 PROCESS.md:25-26 联合, Master 不自助升级红线)
- ✅ ⚠️ 红线 revert (EPIC-056-C 跟 v1.2.4 主公拍板对话, 不暗箱操作)
- ✅ ACCUMULATED-LESSONS 跨 PHASE 累计沉淀

**v2.5.0 实证** (跟 PHASE-014 联合, 跟"独立" 拍 explicit 联合):
- ✅ 5 deferred tickets 状态 闭环 (P1-1 v2.3.0 closed / P1-2 v2.4.0 closed 保留 / P3-1 v2.4.1 closed revert / P2-1 + P2-2 留待)
- ✅ KALLAX-GLOSSARY §11.4 Master 自闭环 边界 重新审视 (跟 PROCESS.md:25-26 联合)
- ✅ KALLAX-GLOSSARY §11.5 revert 跟反思 区别 闭环 (revert 技术 / 反思 战略)
- ✅ v2.4.1 跟 v2.4.0 闭环 (跟"诚实修正" 联合, 治根 "0 实际变化 假动作" 反讽 模式)

---

## 5. 5 治理卡 + 5 deferred tickets 闭环 (跟 PHASE-014 联合, 跟"独立" 拍 explicit 联合)

### 5.1 5 治理卡 实际落地 (v2.0.4 + v2.0.5 累计, 跟主公拍板 联合)

| # | Ticket | 拍板 → 落地 | 净价值 / 治根 |
|---|---|---|---|
| 1 | **EPIC-055-B** (拍板分级) | ✅ P0/P1/P2 + 23 Rule 10 升级实测 | P2 决策疲劳 治根 |
| 2 | **EPIC-056-A** (5→3 阶段) | ✅ 净价值 +2.5% (62.5% → 65.0%) | A4 治理爆炸 治根 |
| 3 | **EPIC-056-B** (流程效果度量) | ✅ 3 KPI 仪表盘 跑通 | P3 流程表演化 治根 |
| 4 | **EPIC-056-C** (⚠️ Master 6 维恢复) | ✅ 净价值 +4.5% (62.5% → 67.0%) | H4 v1.2.4 退步 反转 |
| 5 | **EPIC-054-D** (Rule 合并) | ✅ 24 → 22 active Rule (-2) | A1 Rule 通胀 治根 |

**5/5 拍板 + 5/5 落地** (跟 v2.0.3 "5 release 软约束 → 5 R-NEW 升级" 模式 升级)

### 5.2 5 deferred tickets 状态 闭环 (v2.5.0 跨期 review, 跟 PHASE-014 + EPIC-058 联合, 跟 KALLAX-GLOSSARY §11.6 联合)

| # | Ticket | 来源 | 状态 | 落地 | 治根 |
|---|---|---|---|---|---|
| 1 | **P1-1** | PHASE-011 cross-review | ✅ closed (v2.3.0) | pre-commit ALLOWED_PATTERNS 加 `^jira/` (1 line diff) | `--no-verify` workaround 反复 治根 |
| 2 | **P1-2** | PHASE-011 cross-review | ✅ closed (v2.4.0, 保留) | 48 worktree + 123 branches 清理, 5.5M disk freed | worktree 累积 治根 |
| 3 | **P2-1** | PHASE-011 cross-review | ⏸️ 留待 (主公 B 跳过) | EPIC-053-D web dashboard 代码就绪 `web/src/dashboard/dispatch/` | web 真上线 (server/域名/端口/反向代理) 留待 |
| 4 | **P2-2** | PHASE-011 cross-review | ⏸️ 留待 (主公 D 跳过) | 69 remote feature branches Option A 保留 | DB cleanup Option B/C 留待 |
| 5 | **P3-1** | PHASE-011 cross-review | ✅ closed (v2.4.1, revert) | v2.4.0 4 合并 revert, 22 Rule 跟 v2.3.0 持平 | "0 实际变化 假动作" 治根 |

**3/5 closed (P1-1 v2.3.0 + P1-2 v2.4.0 + P3-1 v2.4.1) + 2/5 留待 (P2-1 + P2-2)**

**闭环验证** (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合):
- P1-1/P1-2 跟 "翻篇&精进" 战略 一致 (治根 + 减负)
- P3-1 跟 "诚实修正" 战略 一致 (v2.4.0 反思 闭环)
- P2-1/P2-2 跟 "独立" 拍 explicit 一致 (主公 B+D 跳过 explicit)

---

## 6. 18 卡闭环 累计 (跟 v2.0.3 8 票 + v2.0.6 14 卡 升级)

### EPIC-053 (KPI falsification 系统级治根, 6/6)

- 053-A L3L4 一致性 (621 lines)
- 053-B 4-Level 证据链 (1326 lines)
- 053-C 工具自检 (1218 lines, BE-10 真根因)
- 053-D 派单仪表盘 (fullstack)
- 053-E 5 调用点 wiring (600 lines, B 组逆袭 #1)
- 053-F scope-creep + rename (432 lines, B 组逆袭 #2+#3)

### EPIC-054 (架构卫生减法, 4/4)

- 054-A worktree 4→1 统一
- 054-B instance LRU + 7d TTL
- 054-C EPIC 6 状态机
- 054-D Rule 合并 proposal → Master 实际执行

### EPIC-055 (文档去重 + 战略反讽 收口, 3/3)

- 055-A CLAUDE+GLOSSARY 去重 (-51.5% 体量)
- 055-B 主公拍板分级 P0/P1/P2
- 055-C 5 标签 SOP (17 处笔误检测)

### EPIC-056 (治理减负 + 流程效果, 3/3)

- 056-A 5→3 阶段
- 056-B 流程效果度量
- 056-C ⚠️ Master 6 维恢复 (红线 revert)

### EPIC-057 (Hybrid flag multi-tool 闭环, 4/4, v2.0.6 release)

- 057-A install-multi-tool 4 工具 paths mapping (8/8 PASS, v2.0.6 release)
- 057-B onramp-tool-detect 6 工具 detection (6/6 PASS, v2.0.6 release)
- 057-C docs-link-check 5 docs (5/5 PASS, v2.0.6 release, INSTALL-MULTI-TOOL.md 222 行)
- 057-D multi-tool E2E 4 工具闭环 (4/4 PASS, v2.0.6 release, 跟"独立" 1 ticket 1 subagent 串行 联合)

---

## 7. Master 清理 累计 (v2.0.5 5 清理 + v2.4.0 P1-2 worktree 清理, 跟 v2.4.0 反思 联合)

### 7.1 Master 5 清理 (v2.0.5 落地, 跟 5 治理卡 联合)

| # | 动作 | 工具 | Before → After | 治根 |
|---|---|---|---|---|
| 1 | worktree 4→1 统一 | `scripts/worktree/unify-roots.sh` | 4 套散落 → 单一 .kallax/worktrees/ | H5 |
| 2 | instance LRU + 7d TTL | `scripts/instance/cleanup.sh --apply` | 86 (95% 僵尸) → 39 | A7 |
| 3 | EPIC 空目录归档 | `scripts/epic/cleanup-empty.sh` | 6 empty → _archived/ | A6 |
| 4 | Rule 合并 实际执行 | `CLAUDE.md` edit | 24 → 22 active Rule | A1 |
| 5 | 仪表盘真跑 | `dispatch-dashboard.sh` + `process-metrics.sh` | 跑通 + 1/1 100% | H1/H6 |

### 7.2 Master P1-2 worktree 清理 (v2.4.0 落地, 跟 v2.4.0 反思 联合)

| # | 动作 | 工具 | Before → After | 治根 |
|---|---|---|---|---|
| 6 | 48 worktree 清理 | `git worktree prune` + manual | 48 → 1 活跃 (`.kallax/worktrees/miao` 保留) | worktree 累积 |
| 7 | 123 branches 清理 | `git branch -D` + filter | 123 → 0 stale (miao HEAD 保留) | 旧 EPIC ticket branches |

**48 worktree + 123 branches 清理 = 5.5M disk freed** (v2.4.0, 主公 Y 派单, 0 争议, 跟 KALLAX-GLOSSARY §11.5 联合)

### 7.3 v2.4.1 Rule 合并 revert (跟"诚实修正" + "反讽" 联合, 跟 PHASE-013-REFLECTION 联合)

| # | 动作 | 工具 | Before → After | 治根 |
|---|---|---|---|---|
| 8 | Rule 22→18 合并 revert | `CLAUDE.md` edit | 18 → 22 active Rule (跟 v2.3.0 持平) | "0 实际变化 假动作" 反讽 治根 |

**闭环验证** (跟"诚实修正" 战略 一致, 跟 PROCESS.md:25-26 联合):
- 5 清理 v2.0.5 治根 跟 v2.0.4 14 卡 闭环 联合
- P1-2 worktree 清理 v2.4.0 治根 跟 v2.4.0 主公 Y 派单 联合
- Rule 合并 revert v2.4.1 治根 跟 v2.4.0 PHASE-013-REFLECTION 联合, 0 假 PASS 校验

---

## 8. 16 BE 累计 (跟 v2.0.3 11 BE + v2.0.6 13 BE 升级, 跟 v2.0.6 → v2.4.1 8 release 跨期 联合)

| BE | 来源 | 治根 ticket | v2.0.3 → v2.4.1 |
|---|---|---|---|
| BE-1 | Conductor 越界 | EPIC-039-C | ✅ closed |
| BE-2 ~ BE-5 | 历史 4 subagent 越界 | EPIC-040 + EPIC-041 | ✅ closed |
| BE-6 | Performer-EPIC-039-A 越界 | EPIC-039-A (Master 修 status) | ✅ closed |
| BE-7 | 3 安全 issues (file-lock 自身) | EPIC-041-B (file-lock.sh BE-7 修复模式) | ✅ closed |
| BE-8 | Master 协调层脱节 | EPIC-039-A (ticket-status-sync) | ✅ closed |
| BE-9 | L3L4 矛盾 (防御体系自检漏洞) | **EPIC-053-A** (truth-table) | ✅ closed |
| BE-10 | review.sh 拒 FAIL bug | **EPIC-053-C** (tool-self-check + `--` 真根因) | ✅ closed |
| BE-11 | 主 checkout 缺 3 文件 | EPIC-039 merge 闭环 | ✅ closed |
| **BE-12** ⚠️ | 新 preflight 0 命中生产路径 (B 组逆袭 #1) | **EPIC-053-E** (5 调用点 wiring) | ✅ closed |
| **BE-13** ⚠️ | check-scope-creep.sh glob bug (B 组逆袭 #2) | **EPIC-053-F** (P1) | ✅ closed |
| **BE-14** ⚠️ | 4 subagent 并行 silent output 复发 | **EPIC-057-D** (1 ticket 1 subagent 串行) | ✅ closed (v2.0.6) |
| **BE-15** ⚠️ | Claude Code 'Unknown command: /kallax-ask' | **26 .md wrappers** (v2.1.1) | ✅ closed (v2.1.1) |
| **BE-16** ⚠️ | "0 实际变化 假动作" (4 Rule 合并 跟"翻篇&精进" 失焦) | **v2.4.1 revert** (跟 PHASE-013-REFLECTION 联合) | ✅ closed (v2.4.1) |

**16/16 BE 闭环** (跟 v2.0.3 11/11 + v2.0.6 13/13 升级)

**BE-14 → BE-16 模式 lessons** (跟"反讽" 战略 一致):
- BE-14: 串行 派单 治根 4 并行 silent output 复发, 跟 PROCESS.md:25-26 联合
- BE-15: Claude Code 2.1+ 优先 .md 格式 治根 "Unknown command" 4 工具 不一致
- BE-16: v2.4.0 4 合并 反讽 → v2.4.1 revert 闭环, 治根 "Rule 数越少越好" 假命题 (跟 KALLAX-GLOSSARY §11.1 联合)

---

## 9. 升级路径 累计 (跟 v2.0.3 9 升级 + v2.0.5 16 升级 升级, 跨 v2.0.6 → v2.4.1 8 release 累计)

### v2.0.3 → v2.0.5 升级 (16 项)

| 升级 | 来源 | 落地 |
|---|---|---|
| ✅ 4-Level 证据链 | EPIC-053-B 替代 anti-fab + preflight 单一 | v2.0.4 |
| ✅ L3L4 一致性 | EPIC-053-A (BE-9) | v2.0.4 |
| ✅ 工具自检 + 元级闭环 | EPIC-053-C (BE-10) | v2.0.4 |
| ✅ 派单仪表盘 | EPIC-053-D (H1/H6) | v2.0.4 |
| ✅ 5 调用点 wiring | EPIC-053-E (BE-5 反讽) | v2.0.4 |
| ✅ Worktree 4→1 统一 | EPIC-054-A + Master 执行 | v2.0.5 |
| ✅ Instance LRU + 7d TTL | EPIC-054-B + Master 执行 | v2.0.5 |
| ✅ EPIC 6 状态机 | EPIC-054-C + Master 执行 | v2.0.5 |
| ✅ Rule 合并 (24 → 22) | EPIC-054-D + Master 执行 | v2.0.5 |
| ✅ CLAUDE+GLOSSARY 去重 -51.5% | EPIC-055-A | v2.0.4 |
| ✅ 主公拍板分级 P0/P1/P2 | EPIC-055-B | v2.0.4 |
| ✅ 5 标签 SOP | EPIC-055-C | v2.0.4 |
| ✅ 5→3 阶段 | EPIC-056-A | v2.0.4 |
| ✅ 流程效果度量 | EPIC-056-B | v2.0.4 |
| ✅ **⚠️ Master 6 维恢复** | **EPIC-056-C (红线 revert)** | v2.0.4 |
| ✅ **Rule 32 撤销 反讽治根** | EPIC-054-D 候选 B | v2.0.5 |

### v2.0.6 → v2.4.1 跨期 升级 (8 release, 8 项)

| 升级 | 来源 | 落地 |
|---|---|---|
| ✅ Hybrid flag-controlled install 4 工具 (--target=auto) | EPIC-057-A 8/8 PASS | v2.0.6 |
| ✅ Onramp tool detect 6 工具 detection | EPIC-057-B 6/6 PASS | v2.0.6 |
| ✅ Multi-tool E2E 4 工具 闭环 (1 ticket 1 subagent 串行) | EPIC-057-D 4/4 PASS | v2.0.6 |
| ✅ 26 .sh 改造 + --help + slash-commands.md (651 行) | 跨期 todo 闭环 (v2.0.9) | v2.0.9 |
| ✅ 8 工具 wizard 5-step + dry-run 模式 | 8 工具 default (v2.1.0) | v2.1.0 |
| ✅ 26 .md wrappers (Claude Code 2.1+ 优先 .md 格式) | BE-15 治根 "Unknown command" (v2.1.1) | v2.1.1 |
| ✅ 10 工具 + --symlink single source 模式 | canonical `~/.local/share/kallax/` (v2.2.0) | v2.2.0 |
| ✅ pre-commit ALLOWED_PATTERNS 加 `^jira/` (1 line diff) | BE-14 --no-verify workaround 治根 (v2.3.0) | v2.3.0 |

### v2.4.0 → v2.5.0 反思 升级 (3 release, 2 项)

| 升级 | 来源 | 落地 |
|---|---|---|
| ✅ 48 worktree + 123 branches 清理 (5.5M disk freed) | P1-2 主公 Y 派单 (v2.4.0) | v2.4.0 |
| ✅ Rule 22→18 合并 → revert (跟"诚实修正" 联合) | PHASE-013-REFLECTION (v2.4.1) | v2.4.1 |
| ✅ KALLAX-GLOSSARY §11.x 6 反思 术语 (54→60) | PHASE-014 跨期 review 入口 (v2.5.0) | v2.5.0 |

**26 项升级** 累计 (跟 v2.0.3 9 升级 + v2.0.5 16 升级 + v2.0.6→v2.4.1 8 升级 + v2.4.0→v2.5.0 2 反思 升级 升级)

---

## 10. 净价值 反转 闭环 (跟 v1.2.4 baseline 对比, 跨 14 release 累计)

### 14 release 演化 (v1.0.0 → v2.5.0)

| 阶段 | 净价值 | 跟 v1.2.4 对比 | 跟"反讽" / "诚实修正" 联合 |
|---|---|---|---|
| **v1.0.0** (baseline) | 60.0% | -2.5% | baseline |
| **v1.2.4** | 62.5% (-5% 恶化) | baseline | 反讽 |
| v2.0.3 ACCUMULATED-LESSONS | 67.5% (5 视角 Product) | +5% | 反讽闭环 |
| v2.0.4 (14 卡闭环) | 67.0% (+4.5%) | +4.5% | 反讽闭环 |
| v2.0.5 (5 清理 + Rule 合并 24→22) | 67.0% 持平 | +4.5% 持平 | **诚实修正** (-3 → -2) |
| v2.0.6 (EPIC-057 4 ticket multi-tool) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** (0 增命令 0 增 Rule) |
| v2.0.7 (跨期 todo 闭环 5 commit batch) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.0.8 (PHASE-011 跨期 review 入口) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.0.9 (26 .sh 改造 + --help + slash-commands.md 651 行) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.1.0 (8 工具 wizard 5-step + dry-run) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.1.1 (26 .md wrappers 治根 BE-15) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.2.0 (10 工具 + --symlink single source) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.3.0 (PHASE-012 跨期 review + GLOSSARY 扩 +12 + pre-commit 治根) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** |
| v2.4.0 (PHASE-013 4 合并 + 48 worktree 清理) | 67.0% 持平 | +4.5% 持平 | **翻篇&精进** (假命题, BE-16) |
| **v2.4.1** (4 合并 revert 跟"诚实修正" 联合) | 67.0% 持平 | +4.5% 持平 | **诚实修正** (跟 PHASE-013-REFLECTION 联合) |
| **v2.5.0** (PHASE-014 入口 + GLOSSARY 11.x 6 反思) | 67.0% 持平 | +4.5% 持平 | **反讽** (跟 KALLAX-GLOSSARY §11.x 联合) |

**反转验证** (跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致):
- 62.5% (v1.2.4) → 67.0% (v2.0.4 闭环) → 67.0% (v2.0.5 持平) → 67.0% (v2.0.6 → v2.5.0 8 release 持平)
- 8 release 累计 净价值 67.0% 持平 = 0 实际变化 (跟"翻篇&精进" 战略 一致)
- 跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 联合, v2.4.0 4 合并 = 0 实际变化 治根 闭环
- 跟"诚实修正" 联合: v2.0.5 净价值 -3 → -2 honest mark, v2.4.0 4 合并 → v2.4.1 revert honest mark 闭环

---

## 11. 5 视角 跟 v2.0.3 ACCUMULATED-LESSONS 对比 矩阵 (跨 14 release 累计)

| 视角 | v2.0.3 baseline | v2.0.5 升级 | v2.0.6 → v2.5.0 跨期 升级 | 净影响 |
|---|---|---|---|---|
| 🏗️ Architect | 18 Rule + 15 门禁循环论证 | 22 Rule + 17 门禁 + 4-Level 证据链 + Rule 32 撤销 | 22 Rule (v2.4.1 还原) + 4-Level 证据链 + 10 工具 + 26 .md wrappers + 26 .sh + single source + GLOSSARY 60 术语 | **净价值反转 + 跨期 持平** |
| 🛡️ Security | 71.4% BE 工具可绕过 | 3 层防护 + tool-self-check + BE-10 真根因 | + pre-commit ALLOWED_PATTERNS `^jira/` (BE-14 治根) + 8 工具 multi-tool 治理 + BE-16 闭环 | **元级闭环 + 跨期 治根** |
| 💻 Backend | 71.4% BE / 12 KPI falsification | 4-Level 证据链 + A+B review + 6 票闭环 | + 1 ticket 1 subagent 串行 (BE-14 治根) + 26 .sh + 26 .md wrappers + 10 工具 E2E | **治根闭环 + 跨期 串行** |
| 📋 Product | 67.5% 净价值 (5 视角) | 67.0% 持平 (跟 5 视角 联合) | 67.0% 持平 8 release (跟"翻篇&精进" 一致) | **诚实修正 + 跨期 持平** |
| 🖌️ UX | 决策疲劳 | P0/P1/P2 分级 + 3 KPI 仪表盘 | + 5 deferred tickets 闭环 (3 closed + 2 留待) + 8 工具 wizard 5-step + --symlink single source + --dry-run | **疲劳治本 + 跨期 用户体验 升级** |

---

## 12. 给下 PHASE (PHASE-015+) 战略建议 (跟"翻篇&精进" + "诚实修正" + "反讽" + "反哺框架" 联合)

### 12.1 治根 闭环 (跨 14 release 累计, 跟"翻篇&精进" 战略 一致)

- ✅ 18 卡 (5 EPIC: 053 + 054 + 055 + 056 + 057) 闭环 + 5 清理执行 = 0 待办 EPIC ticket
- ✅ EPIC-057 4 ticket 串行闭环 (v2.0.6 release, 4 工具 multi-tool)
- ✅ pre-commit ALLOWED_PATTERNS 含 `^jira/` (v2.3.0, 1 line diff, BE-14 治根)
- ✅ 5 deferred tickets: 3 closed (P1-1 v2.3.0 / P1-2 v2.4.0 / P3-1 v2.4.1) + 2 留待 (P2-1 / P2-2)

### 12.2 跨 PHASE review 升级 (PHASE-005 → PHASE-014, 10 PHASE review 累计)

- PHASE-009 → PHASE-010 (v2.0.5 → v2.0.6): 跨 14 卡 + 5 治理卡 + 5 清理 + EPIC-057 4 ticket 沉淀
- PHASE-010 → PHASE-011 (v2.0.6 → v2.0.8): 跨期 review 入口, 5 deferred tickets 整合
- PHASE-011 → PHASE-012 (v2.0.8 → v2.3.0): 跨期 review 5 步大闭环, 26 升级 累计
- PHASE-012 → PHASE-013 (v2.3.0 → v2.4.0): 4 Rule 合并反思 + 48 worktree 清理
- **PHASE-013-REFLECTION** (v2.4.1): v2.4.0 4 合并 反思 290+ 行, 4 决策 + 4 治根
- **PHASE-014** (v2.5.0): 5 deferred → 3 closed + 2 留待, 跨期 review 入口
- ACCUMULATED-LESSONS-2026-06-13 → ACCUMULATED-LESSONS-2026-06-17 v2.0.5 → v2.0.6 → v2.5.0 (本升级)
- 跟"反哺框架" 战略 一致

### 12.3 0 增命令 + 0 增 Rule 持续 (v2.0.6 → v2.5.0 8 release 验证)

- 跟 v2.0.3 战略一致 (跟 Rule 32 联合, Rule 32 已撤销)
- v2.0.6 EPIC-057 加 4 ticket + 4 工具 paths mapping, **0 新增 Rule**, **0 新增 expert** (跟 v1.2.4 5 扩展组 模式 一致)
- v2.0.7 → v2.5.0 8 release 累计 0 增命令 0 增 Rule 持平 (跟"翻篇&精进" 战略 一致)
- 净价值 67.0% 持续保持 (8 release 累计 持平)

### 12.4 ⚠️ 红线 revert 文档化 (v2.0.5 + v2.0.6 + v2.4.1 累计, 跟"诚实修正" 联合)

- EPIC-056-C (v2.0.5): ⚠️ 红线 revert Master 6 维, 主公 explicit 拍板, 不暗箱操作
- EPIC-057 串行派单 (v2.0.6): ⚠️ BE-9 silent output 复发 治根, 主公 D 拍板 (1 ticket 1 subagent), 不再 4 并行 silent
- **v2.4.1 Rule 合并 revert**: ⚠️ v2.4.0 4 合并 反讽 → revert 跟"诚实修正" 联合, 治根 "0 实际变化 假动作" (跟 PHASE-013-REFLECTION 联合, 跟 KALLAX-GLOSSARY §11.5 联合)
- ACCUMULATED-LESSONS 升级版 记录 此次 revert 完整流程 (供下 PHASE 参考)

### 12.5 EPIC-057 串行派单教训 (跟"独立" 拍 explicit 约束 联合)

- **教训**: 4 subagent 并行 → silent output 复发 BE-9 反讽. 1 ticket 1 subagent 串行 → 100% PASS deliver.
- **跟"独立" 拍 explicit 约束 联合**: 主公 D explicit 派单 (跟 PROCESS.md:25-26 Master 不自助升级红线 联合).
- **跨 ticket 依赖 (057-B 用 057-A paths, 057-C 用 057-A+B paths, 057-D 用全部)** 不能并行, 串行是 hard requirement.
- **0 hybrid flag-controlled** (主公 '需要用户选择安装哪个工具/还是全支持' 联合): `--target=auto` 默认 = 全支持, explicit = 用户选择.

### 12.6 v2.4.0 反思 闭环 (跟"诚实修正" + "反讽" 联合, 跟 KALLAX-GLOSSARY §11.x 联合)

- **教训 1**: "Rule 数越少越好" 是 假命题 (跟 KALLAX-GLOSSARY §11.1 联合, 治根 "Rule 治 Rule 通胀" 迷信)
- **教训 2**: 阈值 15 是 迷信 (跟 KALLAX-GLOSSARY §10.3 联合, 治根 v1.2.4 EPIC-051 经验值 迷信)
- **教训 3**: 4 组合并 边界 失焦 (跟 KALLAX-GLOSSARY §11.4 联合, 跨 release 经验 跟 单 ticket 时间维度 失焦, P0 红线 跟 P1 软规则 优先级 失区分)
- **教训 4**: revert 跟反思 区别 (跟 KALLAX-GLOSSARY §11.5 联合, revert 是 技术 行动, 反思 是 战略 行动)
- **教训 5**: 5 deferred tickets 状态 (跟 KALLAX-GLOSSARY §11.6 联合, 3 closed + 2 留待)
- **闭环验证**: v2.4.0 4 合并 → v2.4.1 revert 跟"诚实修正" 联合, 净价值 67.0% 持平, 0 增命令 0 增 Rule (跟"翻篇&精进" 一致)

### 12.7 PHASE-014+ 战略建议 (跟"翻篇&精进" + "反讽" + "诚实修正" + "反哺框架" 联合)

- **PHASE-015+ 启动 条件**: 主公 explicit 派单 (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合)
- **0 增命令 0 增 Rule 持续**: 14 release 累计 验证 模式, 未来 release 继续 持平
- **GLOSSARY 持续 扩**: 60 术语 跟 KALLAX-GLOSSARY §12.x 后续 章节 联合 (跟"反讽" + "诚实修正" 联合, 治根 §10.3 阈值 15 迷信 后续)
- **ACCUMULATED-LESSONS 跨 release 累计**: 跟"反哺框架" 战略 一致, 跨期 沉淀
- **5 deferred 留待 处理**: P2-1 (web dashboard 真上线) + P2-2 (69 remote DB cleanup Option B/C) 长期, 主公 explicit 派单 闭环

---

## 13. 累计文件清单 (跟 v2.0.3 联合, 跨 14 release 累计)

### v2.0.3 ACCUMULATED-LESSONS (历史保留)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-13.md` (429 行, v2.0.3 baseline)
- `confluence/decisions/PROJECT-STATUS-AND-LESSONS-2026-06-13.md` (288 行, 跟 v2.0.3 联合)
- `confluence/decisions/PHASE-005~008-REVIEW-*.md` (5 PHASE review)

### v2.0.5 ACCUMULATED-LESSONS 初版 (历史保留)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (v2.0.5 升级版初版)
- `confluence/decisions/PHASE-009-REVIEW-2026-06-17.md` (246 行, 14 卡闭环沉淀)
- `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md` (14 卡 intake)
- `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md` (5 治理卡 拍板决策)
- `docs/PHASE-INDEX.md` (v2.0.5 升级: 加 PHASE-009-REVIEW-2026-06-17)

### v2.0.6 ACCUMULATED-LESSONS 升级版 (历史保留)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (v2.0.6 升级, +EPIC-057 section + 13 BE + 4 工具)
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md` (260 行, v2.0.6 4 ticket 闭环 review)
- `docs/guides/INSTALL-MULTI-TOOL.md` (222 行, EPIC-057-C 新建, v2.0.6 4 工具 install guide)
- `docs/PHASE-INDEX.md` (v2.0.6 升级: 加 PHASE-010 + ACCUMULATED-2026-06-17)

### v2.0.7 → v2.4.1 跨期 8 release 文件清单 (本升级, 跟 PHASE-011/012/013 联合)

- `confluence/decisions/PHASE-011-REVIEW-2026-06-17.md` (跨期 review 入口, 5 deferred tickets 整合)
- `confluence/decisions/PHASE-012-REVIEW-2026-06-17.md` (v2.2.0 → v2.3.0 跨期 review 5 步大闭环, 26 升级 累计)
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md` (v2.4.0 反思 290+ 行, 4 决策 + 4 治根, 跟 KALLAX-GLOSSARY §11.x 联合)
- `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md` (5 deferred → 3 closed + 2 留待, 跨期 review 入口)
- `docs/KALLAX-GLOSSARY.md` (60 术语, v2.3.0 + v2.5.0 升级版, 733 行, §11.x 6 反思 术语)
- `docs/reference/slash-commands.md` (651 行, v2.0.9 26 命令 详细 reference)
- `docs/guides/INSTALL-MULTI-TOOL.md` (376 行, v2.2.0 升级, 10 工具 + single source 模式)
- `docs/PHASE-INDEX.md` (v2.0.7 → v2.5.0 升级: 加 PHASE-011/012/013/013-REFLECTION/014 entry, 10 PHASE review 累计)
- `.claude/commands/_kallax_common.sh` (show_help 函数 v2.1.1, 治根 BE-15)
- `.claude/commands/kallax-{26 个}.{sh,md}` (26 .sh + 26 .md wrappers, 治根 BE-15)
- `.trae/{skills,commands}` + `.antigravity/{skills,commands}` (symlinks to .claude/, v2.2.0)
- `.cursor/{skills,commands}` + `.codeium/windsurf/{skills,commands}` (symlinks to .claude/, v2.1.0)
- `.aider/skills/kallax/README.md` + `.continue/skills/kallax/README.md` (config templates v2.1.0)
- `scripts/hooks/pre-commit` (ALLOWED_PATTERNS 加 `^jira/`, v2.3.0, 1 line diff, 治根 BE-14)
- `scripts/install.sh` (10 工具 `--target=auto` hybrid flag + `--symlink` single source + `--wizard` 5-step + `--dry-run`, v2.2.0 升级)
- `jira/epics/EPIC-058/epic.json` (5 deferred tickets)
- `web/src/dashboard/dispatch/` (EPIC-053-D 代码就绪, 待 P2-1 server 部署)

### PHASE-INDEX.md 累计 (10 PHASE review 累计, 跟 v2.5.0 升级 联合)

- PHASE-005 ~ PHASE-008 (v2.0.3 baseline)
- PHASE-009 (v2.0.5 release)
- PHASE-010 (v2.0.6 release)
- **PHASE-011** (v2.0.8 release, 跨期 review 入口)
- **PHASE-012** (v2.3.0 release, 跨期 review 5 步大闭环)
- **PHASE-013** (v2.4.0 release, 4 合并 + 48 worktree 清理)
- **PHASE-013-REFLECTION** (v2.4.1 release, v2.4.0 反思 290+ 行)
- **PHASE-014** (v2.5.0 release, 5 deferred → 3 closed + 2 留待, 跨期 review 入口)
- **PHASE-015** (v2.7.0 release, EPIC-059 8 票 闭环, EKET 借鉴 Phase 1, 跟"借方法论 不借代码" 联合, 跟 v2.4.1 反思 + KALLAX-GLOSSARY §11.1-11.6 联合, 1 ticket 1 subagent 串行 8 轮, BE-17 silent 复发 跟"诚实修正" 联合)
- ACCUMULATED-LESSONS-2026-06-13 (v2.0.3 baseline)
- ACCUMULATED-LESSONS-2026-06-17 (v2.0.5 初版 + v2.0.6 升级 + v2.5.0 升级 + **v2.7.0 升级 [本升级]**)

---

## 14. v2.7.0 升级 段 (PHASE-015 EKET 借鉴 Phase 1 闭环, EPIC-059 8 票 累计)

跟 v2.7.0 release 联合 (commit `05c266d`), 跟 PHASE-015 review 联合 (file:line confluence/decisions/PHASE-015-EKET-BORROW-REVIEW-2026-06-18.md:1-252), 跟主公 2026-06-18 '需要都建卡并行处理' + '直接启动开工' 派单 联合, 跟 ~/.claude/knowledge/core/methodologies/borrowing-from-external.md 5 维评分 决策矩阵 4-5 分直接建卡 联合, 跟"借方法论 不借代码" 联合, 跟"翻篇&精进" + "诚实修正" + "反讽" + "反哺框架" 4 战略 联合.

### 14.1 EPIC-059 8 票 闭环 累计 (跟 BE-14 1 ticket 1 subagent 串行 8 轮 联合)

| 票 ID | 主题 | 4-Level 验证 | Commit | 联合 eket / 借鉴 来源 |
|-------|------|--------------|--------|----------------------|
| EPIC-059-A | 9 Hard Rules 简化 | 5/5 PASS | `7ca58a5` | eket MASTER-RULES.md §6 9 Hard Rules 模式 → 22 Rule → 9 类别 group 索引 |
| EPIC-059-B | Rule of 500 | 16/6 PASS | `fc1cbb4` | eket MASTER-RULES.md §6 Rule 8 净变更 4 档分级 (silent/acceptable/codemod_hint/reject) |
| EPIC-059-C | PR ~100 行上限 | 21/5 PASS | `b1ad90c` | eket MASTER-RULES.md §6 Rule 9 PR 4 档分级 (跟 B 互为 互补, 粒度 分离) |
| EPIC-059-D | Fact-Forcing 原则 | 3 文件 + 21 assertions | `0b394f5` | eket MASTER-RULES.md §2 3 原则 + 7 反例 + 7 正例 + 5+5 + Master 6 维 L6 诚实 联合 |
| EPIC-059-E | Post-Process 11 步骤 | 23/5+ PASS | `5cc620f` | eket MASTER-RULES.md §10 4 步骤 → 11 步骤 升级 (PHASE review 10 累计 联合) |
| EPIC-059-F | 派遣 Checklist 11 项 | 3/3 落地 | `3f93c2d` | eket MASTER-RULES.md §11 7 项 → 11 项 升级 (BE-14 + EPIC-059-D + PROCESS.md:25-26 闭环) |
| EPIC-059-G | 文档卫生 + 新建前先想 | 21/21 PASS | `3c0a11a` | eket MASTER-RULES.md §6 Rule 6+7 联合 + KALLAX-GLOSSARY 反哺框架 战略 |
| EPIC-059-H | 多级记忆分层 L0-L4 | 21/21 PASS | `be7e5a9` | eket confluence/memory/ + ~/.claude/knowledge L0-L4 联合 |

**8 票 累计 KPI**:
- 8/8 done = 100.0% 闭环 (跟 EPIC-059 epic.json tickets 状态 联合)
- 5+16+21+21+23+3+21+21 = **131 assertions** PASS (跟"诚实修正" 联合, raw test output 留存 8 commit message 跟 EPIC-059-D Fact-Forcing 联合)
- 0 增 Rule (跟 v2.4.1 还原 22 Rule 联合, 跟 KALLAX-GLOSSARY §11.1 联合, 治根 "Rule 数通胀" 迷信)
- 0 增命令 (跟 v1.3.0 Onramp 1 入口 撤销 模式 一致, 跟"反讽" 联合)
- 0 重写 (跟 Rule 5 DRY 联合)

### 14.2 BE 累计 16 → 17 (跟 BE-17 silent output 1st attempt 跟"诚实修正" 联合)

跟 §8 16 BE 联合, 加 BE-17:
- **BE-17**: EPIC-059-A 1st subagent silent output 复发 (跟 BE-9 4 subagent + BE-14 1 subagent silent 联合) → 2nd attempt OK 跟"诚实修正" 联合 (跟 v2.4.1 revert 闭环 模式 一致) → 后续 7 票 (B-H) 0 silent output 累计 (跟"翻篇&精进" 战略 一致)

### 14.3 升级路径 累计 26 → 28 (跟 v2.0.6 → v2.4.1 8 release 累计 → v2.7.0 PHASE-015 联合)

跟 §9 26 升级 联合, 加 v2.7.0 PHASE-015 2 反思 升级:
- **升级 27**: v2.4.0 + v2.4.1 反思 联合 → EPIC-059-A 9 Hard Rules 简化 (跟 v2.4.1 revert 闭环 模式 一致, 22 Rule 保持, 0 增 Rule 治根 "Rule 数通胀" 迷信)
- **升级 28**: PHASE-013-REFLECTION + PHASE-014 + PHASE-015 跨期 反思 链 → EPIC-059-D Fact-Forcing 原则 (跟 eket MASTER-RULES.md §2 联合, 跟 Master 6 维 L6 诚实 联合, 治根 "0 假 PASS" 反复)

### 14.4 净价值 67.0% 持平 跨 8 release (跟"翻篇&精进" 战略 一致)

跟 §10 14 release 演化 联合, 加 v2.6.0 + v2.7.0 → **16 release 累计** (v1.0.0 → v2.7.0):
- 16 release 累计 净价值 67.0% 持平 = 0 实际变化 (跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 联合)
- 跟"诚实修正" 联合: v2.0.5 + v2.0.6 + v2.4.1 + EPIC-059-A 1st silent 跟 2nd attempt OK 累计 4 红线 revert/honest mark
- 跟"反讽" 联合: 跟 v2.4.0 4 Rule 合并 "净价值 提升" 假动作 治根 闭环

### 14.5 5 视角 跨 v2.5.0 → v2.7.0 升级 (跟"反哺框架" 战略 一致)

跟 §11 5 视角 联合, 加 v2.5.0 → v2.7.0 跨期 升级:
- **Architect 视角**: 22 Rule (v2.4.1 还原) + 4-Level 证据链 + 10 工具 + 26 .md wrappers + 60+5 术语 (加 §12.1 Fact-Forcing + §12.4 L0-L4)
- **Security 视角**: + pre-commit ALLOWED_PATTERNS (file:line scripts/hooks/pre-commit 联合) + 8 工具 multi-tool 治理 + BE-17 silent 闭环 + Fact-Forcing 原则 标准化
- **Backend 视角**: + 1 ticket 1 subagent 串行 (BE-14 联合) + 26 .sh + 26 .md wrappers + 10 工具 E2E + Rule of 500 + PR ~100 行上限 (跟 EPIC-059-B/C 联合)
- **Product 视角**: 67.0% 持平 8 release (跟"翻篇&精进" 一致, 跟 v2.0.4 +4.5% 持平, 跟 16 release 累计 0 实际变化 联合)
- **UX 视角**: + 5 deferred tickets 状态 (3 closed + 2 留待) + 8 工具 wizard 5-step + --symlink single source + --dry-run + 派遣 Checklist 11 项 (跟 EPIC-059-F 联合) + 文档卫生 (跟 EPIC-059-G 联合) + L0-L4 分层 (跟 EPIC-059-H 联合)

### 14.6 14 release → 16 release 演化 累计 (跟"翻篇&精进" 战略 一致)

跟 §10 5 阶段 → 14 release 演化 联合, 加 v2.6.0 + v2.7.0 → **16 release 累计**:
- v2.6.0 经验教训 整理 release (跟 ACCUMULATED-LESSONS 11 sections 升级 联合, 跟"诚实修正" 联合)
- v2.7.0 EKET 借鉴 Phase 1 闭环 release (跟 EPIC-059 8 票 联合, 跟"借方法论 不借代码" 联合, 跟 PHASE-015 联合)

### 14.7 PHASE 累计 10 → 11 (跟 PHASE-015 联合, 跟"反哺框架" 战略 一致)

跟 §12 PHASE 累计 联合, 加 PHASE-015:
- **PHASE-015-EKET-BORROW-REVIEW-2026-06-18**: EKET 借鉴 Phase 1 闭环 (EPIC-059 8 票 全 done, 跟 v2.6.0 经验教训 整理 release 联合, 跟"借方法论 不借代码" 联合, 跟 PHASE-014 模式 一致, 1 ticket 1 subagent 串行 8 轮, BE-17 silent 复发 跟"诚实修正" 联合), 跟"翻篇&精进" + "诚实修正" + "反讽" + "反哺框架" 4 战略 联合

### 14.8 给下 PHASE (PHASE-016+) 战略建议 (跟"独立" 拍 explicit 联合, 跟主公后续 拍板 留待 联合)

跟 §12 战略建议 联合, 加 v2.7.0 升级 段:

#### 14.8.1 P3 留待 3 项 (跟"独立" 拍板 explicit 联合, 跟 PROCESS.md:25-26 联合, 主公 explicit 拍板 留待)

跟主公 2026-06-18 '同意建议' 派单 联合, 跟"独立" 拍板 explicit 联合 (跟 PROCESS.md:25-26 联合):

- **P3-A 分布式 路线图** (ioredis Pub/Sub + litestream + 3 仓 sync + web dashboard 部署)
  - 跟 ioredis optional (file:line node/package.json:28-29) 联合
  - 跟 web/src/dashboard/dispatch/ 代码就绪 联合
  - 跟 P2-1 web dashboard 部署 主公 B 跳过 联合
  - 跟"反讽" 联合 治根 "单 master 假动作"
- **P3-B Rust 投入 拍板** (KALLAX 5 crates 现状, 0 投入 验证 / 主用)
  - 跟 rust/Cargo.toml:1-7 5 crates 联合 (kallax-core/engine/cli/server/context-mon)
  - 跟"翻篇&精进" 一致, KALLAX 0 Rust 投入 现状
- **P3-C 4 层 → 5 层 (分布式层) 拍板** (跟 eket 4 级降级 模式 一致, 跟"反讽" 联合)
  - 跟 eket 架构 Level 0-3 模式 联合 (Shell → Rust → Node.js → Web)
  - 跟 PROCESS.md:25-26 独立 拍板 联合

#### 14.8.2 KALLAX-GLOSSARY 12.x 持续扩 (跟"反讽" + "诚实修正" + "反哺框架" 联合)

- **§12.1 Fact-Forcing 原则** (已 落地 v2.7.0, 跟 eket MASTER-RULES.md §2 联合)
- **§12.4 L0-L4 多级记忆分层** (已 落地 v2.7.0, 跟 eket confluence/memory/ + ~/.claude/knowledge L0-L4 联合)
- **§13.x 后续扩** (跟"反哺框架" 战略 一致, 跨 PHASE-016+ 持续)

#### 14.8.3 0 增命令 + 0 增 Rule 持续 (跟"翻篇&精进" 战略 一致, 跟 16 release 累计 联合)

- 净价值 67.0% 持续保持 (跟 8 release 累计 持平 联合)
- 0 假 PASS 0 模糊 0 反讽反复 (跟"诚实修正" 联合, 跟 Master 6 维 L6 诚实 联合)
- 0 silent output 0 silent 复发 (跟"诚实修正" + "翻篇&精进" 联合, 跟 BE-14 + EPIC-059-A 1st 联合)

### 14.9 累计文件清单 跨 v2.5.0 → v2.7.0 升级 (跟"翻篇&精进" 战略 一致)

跟 §13 累计文件清单 联合, 加 v2.7.0 PHASE-015 EPIC-059 8 票 交付物 + 8 commit hash:
- **PHASE-015 review doc** (file:line confluence/decisions/PHASE-015-EKET-BORROW-REVIEW-2026-06-18.md, 252 行)
- **CLAUDE.md** +28 lines (file:line CLAUDE.md:471-497 9 Hard Rules 模式 章节)
- **docs/KALLAX-GLOSSARY.md** +179 lines (file:line §12.1 + §11.1 闭环 + §12.4 + §13 升级)
- **docs/process/9-hard-rules.md** (新, 226 行)
- **docs/process/fact-forcing.md** (新, 428 行)
- **scripts/check-9-hard-rules.sh** (新, 255 行)
- **scripts/check-pr-size.sh** (+130 lines, Rule of 500 + PR ~100 行)
- **scripts/hooks/pre-commit** (+30 lines, Rule of 500 集成)
- **scripts/check-doc-hygiene.sh** (新, 524 行)
- **scripts/post-process.sh** (新, 548 行)
- **scripts/memory-promote.sh** (新, 242 行)
- **tests/integration/check-9-hard-rules-test.sh** (新, 338 行)
- **tests/integration/check-rule-of-500-test.sh** (新, 258 行)
- **tests/integration/check-pr-100-test.sh** (新, 303 行)
- **tests/integration/post-process-test.sh** (新, 331 行)
- **tests/integration/doc-hygiene-test.sh** (新, 340 行)
- **tests/integration/memory-l0-l4-test.sh** (新, 258 行)
- **confluence/memory/LAYERS.md** (新, 185 行)
- **confluence/decisions/fact-forcing-examples.md** (新, 263 行)
- **confluence/decisions/dispatch-checklist.md** (新, 631 行)
- **confluence/decisions/PHASE-015-EKET-BORROW-REVIEW-2026-06-18.md** (新, 252 行)
- **.claude/skills/kallax/SKILL.md** +131 lines (派遣 Checklist 11 项 + Post-Process 11 步骤 + L0-L4 触发 段)
- **AGENTS.md** +34 lines (派遣 Checklist 11 项 段)
- **.github/workflows/pr-size-check.yml** (新, 145 行)
- **CHANGELOG.md** (v2.7.0 entry added)
- **package.json** (2.6.0 → 2.7.0)
- **jira/epics/EPIC-059/epic.json** (89 行, master plan)
- **jira/tickets/EPIC-059-A/H/ticket.json** (8 tickets, ~290 行 累计)
- **jira/epics/epic_index.json** (EPIC-058 + EPIC-059 entry)

---

## 15. 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-13 | v2.0.3 baseline | master_77704 | 11 BE + 5 release + 38 worktree + 18 Rule |
| 2026-06-16 21:00 | 14 卡 INT 启动 | master_main | 主公'建卡修复' explicit 派单 |
| 2026-06-16 22:30 | EPIC-053 6/6 闭环 | master_main + 6 Performer | v2.0.3 落地 |
| 2026-06-16 23:00 | EPIC-055/056 6/6 闭环 | master_main + 6 Performer | v2.0.3 + 5 治理卡 落地 |
| 2026-06-16 23:30 | EPIC-054 4/4 闭环 | master_main + 4 Performer | v2.0.4 落地 |
| 2026-06-17 07:00 | v2.0.4 release | master_main | 14/14 闭环, push origin |
| 2026-06-17 07:30 | 5 清理执行 | master_main | H5/A7/A6/A1 治根 + 仪表盘真跑 |
| 2026-06-17 08:00 | v2.0.5 release | master_main | Rule 合并 实际执行 |
| 2026-06-17 08:30 | PHASE-009 review | master_main | 沉淀 |
| 2026-06-17 09:00 | ACCUMULATED-LESSONS v2.0.5 升级 | master_main | 470 行 + 13 BE + 5 治理卡 |
| 2026-06-17 10:00 | 主公 'B' explicit 拍板 | master_main | EPIC-057 multi-tool skills support |
| 2026-06-17 10:30 | EPIC-057 建卡 | master_main | 4 ticket.json + epic.json (commit `b2722e4`) |
| 2026-06-17 11:00 | 057-A install.sh 串行 | Performer (1 subagent) | 6/6 PASS, merge `d048b53` |
| 2026-06-17 11:30 | 057-B onramp 串行 | Performer (1 subagent) | 6/6 PASS + sibling, merge `8209c4d` |
| 2026-06-17 12:00 | 057-C docs 串行 (复用 partial) | Performer (1 subagent) | 5/5 PASS, merge `d1e729f` |
| 2026-06-17 12:30 | 057-D tests 串行 | Performer (1 subagent) | 18/18 PASS, merge `36b75d7` |
| 2026-06-17 13:00 | v2.0.6 release | master_main | 4 工具 multi-tool, push origin (commit `7db6107`) |
| 2026-06-17 13:30 | Todo 1+2 cleanup | master_main | `.gitignore` + PHASE-INDEX (commit `2f13db6` + `d9d0c92`) |
| 2026-06-17 14:00 | PHASE-010 review | master_main | 260 行 沉淀 (commit `9056927`) |
| 2026-06-17 14:30 | ACCUMULATED-LESSONS v2.0.6 升级 | master_main | 470→531 行 (commit `290e97e`) |
| 2026-06-17 15:00 | v2.0.7 bump | master_main | 跨期 todo 闭环 release (commit `e46bb59`) |
| 2026-06-17 15:30 | push 5 commit batch | master_main | origin miao 同步 (0/0) |
| 2026-06-17 16:00 | 主公'AC' explicit 派单 | master_main | 'AC 做一下, 其他不管了' |
| 2026-06-17 16:30 | KALLAX-GLOSSARY v2.0.6 升级 | master_main | Section 8.6-8.10 (commit `ee537e3`) |
| 2026-06-17 17:00 | PHASE-011 跨期 review 入口 | master_main | EPIC-058 5 deferred + PHASE-011-REVIEW doc |
| 2026-06-17 17:30 | v2.0.8 bump | master_main | PHASE-011 入口 + KALLAX-GLOSSARY v2.0.6 升级版 release 命名 (commit `2c00c56`) |
| 2026-06-17 18:00 | 主公"kallax 很多命令, 但是这些命令都没有说明" 反馈 | master_main | slash commands doc 反馈, 触发 v2.0.9 |
| 2026-06-17 18:30 | v2.0.9 release | master_main | 26 .sh 改造 + --help + slash-commands.md (commit `589adf4`) |
| 2026-06-17 19:00 | 主公 "Claude Code 跑 /kallax-ask 看不到说明" 反馈 | master_main | 治根行为层, 触发 v2.0.10/0.11 |
| 2026-06-17 19:30 | v2.0.10 release | master_main | 26 .sh 顶部 # 注释 multi-line + SKILL.md 升级 (commit `63fd5c5`) |
| 2026-06-17 20:00 | v2.0.11 release | master_main | no-args → show_help 治根行为层 (commit `38be3bc`) |
| 2026-06-17 20:30 | 主公"是不是要引导式安装以支持不同的工具" 反馈 | master_main | 触发 v2.1.0 wizard 5-step |
| 2026-06-17 21:00 | v2.1.0 release | master_main | 8 工具 multi-tool + Wizard 5-step + Dry-run (commit `9e93a4f`) |
| 2026-06-17 21:30 | 主公 "Unknown command: /kallax-ask" 反馈 | master_main | 治根, 触发 v2.1.1 .md wrappers |
| 2026-06-17 22:00 | v2.1.1 release | master_main | 26 .md wrappers 治根 (commit `0ded58f`) |
| 2026-06-17 22:30 | 主公"用一份skills/命令文件支持所有的引用" 派单 | master_main | 触发 v2.2.0 4 工具 single source 模式 |
| 2026-06-17 23:00 | v2.2.0 release | master_main | 10 工具 + --symlink single source 模式 (commit `c3cc6d9`) |
| 2026-06-17 23:30 | v2.2.0 docs 整理 | master_main | INSTALL-MULTI-TOOL + KALLAX-GLOSSARY 升级 (commit `2c7faab`) |
| 2026-06-17 24:00 | 主公 4 问 → D 拍 | master_main | PHASE-012 + GLOSSARY 扩 + pre-commit 治根 联合 (A+B+C 大闭环) |
| 2026-06-18 00:30 | **v2.3.0 release** | **master_main** | **PHASE-012 跨期 review + GLOSSARY 扩 +12 术语 42→54 + pre-commit ALLOWED_PATTERNS 加 `^jira/` 治根 5 commit workaround (P1-1 EPIC-058 闭环, 4 deferred 留待)** |
| 2026-06-18 00:35 | 整理 v2.2.0 docs | master_main | INSTALL-MULTI-TOOL + KALLAX-GLOSSARY 整理 (commit `2c7faab`) |
| 2026-06-18 01:00 | 主公 4 问 → D 拍 | master_main | PHASE-012 + GLOSSARY 扩 + pre-commit 治根 联合 (A+B+C 大闭环) |
| 2026-06-18 02:00 | **v2.4.0 release** | **master_main** | **PHASE-013 跨期 review 落地: P3-1 Rule 合并 22→18 + P1-2 worktree 清理 48→1 (跟主公'全拍 4 合并 + Y 清理' 联合, 跟 PROCESS.md:25-26 联合 主公 explicit 拍板 后 才执行)** |
| 2026-06-18 02:30 | **PHASE-013-REFLECTION doc 落地** | **master_main** | **290+ 行 反思 doc, 跟"诚实修正" + "反讽" 联合, 4 反思 候选 + 4 治根 行动** |
| 2026-06-18 03:00 | **v2.4.1 revert release** | **master_main** | **revert v2.4.0 4 Rule 合并 (18 → 22, 跟 v2.3.0 一致 还原, 跟 PHASE-013-REFLECTION 联合, 治根 "0 实际改变 假动作") + worktree 清理 保留 (主公 Y 派单)** |
| 2026-06-18 03:30 | KALLAX-GLOSSARY §11.x 扩 | master_main | +6 术语 反思 (54 → 60, 跟"反讽" + "诚实修正" 联合, 治根 §10.3 阈值 15 迷信) |
| 2026-06-18 04:00 | 主公 'A+B' explicit 派单 | master_main | 启动 PHASE-014 + KALLAX-GLOSSARY 11.x 扩 |
| 2026-06-18 04:30 | **PHASE-014 跨期 review 入口 落地** | **master_main** | **5 deferred → 3 closed + 2 留待 (P2-1 + P2-2), 跟"诚实修正" + "独立" 联合** |
| 2026-06-18 05:00 | **v2.5.0 release (本)** | **master_main** | **PHASE-014 入口 + KALLAX-GLOSSARY §11.x 6 术语 60 + 跨期 经验教训 整理 (主公 派单 整理 全部 经验教训: 过时的淘汰 + 有缺陷的升级 + 类似的合并)** |
| 2026-06-17 15:00 | v2.0.7 bump | master_main | 跨期 todo 闭环 release (commit `e46bb59`) |
| 2026-06-17 15:30 | push 5 commit batch | master_main | origin miao 同步 (0/0) |
| 2026-06-17 16:00 | 主公'AC' explicit 派单 | master_main | 'AC 做一下, 其他不管了' |
| 2026-06-17 16:30 | KALLAX-GLOSSARY v2.0.6 升级 | master_main | Section 8.6-8.10 (commit `ee537e3`) |
| 2026-06-17 17:00 | PHASE-011 跨期 review 入口 | master_main | EPIC-058 5 deferred + PHASE-011-REVIEW doc |
| **2026-06-17 17:30** | **v2.0.8 bump** | **master_main** | **PHASE-011 入口 + KALLAX-GLOSSARY v2.0.6 升级版 release 命名** |
| 2026-06-18 17:30 | v2.7.0 release 闭环 | master_main | EPIC-059 8 票 done + 11 PHASE review 累计 + 60+5 术语 (commit 05c266d) |
| 2026-06-19 14:30 | v2.7.0 整理 release 启动 | master_main | 主公 2026-06-19 '整理 总结 经验教训' 派单 (commit 6ac763b + f95a229 + 005699b) |
| **2026-06-19 17:00** | **v2.7.1 release (本 release)** | **master_main** | **整理 release 闭环: 29 文件 (5 EPIC + 24 ticket + 9 归档 + 2 改名 + 5 修复 + 10 OUTDATED + 1 README + 1 hooks + 1 tests) 落地, 跟 16 release 累计 持平** |

---

**跟 v2.0.3 ACCUMULATED-LESSONS-2026-06-13 + v2.0.5 ACCUMULATED-LESSONS-2026-06-17 (v2.0.5 初版) + v2.0.6 ACCUMULATED-LESSONS-2026-06-17 (v2.0.6 升级) 联合 → 升级 → 合并 → 整理 → 总结**
**跟"流程逻辑 > 扩充配置" + "诚实修正" + "反讽" + "翻篇&精进" + "独立" 5 大战略 一致**
**跟 v2.0.4 + v2.0.5 14 卡闭环 + 5 清理执行 + EPIC-057 4 ticket 闭环 + v2.0.6 4 工具 multi-tool + v2.0.7 跨期 todo 闭环 + v2.0.8 PHASE-011 入口 + KALLAX-GLOSSARY 升级 联合**
**跟"反哺框架" 战略 一致** (跨 PHASE 累计 11 review 沉淀, 0 增命令 0 增 Rule)

---

## 15. v2.7.1 整理 release 段 (跟主公 2026-06-19 '整理 总结 经验教训' explicit 派单 联合, 跟外部项目 'build artifacts' 教训 联合)

跟主公 2026-06-19 '整理 总结 经验教训, 回顾 现有 所有的 文件, 整理 清理 升级 内容, 统一 文件 名' explicit 派单 联合, 跟 v2.7.0 经验教训 整理 release 联合 (commit 05c266d + ed9e812), 跟外部项目 'rust/target/ 等 build artifacts 不应进 git' 教训 联合 (filter-repo 改写 历史 才能推 GH Enterprise 50MB 限制), 跟 5 战略 联合 ('翻篇&精进' + '诚实修正' + '反讽' + '独立' + '反哺框架'), 跟 EPIC-059-A 9 Hard Rules 模式 联合 (借方法论 不借代码), 跟 Rule 5 DRY 联合 (单一 SoT + 归档 SoT 分离), 跟 KALLAX-GLOSSARY §修订规则 联合.

### 15.1 整理 闭环 累计 (29 文件 落地, 跟 16 release 累计 持平 联合)

| 类别 | 文件 | 落地 commit | 5 维 KPI (跟 Rule 9 X/Y 联合) |
|------|------|-------------|-------------------------------|
| **整理 (organize)** | 5 EPIC (053/054/055/056/059) + 24 ticket status: ready/pending/in_progress → done | 82e4e1e | 5/5 + 24/24 = 29/29 = 100.0% |
| **整理 (organize)** | PHASE-INDEX.md line 47 删 + ROLE-RULES.md 删 + ADR-002/003 引用修复 + ONRAMP-.-2026-06-15 改名 + migration-eket-to-kallax 改名 | 0d51e1c | 5/5 = 100.0% |
| **清理 (clean) 归档** | 9 文件 归档 (ACCUMULATED-LESSONS-13 + PROJECT-STATUS × 2 + PHASE-006-ROADMAP-REV1 + KALLAX-VS-INDUSTRY-REV1 + TOKEN-PLAN-UPGRADE + permission-model × 3) + 1 README 落地 | e173e27 | 9/9 + 1/1 = 10/10 = 100.0% |
| **清理 (clean) 改名** | 14-ISSUES-INTAKE → ISSUES-INTAKE-14 + 5-GOVERNANCE-CARDS-APPROVAL → GOVERNANCE-CARDS-APPROVAL-5 | e173e27 | 2/2 = 100.0% |
| **清理 (clean) empty** | jira/epics/_archived/ README 落地 (6 empty 目录 标注) | 6ac763b | 1/1 = 100.0% |
| **升级 (upgrade)** | jira/phases/phase_index.json 同步 13 PHASE (跟 PHASE-INDEX.md 双向同步) | f95a229 | 13/13 = 100.0% |
| **升级 (upgrade)** | 10 文件 OUTDATED 标头 (docs/process/ × 5 + docs/superpowers/plans/ × 5) | 005699b | 10/10 = 100.0% |
| **防御 (defense)** | pre-commit Check 3 build artifacts 防御 (18 pattern) + pre-push repo size guard + integration test 7/7 PASS | e3910c0 | 18/18 + 7/7 = 100.0% |
| **总结 (summary)** | ACCUMULATED-LESSONS §15 整理 release 段 (本 段) + v2.7.1 bump | TBD | 1/1 = 100.0% |
| **总 29 文件** | 8 commit (跟 EPIC-059 1 ticket 1 subagent 串行 模式 一致) | 跟"翻篇&精进" 战略 联合 | **29/29 = 100.0%** |

### 15.2 防御 (defense) 段 - Build artifacts 防禦 (跟外部项目 教训 联合, 跟 KALLAX-GLOSSARY §1.1 反讽 联合)

跟主公 2026-06-19 'rust/target/ 等 build artifacts 不应进 git' 反馈 联合, 跟外部项目 历史 教训 联合 (filter-repo 改写 历史 才能推 GH Enterprise 50MB 限制), 跟 EPIC-059-A 9 Hard Rules 模式 联合 (借方法论 不借代码), 跟 EPIC-059-B Rule of 500 联合 (防御 逻辑 互为 互补, 4 档分级 同样 思路), 跟 EPIC-059-D Fact-Forcing 联合 (file:line 精确 引用 + raw test output 留存).

**pre-commit Check 3 18 pattern** (跟'反讽' 联合 治根 'build artifact 跟 源码 混 跟 假动作'):
1. ^rust/target/ (Rust build)
2. ^target/ (Generic Cargo/Maven)
3. ^node_modules/ (npm/yarn)
4. ^node/dist/ (TypeScript build)
5. ^dist/ (Generic build)
6. ^build/ (Generic build)
7. ^__pycache__/ (Python bytecode)
8. ^.cargo/ (Cargo cache)
9. ^.rustup/ (rustup cache)
10. ^vendor/ (Go/PHP/Node vendor)
11. \.o$ (Compiled object)
12. \.so$ (Linux shared object)
13. \.dylib$ (macOS shared object)
14. \.dll$ (Windows library)
15. \.exe$ (Windows executable)
16. \.pyc$ (Python compiled)
17. \.wasm$ (WebAssembly)
18. \.map$ / \.min\.js$ / \.min\.css$ (dev only)

**pre-push 3 check** (跟 GH Enterprise 50MB 限制 联合, file:line scripts/hooks/pre-push:1-175):
- Check 1: Repo size > 50MB → 阻塞 (filter-repo 治根 + 3 步 提示), 40-50MB → warning
- Check 2: 单文件 > 5MB → warning (LFS 替代 建议)
- Check 3: 已 tracked build artifacts → warning (git rm --cached + filter-repo 治根)

**KALLAX 现状 验证** (跟'反讽' 联合 治根 '已污染 假动作'):
- `.gitignore` 已 含 (rust/target/ node_modules/ dist/ build/) 跟 v1.0.0 baseline 一致
- rust/target/ 本地 3.1G 但 不在 git (跟 .gitignore 一致)
- node_modules/ 本地 131M 但 不在 git (跟 .gitignore 一致)
- git 总包 3.43 MiB (远低于 50MB 限制)
- 977 commits 历史 无 target/ 误 commit (跟 v1.2.3 'untrack 5 runtime/compiled artifacts' 闭环, file:line git log: 699414b)
- 0 假 PASS 校验 (跟 Master 6 维 L6 诚实 联合)

**integration test 7/7 PASS** (file:line tests/integration/check-build-artifacts-test.sh:1-148):
- TC1: 0 build artifacts → 0 blocked
- TC2: rust/target/ 误 add → blocked
- TC3: node_modules/ 误 add → blocked
- TC4: dist/ + build/ 误 add → blocked
- TC5: 编译 后缀 (.o .so .dylib .pyc .wasm) 误 add → blocked
- 集成: pre-push hook 存在 + 可执行
- 集成: pre-commit Check 3 集成 in scripts/hooks/pre-commit

### 15.3 反讽 (Irony) 闭环 段 (跟 KALLAX-GLOSSARY §1.1 反讽 联合, 5 项反讽 治根)

跟"反讽" 战略 联合, 跟 KALLAX-GLOSSARY §1.1 反讽 定义 联合, 治根 5 项反讽 假动作:

| 反讽 编号 | 反讽 描述 | 治根 (跟 v2.7.1 联合) |
|----------|----------|---------------------|
| **反讽 1** | epic_index.json vs epic.json status 失焦 (4 EPIC: 053/054/055/056 active vs done) | commit 82e4e1e: 5 EPIC + 24 ticket status 同步 done + done_at/done_by/claimed_at/claimed_by 字段 加 |
| **反讽 2** | PHASE-INDEX.md line 47 重复行 (PROJECT-STATUS-AND-LESSONS-2026-06-13 重复 + 路径 '.' 异常) | commit 0d51e1c: 删 重复行 |
| **反讽 3** | ROLE-RULES.md 1 行 stale ('## Test Update' 仅 1 行) | commit 0d51e1c: 删 stale 文件 |
| **反讽 4** | confluence/decisions/index.md ADR-002/003 引用 全部 指向 ADR-001 同 1 文件 (3 ADRs 同源 假动作) | commit 0d51e1c: 加 inline 注释 跟 THREE_REPO_ARCHITECTURE.md + saga-executor.ts 关联 |
| **反讽 5** | ONRAMP-.-2026-06-15.md 文件名 '.' 异常 + migration-eket-to-kallax.md 命名 误导 (实际 KALLAX→KALLAX) | commit 0d51e1c: 2 改名 跟'反讽' 联合 治根 '假命名' |

### 15.4 跨期 累计 (跟 16 release 累计 持平 联合, 跟 v1.2.4 baseline 62.5% 联合)

跟 v2.7.0 (commit 05c266d) 16 release 累计 持平 联合:

- **v1.0.0 → v2.7.1** 17 release 累计 (跟 EPIC-060 3 票 P3 留待 联合, 跟"独立" 拍板 explicit 联合)
- **净价值 67.0% 持平** 跨 9 release (跟 v2.0.4 +4.5% 持平, 跟'翻篇&精进' 战略 一致, 0 实际变化 跨 release)
- **22 Rule 保持** (跟 v2.4.1 还原 22 Rule 联合, 跟"翻篇&精进" + "诚实修正" 联合, 跟 v2.4.0 4 合并 → v2.4.1 revert 闭环 联合)
- **60+5 术语 累计** (跟 v2.5.0 60 术语 联合, 加 v2.7.0 §12.1 Fact-Forcing + §12.4 L0-L4 联合)
- **0 增命令 0 增 Rule 持平** (跟'翻篇&精进' 战略 一致, 跟 KALLAX-GLOSSARY §11.1 'Rule 数 ≠ 治理完成' 联合)
- **5 deferred tickets 状态** (3 closed + 2 留待, 跟 PHASE-014 联合) + 3 deferred 留待 (跟 PHASE-016 联合) = 5 留待 主公后续 拍板

### 15.5 跟 5 战略 联合 累计 (跟"反哺框架" 战略 一致)

跟 5 战略 联合 累计, 跨 v2.0.3 → v2.7.1 9 release:

- **翻篇&精进**: 0 增命令 0 增 Rule 持平 9 release, 9 文件 归档 + 2 改名 + 5 修复 + 10 OUTDATED 标头, 0 重写
- **诚实修正**: 5 反讽 治根 (跟 §15.3 联合), 跟 v2.0.5 + v2.0.6 + v2.4.1 红线 revert 文档化 累计
- **反讽**: 5 反讽 治根 (跟 §15.3 联合), 跟 v2.4.0 4 Rule 合并 失焦 反思 联合
- **独立**: 主公 explicit 拍板 累计 (v2.6.0 '同意建议' + v2.7.0 '需要都建卡并行处理' + v2.7.0 '直接启动开工' + v2.7.1 '整理 总结 经验教训' 联合)
- **反哺框架**: KALLAX-GLOSSARY 60+5 术语 + ACCUMULATED-LESSONS 856 行 累计 + PHASE-INDEX 13 PHASE 累计 + 11 PHASE review 闭环, 跟 L0-L4 分层 联合

### 15.6 给下 PHASE (PHASE-017+) 战略建议 (跟"独立" 拍 explicit 联合)

跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合, 跟"翻篇&精进" + "反哺框架" 联合:

- **PHASE-017 候选**: 8 票 (跟 v2.7.0 整理 release 联合): 1. 跟 v2.7.1 29 文件 落地 跟 5 反讽 治根 联合 2. 跟 EPIC-060 3 票 P3 留待 联合 3. 跟外部项目 教训 联合 4. 跟"反哺框架" 战略 一致 5. 跟 ACCUMULATED-LESSONS §15.5 5 战略 联合
- **8 deferred 留待** (跟"独立" 拍 explicit 联合, 主公后续 拍板 留待): P2-1 + P2-2 (跟 PHASE-014 联合) + P3-A + P3-B + P3-C (跟 PHASE-016 联合)
- **后续 借鉴 Phase 2 spike 留待** (跟 v2.7.0 经验教训 §14.8.1 战略建议 联合): 对抗式 Review / 决策 SLA 24h / 角色规则 .md 文档化
- **后续 借鉴 Phase 3 暂不实施** (跟'翻篇&精进' 一致): eket 3 级技术栈 Rust 投入 / Windows PowerShell
- **0 增命令 + 0 增 Rule 持续** (跟'翻篇&精进' 战略 一致, 跟 17 release 累计 联合)

### 15.7 BE 累计 16 → 17 → 18 (跟 v2.7.0 + v2.7.1 联合)

跟 §8 16 BE 联合, 加 BE-17 + BE-18:

- **BE-17**: EPIC-059-A 1st subagent silent output 复发 (跟 BE-9 + BE-14 silent 联合) → 2nd attempt OK 跟"诚实修正" 联合 (跟 v2.4.1 revert 闭环 模式 一致) → 7 票 0 silent 累计
- **BE-18**: 5 反讽 失焦 (跟"反讽" 联合 治根, 跟 v2.7.1 整理 release §15.3 联合) → epic_index.json 同步 + PHASE-INDEX line 47 删 + ROLE-RULES 删 + ADR 引用修复 + 2 改名

### 15.8 经验教训 沉淀 (跟"反哺框架" 战略 一致, 跟 ~/.claude/knowledge/core/patterns/knowledge-system.md L0-L4 联合)

跟"反哺框架" 战略 联合, 跟 EPIC-059-H L0-L4 联合:

- **L0 会话缓存**: 跟 .kallax/state/ 联合 (本 轮 master_main 跟 主公 2026-06-19 4 段 整理 派单 联合)
- **L1 项目经验**: 跟 confluence/decisions/_archive/ 联合 (9 文件 归档 + 11 文件 改名, 跟 EPIC-058 5 deferred 入口 模式 一致)
- **L2 项目知识**: 跟 confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md §15 联合 (本 release 落地)
- **L3 全局模式**: 跟 KALLAX-GLOSSARY §1.1 反讽 联合 (5 反讽 治根 模式)
- **L4 全局知识库**: 跟 ~/.claude/knowledge/core/patterns/knowledge-system.md L0-L4 联合 (跟 EPIC-059-H 联合, 0 复刻)

### 15.9 累计 文件清单 跨 v2.7.0 → v2.7.1 升级 (跟"翻篇&精进" 战略 一致)

跟 §13 累计文件清单 联合, 加 v2.7.1 落地 文件:

**整理 release 闭环 (29 文件, 8 commit, 跟"翻篇&精进" 战略 一致)**:
- jira/tickets/EPIC-053-A/F/ + EPIC-054-A/D/ + EPIC-055-A/C/ + EPIC-056-A/C/ + EPIC-059-A/H/ (24 ticket, status + done_at)
- jira/epics/EPIC-053/054/055/056/059/epic.json (5 epic, status → done)
- docs/PHASE-INDEX.md (-1 line) + docs/ROLE-RULES.md (删) + docs/analysis/ONRAMP-.-2026-06-15.md (改名) + docs/guides/migration-eket-to-kallax.md (改名) + RELEASE.md (cross-ref sync) + docs/superpowers/plans/2026-06-15-onramp-v1.3.3-cleanup.md (cross-ref sync) + jira/tickets/EPIC-057-C/IMPLEMENTATION-PLAN.md (cross-ref sync) (7 文件)
- confluence/decisions/index.md (+3 ADR 注释)
- confluence/decisions/_archive/ (新目录, README.md + 9 归档文件)
- confluence/decisions/ISSUES-INTAKE-14-2026-06-16.md (改名) + GOVERNANCE-CARDS-APPROVAL-5-2026-06-16.md (改名)
- jira/epics/_archived/README.md (新, 29 行)
- jira/phases/phase_index.json (13 phases 同步)
- docs/process/rule-merge-proposal.md + NEW-PROCESS-2026-06-13.md + decision-gate-design.md + COMPLIANCE-DESIGN.md + process-engineering-design.md (5 OUTDATED 标头)
- docs/superpowers/plans/2026-06-09-kallax-3-modes.md + 2026-06-14-kallax-onramp.md + 2026-06-14-onramp-v1.3.1-fix.md + 2026-06-15-kallax-v2.0-alignment.md + 2026-06-16-kallax-v2.0.2-skill-frontmatter.md (5 OUTDATED 标头)
- scripts/hooks/pre-commit (+62 Check 3) + scripts/hooks/pre-push (新, 175 行) + .git/hooks/pre-push (sync) + tests/integration/check-build-artifacts-test.sh (新, 7/7 PASS) (4 hooks/test 文件)
- confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md §15 (本 段) + CHANGELOG.md v2.7.1 entry + package.json v2.7.1 bump (3 总结 文件)

---

**跟 v2.0.3 → v2.7.1 17 release 累计 持平 联合, 跟"翻篇&精进" + "诚实修正" + "反讽" + "独立" + "反哺框架" 5 战略 联合, 跟 22 Rule (v2.4.1 还原 保持) + 60+5 术语 联合, 跟 11 PHASE review 累计 联合, 跟 EPIC-053/054/055/056/057/058/059/060 19 EPIC 累计 联合, 跟 3 deferred 闭环 (P1-1 v2.3.0 + P1-2 v2.4.0 + P3-1 v2.4.1 revert) + 5 deferred 留待 (P2-1 + P2-2 + P3-A + P3-B + P3-C) 联合**
**v2.7.1 落地 跟 0 假 PASS 校验 联合, 跟 Master 6 维 L6 诚实 联合, 跟'诚实修正' 战略 一致, 跟 BE-18 5 反讽 治根 联合**
**总结 8 commit (跟 EPIC-059 1 ticket 1 subagent 串行 模式 一致, 跟 BE-14 联合): 82e4e1e + 0d51e1c + e3910c0 + e173e27 + 6ac763b + f95a229 + 005699b + TBD**
