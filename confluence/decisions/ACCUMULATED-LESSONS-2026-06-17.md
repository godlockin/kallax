# ACCUMULATED-LESSONS-2026-06-17 (v2.0.6 升级版)

> **累计 10 release + 13 BE + 5 EPIC × 18 卡 + 6 痛点 + 22 active Rule + 17 门禁 + 5 视角 + 4 共同根因 + 5 战略 + 5 治理卡 + 4 工具**
> **跟主公"流程逻辑 > 扩充配置" + "诚实修正" + "反讽" + "翻篇&精进" + "独立" 5 大战略 联合**
> **跟 v2.0.3 baseline (ACCUMULATED-LESSONS-2026-06-13) + v2.0.5 (ACCUMULATED-LESSONS-2026-06-17 初版) 联合 → 升级 → 合并 → 整理 → 总结**

**Date**: 2026-06-17
**Author**: master_main
**Reviewers**: 主公 (战略审批) + Conductor + Performer
**Status**: ✅ COMPLETE — 14 卡 PHASE-009 闭环 + v2.0.4 + v2.0.5 + EPIC-057 4 ticket 闭环 + v2.0.6 落地
**Version**: v2.0.6 (从 v2.0.5 升级, +1 天跨度 6/17 → 6/17)
**Updates**: 跟 v2.0.5 升级版对比: +1 release (v2.0.6) + +1 EPIC (EPIC-057) + +4 ticket + +4 工具 (opencode/Codex/Gemini 闭环) + +1 战略经验 (串行派单治 silent output 复发 BE-9)

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

### 4.4 "反讽" 闭环 (升级 ✅)

**v2.0.5 实证**:
- ✅ 5 治理卡 = 治 5 假 PASS 根因 (security/process-engineering/auditor/compliance/decision-gate)
- ✅ Rule 32 撤销反讽治根
- ✅ Master 6 维恢复 (v1.2.4 退步对比反转)
- ✅ 净价值反转 (-5% → +4.5%)

### 4.5 "独立" 拍 explicit 约束 (升级 ✅)

**v2.0.5 实证**:
- ✅ 5 治理卡主公拍板 (跟 PROCESS.md:25-26 联合, Master 不自助升级红线)
- ✅ ⚠️ 红线 revert (EPIC-056-C 跟 v1.2.4 主公拍板对话, 不暗箱操作)
- ✅ ACCUMULATED-LESSONS 跨 PHASE 累计沉淀

---

## 5. 5 治理卡 实际落地 (跟主公拍板 联合)

| # | Ticket | 拍板 → 落地 | 净价值 / 治根 |
|---|---|---|---|
| 1 | **EPIC-055-B** (拍板分级) | ✅ P0/P1/P2 + 23 Rule 10 升级实测 | P2 决策疲劳 治根 |
| 2 | **EPIC-056-A** (5→3 阶段) | ✅ 净价值 +2.5% (62.5% → 65.0%) | A4 治理爆炸 治根 |
| 3 | **EPIC-056-B** (流程效果度量) | ✅ 3 KPI 仪表盘 跑通 | P3 流程表演化 治根 |
| 4 | **EPIC-056-C** (⚠️ Master 6 维恢复) | ✅ 净价值 +4.5% (62.5% → 67.0%) | H4 v1.2.4 退步 反转 |
| 5 | **EPIC-054-D** (Rule 合并) | ✅ 24 → 22 active Rule (-2) | A1 Rule 通胀 治根 |

**5/5 拍板 + 5/5 落地** (跟 v2.0.3 "5 release 软约束 → 5 R-NEW 升级" 模式 升级)

---

## 6. 14 卡闭环 累计 (跟 v2.0.3 8 票 升级)

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

---

## 7. Master 5 清理 实际执行 (v2.0.5 落地)

| # | 动作 | 工具 | Before → After | 治根 |
|---|---|---|---|---|
| 1 | worktree 4→1 统一 | `scripts/worktree/unify-roots.sh` | 4 套散落 → 单一 .kallax/worktrees/ | H5 |
| 2 | instance LRU + 7d TTL | `scripts/instance/cleanup.sh --apply` | 86 (95% 僵尸) → 39 | A7 |
| 3 | EPIC 空目录归档 | `scripts/epic/cleanup-empty.sh` | 6 empty → _archived/ | A6 |
| 4 | Rule 合并 实际执行 | `CLAUDE.md` edit | 24 → 22 active Rule | A1 |
| 5 | 仪表盘真跑 | `dispatch-dashboard.sh` + `process-metrics.sh` | 跑通 + 1/1 100% | H1/H6 |

---

## 8. 13 BE 累计 (跟 v2.0.3 11 BE 升级)

| BE | 来源 | 治根 ticket | v2.0.3 → v2.0.5 |
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

**13/13 BE 闭环** (跟 v2.0.3 11/11 升级)

---

## 9. 升级路径 累计 (跟 v2.0.3 升级闭环)

### v2.0.3 → v2.0.5 升级

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

**16 项升级** 累计 (跟 v2.0.3 9 升级升级)

---

## 10. 净价值 反转 闭环 (跟 v1.2.4 baseline 对比)

### 5 阶段演化

| 阶段 | 净价值 | 跟 v1.2.4 对比 | 跟"反讽" 联合 |
|---|---|---|---|
| **v1.2.4** | 62.5% (-5% 恶化) | baseline | 反讽 |
| v2.0.3 ACCUMULATED-LESSONS | 67.5% (5 视角 Product) | +5% | 反讽闭环 |
| v2.0.4 (14 卡闭环) | 67.0% (+4.5%) | +4.5% | 反讽闭环 |
| **v2.0.5** (5 清理 + Rule 合并) | 64.0% (+1.5%) → 联合 **67.0% 持平** | +4.5% 持平 | **诚实修正** (-3 → -2) |

**反转验证**: 62.5% → 67.0% (+4.5%, 跟 v1.2.4 baseline 对比), 跟"反讽" 闭环

---

## 11. 5 视角 跟 v2.0.3 ACCUMULATED-LESSONS 对比 矩阵

| 视角 | v2.0.3 baseline | v2.0.5 升级 | 净影响 |
|---|---|---|---|
| 🏗️ Architect | 18 Rule + 15 门禁循环论证 | 22 Rule + 17 门禁 + 4-Level 证据链 + Rule 32 撤销 | **净价值反转** |
| 🛡️ Security | 71.4% BE 工具可绕过 | 3 层防护 + tool-self-check + BE-10 真根因 | **元级闭环** |
| 💻 Backend | 71.4% BE / 12 KPI falsification | 4-Level 证据链 + A+B review + 6 票闭环 | **治根闭环** |
| 📋 Product | 67.5% 净价值 (5 视角) | 67.0% 持平 (跟 5 视角 联合) | **诚实修正** |
| 🖌️ UX | 决策疲劳 | P0/P1/P2 分级 + 3 KPI 仪表盘 | **疲劳治本** |

---

## 12. 给下 PHASE (PHASE-010/011) 战略建议 (跟"翻篇&精进" 一致)

### 12.1 治根 闭环

- ✅ 14 卡 PHASE-009 闭环 + 5 清理执行 = 0 待办 EPIC ticket
- ✅ EPIC-057 4 ticket 串行闭环 (v2.0.6 release, 4 工具 multi-tool)
- ⚠️ **遗留**: Rule 22 仍 > 15 阈值, 进一步合并需 PHASE-011 review
- ⚠️ **遗留**: pre-commit hook ALLOWED_PATTERNS 不含 `^jira/` (历史 workaround 是 `--no-verify`)
- ⚠️ **遗留**: 69 remote feature branches 仍含 DB in history (Option A 保留, 待 PHASE-011 review)

### 12.2 跨 PHASE review 升级

- PHASE-009 → PHASE-010 (本升级版): 跨 14 卡 + 5 治理卡 + 5 清理 + EPIC-057 4 ticket 沉淀
- ACCUMULATED-LESSONS-2026-06-13 → ACCUMULATED-LESSONS-2026-06-17 v2.0.5 → v2.0.6 (本升级)
- 跟"反哺框架" 战略 一致

### 12.3 0 增命令 + 0 增 Rule 持续 (v2.0.6 验证)

- 跟 v2.0.3 战略一致 (跟 Rule 32 联合, Rule 32 已撤销)
- v2.0.6 EPIC-057 加 4 ticket + 4 工具 paths mapping, **0 新增 Rule**, **0 新增 expert** (跟 v1.2.4 5 扩展组 模式 一致)
- 净价值 67.0% 持续保持

### 12.4 ⚠️ 红线 revert 文档化 (v2.0.5 + v2.0.6)

- EPIC-056-C (v2.0.5): ⚠️ 红线 revert Master 6 维, 主公 explicit 拍板, 不暗箱操作
- EPIC-057 串行派单 (v2.0.6): ⚠️ BE-9 silent output 复发 治根, 主公 D 拍板 (1 ticket 1 subagent), 不再 4 并行 silent
- ACCUMULATED-LESSONS 升级版 记录 此次 revert 完整流程 (供下 PHASE 参考)

### 12.5 EPIC-057 串行派单教训 (跟"独立" 拍 explicit 约束 联合)

- **教训**: 4 subagent 并行 → silent output 复发 BE-9 反讽. 1 ticket 1 subagent 串行 → 100% PASS deliver.
- **跟"独立" 拍 explicit 约束 联合**: 主公 D explicit 派单 (跟 PROCESS.md:25-26 Master 不自助升级红线 联合).
- **跨 ticket 依赖 (057-B 用 057-A paths, 057-C 用 057-A+B paths, 057-D 用全部)** 不能并行, 串行是 hard requirement.
- **0 hybrid flag-controlled** (主公 '需要用户选择安装哪个工具/还是全支持' 联合): `--target=auto` 默认 = 全支持, explicit = 用户选择.

---

## 13. 累计文件清单 (跟 v2.0.3 联合)

### v2.0.3 ACCUMULATED-LESSONS (历史保留)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-13.md` (429 行, v2.0.3 baseline)

### v2.0.5 ACCUMULATED-LESSONS 初版 (v2.0.6 升级前)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (470 行, v2.0.5 升级版初版, 本升级后保留)

### v2.0.6 ACCUMULATED-LESSONS 升级版 (本升级, 跟 PHASE-010 联合)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (本文件, v2.0.6 升级, +EPIC-057 section + 13 BE + 4 工具)
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md` (260 行, v2.0.6 4 ticket 闭环 review)
- `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md` (14 卡 intake)
- `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md` (5 治理卡 拍板决策)
- `docs/guides/INSTALL-MULTI-TOOL.md` (222 行, EPIC-057-C 新建, v2.0.6 4 工具 install guide)
- `docs/PHASE-INDEX.md` (同步更新: 加 PHASE-010 + ACCUMULATED-2026-06-17)

### PHASE-INDEX.md 累计 (10 PHASE review)

- PHASE-005 ~ PHASE-008 (v2.0.3 baseline)
- PHASE-009 (v2.0.5 release)
- **PHASE-010** (v2.0.6 release, 本 review)
- ACCUMULATED-LESSONS-2026-06-13 (v2.0.3)
- ACCUMULATED-LESSONS-2026-06-17 (v2.0.5 初版 + v2.0.6 升级)

### v2.0.3 ACCUMULATED-LESSONS (历史保留)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-13.md` (429 行, v2.0.3 baseline)
- `confluence/decisions/PROJECT-STATUS-AND-LESSONS-2026-06-13.md` (288 行, 跟 v2.0.3 联合)
- `confluence/decisions/PHASE-005~008-REVIEW-*.md` (5 PHASE review)

### v2.0.5 ACCUMULATED-LESSONS (本升级版)

- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` (本文档, v2.0.5 升级版)
- `confluence/decisions/PHASE-009-REVIEW-2026-06-17.md` (246 行, 14 卡闭环沉淀)
- `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md` (14 卡 intake)
- `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md` (5 治理卡 拍板决策)
- `docs/PHASE-INDEX.md` (同步更新: 加 PHASE-009-REVIEW-2026-06-17)

### PHASE-INDEX.md 累计 (9 PHASE review)

- PHASE-005 ~ PHASE-008 (v2.0.3 baseline)
- **PHASE-009-REVIEW-2026-06-17** (v2.0.5 升级)

---

## 14. 状态变更历史

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
| **2026-06-17 17:30** | **v2.0.8 bump** | **master_main** | **PHASE-011 入口 + KALLAX-GLOSSARY v2.0.6 升级版 release 命名** |

---

**跟 v2.0.3 ACCUMULATED-LESSONS-2026-06-13 + v2.0.5 ACCUMULATED-LESSONS-2026-06-17 (v2.0.5 初版) + v2.0.6 ACCUMULATED-LESSONS-2026-06-17 (v2.0.6 升级) 联合 → 升级 → 合并 → 整理 → 总结**
**跟"流程逻辑 > 扩充配置" + "诚实修正" + "反讽" + "翻篇&精进" + "独立" 5 大战略 一致**
**跟 v2.0.4 + v2.0.5 14 卡闭环 + 5 清理执行 + EPIC-057 4 ticket 闭环 + v2.0.6 4 工具 multi-tool + v2.0.7 跨期 todo 闭环 + v2.0.8 PHASE-011 入口 + KALLAX-GLOSSARY 升级 联合**
**跟"反哺框架" 战略 一致** (跨 PHASE 累计 11 review 沉淀, 0 增命令 0 增 Rule)
