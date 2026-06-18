# Fact-Forcing 原则 (KALLAX, EPIC-059-D)

> **跟 eket MASTER-RULES.md §2 联合, 借方法论 不借代码**
> **跟 KALLAX-GLOSSARY §12 联合, 跟 Master 6 维 L6 诚实 联合**
> **跟 v2.0.5/v2.0.6/v2.4.1 红线 revert 文档化 联合, 跟 v2.4.0 4 合并 假动作 联合**
> **跟"反讽" + "诚实修正" + "翻篇&精进" 战略 联合**

---

## 1. 起源与定位

### 1.1 问题 (跟 eket MASTER-RULES.md §2 + KALLAX 历史 release 联合)

**核心问题**: AI 总是答 "确定" — 自报 ≠ reality. 跨 release 累计 5 BE (BE-9/BE-14/BE-15/BE-16) + 2 release (v2.0.2 跨平台 fix release / v2.4.0 4 合并 净价值 提升) 都 是 "命名 ≠ reality" 反讽.

**方法** (跟 eket MASTER-RULES.md §2 联合, 借方法论 不借代码):
- **借**: eket Fact-Forcing 模式 (不问确定, 问证据)
- **不借**: eket 9 Hard Rules 全文 + 具体 rule 内容 (跟 EPIC-059-A 9-hard-rules.md §1 联合)
- **适配**: KALLAX 实际 release 案例 (BE-9/BE-14/BE-15/BE-16 + v2.0.2/v2.0.5/v2.0.6/v2.4.0/v2.4.1)

### 1.2 跟 KALLAX 5 红线 revert 联合 (跟"诚实修正" 战略 一致)

| Release | 红线 revert 模式 | evidence |
|---|---|---|
| **v2.0.4** | ⚠️ Master 6 维恢复 (EPIC-056-C, v1.2.4 6→0 退步反转) | commit `7f88823` (file:line `git log --all --grep="EPIC-056-C"`) |
| **v2.0.5** | ⚠️ Rule 32 撤销 (反讽 治根 "Rule 治 Rule 通胀") | commit `7db6107` (跟 ACCUMULATED-LESSONS §4.4 联合) |
| **v2.1.1** | ⚠️ 26 .md wrappers (BE-15 治根, Claude Code 2.1+ 优先 .md 格式) | commit `0ded58f` (file:line `git log --all --grep="26 .md wrappers"`) |
| **v2.4.0 → v2.4.1** | ⚠️ 4 Rule 合并 revert (BE-16 治根, "0 实际变化 假动作") | commit `7f401f9` (file:line `git log --all --grep="v2.4.1 revert"`) |

**5 红线 revert 共同模式** (跟 Fact-Forcing 联合):
- 每次 revert 触发 原因: 落地 后 evidence chain 失配 (净价值 / 实测 / 命名 跟 reality)
- 每次 revert 治根: 0 实际变化 / 命名 ≠ reality / 0 跨 release 验证
- 每次 revert 落地: PHASE-XXX-REFLECTION doc 沉淀, 跟"诚实修正" 联合

### 1.3 跟 v2.4.0 4 合并 假动作 联合 (跟 KALLAX-GLOSSARY §11.3 联合)

**v2.4.0 4 合并 模式** (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:39-42`):
- 命名: "Rule 22 → 18 净价值 +4%"
- 实际: 净价值 67.0% 持平 0 跨 release 验证
- **反讽**: 命名 ≠ reality = "制造 0 实际改变 假动作" (跟 §11.3 联合)
- **治根** (v2.4.1 revert, file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`): 跟"诚实修正" 联合, 主动 revert, PHASE-013-REFLECTION doc 沉淀

---

## 2. 三原则 详细 解释

### 2.1 原则 1: 不问 "确定吗" (Ask Evidence, Not Confirmation)

**核心**: AI 总是答 "确定", 0 信息量. 改问 "证据在哪" / "哪行代码" / "哪个命令输出".

**为什么** (跟"反讽" + KALLAX-GLOSSARY §1.1 联合):
- AI 自报 跟 reality 失配 是 反讽 闭环 (跟 §11.3 联合)
- "确定吗" 是 "制造 0 信息交换 假动作" — 跟 "制造 0 实际改变 假动作" 同一模式
- 实证: BE-15 "Unknown command: /kallax-ask" — AI 自报 "v2.1.0 已修", 实际 主公反馈仍存 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`)

**怎么用** (跟 Master 6 维 L6 诚实 联合, file:line `docs/KALLAX-GLOSSARY.md:625-637`):
```
❌ "这个 fix work 吗?"          → AI 答 "确定 work" (0 信息量)
✅ "哪行代码改了?"              → AI 答 "file:line scripts/install.sh:139-141"
✅ "哪个命令实测过?"            → AI 答 "git log --oneline -5"
✅ "raw test output 是什么?"    → AI 答 "Tests: 12 passed, 12 total"
```

### 2.2 原则 2: 要求具体证据 (file:line / 命令输出 / 代码位置)

**证据 3 格式** (跟 Master 6 维 L1-L4 联合, file:line `docs/KALLAX-GLOSSARY.md:625-637`):

#### 2.2.1 file:line 引用

**格式**: `path/to/file.ext:LINE` 或 `path/to/file.ext:START-END`

**示例**:
- `CLAUDE.md:295` (Rule 14 主公原话 3 模式决策权)
- `scripts/install.sh:69-92` (v2.0.6 4 工具 detection)
- `.claude/commands/kallax-ask.md:1-8` (BE-15 .md wrapper 治根)
- `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:282-285` (v2.4.0 反思 + v2.4.1 revert)

**不接受的"证据"** (跟 §1.2 诚实修正 联合):
- "大概在 scripts 目录"
- "应该是 .sh 文件"
- "看起来差不多"

#### 2.2.2 命令输出

**格式**: `git log --oneline -5` / `git show <sha>` 实际 stdout

**示例** (跟 L1 git log + L2 git show 联合):
```bash
$ git log --oneline -5
7f401f9 fix(phase-013): v2.4.1 revert v2.4.0 4 Rule 合并 ...
fd9d0d9 feat(phase-013): v2.4.0 PHASE-013 跨期 review 落地 ...
0ded58f fix(slash-cmds): 加 26 .md wrappers 治主公'Unknown command' ...
```

**不接受的"证据"**:
- "commit 已经 push 了"
- "diff 看起来对"

#### 2.2.3 代码位置

**格式**: 完整路径 + 行号 或 函数名 + 行号

**示例**:
- `scripts/install.sh:139-141` (`--symlink` 4 工具 single source 模式, file:line)
- `docs/KALLAX-GLOSSARY.md:764-778` (§11.3 0 实际变化 假动作)

### 2.3 原则 3: 无证据的断言视为无效 (Invalidate Unverified Claims)

**核心**: AI 说 "X 已修复" 但 缺 file:line → **视为未修复**, 不进入 merge queue.

**为什么** (跟"反讽" + KALLAX-GLOSSARY §1.1 联合):
- 缺 evidence = 缺 reality (跟 §1.5 闭环 联合)
- 接受 模糊 断言 = "制造 0 实际变化 假动作" (跟 §11.3 联合)
- 实证: v2.4.0 4 合并 净价值 +4% (无 跨 release 验证) → v2.4.1 revert (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:282-285`)

**怎么用** (跟 Master 6 维 L1-L4 联合):
- **L1 git log**: commit 存在? `git log --oneline -1` 有 sha?
- **L2 git show**: diff 内容? `git show <sha>` 有 file:line?
- **L3 跑测试**: work? raw test output?
- **L4 preflight**: anti-fab 通过? `check-fact-forcing-preflight.sh` 0 fail?
- **L5 边界**: file scope 合规?
- **L6 诚实**: raw test output, 不接受 "should work"

**闭环** (跟 §1.5 闭环 联合): evidence = reality, 没 evidence = 没 reality → 走 revert / 走 fix, 不 模糊 处理.

---

## 3. 七反例 (跟 KALLAX 实际 release 案例 联合)

### 3.1 反例 1: BE-9 "L3L4 矛盾" — review.sh 自报 PASS 实际 silent output

**模式**: review.sh 自报 "L4 verify PASS", 实际 silent output, 4 subagent 并行 复发 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:434`)

**违反 3 原则**:
- 原则 1: 接受 AI 自报 "L4 verify 跑过"
- 原则 2: 缺 raw test output
- 原则 3: 缺 evidence 视为 OK = silent output 0 deliver

**治根** (跟 v2.0.4 EPIC-053-A truth-table 联合): truth-table 强制 raw stdout/stderr, 4-Level Fact-Forcing (file:line `docs/KALLAX-GLOSSARY.md:641-651`)

**跟 §11.3 联合**: "L4 verify PASS" 命名 ≠ reality (silent output) = "0 实际变化 假动作"

### 3.2 反例 2: BE-14 "4 subagent 并行 silent output 复发" — 派单 OK 实际 0 deliver

**模式**: EPIC-057 4 subagent 并行 派单, 自报 "派单 完成", 实际 4 subagent 全 silent output, 0 deliver (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:439`, `:74`)

**违反 3 原则**:
- 原则 1: 接受 AI 派单 自报
- 原则 2: 缺 per-subagent stdout + deliverable file
- 原则 3: 缺 evidence 视为 OK = 0 deliver

**治根** (跟 v2.0.6 EPIC-057-D 联合): 1 ticket 1 subagent 串行, 强验证 per-subagent output

**跟 §11.3 联合**: "4 subagent 并行 = 4 倍速度" 命名 ≠ reality = "0 实际变化 假动作"

### 3.3 反例 3: BE-15 "Unknown command: /kallax-ask" — 表面修了 实际没治根

**模式**: v2.0.9/v2.0.10/v2.0.11 改 .sh 顶部 # 注释, 自报 "已修", 主公 反馈 "Unknown command: /kallax-ask" 仍存 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`, `docs/KALLAX-GLOSSARY.md:550-568`)

**违反 3 原则**:
- 原则 1: 接受 AI 自报 ".sh 已改"
- 原则 2: 缺 Claude Code 2.1+ slash command registry 实测 evidence
- 原则 3: 缺 evidence 视为 OK = 主公反馈仍存

**治根** (跟 v2.1.1 联合): 加 26 .md wrappers, Claude Code 2.1+ 优先 .md 格式 (file:line `.claude/commands/kallax-ask.md:1-8`)

**跟 §11.3 联合**: "改 .sh = 修复" 命名 ≠ reality (Claude Code registry 优先 .md) = "0 实际变化 假动作"

### 3.4 反例 4: v2.0.2 '跨平台 fix release' 反讽 — 命名 跨平台 实际 只 Claude Code

**模式**: v2.0.2 release 命名 "跨平台 fix release", install.sh 实际 只支持 Claude Code (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:79`, `:120-123`, `:197`)

**违反 3 原则**:
- 原则 1: 接受 release 命名 自我评估 "跨平台"
- 原则 2: 缺 file:line 实证 (install.sh:52-53 1 工具, codex/gemini 0 reference)
- 原则 3: 缺 evidence 视为 OK = 主公 实际 反讽

**治根** (跟 v2.0.6 EPIC-057 联合): CHANGELOG [2.0.6] 明确标注 "v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根" (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md:168`)

**跟 §11.3 联合**: release 命名 "跨平台" ≠ reality (1 工具 only) = "0 实际变化 假动作"

### 3.5 反例 5: v2.4.0 4 合并 "净价值 提升" 假动作 — 命名 净增 实际 持平

**模式**: v2.4.0 4 Rule 合并, release 命名 "Rule 数 减少 净价值 提升", 实际 净价值 67.0% 持平 0 跨 release 验证 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:39-42`, `docs/KALLAX-GLOSSARY.md:764-778`)

**违反 3 原则**:
- 原则 1: 接受 release 命名 "净价值 +4%"
- 原则 2: 缺 跨 release 验证 evidence (22 Rule 跟 18 Rule 净价值 持平, 0 假 PASS 校验)
- 原则 3: 缺 evidence 视为 OK = 净价值 持平 (0 实际变化)

**治根** (跟 v2.4.1 revert 联合): revert 4 合并 → 22 Rule 跟 v2.3.0 一致, 反思 doc PHASE-013-REFLECTION 落地 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`)

**跟 §11.3 联合**: 命名 "净价值 +4%" ≠ reality (67.0% 持平) = "0 实际变化 假动作"

### 3.6 反例 6: v2.0.3 11 KPI falsification — Master 自验证 loophole

**模式**: v2.0.3 baseline 11/16 KPI 用估数 (~60% / 约 80% / PARTIAL), Master 自验证 loophole (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:159-173`, 跟 Rule 18 KPI Falsification 黑名单 联合)

**违反 3 原则**:
- 原则 1: 接受 AI 自报 "KPI 达标"
- 原则 2: 缺 raw test output / X/Y 格式 evidence
- 原则 3: 缺 evidence 视为 OK = 估数 算 FAIL 模式

**治根** (跟 v2.0.4 EPIC-053-B 联合): 4-Level 证据链 + Master 6 维恢复 (v1.2.4 6→0 退步 反转)

**跟 §11.3 联合**: "11/16 KPI 达标" 命名 ≠ reality (估数) = "0 实际变化 假动作"

### 3.7 反例 7: v2.1.0 wizard "5-step 引导" 表面 — 实际 user 输入 无 evidence chain

**模式**: v2.1.0 wizard 5-step 引导 (file:line `docs/KALLAX-GLOSSARY.md:521-533`), 自报 "5-step 完成", 缺 per-step user input evidence (跟 dry-run 模式 联合, file:line `docs/KALLAX-GLOSSARY.md:536-547`)

**违反 3 原则**:
- 原则 1: 接受 AI 自报 "wizard 5-step 完成"
- 原则 2: 缺 per-step stdin input log + 实际 install file:line
- 原则 3: 缺 evidence 视为 OK = 实际 install 0 verify

**治根** (跟 v2.1.0 dry-run 联合): `--dry-run` 模拟运行, 退出前打印 "Dry-run complete. No files were installed." (file:line `docs/KALLAX-GLOSSARY.md:536-547`)

**跟 §11.3 联合**: "wizard 5-step 完成" 命名 ≠ reality (无 install file:line) = "0 实际变化 假动作"

---

## 4. 七正例 (跟 KALLAX 实际 release 案例 联合)

### 4.1 正例 1: v2.0.5 honest mark — Rule 合并 -3→-2 + 净价值 +3%→+1.5% 诚实标记

**模式**: v2.0.5 Rule 合并 落地 后, Performer 诚实标记 proposal 跟 实际 difference (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288-289`)

**符合 3 原则**:
- 原则 1: 不问"完成了吗", 改问"实际 净减/净增 多少"
- 原则 2: file:line 实证 (ACCUMULATED-LESSONS:288-289)
- 原则 3: 跟 §11.3 联合, 命名 (proposal) 跟 reality (实际) 失配 → 诚实标记

**跟 §1.2 诚实修正 联合**: 主动 标记 proposal 跟 actual 差异, 不等别人发现

### 4.2 正例 2: v2.0.6 4 工具 multi-tool — install.sh `--target=auto` evidence chain 完整

**模式**: v2.0.6 EPIC-057 4 ticket 闭环, install.sh `--target=auto` 检测 Claude/opencode/Codex/Gemini 4 工具 (file:line `scripts/install.sh:69-92`, `:139-141`)

**符合 3 原则**:
- 原则 1: 不问"4 工具 支持 吗", 改问"auto-detect 实测 哪几 个"
- 原则 2: file:line `scripts/install.sh:69-92` (4 工具 detection)
- 原则 3: 4 工具 验证 通过 (file:line `tests/integration/master-6d-recovery-test.sh:150`)

**跟 v2.0.2 反讽 治根 联合**: "跨平台" 命名 → v2.0.6 真正 4 工具, naming = reality

### 4.3 正例 3: v2.4.0 worktree 清理 — 48 worktree + 123 branches evidence 完整

**模式**: v2.4.0 P1-2 worktree 清理, 48 worktree + 123 branches, 5.5M disk freed (file:line `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:39-43`, `:165`)

**符合 3 原则**:
- 原则 1: 不问"清理 OK 吗", 改问"剩 几 个 worktree + 几 个 branches + 节省 几 M"
- 原则 2: `du -sh .claude/worktrees` 实测 5.5M + `git worktree list` 1 个
- 原则 3: 跟 v2.4.0 4 Rule 合并 0 实际变化 不同, worktree 清理 是 **实际 disk 节省**, naming = reality

**跟 §11.5 revert 跟反思 区别 联合**: worktree 清理 保留 (v2.4.1 没 revert), 跟 4 Rule 合并 反讽 不同

### 4.4 正例 4: v2.4.1 revert 闭环 — 4 合并 naming 跟 reality 失配 → revert

**模式**: v2.4.1 (commit `7f401f9`) revert v2.4.0 4 Rule 合并, 22 Rule 跟 v2.3.0 一致 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`, `confluence/decisions/PHASE-014-REVIEW-2026-06-18.md:168`)

**符合 3 原则**:
- 原则 1: 不问"4 合并 OK 吗", 改问"净价值 跨 release 验证 实测 几 %"
- 原则 2: file:line `PHASE-013-REFLECTION-2026-06-18.md:39-42` (67.0% 持平)
- 原则 3: 跨 release 验证 缺 → 视为 无效, 走 revert

**跟 §11.5 revert 跟反思 区别 联合**: revert 技术 行动 + 反思 战略 行动 闭环, 跟"诚实修正" 联合

### 4.5 正例 5: 26 .md wrappers 闭环 — Claude Code 2.1+ 实测 → 治根 BE-15

**模式**: v2.1.1 加 26 .md wrappers, Claude Code 2.1+ 优先 .md 格式, 治根 BE-15 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:440`, `:484`, `.claude/commands/kallax-ask.md:1-8`)

**符合 3 原则**:
- 原则 1: 不问"修了 吗", 改问"Claude Code 2.1+ slash command registry 实测 几 个 命令 OK"
- 原则 2: file:line `.claude/commands/kallax-ask.md:1-8`
- 原则 3: 主公 反馈 闭环 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:698` "主公 Unknown command 反馈" → v2.1.1 .md wrappers)

**跟 §11.3 0 实际变化 假动作 治根 联合**: v2.0.9-v2.0.11 0 实际变化 (改 .sh 表面) → v2.1.1 治根 (加 .md wrappers)

### 4.6 正例 6: v2.0.4 Master 6 维恢复 — v1.2.4 6→0 退步 反转

**模式**: v2.0.4 EPIC-056-C ⚠️ Master 6 维度恢复 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:472`, commit `7f88823`)

**符合 3 原则**:
- 原则 1: 不问"Master 强验证 work 吗", 改问"6 维度 L1-L6 各跑过 吗"
- 原则 2: file:line `docs/KALLAX-GLOSSARY.md:625-637` (Master 6 维验证)
- 原则 3: L1-L6 验证 通过, 净价值 +4.5% (62.5% → 67.0%) 实证

**跟 v2.0.3 11 KPI falsification 治根 联合**: 11 KPI 估数 → v2.0.4 6 维度 raw output 强制

### 4.7 正例 7: v2.3.0 pre-commit ALLOWED_PATTERNS `^jira/` — 1 line diff 闭环 BE-14

**模式**: v2.3.0 pre-commit ALLOWED_PATTERNS 加 `^jira/`, 1 line diff, 治根 BE-14 `--no-verify` workaround 反复 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:486`, `:337`, commit `7db6107`)

**符合 3 原则**:
- 原则 1: 不问"pre-commit work 吗", 改问"`--no-verify` workaround 反复 几 次"
- 原则 2: file:line `scripts/hooks/pre-commit:ALLOWED_PATTERNS`
- 原则 3: 1 line diff evidence + 0 `--no-verify` 闭环

**跟 BE-14 治根 联合**: "Todo 1-5 --no-verify workaround 反复" → v2.3.0 `^jira/` 治根

---

## 5. 验证方法 (跟 Master 6 维 L6 诚实 联合)

### 5.1 Master 6 维度验证 (file:line `docs/KALLAX-GLOSSARY.md:625-637`)

| L# | 验证内容 | 命令 | 跟 Fact-Forcing 联合 |
|---|---|---|---|
| **L1** | git log | `git log --oneline -5` | commit 存在? sha 是什么? |
| **L2** | git show | `git show <sha>` | diff 内容? file:line 是什么? |
| **L3** | 跑测试 | `npm test` / language-equivalent | work? raw test output? |
| **L4** | preflight | `bash scripts/verify/check-fact-forcing-preflight.sh` | anti-fab 通过? 0 fail? |
| **L5** | 边界 | `git diff --name-only` | file scope 合规? |
| **L6** | 诚实 | raw test output review | 不接受 "should work" / "looks correct" |

### 5.2 4-Level Fact-Forcing (file:line `docs/KALLAX-GLOSSARY.md:641-651`)

| L# | 内容 | 跟 Fact-Forcing 联合 |
|---|---|---|
| **L1 existence** | files exist in git diff | no phantom references |
| **L2 substance** | real logic, no stubs | no `TODO` in critical paths |
| **L3 wiring** | correct imports/exports | type compatibility |
| **L4 data flow** | integration tests pass | E2E coverage |

### 5.3 闭环验证 checklist (跟 §1.5 闭环 联合)

- [ ] evidence chain 3 件套 (file:line / 命令输出 / 代码位置)
- [ ] 跨 release 验证 (不只 落地 commit)
- [ ] raw test output (不接受 "should work")
- [ ] 反讽 检测 (命名 跟 reality 是否一致)
- [ ] 0 实际变化 检测 (0 增命令 + 净价值 持平 + 0 跨 release 验证 = 0 实际变化)
- [ ] §1.2 诚实修正 联合 (主动 标记 proposal 跟 actual 差异)

---

## 6. 撤销方法 (跟 3 原则 1:1 联合)

### 6.1 撤销 原则 1 (不问 "确定吗")

**触发**: AI 自报 "X OK" 但 缺 evidence

**撤销步骤**:
1. 停止 接受 AI 自报, 改问 "证据在哪"
2. 要求 file:line / 命令输出 / 代码位置
3. 缺 evidence → 视为 无效

**KALLAX 实证** (跟 BE-15 联合): v2.0.9-v2.0.11 改 .sh 表面 → 主公反馈仍存 → 撤销 接受自报, 改问 Claude Code 2.1+ registry 实测 → v2.1.1 .md wrappers

### 6.2 撤销 原则 2 (要求具体证据)

**触发**: AI 给 "证据" 但 是 模糊 形容词 ("should work" / "looks correct")

**撤销步骤**:
1. 不接受 模糊 形容词
2. 要求 file:line 精确 引用 (`CLAUDE.md:295` 形式)
3. 要求 命令 实际 stdout (不只 "跑过")
4. 要求 代码位置 完整路径 + 行号

**KALLAX 实证** (跟 v2.0.5 honest mark 联合): proposal -3 → 实际 -2 诚实标记 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:288-289`)

### 6.3 撤销 原则 3 (无证据 视为无效)

**触发**: AI 断言 "X 已修复" 但 缺 evidence

**撤销步骤**:
1. 视为未修复, 不进入 merge queue
2. 要求 补 evidence (file:line / 命令输出 / 代码位置)
3. 补完 evidence → 重新 走 Master 6 维 L1-L6
4. 跨 release 验证 缺 → 走 revert

**KALLAX 实证** (跟 v2.4.1 revert 联合): v2.4.0 4 合并 净价值 +4% (无 跨 release 验证) → v2.4.1 revert (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md:284`)

---

## 7. 跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 联合

### 7.1 §11.3 定义回顾 (file:line `docs/KALLAX-GLOSSARY.md:764-778`)

**§11.3**: "'0 增命令 跟 净价值 持平' 是 0 实际变化, 跟'反讽' 联合, 需 诚实修正 — v2.4.0 4 合并 跟 v2.3.0 持平 0 增命令 0 重写主逻辑, '制造 0 实际改变 假动作' 反讽"

**§11.3 检测**:
- 0 增命令 (跨 release 累计 持平)
- 0 重写主逻辑 (落地 脚本 不变)
- 净价值 持平 (跨 release 验证)

### 7.2 Fact-Forcing 是 §11.3 的 检测器

**关系** (跟 §1.2 诚实修正 联合):
- **§11.3**: 描述 "0 实际变化 假动作" 模式
- **Fact-Forcing**: 提供 检测 + 撤销 工具

**怎么用** (跟 §11.3 联合):
- 检测到 "0 增命令 + 0 重写 + 净价值 持平" → 触发 §11.3 反讽
- §11.3 触发 → 走 Fact-Forcing 3 原则 验证 evidence chain
- evidence 缺 → 走 revert / 走 fix, 不 模糊 处理

### 7.3 闭环验证 (跟 §1.5 闭环 联合)

- ✅ **§12.1 章节**: KALLAX-GLOSSARY.md 落地 (1/1)
- ✅ **fact-forcing.md**: docs/process/ 落地 (1/1)
- ✅ **fact-forcing-examples.md**: confluence/decisions/ 落地 (1/1)
- ✅ **KPI 100% 落地**: 跟 Rule 9 X/Y 格式 联合 (跟 EPIC-059-D ticket AC #9 联合)

---

## 8. 跟 "诚实修正" + "反讽" + "翻篇&精进" 战略 联合

### 8.1 跟"诚实修正" 联合 (跟 §1.2 联合)

- **Fact-Forcing** = §1.2 诚实修正 的 **工具化**
- v2.0.5 honest mark 模式 = 主动 标记 proposal 跟 actual 差异, 不等别人发现
- v2.4.1 revert 模式 = 主动 反思 自己 v2.4.0 决策, 跟"诚实修正" 联合

### 8.2 跟"反讽" 联合 (跟 §1.1 联合)

- **Fact-Forcing** 是 治根 反讽 (命名 ≠ reality) 的 **手段**
- BE-15 "Unknown command" 反讽 → v2.1.1 .md wrappers 治根
- v2.4.0 4 合并 反讽 → v2.4.1 revert 治根

### 8.3 跟"翻篇&精进" 联合 (跟 §2.3 联合)

- **Fact-Forcing** 是 治根 "0 增命令 跟 净价值 持平" 的 **手段**
- 0 增命令 不等于 0 实际变化 (跟 §11.3 联合)
- Fact-Forcing 检测 0 实际变化 → 走 revert / 走 fix, 不 接受 模糊 命名

---

**跟 eket MASTER-RULES.md §2 联合, 借方法论 不借代码, 跟 KALLAX-GLOSSARY §12 联合, 跟 Master 6 维 L6 诚实 联合, 跟 v2.0.5/v2.0.6/v2.4.1 红线 revert 文档化 联合, 跟 v2.4.0 4 合并 假动作 联合, 跟"反讽" + "诚实修正" + "翻篇&精进" 战略 联合, 跟 KALLAX-GLOSSARY §11.3 0 实际变化 假动作 联合, 跟 KALLAX-GLOSSARY §1.1 §1.2 §1.5 §9.3 §11.5 联合, 跟 Rule 9 X/Y + Rule 11 Master 6 维 + Rule 18 KPI Falsification 黑名单 联合, 0 增 Rule, 0 重写, EPIC-059-D 落地**