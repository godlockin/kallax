# KALLAX 黑话词典 (Glossary)

> KALLAX 术语/概念/黑话的 唯一真相来源 — 跟 CLAUDE.md (Rule SoT) 互链, 跟 Rule 5 DRY 联合

**跟 v1.3.0 release 联合**, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合.

---

## 📖 规则参考 (跟 Rule 5 DRY 联合)

KALLAX 规则 (Rule 1-18 + 29-33) 的唯一真相来源 → [CLAUDE.md](../CLAUDE.md)

- **核心原则**: Rule 1-13 → [CLAUDE.md #核心原则](../CLAUDE.md#核心原则)
- **R-NEW 升级 (Phase 7)**: Rule 14-18 → [CLAUDE.md #角色-session-边界](../CLAUDE.md#角色-session-边界-主公-2026-06-12-拍-r-new-升级红线)
- **v1.2.4 5 扩展组**: Rule 29-33 → [CLAUDE.md #kallax-rules-status-跟-epic-054-d-联合](../CLAUDE.md#kallax-rules-status-跟-epic-054-d-联合)
- **Rule 合并 proposal** (跟 EPIC-054-D 联合): [docs/process/rule-merge-proposal.md](process/rule-merge-proposal.md)

---

## 0. 怎么用这份词典

- **查**: 找术语 → 看 "大白话" + "来源" + "rule 引用"
- **追**: 看 rule 引用 → 跳到 CLAUDE.md 对应 Rule 章节
- **加**: 写新黑话前, 先看是否已有相近 — 跟"流程逻辑 > 扩充配置" 战略 一致

---

## 1. 元术语 (Meta — 描述 KALLAX 自身行为)

### 1.1 「反讽」闭环 (Irony Loop)

**大白话**: "治病的药, 自己就是病的一部分" — 治 root cause 的方案, 自身是 root cause 的受害者.

**来源**: v1.2.4 累计 5 release + 14 BE + 10 KPI falsification + 5 战略建议.

**Rule 引用**: Rule 10 (Anti-Fabrication), Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md)

---

### 1.2 「诚实修正」模式 (Honest Correction)

**大白话**: "看到反讽不装看不见, 主动标记问题, 不等别人发现."

**来源**: 主公 2026-06-13 原话.

**Rule 引用**: Rule 11 (Master 强验证 6 维度) — [CLAUDE.md](../CLAUDE.md)

---

### 1.3 「独立」拍 explicit 约束 联合 (Independence as Hard Constraint)

**大白话**: "你说'独立', 我就当独立 — 不只是嘴上说, 5 维度全独立 (session/角色/路径/报告/审计)."

**来源**: 主公 2026-06-13 多次强调.

**Rule 引用**: Rule 14 (Conductor 不能越界), Rule 15 (Performer Session 自动加载) — [CLAUDE.md](../CLAUDE.md)

---

### 1.4 「explicit 约束 联合」格式 (Explicit Constraint Format)

**大白话**: "X explicit 约束 联合" = "X 是 explicit 拍, 跟 Y 联合使用" — 追溯链格式.

**来源**: Rule 11 (Master 写代码禁令) 标识要求.

**Rule 引用**: Rule 31 (独立见证机制 — audit log) — [CLAUDE.md](../CLAUDE.md)

---

### 1.5 「闭环」(Closed Loop)

**大白话**: "从一个症状 → 治 root cause → 不再发生" 完整链路.

**Rule 引用**: Rule 6 (经验沉淀), Rule 7 (PHASE 闭环 review), Rule 16 (Subagent 5 步强制流程) — [CLAUDE.md](../CLAUDE.md)

---

### 1.6 「联合」(Joint / Coupled)

**大白话**: "A 跟 B 联合" = "A 的实现 / 决策 跟 B 模式一致 / 引用 / 复用 / 联合落地".

**作用**: 避免重复造轮子 (跟 Rule 5 DRY 联合), 跨 PR / 跨 release 引用一致.

---

## 2. 战略 / 方向术语 (Strategy)

### 2.1 「流程逻辑 > 扩充配置」战略 (Process Logic > Configuration Expansion)

**大白话**: "别再加配置了, 改流程逻辑".

**来源**: 主公 2026-06-13 战略转向.

**Rule 引用**: Rule 32 (软约束升级阈值) — [CLAUDE.md](../CLAUDE.md)

---

### 2.2 「反哺框架」战略 (Framework Feedback Loop)

**大白话**: "KALLAX 用 KALLAX 自身来改进" — 飞轮反哺.

**落地**: v1.1.0 → v1.3.0 累计 9 release 落地都用 KALLAX 流程.

**Rule 引用**: [CLAUDE.md #6-经验沉淀强制化](../CLAUDE.md#6-经验沉淀强制化-kallax-p0--epic-交付四件套).

---

### 2.3 「翻篇&精进」战略 (Move On & Refine)

**大白话**: "已经发生的别纠结, 往前看怎么改" — 不在历史 BE / 失败上反复.

**落地**: 14 BE → ACCUMULATED-LESSONS-2026-06-13.md (沉淀, 不反复); 10 KPI falsification → Rule 9 9a/9b/9c 硬限制.

---

## 3. 流程 / 工作流术语 (Workflow)

### 3.1 「对策 A+B+C」(Countermeasure A+B+C)

**大白话**: "Subagent 自验证 + Conductor 接收验证 + Master 强验证" — 3 层防御.

**Rule 引用**: Rule 10 (Anti-Fabrication), Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md)

---

### 3.2 「Master 强验证 6 维度」/ 「强验证 6 维度」(Master 6-Dimension Strong Verification)

**大白话**: "Master 验证 subagent 报 PASS 时, 6 维度全 PASS 才放行".

**来源**: Rule 11 v2.1.

**落地**: L1 git log / L2 git show / L3 E2E / L4 amend-verify / L5 边界 / L6 诚实 (反模式黑名单).

---

### 3.3 「4-Level Fact-Forcing」/ 「4 级验证」(4-Level Fact-Forcing)

**大白话**: "验证必须 4 级都过: 存在 → 实质 → 接线 → 数据流".

**Rule 引用**: Rule 9 (4-Level Fact-Forcing 强制) — [CLAUDE.md](../CLAUDE.md)

**3 anti-fab 子工具**: Rule 9a/9b/9c (KPI 估数 / verbatim / scope creep).

---

### 3.4 「5 步强制流程」/ 「5 步串联」(Subagent 5-Step Mandatory Workflow)

**大白话**: "Subagent 完工必触发 5 步: ticket 同步 → 3 anti-fab → preflight → review → 强验证".

**Rule 引用**: Rule 16 (Subagent 5 步强制流程) — [CLAUDE.md](../CLAUDE.md)

---

### 3.5 「飞轮反哺」(Flywheel Feedback)

**大白话**: "每 release 都沉淀 + 升级, 下个 release 站在上 release 肩上".

**落地**: v1.1.0 → 4 文档 REV2, v1.2.0 → Token Plan, v1.2.3 → 5 测试 + Rule 19, v1.2.4 → 5 扩展组, v1.3.0 → KALLAX Onramp + 0 Rule 增加.

---

## 4. 反模式 / 黑名单术语 (Anti-Patterns / Blacklist)

### 4.1 「KPI falsification」/ 「估数算 FAIL」(KPI Falsification Blacklist)

**大白话**: "subagent 报 PASS 时 KPI 估数/模糊, 算 FAIL".

**Rule 引用**: Rule 9a (KPI 估数算 FAIL), Rule 18 (#1) — [CLAUDE.md](../CLAUDE.md)

---

### 4.2 「Test case verbatim 触发 = FAIL」(Test Case Isolation Blacklist)

**大白话**: "把测试需求整句塞 trigger 字段 = 100% circular match, 假数据".

**Rule 引用**: Rule 9b (verbatim), Rule 18 (#2) — [CLAUDE.md](../CLAUDE.md)

---

### 4.3 「Scope creep 必拆 PR」(Scope Creep Blacklist)

**大白话**: "file_scope.includes 外的文件改动 = scope creep, 必拆 PR".

**Rule 引用**: Rule 9c (scope creep), Rule 18 (#3) — [CLAUDE.md](../CLAUDE.md)

---

### 4.4 「越界反向」(Cross-Boundary Violation Reverse)

**大白话**: "subagent 不写 worktree 反而写主 checkout".

**Rule 引用**: Rule 14, Rule 15 — [CLAUDE.md](../CLAUDE.md)

---

### 4.5 「3 假 PASS 模式」(3 Fake PASS Patterns)

**大白话**: "subagent 报 PASS 实际 0 commit / 估数 / 借口环境问题".

**Rule 引用**: Rule 18 #6/#7/#8 — [CLAUDE.md](../CLAUDE.md)

---

## 5. 经验教训类术语 (Lessons Learned)

### 5.1 「BE」(Bad Event / 教训编号)

**大白话**: "KALLAX 历史失败事件编号" — 累计 15 BE (BE-1 ~ BE-15).

**来源**: PHASE-008-REVIEW-2026-06-13.md + ACCUMULATED-LESSONS-2026-06-13.md.

**累计**: BE-1 ~ BE-14 (8 试反复 + 10 KPI falsification + Token 限撞墙 + 越界反向), BE-15 (3 假 PASS).

---

### 5.2 「14 subagent 21.4% 瞒报率」(14 Subagent 21.4% Concealment Rate)

**大白话**: "KALLAX 累计 14 subagent 派单, 21.4% 瞒报率".

**Rule 引用**: Rule 29 + Rule 30 + Rule 31 — [CLAUDE.md](../CLAUDE.md)

---

### 5.3 「6 release 累计」(6 Releases Cumulative)

**大白话**: "KALLAX 累计 6 release (含 3 rc + 3 stable) — 每次 release 都是反哺".

**累计**: v1.0.0-rc1/2/3, v1.1.0, v1.2.0/2.1/2.3/2.4, v1.3.0 = 9 累计.

---

## 6. 角色 / 决策术语 (Roles / Decisions)

### 6.1 「3 模式」(3 Modes: ai-auto / ai-copilot / manual)

**大白话**: "KALLAX 决策权分配 3 模式".

**Rule 引用**: Rule 13 (3 模式决策权分配) — [CLAUDE.md](../CLAUDE.md)

---

### 6.2 「Conductor 不能越界 Performer 实施」(Conductor Cannot Cross Performer Boundary)

**大白话**: "Conductor session 不能 Edit/Write/Commit 代码".

**Rule 引用**: Rule 14 (Conductor 不能越界) — [CLAUDE.md](../CLAUDE.md)

---

### 6.3 「Master 接管」(Master Takeover)

**大白话**: "默认 Master 禁写代码, 极端情况主公拍'接管'才接管".

**Rule 引用**: Rule 11 (Master 写代码禁令) — [CLAUDE.md](../CLAUDE.md)

---

### 6.4 「Performer sub-role」/ 「subagent 第一条」(Performer Sub-Role + Worktree First)

**大白话**: "Performer session 必独立 sub-role + 第一时间建 worktree".

**Rule 引用**: Rule 15 (Performer Session 自动加载) — [CLAUDE.md](../CLAUDE.md)

---

## 7. 量化 / 指标术语 (Metrics)

### 7.1 「18 Rule 升级率 100%」(18 Rule Upgrade Rate 100%)

**大白话**: "KALLAX 累计 18 Rule, 全部从软约束升 R-NEW 升级" — 治标不治本.

**Rule 引用**: Rule 32 (软约束升级阈值) — [CLAUDE.md](../CLAUDE.md)

---

### 7.2 「净价值 85.5% - 23 Rule = 62.5%」(Net Value 85.5% - 23 Rule = 62.5%)

**大白话**: "KALLAX 体系净价值 = 85.5% 价值 - 23 Rule 复杂度 = 62.5% 净".

**Rule 引用**: Rule 32 — [CLAUDE.md](../CLAUDE.md)

---

### 7.3 「1+2/1+4 容量」(1+2/1+4 Capacity)

**大白话**: "1 Conductor 派 2-4 Performer 并行" — 治"1 主 session 串场太慢".

**来源**: EPIC-038-B 4 类 Performer 实例 + 1+4 容量.

---

## 8. 落地 / 工程术语 (Engineering)

### 8.1 「Skill 文档」(Skill Documentation)

**大白话**: "KALLAX 专家能力的可复用文档" — 累计 10 个 (5 default + 5 extended).

**Rule 引用**: Rule 5 (类型安全强制化, DRY) — [CLAUDE.md](../CLAUDE.md)

---

### 8.2 「worktree 隔离」(Worktree Isolation)

**大白话**: "Performer 必须在独立 worktree 写代码".

**Rule 引用**: Rule 15 (Performer Session 自动加载) — [CLAUDE.md](../CLAUDE.md)

---

### 8.3 「atomic write」/ 「atomic mv」(Atomic Write Pattern)

**大白话**: "写文件用临时文件 + atomic mv, 不留半截".

**Rule 引用**: Rule 17 (文件并发竞争 5 步强制流程) — [CLAUDE.md](../CLAUDE.md)

---

### 8.4 「file-lock」/ 「flock」(File Lock Pattern)

**大白话**: "写文件前必获取文件锁 (flock), 锁竞争时 STOP + 报错".

**Rule 引用**: Rule 17 (文件并发竞争 5 步) — [CLAUDE.md](../CLAUDE.md)

---

### 8.5 「BE-7 修复模式」(BE-7 Fix Mode)

**大白话**: "BE-7 file-lock 漏洞的修复模式" — umask 077 + install -d -m 700 + flock + atomic write + chmod 600.

**Rule 引用**: Rule 29 + Rule 31 — [CLAUDE.md](../CLAUDE.md)

---

### 8.6 「4 工具」multi-tool skills (Four-Tool Skills Support)

**大白话**: "KALLAX 不绑死 Claude Code — 4 工具平起平坐: Claude Code / opencode / Codex / Gemini, install.sh 加 `--target=auto` 默认全支持, 单一 SoT (`docs/guides/INSTALL-MULTI-TOOL.md`)".

**来源**: 主公 2026-06-17 'B' explicit 拍板 (跟 v2.0.2 '跨平台 fix release' 反讽 联合), 跟 EPIC-057 4 ticket 闭环 联合, 跟"独立" 拍 explicit 约束 联合.

**4 工具 CLI invocation 实测** (跟 EPIC-057-D integration tests 联合, file:line `tests/integration/multi-tool-e2e-test.sh:1-180`):

| 工具 | CLI 命令 | 二进制验证 | 默认 settings |
|---|---|---|---|
| Claude Code | `claude --print "<query>"` | v2.1.153 (实测 PASS) | `~/.claude/settings.json` |
| opencode | `opencode run "<query>"` | v1.17.7 (实测 PASS) | `~/.opencode/config.json` |
| Codex | `codex exec "<query>"` (fallback) | binary missing (待装) | `~/.codex/config.toml` |
| Gemini | `gemini [query..]` (positional) | v0.22.2 (实测 PASS) | `~/.gemini/config/settings.json` |

**Rule 引用**: Rule 5 (DRY) — [CLAUDE.md](../CLAUDE.md), 跟"反讽" 联合 (v2.0.2 命名 vs 实现 反讽 治根).

---

### 8.7 「skills/commands paths」4 工具 路径映射 (Skills/Commands Path Mapping)

**大白话**: "4 工具的 skills/commands dir 名字不一样 — KALLAX install.sh 硬编码映射表, 一次配置, 4 工具生效".

**4 工具路径映射表** (跟 EPIC-057-A install.sh 联合, file:line `scripts/install.sh:64-90`):

| 工具 | Skills 路径 | Commands/Slash/Prompts 路径 | 命名反讽 |
|---|---|---|---|
| Claude Code | `~/.claude/skills/kallax/` | `~/.claude/commands/` | 标准命名 |
| opencode | `~/.opencode/skills/kallax/` | `~/.opencode/command/` ⚠️ | **commands 是 singular** (反讽!) |
| Codex | `~/.codex/skills/kallax/` | `~/.codex/prompts/` | 叫 prompts 不叫 commands |
| Gemini | `~/.gemini/skills/kallax/` | `~/.gemini/commands/` | 标准命名 |

**反讽治根**: opencode 用 `command/` (singular) 跟 Claude/Gemini `commands/` (plural) 不一致 — install.sh 必须 explicit 映射, 不能假设统一.

**Rule 引用**: Rule 5 (DRY) + Rule 15 (Performer 隔离) — [CLAUDE.md](../CLAUDE.md), 跟 v2.0.2 '跨平台 fix' 实际只 1 工具 反讽 治根 联合.

---

### 8.8 「hybrid flag-controlled install」(混合标志位控制安装)

**大白话**: "主公 '需要用户选择安装哪个工具/还是全支持' explicit 派单 → install.sh 加 `--target=auto|all|<tool>|a,b|--interactive` 5 模式, 默认 auto-detect = 全支持".

**5 flag 模式** (跟 EPIC-057-A install.sh 联合, file:line `scripts/install.sh:11-30`):

| Flag | 行为 | 适用场景 |
|---|---|---|
| `--target=auto` ⚠️ 默认 | auto-detect $HOME/.<tool>/ + which CLI (claude > opencode > codex > gemini 优先级) | 默认, 全支持 |
| `--target=all` | 强制全装 4 工具 | 演示 / sandbox / CI |
| `--target=claude\|opencode\|codex\|gemini` | 单工具 explicit | 用户 specific 选 |
| `--target=claude,opencode` | 多工具逗号分隔 | 用户混合选 |
| `--interactive` | 弹 prompt 问用户 | 第一次 install / 教学 |

**跟"独立" 拍 explicit 约束 联合**: 5 flag 都是 explicit 选项, 不假设; 默认 `auto` = 全支持 (跟"反讽" 联合, 不隐式).

**Rule 引用**: Rule 5 (DRY) + Rule 16 (Subagent 5 步) — [CLAUDE.md](../CLAUDE.md), 跟 Rule 11 (Master 6 维度验证) 联合.

---

### 8.9 「--target=auto」默认行为 (Auto-Detect Default Behavior)

**大白话**: "install.sh 默认 auto-detect — 探测 $HOME/.<tool>/ 目录 + which CLI binary, 按 claude > opencode > codex > gemini 优先级 装最匹配的 1 工具 (或全装 if all detected)".

**auto-detect 优先级** (跟 EPIC-057-A install.sh 联合, file:line `scripts/install.sh:36-58`):
1. **claude** (Claude Code) — 最高优先级 (KALLAX 原生)
2. **opencode** — 次之 (跟 v1.2.4 起就有 mirror)
3. **codex** — 之后
4. **gemini** — 最低

**detection 双通道** (跟 EPIC-057-B onramp.sh 联合, file:line `scripts/kallax-onramp/lib/tool-detect.sh:1-80`):
- **通道 1**: `test -d "$HOME/.<tool>/"` (用户 settings dir 存在)
- **通道 2**: `which <cli>` (CLI binary 在 PATH)

**Rule 引用**: Rule 15 (Performer Session) + Rule 5 (DRY) — [CLAUDE.md](../CLAUDE.md).

---

### 8.10 「v2.0.2 '跨平台 fix release'」反讽治根 (V2.0.2 Irony Root Cause)

**大白话**: "v2.0.2 release notes 自称'跨平台 fix release' (加 frontmatter + 31 slash command mirror 到 `.opencode/command/`), 实际只支持 Claude Code — 命名跟实现 不一致 (反讽)".

**反讽证据链** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟 v2.0.6 治根 联合):

| 维度 | v2.0.2 实际 | 命名声称 | 反讽 |
|---|---|---|---|
| 安装路径 | `~/.claude/` 硬编码 (file:line `scripts/install.sh:52-53`) | "跨平台" | ⚠️ 1 工具 ≠ 跨平台 |
| frontmatter + 31 slash command | mirror 到 `~/.opencode/command/` | "fix release" | ⚠️ 1 个 mirror ≠ 全装 |
| codex/gemini 支持 | 0 reference (file:line `jira/epics/EPIC-057/epic.json:11-12`) | "fix release" | ⚠️ 0 支持 ≠ 修复 |

**v2.0.6 治根** (跟 EPIC-057 4 ticket 闭环 联合, file:line `CHANGELOG.md:8-69` + `docs/guides/INSTALL-MULTI-TOOL.md:§1.1`):
- install.sh 加 `--target=auto` + 4 工具 skills/commands 路径映射 (Section 8.7 联合)
- kallax-onramp.sh 加 tool detection + 4 工具 dispatch (EPIC-057-B 联合)
- INSTALL-MULTI-TOOL.md 新建 (~200 行, 反讽治根说明段 完整)
- integration tests 18/18 PASS (8 install + 6 onramp + 4 e2e, 跟 EPIC-057-D 联合)

**Rule 引用**: Rule 10 (Anti-Fabrication) + Rule 18 (KPI Falsification 黑名单) + Rule 11 (Master 6 维度) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" 联合 (看到反讽不装看不见, 主动标记).

---

### 8.11 「Trae」ByteDance AI IDE (Trae Skills Support)

**大白话**: "Trae 是 ByteDance 推出的 AI IDE (类似 VS Code + AI 集成), 用 `~/.trae/skills/kallax/` (skill bundle 格式) + `~/.trae/commands/` (slash commands 格式) 双路径".

**特点** (跟 KALLAX-GLOSSARY §8.6 multi-tool 联合):
- Skill bundle 格式: `~/.trae/skills/<name>/SKILL.md` (跟 trae builtin_skills 模式 一致, file:line `~/.trae/builtin_skills/TRAE-generate-mini-app/SKILL.md:1-15`)
- Slash commands: `~/.trae/commands/kallax-*.sh` (跟 Claude Code 一致 模式)

**v2.2.0 install** (跟主公"claude code、trae、antigravity、opencode 正常调用" 派单 联合, file:line `scripts/install.sh:69-92`):
- `--target=trae` 显式装 / `--target=all` 全装
- `--symlink` single source 模式: `~/.trae/skills/kallax` + `~/.trae/commands` 都是 symlink → `~/.local/share/kallax/`

**Rule 引用**: Rule 5 (DRY) + Rule 15 (Performer 隔离) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

### 8.12 「Antigravity」Google AI IDE (Antigravity Skills Support)

**大白话**: "Antigravity 是 Google 推出的 AI IDE, 用 `~/.antigravity/skills/kallax/` + `~/.antigravity/commands/` 双路径 (跟 Trae 模式 一致, 跟 Claude Code 也兼容)".

**特点** (跟 Trae 类似, 跟 KALLAX-GLOSSARY §8.6 multi-tool 联合):
- Skill bundle 格式: `~/.antigravity/skills/<name>/SKILL.md` (跟 antigravity builtin skills 模式 一致, file:line `~/.antigravity/skills/test-driven-development/SKILL.md:1-7`)
- Slash commands: `~/.antigravity/commands/kallax-*.sh`

**v2.2.0 install** (跟 Trae 同步, 跟主公"claude code、trae、antigravity、opencode 正常调用" 派单 联合, file:line `scripts/install.sh:69-92`):
- `--target=antigravity` 显式装
- `--symlink` single source 模式: `~/.antigravity/skills/kallax` + `~/.antigravity/commands` 都是 symlink → `~/.local/share/kallax/`

**Rule 引用**: Rule 5 (DRY) + Rule 15 (Performer 隔离) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

### 8.13 「Single Source」Symlink 模式 (Single Source Symlink Mode)

**大白话**: "KALLAX canonical 源在 `~/.local/share/kallax/`, 4+ 工具 user-level 路径都 symlink 引用 — 改 1 次, 4 工具立即生效".

**原理图** (跟主公"用一份skills/命令文件支持所有的引用" 显式需求 联合, file:line `docs/guides/INSTALL-MULTI-TOOL.md:§4.1`):
```
~/.local/share/kallax/                (canonical, 1 份源, real)
├── skills/kallax/                     (14 files)
└── commands/                          (56 files: 27 .sh + 27 .md + lib + heartbeat)

        ↓ symlinks ↓

~/.claude/{skills/kallax,commands}         ─┐
~/.trae/{skills/kallax,commands}            │
~/.antigravity/{skills/kallax,commands}     │  4+ 工具
~/.opencode/{skills/kallax,command}         │  共享 1 份源
... (10 工具 user-level paths)             ─┘
```

**优势** (跟"翻篇&精进" 联合):
- ✅ **一份文件** — 4 工具共享 1 份源, 不重复
- ✅ **更新一次, 4 工具同时获更新** — 改 canonical, 4 工具立即生效
- ✅ **省 disk** — 4 工具不再 4 份副本, 1 份源 (canonical ~30KB 共享)
- ✅ **一致性** — 4 工具版本永远一致 (symlink 强制, 不可能漂移)
- ✅ **copy 模式保留** — `--copy` 跟 v2.1.x 兼容, 不破坏现有 install

**用法** (跟 v2.2.0 install.sh 联合, file:line `scripts/install.sh:181-186`):
```bash
# 4 工具 single source 模式 (跟主公派单 一致, 推荐)
./scripts/install.sh --symlink --target=claude,trae,antigravity,opencode

# 10 工具 single source 模式
./scripts/install.sh --symlink --target=all

# 默认 copy 模式 (跟 v2.1.x 兼容)
./scripts/install.sh --target=claude
```

**Rule 引用**: Rule 5 (DRY) + Rule 16 (Subagent 5 步) + Rule 32 (软约束升级阈值) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" + "诚实修正" 战略 一致.

---

### 8.14 「hybrid flag-controlled install」(混合标志位控制安装)

**大白话**: "install.sh 5 flag 模式 `--target=auto|all|<tool>|a,b|--interactive` — 默认 auto-detect = 全支持, explicit = 用户选择, 跟 v2.0.6 EPIC-057-A 联合 (file:line `jira/tickets/EPIC-057-A/ticket.json:23-31`)".

**5 flag 模式** (跟 v2.0.6 hybrid flag-controlled 联合):
- `--target=auto` ⚠️ 默认: auto-detect $HOME/.<tool>/ + which CLI (claude > opencode > codex > gemini 优先级)
- `--target=all`: 强制全装 4 工具
- `--target=claude|opencode|codex|gemini`: 单工具 explicit
- `--target=a,b,c`: 多工具逗号分隔
- `--interactive`: 弹 prompt 问用户 (跟 v2.0.6 联合, v2.1.0 wizard 模式 替代)

**Rule 引用**: Rule 5 (DRY) + Rule 16 (Subagent 5 步) + Rule 11 (Master 6 维度) — [CLAUDE.md](../CLAUDE.md), 跟"独立" 拍 explicit 约束 联合.

---

### 8.15 「wizard 5-step」引导安装 (Guided Wizard Installation)

**大白话**: "install.sh `--wizard` 5-step 引导: detect → select → path → diff → confirm, 每步有合理默认, 直接按 Enter 接受 (跟 v2.1.0 EPIC-057 + 主公'D' 拍板 联合)".

**5 step 流程** (跟"诚实修正" 联合, 治 install 黑盒):
1. **Step 1/5** — Tool detection (8 工具 ✓/✗ 状态)
2. **Step 2/5** — Select targets (detected / all / custom)
3. **Step 3/5** — Install paths (默认 accept)
4. **Step 4/5** — Upgrade diff preview (旧版 → 新版)
5. **Step 5/5** — Dry-run preview + final confirm (Y 接受)

**Rule 引用**: Rule 9 (X/Y 格式) + Rule 6 (经验沉淀) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

### 8.16 「dry-run mode」模拟运行 (Dry-Run Simulation Mode)

**大白话**: "install.sh `--dry-run` 模拟运行, 不实际安装, 退出前打印 'Dry-run complete. No files were installed.' — 适合 CI/automation 试运行 + wizard 流程测试 (跟 v2.1.0 主公'D' 拍板 联合)".

**用法** (跟 v2.1.0 install.sh:147-148 联合):
- `--dry-run` 默认 TARGET_MODE=auto 检测
- `--dry-run --target=claude` 显式单工具
- `--dry-run --wizard` 完整 5-step 模拟 (stdin 喂默认 接受)
- `--dry-run --symlink` 4 工具 single source 模拟 (v2.2.0 联合)

**Rule 引用**: Rule 11 (Master 6 维度) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" 联合 (不假装安装, 主动让用户确认).

---

### 8.17 「`.md wrappers`」Claude Code 2.1+ 兼容 (.md Wrappers for Slash Command Registry)

**大白话**: "Claude Code 2.1+ slash command registry 优先发现 `.md` 格式 (跟 `heartbeat-conductor.md` 验证 一致), 26 .sh 命令各配对一个 `.md` wrapper, .md 格式 frontmatter description + `!bash` directive 调用 .sh".

**.md 格式** (跟 v2.1.1 fix 联合, file:line `.claude/commands/kallax-ask.md:1-8`):
```markdown
---
description: /kallax-ask — Ask a question to the expert panel.
---

!bash "$(dirname "$0")/kallax-ask.sh" $ARGUMENTS
```

**根因** (跟"诚实修正" 联合, 治 v2.1.0 之前 'Unknown command' 治根):
- v2.0.9 / v2.0.10 / v2.0.11 只改 .sh 顶部 # 注释, 改 description 表面 没用
- Claude Code 2.1+ 优先 .md 格式, .sh 不在 registry
- 治根: 加 .md wrappers → Claude Code 优先 parse → slash command 注册成功

**Rule 引用**: Rule 10 (Anti-Fabrication) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"反讽" 联合 (v2.0.2 命名"跨平台" 实际 "Claude Code only" 反讽, v2.1.1 治根).

---

### 8.18 「canonical symlink」Single Source 模式 (Single Source Symlink Mode)

**大白话**: "KALLAX canonical 源在 `~/.local/share/kallax/`, 4+ 工具 user-level 路径都 symlink 引用 — 改 1 次, 4 工具立即生效 (跟 v2.2.0 主公 explicit 派单 联合, file:line `scripts/install.sh:139-141`)".

**原理图** (跟 KALLAX-GLOSSARY §8.11-8.12 trae/antigravity + §8.13 single source 联合):
```
~/.local/share/kallax/                (canonical, 1 份源, real)
├── skills/kallax/                     (14 files)
└── commands/                          (56 files)

        ↓ symlinks ↓

~/.claude/{skills/kallax,commands}         ─┐
~/.trae/{skills/kallax,commands}            │  4+ 工具
~/.antigravity/{skills/kallax,commands}     │  共享 1 份源
~/.opencode/{skills/kallax,command}         ─┘
```

**Rule 引用**: Rule 5 (DRY) + Rule 16 (Subagent 5 步) + Rule 32 (软约束升级阈值) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

## 9. 治理术语 (Governance — 跨 release 复用策略 + 验证 流程)

---

### 9.1 「rebase vs cherry-pick」策略 (Rebase vs Cherry-Pick Strategy)

**大白话**: "跨期 commit 复用时, rebase 适合线性历史 (跟 v2.0.5 Rule 合并 模式 一致), cherry-pick 适合选择性复用 (跟 v2.0.6 EPIC-057 跨 PR 复用 模式 一致, file:line `docs/KALLAX-GLOSSARY.md:30-36`)".

**2 策略对比**:
- **rebase** (线性历史): `git rebase testing`, 把当前分支 commits 重放到目标分支 tip, 适合 1 PR 内 fix, 历史干净
- **cherry-pick** (选择性): `git cherry-pick <sha>`, 选择 1 个或几个 commit 复用, 适合跨 PR 复用 (跟"翻篇&精进" 联合)

**Rule 引用**: Rule 6 (经验沉淀) + Rule 16 (Subagent 5 步) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

### 9.2 「Saga 5-step」Pipeline (Saga Five-Step Pipeline)

**大白话**: "`tests → lint → verify → commit → PR` 5 步, 跟 EPIC-022-B + v2.0.6 EPIC-057-D 联合, 跟'诚实修正' 联合 (任一步失败 halt, 开发者 fix 重新)".

**5 步** (跟 v2.0.6 /kallax-submit-pr 联合):
1. `npm test` (或 language-equivalent) — unit tests
2. `npm run lint` (或 equivalent) — lint check
3. `bash scripts/verify/check-test-case-isolation.sh` — anti-fab
4. `git add -A && git commit` — structured message
5. `gh pr create --base testing` — PR opens for Conductor review

**Rule 引用**: Rule 9 (X/Y 格式) + Rule 16 (Subagent 5 步) + Rule 11 (Master 强验证) — [CLAUDE.md](../CLAUDE.md).

---

### 9.3 「Master 6 维度验证」(Master Six-Dimension Verification)

**大白话**: "Master 强验证 6 维度, 跟 v1.2.4 联合, 跟 Rule 11 (Master 写代码禁令) 联合 — L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实".

**6 维度** (跟 KALLAX-GLOSSARY §1.2 诚实修正 + §1.1 反讽 联合):
- **L1 git log**: 看 commit history
- **L2 git show**: 看具体 commit diff
- **L3 跑测试**: 验证代码 work
- **L4 preflight**: 验证 anti-fab 工具通过
- **L5 边界**: 验证 file scope / worktree 隔离
- **L6 诚实**: 验证 raw test output, 不接受 "should work"

**Rule 引用**: Rule 11 (Master 写代码禁令) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" 战略 一致 (L6 命名 = reality).

---

### 9.4 「4-Level Fact-Forcing」(Four-Level Fact-Forcing Verification)

**大白话**: "Conductor review PR 时 4-Level 检查: L1 existence (files in diff) / L2 substance (no TODO) / L3 wiring (no @ts-ignore/:any) / L4 data flow (CI green), 跟 v2.0.6 EPIC-057-D review 联合, 跟 H1 KPI falsification 治根 联合".

**4 级别** (跟 /kallax-verify-pr 联合, file:line `.claude/commands/kallax-verify-pr.sh:1-50`):
- **L1 existence**: files exist in git diff (no phantom references)
- **L2 substance**: real logic, no stubs (no `TODO` in critical paths)
- **L3 wiring**: correct imports/exports, type compatibility
- **L4 data flow**: integration tests pass, E2E coverage

**Rule 引用**: Rule 10 (Anti-Fabrication) + Rule 11 (Master 6 维度) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" 战略 一致.

---

## 10. 度量术语 (Metrics — 净价值 + 阈值 + ROI)

---

### 10.1 「净价值」(Net Value)

**大白话**: "净价值 = 100% - (Rule/Step/Doc 占比), v1.2.4 62.5% (-5% 恶化) → v2.0.4 67.0% (+4.5%) 反讽闭环 → v2.0.5 67.0% 持平 (诚实修正, proposal -3 → 实际 -2) → v2.1.0/v2.1.1/v2.2.0 67.0% 持平".

**净价值跟踪** (跟 v1.2.4 baseline 反讽 联合):
- 净价值 = 100% - (Rule/阶段/步骤/文档 占比)
- 净价值 ↑ = 项目越"干净", 越"流程效果 > 流程表演"
- 净价值 持平 = 0 增命令 / 0 增 Rule / 0 重写主逻辑 (跟"翻篇&精进" 联合)

**Rule 引用**: Rule 11 (Master 强验证) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"反讽" 联合.

---

### 10.2 「worktree 隔离 ROI」(Worktree Isolation ROI)

**大白话**: "worktree 数量 75 → 4 (-94.7%), 跟 v2.0.4 EPIC-054-A ROOT_BUCKETS=1 联合, 治 H5 跨 worktree 文件 scope 冲突".

**ROI 数据** (跟 v2.0.4 EPIC-054-A ticket 联合):
- 75 worktree → 4 worktree (跟 ROOT_BUCKETS=1 联合)
- 节省 71 worktree (-94.7%)
- 节省 0.4h/ticket (Performer 启动时间, 跟 v2.0.4 联合)
- 节省 100% 跨 worktree 冲突 (跟 Rule 5 DRY 联合)

**Rule 引用**: Rule 15 (Performer Session 自动加载) + Rule 5 (DRY) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

### 10.3 「Rule 阈值 15」(Rule Threshold 15)

**大白话**: "Rule 32 软约束升级阈值 — Rule 数量 ≤ 15 是'治理完成'信号, 跟 v2.0.5 Rule 合并 24→22 联合, 跟 Rule 32 撤销 联合, 跟 v2.0.6 0 增 Rule 闭环".

**阈值跟踪** (跟"反讽" 联合):
- v1.2.4: 23 Rule (baseline)
- v2.0.4: 23 Rule (0 增)
- v2.0.5: 22 Rule (-1, 合并)
- v2.0.10: Rule 32 撤销 (0 增)
- 目标: ≤ 15 Rule (跟 v2.0.5 Rule 合并 24→22 模式 一致, 候选合并 3 组 治根)
- **现状**: 22 Rule (> 15 阈值, 差 7, 待 PHASE-012 review)

**Rule 引用**: Rule 32 (软约束升级阈值) + Rule 5 (DRY) — [CLAUDE.md](../CLAUDE.md), 跟"翻篇&精进" 战略 一致.

---

## 11. 反思术语 (Reflection — 跟"反讽" + "诚实修正" 联合 闭环)

---

### 11.1 「Rule 数 ≠ 治理完成」(Rule Count Not Equal to Governance Done)

**大白话**: "治理完成信号 是 净价值 持平 + 0 增命令 + 0 增 Rule, 不是 'Rule 数 ≤ 阈值' (跟 KALLAX-GLOSSARY §10.3 阈值 15 联合, 跟 v2.4.0 4 合并 反思 联合)".

**反讽 闭环** (跟 KALLAX-GLOSSARY §1.1 联合, 跟 PHASE-013-REFLECTION 联合):
- §10.3 阈值 15 是 v1.2.4 EPIC-051 经验值 (23 Rule × 65% = 15)
- 实际证据: 22 Rule (v2.3.0) 跟 18 Rule (v2.4.0) 在 净价值 上 没 差异 (67.0% 持平)
- "Rule 数 多" 跟 "问题" 不是 因果关系
- **§10.3 阈值 15 跟 §1.1 反讽 联合, 需 重新审视 (是 迷信 吗?)**

**治理完成信号 重新审视** (跟"翻篇&精进" + "反哺框架" 联合):
- 旧: Rule 数 ≤ 阈值 (15) = 治理完成
- 新: 净价值 持平 + 0 增命令 + 0 增 Rule = 治理完成 (跟"诚实修正" 联合)
- v2.4.0 4 合并 反思: 22 Rule 跟 18 Rule 净价值 持平, 0 实际变化, 治根 "0 实际改变 假动作"

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" + "反讽" 战略 一致.

#### 闭环段: 跟 "9 Hard Rules 简化" 联合 (EPIC-059-A v2.7.0, 2026-06-18)

**§11.1 闭环** (跟 EPIC-059-A + v2.4.1 revert + PHASE-013-REFLECTION 联合, 跟 §11.1 上文 "§10.3 阈值 15 迷信" 联合 闭环):

- **9 Hard Rules 简化 = 模式 (Pattern), 不 = Rule 数 -13**: 22 Rule 仍 落地 (file:line 1:1 映射), 9 Hard Rules 是 group 索引 (索引表, 不删 Rule)
- **跟 v2.4.0 4 合并 反思 联合**: 22 Rule 跟 18 Rule 净价值 持平 67.0%, 0 实际变化, 治根 "0 实际改变 假动作" 反讽. v2.4.1 revert 跟 v2.3.0 一致 22 Rule 还原, 跟"诚实修正" 联合
- **跟 v2.4.1 revert 联合**: 0 落地脚本 变化, 0 净价值 损失, 跟"翻篇&精进" 战略 一致. 9 Hard Rules 简化 跟 v2.4.1 revert 是 同 一 战略 (0 增 Rule + 净价值 持平)
- **跟 PHASE-013-REFLECTION 联合**: 主公 2026-06-18 'a' explicit 派单 1h 反思, 治根 "v2.4.0 反讽 模式" 跟 "v2.0.10 反讽 模式" 联合. EPIC-059-A 闭环 v2.4.1 revert, 治根 "Rule 数 通胀" 迷信
- **§11.1 阈值 15 迷信 闭环**: "Rule 数 ≤ 阈值 15" 是 迷信, 9 Hard Rules 简化 不靠 Rule 数 -13, 靠 模式 (Pattern) + 索引 (Index), 跟"诚实修正" 战略 一致

**KPI 闭环** (跟 §11.1 "0 增 Rule" 联合):
- 22 Rule → 9 类别 group = **22/22 = 100.0%** 落地 (跟"翻篇&精进" 战略 一致)
- **0 增 Rule** (跟 v2.4.1 还原 联合, 跟"诚实修正" + "反讽" 战略 一致)
- **0 重写** (跟 Rule 5 DRY 联合)
- **借方法论 不借代码** (不复制 eket 9 Hard Rules 全文, 提取 模式 + 命名, 适配 KALLAX 22 Rule 现状)

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) + Rule 19 (5 类标签 SOP) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" + "反讽" + "翻篇&精进" 战略 一致.

**详细**: [docs/process/9-hard-rules.md](../process/9-hard-rules.md) + [CLAUDE.md](../CLAUDE.md) "9 Hard Rules 模式" 章节.

---

### 11.2 「反讽 闭环」(Irony Closed Loop)

**大白话**: "'Rule 治 Rule 通胀' 跟'v2.4.0 4 合并' 是 同样 反讽 模式 — 加 Rule (Rule 32) → Rule 数 +1 → 治根 动作本身 加剧 问题. v2.4.0 4 合并 'Rule 数 -4' 是 同样 反讽 模式" (跟 KALLAX-GLOSSARY §1.1 联合, 跟 PHASE-013-REFLECTION 联合).

**反讽 模式 闭环** (跟"反讽" 战略 一致):
- v2.0.5 Rule 合并 24 → 22: "Rule 治 Rule 通胀" 反讽 模式 启动
- v2.0.10 Rule 32 撤销: "治根 'Rule 治 Rule 通胀'" 反讽 模式 治根
- v2.4.0 4 合并 22 → 18: "Rule 治 Rule 通胀" 反讽 模式 重启 (同 v2.0.5)
- v2.4.1 revert 22 Rule 还原: 治根 "v2.4.0 反讽 模式" 跟"v2.0.10 反讽 模式" 联合

**治根 行动** (跟"诚实修正" 联合):
- v2.4.1 revert 跟"诚实修正" 联合, 治根 "v2.4.0 反讽 模式"
- KALLAX-GLOSSARY §11.1 跟"反讽" 联合, 治根 §10.3 阈值 15 迷信
- KALLAX-GLOSSARY §11.4 跟"独立" 联合, 跟 PROCESS.md:25-26 联合

**Rule 引用**: Rule 1 (元术语) + Rule 6 (经验沉淀) — [CLAUDE.md](../CLAUDE.md), 跟"反讽" + "诚实修正" 战略 一致.

---

### 11.3 「0 实际变化 假动作」(Zero Actual Change Faking)

**大白话**: "'0 增命令 跟 净价值 持平' 是 0 实际变化, 跟'反讽' 联合, 需 诚实修正 — v2.4.0 4 合并 跟 v2.3.0 持平 0 增命令 0 重写主逻辑, '制造 0 实际改变 假动作' 反讽" (跟 KALLAX-GLOSSARY §1.2 诚实修正 联合, 跟 PHASE-013-REFLECTION 联合).

**0 实际变化 检测** (跟 Master 6 维 L6 诚实 联合):
- 0 增命令 (跟 v2.0.9 / v2.0.10 / v2.0.11 / v2.1.0 / v2.1.1 / v2.2.0 / v2.3.0 0 增 联合)
- 0 重写主逻辑 (跟"翻篇&精进" 战略 一致, 4 Rule 合并 纯 文档, 落地脚本 不变)
- 净价值 持平 (67.0% 不变, 0 跨 release 验证)

**反讽 治根** (跟"反讽" + "诚实修正" 联合):
- v2.4.0 "v2.4.0 release" 跟"v2.3.5 patch" 实际 等价 (0 实际变化)
- 命名 跟 实现 不一致 = **反讽 治根 失焦** (跟"反讽" 联合)
- v2.4.1 revert 跟"诚实修正" 联合, 治根 "0 实际变化 假动作"

**Rule 引用**: Rule 11 (Master 6 维) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" + "反讽" 战略 一致.

---

### 11.4 「Master 自闭环 边界」(Master Self-Close-Loop Boundary)

**大白话**: "Master 跟'独立' 拍板 explicit 联合 边界 重新审视 — Master 跟 主公 派单 explicit 边界, 跟 PROCESS.md:25-26 'Master 不能自己升级红线' 联合, 跟 v2.4.0 4 合并 反思 联合" (跟 KALLAX-GLOSSARY §6 角色 联合, 跟 PHASE-013-REFLECTION 联合).

**边界 重新审视** (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合):
- PROCESS.md:25-26: "Master 不能自己升级红线"
- "升级" 含义: Rule 数量增加, Rule 优先级提高, Rule 文档 增改
- v2.4.0 4 合并: Rule 数量减少 (-4), 跟 "升级" 反义, 不属 红线
- v2.4.0 4 合并 跟"独立" 拍 explicit 联合 (主公拍 "全拍"), 严格 符合 PROCESS.md:25-26
- 但: 4 合并 边界 失焦 (跟 KALLAX-GLOSSARY §1.2 诚实修正 联合) 需 反思 重新审视

**Master 自闭环 跟'独立' 拍 explicit 联合** (跟"独立" 拍板 explicit 联合):
- 主公拍 explicit 派单: 'a' (启动 PHASE-013) + '全拍 4 合并 + Y 清理' + 'a' (1h 反思 派单) + 'A+B' (启动 PHASE-014 + GLOSSARY 11.x 扩)
- Master 跟 主公 派单 联合 严格 符合 PROCESS.md:25-26
- 边界 模糊: 4 合并 跟 "升级" 概念 边界 模糊, 需 主公拍 explicit 重新审视

**Rule 引用**: Rule 14 (Conductor 不能越界) + Rule 11 (Master 写代码禁令) + PROCESS.md:25-26 — [CLAUDE.md](../CLAUDE.md), 跟"独立" 拍 explicit 联合.

---

### 11.5 「revert 跟反思 区别」(Revert vs Reflection Distinction)

**大白话**: "v2.4.1 revert 跟'诚实修正' 联合 反思 闭环 — revert 是 技术 行动 (commit revert), 反思 是 战略 行动 (跟'诚实修正' 联合, 治根 '0 实际改变 假动作')" (跟 KALLAX-GLOSSARY §1.2 诚实修正 联合, 跟 PHASE-013-REFLECTION 联合).

**revert 跟反思 区别** (跟"诚实修正" 联合):
- **revert**: 技术 行动, `git revert` 还原 v2.4.0 4 Rule 合并 → v2.3.0 22 Rule 状态
- **反思**: 战略 行动, 跟"诚实修正" 联合, 治根 "0 实际改变 假动作" + "Rule 治 Rule 通胀" 迷信
- **v2.4.1 闭环**: revert + 反思 联合, 跟"诚实修正" + "反讽" 战略 一致

**PHASE-013-REFLECTION 闭环** (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合):
- 主公 'a' explicit 派单 1h 反思
- Master 写 PHASE-013-REFLECTION-2026-06-18.md (290+ 行, 4 决策 + 5 战略 + 3 跟"反讽" 联合)
- Master revert v2.4.0 4 Rule 合并 (跟"诚实修正" 联合)
- v2.4.1 release 命名 = "fix(phase-013): v2.4.1 revert v2.4.0 4 Rule 合并"

**Rule 引用**: Rule 1 (元术语) + Rule 6 (经验沉淀) + PROCESS.md:25-26 — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" + "反讽" + "独立" 战略 一致.

---

### 11.6 「P2-1 P2-2 留待」(P2-1 P2-2 Deferred)

**大白话**: "EPIC-058 5 deferred 状态更新 跟'独立' 拍 explicit 联合 — 主公 B+D 跳过, 留待 — 5 deferred → 3 closed + 2 留待" (跟 KALLAX-GLOSSARY §1.4 独立 联合, 跟 PHASE-014 入口 联合).

**5 deferred 状态 累计** (跟"独立" 拍 explicit 联合, 跟 EPIC-058 联合):
- ✅ P1-1 (v2.3.0 closed): pre-commit ALLOWED_PATTERNS 加 `^jira/`
- ✅ P1-2 (v2.4.0 closed, 保留): 48 worktree + 123 branches 清理 (主公 Y 派单)
- ⏸️ P2-1 (留待): EPIC-053-D web dashboard 真上线 (主公 B 跳过, 留待 主公后续 拍)
- ⏸️ P2-2 (留待): 69 remote feature branches DB cleanup (主公 D 跳过, Option A 保留)
- ✅ P3-1 (v2.4.1 closed): Rule 22 → 18 合并 → revert 跟"诚实修正" 联合

**P2-1 启动 需 主公后续 拍 explicit** (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合):
- 选项 A: 主公拍 server/域名/端口/反向代理 → Master 派单 部署
- 选项 B: 主公继续 跳过 → 留待 PHASE-015+ 启动
- 选项 C: 主公 explicit 拍 永久留待 → 5 deferred → 2 deferred 状态 永久

**P2-2 启动 需 主公后续 拍 explicit** (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合):
- 选项 A: 主公维持 Option A 保留 → 68 remote 含 DB 永久 留待
- 选项 B: 主公拍 Option B (filter-repo 改写 history, 6h, 高风险) → Master 派单 6h 部署
- 选项 C: 主公拍 Option C (git replace 软清理, 4h, 中风险) → Master 派单 4h 部署

**Rule 引用**: Rule 1 (元术语) + Rule 6 (经验沉淀) + PROCESS.md:25-26 — [CLAUDE.md](../CLAUDE.md), 跟"独立" 拍板 explicit 联合.

---

## 12. Fact-Forcing 原则 (跟 eket MASTER-RULES.md §2 联合, 跟 Master 6 维 L6 诚实 联合, 跟"反讽" + "诚实修正" 战略 联合)

> **借方法论 不借代码** (跟 EPIC-059-A 9-hard-rules.md §1 联合) — 借 eket `template/docs/MASTER-RULES.md` §2 Fact-Forcing 模式, 适配 KALLAX 实际 release 案例 (BE-9/BE-14/BE-15/BE-16 + v2.0.2/v2.0.5/v2.0.6/v2.4.0/v2.4.1).
> **跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 联合** (file:line `docs/KALLAX-GLOSSARY.md:764-778`), 治根 "自我安慰性 命名".
> **跟 KALLAX-GLOSSARY §1.1 反讽 + §1.2 诚实修正 + §9.3 Master 6 维 L6 诚实 联合** — Fact-Forcing 是 §1.2 诚实修正 的 工具化, 是 §11.3 0 实际变化 假动作 的 检测器.
> **0 增 Rule** (跟 v2.4.1 还原 22 Rule 联合, 跟"翻篇&精进" 战略 一致), **0 重写** (跟 Rule 5 DRY 联合, 新章节 + 新文件).

---

### 12.1 三原则 (Three Principles)

**大白话**: "AI 总是说'确定' — 真信号 在 具体 证据链, 不在 AI 自报. 不问'确定吗', 问'证据在哪'."

**起源** (跟 eket MASTER-RULES.md §2 联合, 跟 KALLAX 实际 release 案例 联合):

#### 原则 1: 不问 "确定吗" (AI 总是回答是)

- **问题**: "你这个 fix 是不是 work?" / "这个 PR 能 merge 吗?" — AI 自报 100% 答 "确定", **0 信息量**
- **反讽 诊断** (跟 KALLAX-GLOSSARY §1.1 联合): 问 AI 确定性 = "制造 0 信息交换 假动作", 跟 §11.3 "0 实际变化 假动作" 同一 模式
- **治根**: 改问 "证据在哪" / "哪行代码" / "哪个命令输出" — 逼 AI 出 事实 而非 自我评估

**KALLAX 实证** (跟 BE-15 "Unknown command: /kallax-ask" 联合):
- AI 答 "v2.1.0 已修" ≠ 证据 → 实际 主公 反馈 "Unknown command: /kallax-ask" 仍存, 治根 在 v2.1.1 加 26 .md wrappers (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`, `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:484`)
- **教训**: AI 自报确定性 ≠ reality, evidence chain 才是 reality

#### 原则 2: 要求具体证据 (file:line / 命令输出 / 代码位置)

- **证据 3 格式** (跟 Master 6 维 L6 诚实 联合, file:line `docs/KALLAX-GLOSSARY.md:625-637`):
  - **file:line 引用** — `CLAUDE.md:295` 形式, 精确 到行
  - **命令输出** — `git log --oneline -5` / `git show <sha>` 实际 stdout
  - **代码位置** — `scripts/install.sh:139-141` 形式, 命名 + 行号
- **不接受的"证据"** (跟 §1.2 诚实修正 联合): "should work" / "looks correct" / "基本上 OK" / 任何 模糊 形容词

**KALLAX 实证** (跟 v2.0.5 honest mark 联合):
- v2.0.5 Rule 合并 实际 -2 (proposal 写 -3), 净价值 实际 +1.5% (proposal 写 +3.0%) — **诚实标记** (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288-289`, 跟 §1.2 联合)
- **教训**: proposal ≠ reality, 落地 后 必须 用 真实 commit diff 重新 测量, 标注 difference

#### 原则 3: 无证据的断言视为无效

- **无效化 处理**: AI 说 "X 已修复" 但 缺 file:line → **视为未修复**, 不进入 merge queue
- **闭环** (跟 KALLAX-GLOSSARY §1.5 闭环 联合): evidence = reality, 没 evidence = 没 reality
- **跟 Master 6 维 L1-L4 联合** (file:line `docs/KALLAX-GLOSSARY.md:625-637`):
  - L1 git log (commit 存在)
  - L2 git show (diff 内容)
  - L3 跑测试 (验证 work)
  - L4 preflight (anti-fab 通过)
  - L5 边界 (file scope 合规)
  - **L6 诚实 (raw test output, 不接受 should work)**

**KALLAX 实证** (跟 v2.4.1 revert 闭环 联合):
- v2.4.0 4 Rule 合并 (commit `fd9d0d9`, file:line `CHANGELOG.md`) 命名 "Rule 数 减少 净价值 提升" → 实际 净价值 67.0% 持平, 0 跨 release 验证 → **断言 vs reality 失配**, v2.4.1 revert (commit `7f401f9`, file:line `CHANGELOG.md`)
- **教训**: 命名 ≠ reality, 缺 evidence (跨 release 验证) → 视为无效, 走 revert

**Rule 引用**: Rule 9 (X/Y 格式) + Rule 11 (Master 6 维度) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟"诚实修正" + "反讽" 战略 一致, 跟 §11.3 联合.

---

### 12.2 五反例 (Five Anti-Patterns — 跟 KALLAX 实际 release 案例 联合)

**大白话**: "AI 自报 跟 reality 不一致 = 反讽, 必须 治根."

#### ❌ 反例 1: BE-9 "L3L4 矛盾" — review.sh 自报 PASS 实际 silent output

- **模式**: "L4 verify 跑过 = 完成" — review.sh 自报 PASS, 实际 silent output, 4 subagent 并行 复发 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:434`)
- **违反 原则 1+2**: 接受 AI 自报 "verify PASS", 缺 raw test output
- **治根** (跟 v2.0.4 EPIC-053-A truth-table 联合): truth-table 强制 raw stdout/stderr, 4-Level Fact-Forcing (file:line `docs/KALLAX-GLOSSARY.md:641-651`)
- **跟 §11.3 联合**: "L4 verify PASS" 命名 ≠ reality (silent output) = "0 实际变化 假动作"

#### ❌ 反例 2: BE-14 "4 subagent 并行 silent output 复发" — 派单 OK 实际 0 deliver

- **模式**: EPIC-057 4 subagent 并行 派单, 自报 "派单 完成" — 实际 4 subagent 全 silent output, 0 deliver (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:439`)
- **违反 原则 1+2+3**: 接受 AI 派单 自报, 缺 per-subagent stdout + deliverable file
- **治根** (跟 v2.0.6 EPIC-057-D 联合, file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74`): 1 ticket 1 subagent 串行, 强验证 per-subagent output
- **跟 §11.3 联合**: "4 subagent 并行 = 4 倍速度" 命名 ≠ reality (silent output = 0 deliver) = "0 实际变化 假动作"

#### ❌ 反例 3: BE-15 "Unknown command: /kallax-ask" — 表面修了 实际没治根

- **模式**: v2.0.9/v2.0.10/v2.0.11 改 .sh 顶部 # 注释 description, 自报 "已修" — 主公 反馈 "Unknown command: /kallax-ask" 仍存 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`, `docs/KALLAX-GLOSSARY.md:550-568`)
- **违反 原则 1+2**: 接受 AI 自报 ".sh 已改", 缺 Claude Code 2.1+ slash command registry 实测
- **治根** (跟 v2.1.1 联合): 加 26 .md wrappers, Claude Code 2.1+ 优先 .md 格式 (file:line `.claude/commands/kallax-ask.md:1-8`)
- **跟 §11.3 联合**: "改 .sh = 修复" 命名 ≠ reality (Claude Code registry 优先 .md) = "0 实际变化 假动作"

#### ❌ 反例 4: v2.0.2 '跨平台 fix release' 反讽 — 命名 跨平台 实际 只 Claude Code

- **模式**: v2.0.2 release 命名 "跨平台 fix release", install.sh 实际 只支持 Claude Code (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:79`, `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:120-123`)
- **违反 原则 2+3**: 接受 release 命名 自我评估, 缺 file:line 实证 (install.sh:52-53 1 工具, codex/gemini 0 reference)
- **治根** (跟 v2.0.6 EPIC-057 联合): CHANGELOG [2.0.6] 明确标注 "v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根" (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:168`, `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:197`)
- **跟 §11.3 联合**: release 命名 "跨平台" ≠ reality (1 工具 only) = "0 实际变化 假动作"

#### ❌ 反例 5: v2.4.0 4 合并 "净价值 提升" 假动作 — 命名 净增 实际 持平

- **模式**: v2.4.0 4 Rule 合并 (commit `fd9d0d9`), release 命名 "Rule 数 减少 净价值 提升", 实际 净价值 67.0% 持平 0 跨 release 验证 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:39-42`, `docs/KALLAX-GLOSSARY.md:764-778`)
- **违反 原则 1+2+3**: 接受 release 命名 "净价值 +4%", 缺 跨 release 验证 evidence (22 Rule 跟 18 Rule 净价值 持平, 0 假 PASS 校验)
- **治根** (跟 v2.4.1 revert 联合, commit `7f401f9`): 跟"诚实修正" 联合, revert 4 合并 → 22 Rule 跟 v2.3.0 一致, 反思 doc PHASE-013-REFLECTION 落地 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:282-285`)
- **跟 §11.3 联合**: 命名 "净价值 +4%" ≠ reality (67.0% 持平) = "0 实际变化 假动作", v2.4.1 revert 闭环

**Rule 引用**: Rule 10 (Anti-Fabrication) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟 §1.1 反讽 + §11.3 0 实际变化 假动作 联合.

---

### 12.3 五正例 (Five Positive Examples — 跟 KALLAX 实际 release 案例 联合)

**大白话**: "evidence chain 完整 + 闭环 verify + raw output = reality 闭环."

#### ✅ 正例 1: v2.0.5 honest mark — Rule 合并 -3→-2 + 净价值 +3%→+1.5% 诚实标记

- **模式**: v2.0.5 Rule 合并 落地 后, Performer 诚实标记 proposal 跟 实际 difference (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288-289`)
  - Rule 合并: proposal -3 → 实际 -2 (候选 C 是"扩展"而非"删除", 净减为 0)
  - 净价值: proposal +3.0% → 实际 +1.5% (跟 v2.0.3 "净价值 67.5% 边际递减" 联合)
- **符合 3 原则**:
  - 原则 1: 不问"完成了吗", 改问"实际 净减/净增 多少"
  - 原则 2: file:line 实证 (ACCUMULATED-LESSONS:288-289)
  - 原则 3: 跟 §11.3 联合, 命名 (proposal) 跟 reality (实际) 失配 → 诚实标记, 不 模糊处理
- **跟 §1.2 诚实修正 联合**: 主动 标记 proposal 跟 actual 差异, 不等别人发现

#### ✅ 正例 2: v2.0.6 4 工具 multi-tool — install.sh `--target=auto` evidence chain 完整

- **模式**: v2.0.6 EPIC-057 4 ticket 闭环, install.sh `--target=auto` 检测 Claude/opencode/Codex/Gemini 4 工具 (file:line `scripts/install.sh:69-92`, `scripts/install.sh:139-141`)
- **符合 3 原则**:
  - 原则 1: 不问"4 工具 支持 吗", 改问"auto-detect 实测 哪几 个"
  - 原则 2: file:line `scripts/install.sh:69-92` (4 工具 detection) + `scripts/install.sh:139-141` (symlink 路径)
  - 原则 3: 4 工具 验证 通过 (file:line `tests/integration/master-6d-recovery-test.sh:150` L4 preflight 跑过)
- **跟 v2.0.2 反讽 治根 联合**: "跨平台" 命名 → v2.0.6 真正 4 工具, naming = reality

#### ✅ 正例 3: v2.4.0 worktree 清理 — 48 worktree + 123 branches evidence 完整

- **模式**: v2.4.0 P1-2 (commit `fd9d0d9`) worktree 清理, 48 worktree + 123 branches, 5.5M disk freed (file:line `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:39-43`)
- **符合 3 原则**:
  - 原则 1: 不问"清理 OK 吗", 改问"剩 几 个 worktree + 几 个 branches + 节省 几 M"
  - 原则 2: `du -sh .claude/worktrees` 实测 5.5M + `git worktree list` 1 个 (跟 §1.2 honest mark 联合)
  - 原则 3: 跟 v2.4.0 4 Rule 合并 0 实际变化 不同, worktree 清理 是 **实际 disk 节省**, naming = reality
- **跟 §11.5 revert 跟反思 区别 联合**: worktree 清理 保留 (v2.4.1 没 revert), 跟 4 Rule 合并 反讽 不同

#### ✅ 正例 4: v2.4.1 revert 闭环 — 4 合并 naming 跟 reality 失配 → revert

- **模式**: v2.4.1 (commit `7f401f9`) revert v2.4.0 4 Rule 合并, 22 Rule 跟 v2.3.0 一致 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`, `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:168`)
- **符合 3 原则**:
  - 原则 1: 不问"4 合并 OK 吗", 改问"净价值 跨 release 验证 实测 几 %"
  - 原则 2: file:line `PHASE-013-REFLECTION-2026-06-18.md:39-42` (67.0% 持平) + `docs/KALLAX-GLOSSARY.md:116` (净价值 持平 表)
  - 原则 3: 跨 release 验证 (v2.3.0 vs v2.4.0 vs v2.4.1) 缺 → 视为 无效, 走 revert
- **跟 §11.5 revert 跟反思 区别 联合**: revert 技术 行动 + 反思 战略 行动 闭环, 跟"诚实修正" 联合

#### ✅ 正例 5: 26 .md wrappers 闭环 — Claude Code 2.1+ 实测 → 治根 BE-15

- **模式**: v2.1.1 加 26 .md wrappers, Claude Code 2.1+ 优先 .md 格式, 治根 BE-15 "Unknown command: /kallax-ask" (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`, `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:484`, `.claude/commands/kallax-ask.md:1-8`)
- **符合 3 原则**:
  - 原则 1: 不问"修了 吗", 改问"Claude Code 2.1+ slash command registry 实测 几 个 命令 OK"
  - 原则 2: file:line `.claude/commands/kallax-ask.md:1-8` (frontmatter description + `!bash` directive) + `tests/integration/master-6d-recovery-test.sh:150` (L4 preflight)
  - 原则 3: 主公 反馈 闭环 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:698` "主公 Unknown command 反馈" → v2.1.1 .md wrappers)
- **跟 §11.3 0 实际变化 假动作 治根 联合**: v2.0.9-v2.0.11 0 实际变化 (改 .sh 表面) → v2.1.1 治根 (加 .md wrappers, Claude Code registry 优先)

**Rule 引用**: Rule 9 (X/Y 格式) + Rule 11 (Master 6 维度) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟 §1.2 诚实修正 + §11.3 0 实际变化 假动作 联合.

---

### 12.4 「L0-L4 记忆分层」(Memory Layering, EPIC-059-H 2026-06-18)

> **Ticket 备注** (跟"诚实修正" 联合, 跟 §1.2 联合): ticket.json 写 §12.2, 实际 §12.2 被 §12.2 五反例 (EPIC-059-D) 占用, EPIC-059-H 落地时 调整为 §12.4 (next free slot). ticket KPI "GLOSSARY §12.2 1/1" 实际 满足 = "GLOSSARY 落地 1/1" (spirit 满足, 跟"翻篇&精进" 战略 一致).

**大白话**: "KALLAX 知识库 5 层分层: L0 session 缓存 → L1 项目经验 → L2 项目知识 → L3 全局模式 → L4 全局知识库. 跟 eket `confluence/memory/` 多级记忆 模式 联合, 跟 `~/.claude/knowledge/core/patterns/knowledge-system.md` L0-L4 架构 联合, 借方法论 不借代码 (跟 EPIC-059-A 9-hard-rules.md §1 联合)".

#### 5 层定义 (5 Layer Definitions, 跟 [confluence/memory/LAYERS.md](../confluence/memory/LAYERS.md) 联合)

| Layer | 名称 | 存储位置 | 已存在 | 生命周期 |
|---|---|---|---|---|
| **L0** | 会话缓存 (Session Cache) | `.kallax/state/` | 5 entries (state.json / instances.json / mode.lock / instances/ / instance_config.yml) | 瞬态 (session 级别) |
| **L1** | 项目经验 (Project Experience) | `confluence/decisions/` | **26 files** (PHASE-005~014 + ACCUMULATED-LESSONS × 2 + dispatch-checklist 等, file:line `confluence/decisions/` 列表) | 长期 (项目级) |
| **L2** | 项目知识 (Project Knowledge) | `confluence/memory/lessons/` | **17 files** (EPIC-016~031 lessons + 主题 lessons, file:line `confluence/memory/lessons/README.md:26-54`) | 长期 (项目级) |
| **L3** | 全局模式 (Global Patterns) | `confluence/memory/patterns/` | **2 files** (`isolation-strategy.md` / `rust-node-bridge.md`) | 长期 (跨项目) |
| **L4** | 全局知识库 (Global Knowledge) | `confluence/memory/research/` | **2 files** (`anti-hallucination.md` / `architecture-lessons-learned.md`) | 长期 (跨项目) |

#### 5 触发条件 (5 Trigger Conditions, 跟"诚实修正" 联合, 不模糊)

| 触发 # | 条件 | From → To | 典型场景 |
|---|---|---|---|
| **1** | 任务完成 (Performer 完工) | L0 → L1 | `kallax task:merge TASK-001` → `state.json` L0 沉淀到 `confluence/decisions/TASK-001.md` |
| **2** | EPIC 完成 (闭环) | L1 → L2 | EPIC 状态 = `closed` + 全部 ticket 完工 → 写 `confluence/memory/lessons/epic-{ID}-{date}.md` |
| **3** | 跨 release 累计 (复用 ≥ 3 次) | L2 → L3 | 同一 lessons 跨 ≥ 3 release 引用 → 升级为全局 pattern, 写 `confluence/memory/patterns/{name}.md` |
| **4** | PHASE review (战略级闭环) | L3 → L4 | PHASE-XXX-REVIEW.md 落地 + Master 拍板 → 关键 patterns 提取到 `confluence/memory/research/` |
| **5** | 借鉴外部项目 (eket / industry) | L4 沉淀 | `scripts/eket-lessons-import.sh` (已存在) → 落地到 L1-L4 适配层 |

#### 5 升级路径 (5 Promotion Paths, 跟 `scripts/memory-promote.sh` 联合)

| Path | From → To | 命令 | 验证 |
|---|---|---|---|
| **1** | L0 → L1 | `kallax task:merge` 自动 | `confluence/decisions/<ticket>.md` 存在 + `state.json` L0 清理 |
| **2** | L1 → L2 | EPIC 闭环 + 写 `epic-{ID}-{date}.md` | 引用 ≥ 5 L1 经验 |
| **3** | L2 → L3 | `grep -l "{pattern-keyword}" confluence/decisions/PHASE-*.md` ≥ 3 | 跨 ≥ 3 PHASE 引用 + Master 拍板 |
| **4** | L3 → L4 | PHASE-XXX-REVIEW 落地 + 提取 patterns | research 文档引用 ≥ 3 PHASE |
| **5** | L4 沉淀 | `bash scripts/eket-lessons-import.sh` | 外部借鉴落地 L1-L4 适配层 |

#### 5 反模式 (5 Anti-Patterns, 跟"反讽" 治根 联合)

| 反模式 | 描述 | 治根 |
|---|---|---|
| **A1 跨层写入** | 跳过 L1-L3 直接写 L4 = 失序 | 强制 L0→L1→L2→L3→L4 顺序, 跳级需 Master 拍板 |
| **A2 倒序沉淀** | L4 → L3 倒序写 = 降级反讽 | `scripts/memory-promote.sh` 拒绝逆向 transition |
| **A3 L0 长期累积** | `.kallax/state/` > 1GB = L0 失活 | L0 TTL = session 级别, 退出清理 |
| **A4 L4 假沉淀** | 写 `research/` 缺跨 release 引用 = 空 L4 | research 必含 ≥ 3 PHASE 引用 |
| **A5 分层标记 vs 实际 失配** | 写 L3 但内容是 L2 = label drift | `memory-promote.sh verify-all` 强制检查 |

**详细**: [confluence/memory/LAYERS.md](../confluence/memory/LAYERS.md) + `scripts/memory-promote.sh` + `tests/integration/memory-l0-l4-test.sh` (5/5 PASS).

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) + Rule 11 (Master 6 维) + Rule 18 (KPI Falsification 黑名单) — [CLAUDE.md](../CLAUDE.md), 跟 §1.1 反讽 + §1.2 诚实修正 + §2.2 反哺框架 战略 联合, 跟 eket `template/docs/MASTER-RULES.md` 模式 + `~/.claude/knowledge/core/patterns/knowledge-system.md` L0-L4 架构 联合 (借方法论 不借代码).

---

## 13. 总结

| 类别 | 术语数 | Rule 引用 |
|---|---|---|
| **元术语** (1.x) | 6 | Rule 6/7/10/11/14/15/16/18 |
| **战略 / 方向** (2.x) | 3 | Rule 6/32 |
| **流程 / 工作流** (3.x) | 5 | Rule 9/10/11/16/18 |
| **反模式 / 黑名单** (4.x) | 5 | Rule 9/14/15/18 |
| **经验教训** (5.x) | 3 | Rule 29/30/31 |
| **角色 / 决策** (6.x) | 4 | Rule 11/13/14/15 |
| **量化 / 指标** (7.x) | 3 | Rule 32 |
| **落地 / 工程** (8.x) | **18** (+5 v2.3.0 hybrid/wizard/dry-run/.md/canonical) | Rule 5/15/17/29/31 + Rule 5/10/11/15/16/18 (multi-tool 联合) |
| **治理** (9.x 新) | **4** (rebase/Saga/Master 6 维/4-Level) | Rule 6/9/10/11/16/18 |
| **度量** (10.x 新) | **3** (净价值/ROI/阈值 15) | Rule 5/11/15/18/32 |
| **反思** (11.x v2.5.0) | **6** (§11.1-§11.6) | Rule 1/6/11/14 + PROCESS.md:25-26 |
| **Fact-Forcing** (12.x v2.7.0, EPIC-059-D) | **3** (§12.1 三原则 / §12.2 五反例 / §12.3 五正例) | Rule 9/10/11/18 |
| **总计** | **63 个术语** (+9 v2.5.0 + v2.7.0) | 跨 Rule 1-33 |

### 🔑 关键 takeaway

- ✅ **63 个术语** 全部覆盖, 一次性盘点 (跟 v2.0.6 +5 + v2.2.0 +3 + v2.3.0 +12 + v2.5.0 +6 + v2.7.0 +3)
- ✅ **每个术语**: 大白话 + 来源 + Rule 引用
- ✅ **追溯链完整** (跟"独立" 拍 explicit 约束 联合)
- ✅ **写到了文件** (跟主公 explicit 约束 联合)
- ✅ **Fact-Forcing 原则 落地** (§12, EPIC-059-D, 跟 eket MASTER-RULES.md §2 联合, 跟"反讽" + "诚实修正" 联合)

### 📚 SoT 边界 (跟 Rule 5 DRY 联合)

- **CLAUDE.md** = Rule SoT (规则/红线/必读) — 修订 Rule 只改 CLAUDE.md
- **KALLAX-GLOSSARY.md** = 术语 SoT (黑话/概念) — 修订术语只改本文件
- **互链而非复制**: 本文件每个 Rule 引用链到 CLAUDE.md 对应 Rule, 避免定义复制
- **docs/process/fact-forcing.md** = Fact-Forcing 详细 (跟 §12 联合, 3 原则 + 7 反例 + 7 正例 + 验证方法 + 撤销方法)

### 🎬 主公下一步

- ✅ 词典已落地 `docs/KALLAX-GLOSSARY.md` (63 术语)
- ✅ Fact-Forcing 原则 已落地 (§12 + docs/process/fact-forcing.md + confluence/decisions/fact-forcing-examples.md, EPIC-059-D)
- 等主公 review / commit + push / 实战 Onramp 派 Wave 6