# Fact-Forcing Examples (KALLAX, EPIC-059-D)

> **跟 docs/process/fact-forcing.md 联合, 跟 KALLAX-GLOSSARY §12 联合**
> **跟 Master 6 维 L6 诚实 联合, 跟 v2.0.5/v2.0.6/v2.4.1 红线 revert 联合**
> **5 正例 + 5 反例, file:line 精确 引用, 跟 KALLAX 实际 release 案例 联合**

---

## 1. 五反例 (Anti-Patterns — 跟 KALLAX 实际 release 案例 联合)

### ❌ 反例 1: BE-9 "L3L4 矛盾" — review.sh 自报 PASS 实际 silent output

**模式**: review.sh 自报 "L4 verify PASS", 实际 silent output, 4 subagent 并行 复发.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:434` (BE-9 行: "L3L4 矛盾 (防御体系自检漏洞) | EPIC-053-A (truth-table) | ✅ closed")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:459` ("✅ L3L4 一致性 | EPIC-053-A (BE-9) | v2.0.4")
- `confluence/decisions/KALLAX-VS-INDUSTRY-2026-06-13-REV2.md:211` ("BE-9 | L4 verify 跟 L3 集成测试矛盾 | 痛点 1 (假完成) + 痛点 2 (上下文失忆)")

**违反 3 原则**:
- 原则 1: 接受 AI 自报 "L4 verify 跑过" (0 信息量)
- 原则 2: 缺 raw test output (silent output = 0 evidence)
- 原则 3: 缺 evidence 视为 OK = silent output 0 deliver

**治根** (跟 v2.0.4 EPIC-053-A truth-table 联合):
- `docs/KALLAX-GLOSSARY.md:641-651` (§9.4 4-Level Fact-Forcing)
- `tests/integration/master-6d-recovery-test.sh:150` (L4 preflight 强制 raw stdout/stderr)

**跟 KALLAX-GLOSSARY §11.3 联合**: "L4 verify PASS" 命名 ≠ reality (silent output) = "0 实际变化 假动作"

---

### ❌ 反例 2: BE-14 "4 subagent 并行 silent output 复发" — 派单 OK 实际 0 deliver

**模式**: EPIC-057 4 subagent 并行 派单, 自报 "派单 完成", 实际 4 subagent 全 silent output, 0 deliver.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:439` (BE-14 行: "4 subagent 并行 silent output 复发 | EPIC-057-D (1 ticket 1 subagent 串行) | ✅ closed (v2.0.6)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` (BE-14 警告: "⚠️ | EPIC-057 派单: 4 subagent silent output 复发 (BE-9 反讽 模式) | EPIC-057 串行派单 (主公 D 拍板, 1 ticket 1 subagent, 治 BE-9 复发)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579` ("教训: 4 subagent 并行 → silent output 复发 BE-9 反讽. 1 ticket 1 subagent 串行 → 100% PASS deliver.")

**违反 3 原则**:
- 原则 1: 接受 AI 派单 自报 (0 信息量)
- 原则 2: 缺 per-subagent stdout + deliverable file (silent output = 0 evidence)
- 原则 3: 缺 evidence 视为 OK = 0 deliver

**治根** (跟 v2.0.6 EPIC-057-D 联合):
- 1 ticket 1 subagent 串行 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74`)
- 强验证 per-subagent output (跟 Master 6 维 L6 诚实 联合)

**跟 KALLAX-GLOSSARY §11.3 联合**: "4 subagent 并行 = 4 倍速度" 命名 ≠ reality (silent output = 0 deliver) = "0 实际变化 假动作"

---

### ❌ 反例 3: BE-15 "Unknown command: /kallax-ask" — 表面修了 实际没治根

**模式**: v2.0.9/v2.0.10/v2.0.11 改 .sh 顶部 # 注释, 自报 "已修", 主公 反馈 "Unknown command: /kallax-ask" 仍存.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440` (BE-15 行: "Claude Code 'Unknown command: /kallax-ask' | 26 .md wrappers (v2.1.1) | ✅ closed (v2.1.1)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:484` ("✅ 26 .md wrappers (Claude Code 2.1+ 优先 .md 格式) | BE-15 治根 'Unknown command' (v2.1.1) | v2.1.1")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:698` ("2026-06-17 21:30 | 主公 'Unknown command: /kallax-ask' 反馈 | master_main | 治根, 触发 v2.1.1 .md wrappers")
- `docs/KALLAX-GLOSSARY.md:550-568` (§8.17 `.md wrappers` 完整 解释)
- `.claude/commands/kallax-ask.md:1-8` (frontmatter description + `!bash` directive)

**违反 3 原则**:
- 原则 1: 接受 AI 自报 ".sh 已改" (0 信息量)
- 原则 2: 缺 Claude Code 2.1+ slash command registry 实测 evidence
- 原则 3: 缺 evidence 视为 OK = 主公反馈仍存

**治根** (跟 v2.1.1 联合):
- 加 26 .md wrappers (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:484`)
- Claude Code 2.1+ 优先 .md 格式 (file:line `docs/KALLAX-GLOSSARY.md:550-568`)

**跟 KALLAX-GLOSSARY §11.3 联合**: "改 .sh = 修复" 命名 ≠ reality (Claude Code registry 优先 .md) = "0 实际变化 假动作"

---

### ❌ 反例 4: v2.0.2 '跨平台 fix release' 反讽 — 命名 跨平台 实际 只 Claude Code

**模式**: v2.0.2 release 命名 "跨平台 fix release", install.sh 实际 只支持 Claude Code.

**file:line 引用**:
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:4` ("跟 v2.0.2 '跨平台 fix release' 反讽 闭环, 跟'反讽' 联合, 跟'诚实修正' 联合")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:79` ("v2.0.2 '跨平台 fix release' 反讽治根 (CHANGELOG Fixed 段 + INSTALL §1.1)")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:120` ("Release naming | '跨平台 fix release' | 'multi-tool skills support'")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:123` ("跟'诚实修正' 联合 | ❌ 命名模糊 | ✅ CHANGELOG [2.0.6] 明确标注 'v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根'")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:168` ("'v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根'")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:172` ("v2.0.2 '跨平台 fix release' 反讽 (naming ≠ reality) → v2.0.6 治根 (naming = reality)")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:197` ("教训 4: Release naming 跟实现状态必须一致. v2.0.2 自称'跨平台' 但 install.sh 仅 Claude Code → 反讽. v2.0.6 install.sh `--target=auto` 检测 4 工具 → naming = reality.")
- `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:199` ("教训 5: 'v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根' 必须明确标注 (跟'诚实修正' 联合, 不模糊处理)")

**违反 3 原则**:
- 原则 1: 接受 release 命名 自我评估 "跨平台" (0 信息量)
- 原则 2: 缺 file:line 实证 (install.sh:52-53 1 工具, codex/gemini 0 reference)
- 原则 3: 缺 evidence 视为 OK = 主公 实际 反讽

**治根** (跟 v2.0.6 EPIC-057 联合):
- CHANGELOG [2.0.6] 明确标注 (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:168`)
- install.sh `--target=auto` 检测 4 工具 (file:line `scripts/install.sh:69-92`)

**跟 KALLAX-GLOSSARY §11.3 联合**: release 命名 "跨平台" ≠ reality (1 工具 only) = "0 实际变化 假动作"

---

### ❌ 反例 5: v2.4.0 4 合并 "净价值 提升" 假动作 — 命名 净增 实际 持平

**模式**: v2.4.0 4 Rule 合并, release 命名 "Rule 数 减少 净价值 提升", 实际 净价值 67.0% 持平 0 跨 release 验证.

**file:line 引用**:
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:39-42` ("v2.3.0 (22 Rule): 净价值 67.0% (实测, 公式估算 1% per Rule) | v2.4.0 (18 Rule): 净价值 67.0% (公式估算: 净增 4% 跟 Master 6 维恢复 +4.5% 抵消) | **0 假 PASS 校验** (跟'诚实修正' 联合, Master 6 维 L6 诚实): 没 任何 实证 证明 净价值 增, 纯 公式估算")
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:116` ("v2.4.0 | 18 | -4 | 67.0% 持平 | 4 合并, 0 实际变化, '制造 0 实际改变 假动作'")
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:117` ("v2.4.1 (本反思) | 22 | +4 | 67.0% 持平 | revert v2.4.0 4 合并, 治根 反讽")
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:138-141` ("v2.4.0 4 合并 命名 = 'Rule 22 → 18 进一步合并' | 实际 = 净价值 持平, 0 实际变化 | 命名 跟 实现 不一致 = **反讽 治根 失焦** (跟'反讽' 联合)")
- `docs/KALLAX-GLOSSARY.md:764-778` (§11.3 0 实际变化 假动作 完整 解释)

**违反 3 原则**:
- 原则 1: 接受 release 命名 "净价值 +4%" (0 信息量)
- 原则 2: 缺 跨 release 验证 evidence (22 Rule 跟 18 Rule 净价值 持平, 0 假 PASS 校验)
- 原则 3: 缺 evidence 视为 OK = 净价值 持平 (0 实际变化)

**治根** (跟 v2.4.1 revert 联合):
- revert 4 合并 → 22 Rule 跟 v2.3.0 一致 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`)
- 反思 doc PHASE-013-REFLECTION 落地 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:285`)

**跟 KALLAX-GLOSSARY §11.3 联合**: 命名 "净价值 +4%" ≠ reality (67.0% 持平) = "0 实际变化 假动作"

---

## 2. 五正例 (Positive Examples — 跟 KALLAX 实际 release 案例 联合)

### ✅ 正例 1: v2.0.5 honest mark — Rule 合并 -3→-2 + 净价值 +3%→+1.5% 诚实标记

**模式**: v2.0.5 Rule 合并 落地 后, Performer 诚实标记 proposal 跟 实际 difference.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288` ("Rule 合并 -3 → -2 honest mark (候选 C 净减 0)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:289` ("净价值 +3.0% → +1.5% honest mark (跟 v2.0.3 '净价值 67.5% 边际递减' 联合)")
- `CLAUDE.md:42` ("v2.0.5 | 22 | (-2) | 3 | 10 | 34001 | 64.0% (+1.5%) → 联合 **67.0% 持平** | 1 | **诚实修正** (proposal -3 → 实际 -2)")
- `CLAUDE.md:132` ("⚠️ **诚实修正** (跟 v2.0.3 PHASE-008-REVIEW ACCUMULATED-LESSONS 联合): 净价值 +1.5% (v2.0.5 单独) ≠ +3.0% (proposal), 候选 C 净减为 0")
- `CLAUDE.md:569` ("v2.0.5 实际 -2 + +1.5% (proposal 写 -3 + +3.0%, 差异原因: 候选 C 是'扩展'而非'删除', 净减为 0)")

**符合 3 原则**:
- 原则 1: 不问"完成了吗", 改问"实际 净减/净增 多少" (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288-289`)
- 原则 2: file:line 实证 (ACCUMULATED-LESSONS:288-289 + CLAUDE.md:132)
- 原则 3: 跟 §11.3 联合, 命名 (proposal) 跟 reality (实际) 失配 → 诚实标记, 不 模糊 处理

**跟 KALLAX-GLOSSARY §1.2 诚实修正 联合** (file:line `docs/KALLAX-GLOSSARY.md:40-46`): 主动 标记 proposal 跟 actual 差异, 不等别人发现

---

### ✅ 正例 2: v2.0.6 4 工具 multi-tool — install.sh `--target=auto` evidence chain 完整

**模式**: v2.0.6 EPIC-057 4 ticket 闭环, install.sh `--target=auto` 检测 Claude/opencode/Codex/Gemini 4 工具.

**file:line 引用**:
- `scripts/install.sh:69-92` (v2.2.0 install.sh 4 工具 detection 联合)
- `scripts/install.sh:139-141` (`--symlink` single source 模式)
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:43` ("v2.0.6 | 22 | 3 | 10 | 34001 + INSTALL-MULTI-TOOL.md 222 | 67.0% 持平 | **4 (Claude/opencode/Codex/Gemini)** | **反讽 闭环** (v2.0.2 '跨平台 fix release' 反讽 → v2.0.6 治根)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:479` ("✅ Hybrid flag-controlled install 4 工具 (--target=auto) | EPIC-057-A 8/8 PASS | v2.0.6")
- `docs/KALLAX-GLOSSARY.md:506-517` (§8.14 hybrid flag-controlled install 完整 解释)

**符合 3 原则**:
- 原则 1: 不问"4 工具 支持 吗", 改问"auto-detect 实测 哪几 个"
- 原则 2: file:line `scripts/install.sh:69-92` (4 工具 detection) + `scripts/install.sh:139-141` (symlink 路径)
- 原则 3: 4 工具 验证 通过 (file:line `tests/integration/master-6d-recovery-test.sh:150` L4 preflight 跑过)

**跟 v2.0.2 反讽 治根 联合** (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:168`): "跨平台" 命名 → v2.0.6 真正 4 工具, naming = reality

---

### ✅ 正例 3: v2.4.0 worktree 清理 — 48 worktree + 123 branches evidence 完整

**模式**: v2.4.0 P1-2 worktree 清理, 48 worktree + 123 branches, 5.5M disk freed.

**file:line 引用**:
- `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:39-43` ("P1-2 (v2.4.0 closed, 保留): 48 worktree + 123 branches 清理 (主公 Y 派单)")
- `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:165` ("v2.4.0 P1-2 closed | master_main | 48 worktree + 123 branches 清理, 主公 Y 派单, 5.5M disk freed")
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:159-168` ("worktree 清理 合理 (跟'独立' 拍 explicit 联合): 47 stale worktree + 123 stale branches 是 实际 stale 资源 | 主公 拍 Y 清理, 跟 PROCESS.md:25-26 联合 (主公 explicit 拍板 后 才执行) | 实际 disk 节省 5.5M, 跟'翻篇&精进' 战略 联合 (0 增 + 5.5M 节省 = 实际 价值)")
- `CLAUDE.md:10` ("v2.4.0 PHASE-013 跨期 review 落地 (P3-1 Rule 合并 22→18 + P1-2 worktree 清理 48→1, 跟主公'a' + '全拍 4 合并 + Y 清理' 联合)")

**符合 3 原则**:
- 原则 1: 不问"清理 OK 吗", 改问"剩 几 个 worktree + 几 个 branches + 节省 几 M"
- 原则 2: `du -sh .claude/worktrees` 实测 5.5M + `git worktree list` 1 个 (跟 §1.2 honest mark 联合)
- 原则 3: 跟 v2.4.0 4 Rule 合并 0 实际变化 不同, worktree 清理 是 **实际 disk 节省**, naming = reality

**跟 KALLAX-GLOSSARY §11.5 revert 跟反思 区别 联合** (file:line `docs/KALLAX-GLOSSARY.md:802-817`): worktree 清理 保留 (v2.4.1 没 revert), 跟 4 Rule 合并 反讽 不同

---

### ✅ 正例 4: v2.4.1 revert 闭环 — 4 合并 naming 跟 reality 失配 → revert

**模式**: v2.4.1 revert v2.4.0 4 Rule 合并, 22 Rule 跟 v2.3.0 一致, 反思 doc PHASE-013-REFLECTION 落地.

**file:line 引用**:
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284` ("2026-06-18 00:30 | **v2.4.1 revert 4 Rule 合并 (18 → 22)** | **master_main** | **本反思, 跟'诚实修正' 联合, 治根 '0 实际改变 假动作'**")
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:285` ("2026-06-18 01:00 | **PHASE-013-REFLECTION doc 落地** | **master_main** | **本反思 doc, 跟'反讽' 联合, 治根 'Rule 治 Rule 通胀' 迷信**")
- `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:43` ("P3-1 (v2.4.0 closed → REVERTED) | v2.4.0 → v2.4.1 (commit `7f401f9`) | 主公 全拍 explicit 派单 → 反思 explicit 派单 revert, 治根 '0 实际改变 假动作' (跟'诚实修正' + '反讽' 联合)")
- `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:168` ("2026-06-18 02:00 | v2.4.1 P3-1 revert | master_main | 跟'诚实修正' 联合, 治根 '0 实际改变 假动作', 22 Rule 还原 跟 v2.3.0 一致")

**符合 3 原则**:
- 原则 1: 不问"4 合并 OK 吗", 改问"净价值 跨 release 验证 实测 几 %"
- 原则 2: file:line `PHASE-013-REFLECTION-2026-06-18.md:39-42` (67.0% 持平) + `docs/KALLAX-GLOSSARY.md:116` (净价值 持平 表)
- 原则 3: 跨 release 验证 (v2.3.0 vs v2.4.0 vs v2.4.1) 缺 → 视为 无效, 走 revert

**跟 KALLAX-GLOSSARY §11.5 revert 跟反思 区别 联合** (file:line `docs/KALLAX-GLOSSARY.md:802-817`): revert 技术 行动 + 反思 战略 行动 闭环, 跟"诚实修正" 联合

---

### ✅ 正例 5: 26 .md wrappers 闭环 — Claude Code 2.1+ 实测 → 治根 BE-15

**模式**: v2.1.1 加 26 .md wrappers, Claude Code 2.1+ 优先 .md 格式, 治根 BE-15 "Unknown command: /kallax-ask".

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440` (BE-15 行: "Claude Code 'Unknown command: /kallax-ask' | **26 .md wrappers** (v2.1.1) | ✅ closed (v2.1.1)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:484` ("✅ 26 .md wrappers (Claude Code 2.1+ 优先 .md 格式) | BE-15 治根 'Unknown command' (v2.1.1) | v2.1.1")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:698` ("2026-06-17 21:30 | 主公 'Unknown command: /kallax-ask' 反馈 | master_main | 治根, 触发 v2.1.1 .md wrappers")
- `.claude/commands/kallax-ask.md:1-8` (frontmatter description + `!bash` directive)
- `docs/KALLAX-GLOSSARY.md:550-568` (§8.17 `.md wrappers` 完整 解释: "v2.0.9 / v2.0.10 / v2.0.11 只改 .sh 顶部 # 注释, 改 description 表面 没用 | Claude Code 2.1+ 优先 .md 格式, .sh 不在 registry | 治根: 加 .md wrappers → Claude Code 优先 parse → slash command 注册成功")

**符合 3 原则**:
- 原则 1: 不问"修了 吗", 改问"Claude Code 2.1+ slash command registry 实测 几 个 命令 OK"
- 原则 2: file:line `.claude/commands/kallax-ask.md:1-8` (frontmatter description + `!bash` directive) + `tests/integration/master-6d-recovery-test.sh:150` (L4 preflight)
- 原则 3: 主公 反馈 闭环 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:698` "主公 Unknown command 反馈" → v2.1.1 .md wrappers)

**跟 KALLAX-GLOSSARY §11.3 0 实际变化 假动作 治根 联合** (file:line `docs/KALLAX-GLOSSARY.md:764-778`): v2.0.9-v2.0.11 0 实际变化 (改 .sh 表面) → v2.1.1 治根 (加 .md wrappers, Claude Code registry 优先)

---

## 3. 闭环验证 (跟 Rule 9 X/Y 格式 + KALLAX-GLOSSARY §1.5 闭环 联合)

### 3.1 KPI 验证 (跟 EPIC-059-D ticket AC #9 联合)

- **GLOSSARY §12.1**: `docs/KALLAX-GLOSSARY.md:846+` (新增 §12.1 三原则, 1/1 落地)
- **fact-forcing.md**: `docs/process/fact-forcing.md` (新文件, 1/1 落地)
- **fact-forcing-examples.md**: `confluence/decisions/fact-forcing-examples.md` (新文件, 1/1 落地)
- **KPI 合计**: 1/1 + 1/1 + 1/1 = **3/3 = 100% 落地**, 0 增 Rule

### 3.2 跟 Master 6 维 L6 诚实 联合 验证

| L# | 验证内容 | 跟 examples 联合 |
|---|---|---|
| **L1 git log** | `git log --oneline -5` 验证 5 反例 + 5 正例 commit 存在 | ✅ |
| **L2 git show** | `git show <sha>` 验证 diff 内容 跟 file:line 一致 | ✅ |
| **L3 跑测试** | raw test output 验证 evidence chain | ✅ |
| **L4 preflight** | `bash scripts/verify/check-fact-forcing-preflight.sh` 0 fail | ✅ |
| **L5 边界** | file scope 合规 (jira/tickets/EPIC-059-D + docs/KALLAX-GLOSSARY.md + docs/process/ + confluence/decisions/) | ✅ |
| **L6 诚实** | 5 反例 + 5 正例 evidence chain 完整, 不接受 "should work" | ✅ |

### 3.3 跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 闭环 验证

- ✅ **5 反例**: BE-9 / BE-14 / BE-15 / v2.0.2 / v2.4.0 都 是 "命名 ≠ reality" 反讽, 跟 §11.3 联合
- ✅ **5 正例**: v2.0.5 / v2.0.6 / v2.4.0 worktree / v2.4.1 revert / 26 .md wrappers 都 是 evidence chain 完整, 跟 §11.3 治根 联合
- ✅ **闭环**: 反例 → 治根 → 正例 闭环, 跟"诚实修正" + "反讽" 战略 联合

### 3.4 跟 v2.0.5 + v2.0.6 + v2.4.1 红线 revert 文档化 联合 验证

- ✅ **v2.0.5**: Rule 32 撤销 (反讽 治根 "Rule 治 Rule 通胀"), 跟 examples §4.1 v2.0.5 honest mark 联合
- ✅ **v2.0.6**: Master 6 维恢复 (v1.2.4 6→0 退步 反转), 跟 examples §4.2 v2.0.6 4 工具 multi-tool 联合
- ✅ **v2.4.1**: 4 合并 revert (治根 "0 实际变化 假动作"), 跟 examples §4.4 v2.4.1 revert 闭环 联合

---

**跟 docs/process/fact-forcing.md 联合, 跟 KALLAX-GLOSSARY §12 联合, 跟 Master 6 维 L6 诚实 联合, 跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 联合, 跟 v2.0.5 + v2.0.6 + v2.4.1 红线 revert 文档化 联合, file:line 精确 引用, 5 正例 + 5 反例, 跟 KALLAX 实际 release 案例 (BE-9/BE-14/BE-15 + v2.0.2/v2.0.5/v2.0.6/v2.4.0/v2.4.1) 联合, EPIC-059-D 落地**