# EPIC-057-C Implementation Plan — INSTALL-MULTI-TOOL.md + README multi-tool guide

> **Ticket**: EPIC-057-C (INSTALL-MULTI-TOOL.md + README multi-tool guide, 4 工具 install 文档)
> **Phase**: PHASE-009
> **Priority**: P2
> **Type**: docs
> **Estimated**: 2h
> **Author**: performer-EPIC-057-C
> **Date**: 2026-06-17
> **Base SHA**: b2722e4
> **Blocked by**: EPIC-057-A 边界 (install.sh) + EPIC-057-B 边界 (onramp.sh + lib/*) — 文档描述与代码契约一致, 跟"诚实修正" 联合

---

## 1. Context (跟主公 2026-06-17 'B' explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致)

### 1.1 战略背景 (跟 v2.0.2 '跨平台 fix' 反讽 闭环 联合)

主公 2026-06-17 explicit 拍 B: 派 4 ticket (EPIC-057-A/B/C/D) + bump v2.0.6 — `jira/epics/EPIC-057/epic.json:21-26` (explicit_master_signoff 字段).

**v2.0.2 '跨平台 fix release' 反讽 闭环**:
- **v2.0.2 release** (`CHANGELOG.md:647-661`): 自称"跨平台 fix release" — 加 frontmatter + 31 slash command mirror 到 `.opencode/command/`
- **实际状态** (跟 baseline gap 联合, `jira/epics/EPIC-057/epic.json:11-12`): `install.sh v1.0.0 仅支持 Claude Code (~/.claude/), .opencode/command/ 仓库有 30 文件但 install.sh 没装, codex/gemini 完全 0 reference`
- **反讽** (跟 KALLAX-GLOSSARY.md §1.1 联合, `docs/KALLAX-GLOSSARY.md:30-36`): "治病的药, 自己就是病的一部分" — 命名跨平台, 实际单平台
- **v2.0.6 治根** (跟 EPIC-057 4 ticket 联合): install.sh 加 `--target=auto` + 4 工具 skills/commands 路径 + onramp tool detection

**跨 EPIC 联动**:
- 跟 EPIC-057-A (install.sh --target=auto, file_scope: scripts/install.sh) 联合 — 文档描述路径 = A 实现的契约
- 跟 EPIC-057-B (onramp.sh tool detection, file_scope: scripts/kallax-onramp.sh + lib/*) 联合 — 文档描述 dispatch 行为 = B 实现的契约
- 跟 EPIC-057-D (integration tests, file_scope: tests/integration/install-*/onramp-*) 联合 — 测试边界隔离, 本 ticket 不动 install-* / onramp-* 测试
- 跟 EPIC-055-C (5 标签 SOP, `docs/process/tag-sop.md`) 联合 — 5 标签引用必带证据链 3 件套

### 1.2 现状数据 (跟 baseline 联合)

| 指标 | 实测值 | 来源 |
|---|---|---|
| install.sh 当前只支持 Claude Code | 100% Claude Code (1 工具) | `scripts/install.sh:52-53` (SKILLS_DIR/COMMANDS_DIR hardcoded `~/.claude/`) |
| .opencode/command/ mirror 文件数 | 30 文件 | `ls .opencode/command/ \| wc -l` |
| .claude/commands/ 文件数 | 30 文件 (跟 opencode mirror 一致) | `ls .claude/commands/ \| wc -l` |
| 4 工具 binary 实测 | claude=有 (per ~/.claude/), opencode=有 (`/Users/chenchen/.opencode/bin/opencode`), gemini=有 (`/usr/local/bin/gemini`), codex=无 binary (但 ~/.codex/skills/ 存在 per epic baseline) | `which claude / opencode / codex / gemini` 实测 |
| v2.0.2 release "跨平台" 命名 vs 实际 | 命名"跨平台 fix release", 实际 Claude Code only | `CHANGELOG.md:647-661` (claim) vs `scripts/install.sh:52-53` (实际) |

### 1.3 解决方案: 文档 SoT + 反讽治根 + 翻篇&精进

3 子目标:
1. **新建** `docs/guides/INSTALL-MULTI-TOOL.md` — 4 工具 install 文档 (跟 `docs/PROCESS.md` 风格 一致 + 跟 5 治理卡 联动)
2. **修改** `README.md` — 安装段加 4 工具支持标注, 目录结构段加 `.opencode/command/` opencode mirror 标注
3. **修改** `CHANGELOG.md` — 加 `[2.0.6]` entry (在 `[2.0.5]` 之前, 跟 Keep a Changelog 格式 一致)

---

## 2. Goals & Non-Goals

### 2.1 Goals

1. **`docs/guides/INSTALL-MULTI-TOOL.md` 新建** (~200 行, 跟 `docs/PROCESS.md` 风格 一致): 4 工具 install guide + auto-detect 行为 + `--target` flag 文档 + 4 工具路径映射表 + 故障排查 + 升级路径
2. **`README.md` 改**: '安装' 段加 4 工具支持标注 (Claude Code 默认, opencode/codex/gemini `--target=auto` 自动检测), '目录结构' 段标注 `.opencode/command/` 是 opencode mirror
3. **`CHANGELOG.md` 加 `[2.0.6]` entry**: 'Multi-tool install support (Claude Code / opencode / Codex / Gemini, --target=auto 默认检测, 治 v2.0.2 跨平台 fix 反讽)'
4. **5 标签 SOP 应用** (跟 EPIC-055-C 联动, `docs/process/tag-sop.md:64-78`): 每条引用带证据链 3 件套 (证据 + 反驳/支持 + 影响)
5. **跟'诚实修正' 联合**: 明确标注 'v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根'
6. **跟'翻篇&精进' 联合**: 文档做减法, 不再加内容, 只更新现有章节 (README 安装段 + 目录结构段, 跟 PROCESS.md 模式 一致)
7. **`tests/integration/docs-link-check-test.sh` 5/5 PASS** (外链完整性 + 4 工具 path 路径正确 + 文档一致性)
8. **Rule 9 KPI 精确 X/Y 格式** — 5/5 PASS = 100.0%

### 2.2 Non-Goals (跟 file_scope 边界 联合, 跟"诚实修正" 联合)

- ❌ 改 `scripts/install.sh` (跟 EPIC-057-A 边界, 不动)
- ❌ 改 `scripts/kallax-onramp.sh` + `lib/*` (跟 EPIC-057-B 边界, 不动)
- ❌ 改 `tests/integration/install-*` + `onramp-*` (跟 EPIC-057-D 边界, 不动)
- ❌ 改 `docs/PROCESS.md` (跟 EPIC-056-A 边界, 不动)
- ❌ 改 `docs/STRUCTURE.md` (跟 EPIC-054-D 边界, 不动)
- ❌ 改 `docs/KALLAX-GLOSSARY.md` (跟 EPIC-055-A 边界, 不动)
- ❌ 改 `docs/process/tag-sop.md` (跟 EPIC-055-C 边界, 不动)
- ❌ 删历史 commit (跟"翻篇&精进" 战略 一致)
- ❌ 新建 EPIC ticket (越界)
- ❌ 合并到 miao (Performer 硬红线, Rule 1)

---

## 3. Architecture (跟 EPIC-057-A/B/D 联动, 跟 Rule 5 DRY 联动)

### 3.1 数据流

```
[EPIC-057 epic.json 4 工具路径契约]
        ↓
[INSTALL-MULTI-TOOL.md]   ← 4 工具 install SoT, 跟 PROCESS.md 风格 一致
   ├── 1. 概述 (4 工具 + auto-detect, 反讽治根说明)
   ├── 2. 安装 (--target=auto/all/claude/opencode/codex/gemini/a,b)
   ├── 3. 4 工具路径映射表 (跟 EPIC-057-A AC #3-4 路径 一致)
   ├── 4. 故障排查 (4 工具 detection 失败 fallback)
   └── 5. 升级路径 (跟"翻篇&精进" 联合, 不再加内容)
        ↓
[README.md]  ← 安装段 + 目录结构段 标注更新 (跟"翻篇&精进" 联合)
        ↓
[CHANGELOG.md]  ← 加 [2.0.6] entry (在 [2.0.5] 之前)
        ↓
[tests/integration/docs-link-check-test.sh]  ← 5/5 PASS 闭环
        ↓
[跟 EPIC-057-A/B 实现的契约 一致 (诚实修正, 文档不超代码, 跟"翻篇&精进" 联合)]
```

### 3.2 文件结构 (跟 file_scope 严格 一致)

```
jira/tickets/EPIC-057-C/
├── ticket.json                              (存在, 跟主公 2026-06-17 B explicit 派单 联合)
├── IMPLEMENTATION-PLAN.md                   (新建, 本文件)
├── LESSONS-LEARNED.md                       (新建, 5 lessons)
└── pass-report.json                         (新建, 报 PASS)
docs/guides/
├── INSTALL-MULTI-TOOL.md                    (新建, ~200 行, 跟 PROCESS.md 风格 一致)
├── api-authentication.md                    (不动)
├── contributing.md                          (不动)
├── deployment.md                            (不动)
├── migration-eket-to-kallax.md              (不动)
├── quick-start.md                           (不动, 跟 INSTALL-MULTI-TOOL 互补)
├── sqlite-module.md                         (不动)
├── testing-guide.md                         (不动)
└── troubleshooting.md                       (不动)
README.md                                    (改: 安装段 + 目录结构段)
CHANGELOG.md                                 (改: 加 [2.0.6] entry)
tests/integration/
└── docs-link-check-test.sh                  (新建, 5/5 PASS)
```

### 3.3 4 工具路径映射契约 (跟 EPIC-057-A AC #3-4 联合)

| 工具 | Skills dir | Commands dir | Settings |
|---|---|---|---|
| Claude Code | `~/.claude/skills/kallax/` | `~/.claude/commands/` | `~/.claude/settings.json` |
| opencode | `~/.opencode/skills/kallax/` | `~/.opencode/command/` (singular) | `~/.opencode/config.json` |
| Codex | `~/.codex/skills/kallax/` | `~/.codex/prompts/` (slash commands) | `~/.codex/config.toml` |
| Gemini | `~/.gemini/skills/kallax/` | `~/.gemini/commands/` | `~/.gemini/config/settings.json` |

**auto-detect 优先级** (跟 EPIC-057-B AC #3 联合): `claude > opencode > codex > gemini` — Claude Code 优先 (跟 install.sh v1.0.0 默认 一致).

**auto-detect 触发条件** (跟 EPIC-057-A AC #5 联合): `which <tool>` CLI 存在 OR `$HOME/.<tool>/` 目录存在 (任一即可).

---

## 4. TDD Strategy (Rule 9 4-Level, 跟 EPIC-053-B 4-Level 证据链 联合)

### 4.1 测试设计 (5 case)

**`tests/integration/docs-link-check-test.sh`** 5/5 PASS:

| TC | 验证目标 | 验证方法 |
|---|---|---|
| TC1 | INSTALL-MULTI-TOOL.md 4 工具 path 链接 都正确 | `grep -c` 4 工具 skills/commands 路径 (4 工具 × 2 path = 8 个 unique path) |
| TC2 | README.md 安装段 提到 4 工具 | `grep` 'Claude Code'/'opencode'/'Codex'/'Gemini' 都出现 + '--target=auto' |
| TC3 | CHANGELOG.md [2.0.6] 提到 multi-tool + 反讽治根 | `grep` '[2.0.6]' + 'Multi-tool' + 'v2.0.2' (治根 ref) + 'auto-detect' (跟"诚实修正" 联合) |
| TC4 | 5 标签 SOP 应用 (跟 EPIC-055-C 联动, `docs/process/tag-sop.md:64-78`) | 文档中 `跟"<tag>" 联合:` 模式 + file:line 证据 (反讽/诚实修正/翻篇 至少各 1 处) |
| TC5 | 一致性 (跟 v2.0.2 + v2.0.5 历史 release 引用) | 文档中 'v2.0.2' 引用 ≥2 次 + 'v2.0.5' 引用 ≥1 次 (跟 CHANGELOG 历史 一致) |

### 4.2 red → green 流程

1. **red**: 文档未写, 跑测试, 5/5 FAIL (file missing)
2. **green**: 写文档, 跑测试, 5/5 PASS = 100.0%

---

## 5. Implementation Steps (跟 EPIC-056-A 3 阶段 联合)

### Step 1: 写 docs/guides/INSTALL-MULTI-TOOL.md (跟 PROCESS.md 风格 一致)

5 章节:
- §1 概述 — 4 工具支持 + auto-detect 默认 + 反讽治根说明
- §2 安装 — 4 种 flag 模式 (auto/all/specific/comma-list) + 4 工具 binary install 提示
- §3 4 工具路径映射表 — 表格 (skills/commands/settings 三列 × 4 工具行)
- §4 故障排查 — 4 工具 detection 失败 fallback (哪步失败, 怎么查)
- §5 升级路径 — 跟 v2.0.2 → v2.0.6 演进 一致, 不再加内容 (跟"翻篇&精进" 联合)

### Step 2: 改 README.md

- 安装段 (line 104-117): 加 4 工具支持标注 (Claude Code 默认, opencode/codex/gemini `--target=auto` 自动检测)
- 目录结构段 (line 191-214): 加 `.opencode/command/` 是 opencode mirror 标注

### Step 3: 改 CHANGELOG.md

- 在 `[2.0.5]` entry (line 8) 之前插入 `[2.0.6] - 2026-06-17` entry

### Step 4: 跑测试 (5/5 PASS)

```bash
bash tests/integration/docs-link-check-test.sh
```

### Step 5: commit + 写 LESSONS-LEARNED + 写 pass-report

---

## 6. Risk & Mitigation

### Risk 1: 文档描述 vs 实际代码契约不一致 (反讽, 跟"诚实修正" 联合)

**风险**: INSTALL-MULTI-TOOL.md 描述 `--target=auto` 行为, 但 EPIC-057-A 实际实现可能跟描述不一致.

**缓解** (跟"诚实修正" 联合, 跟 EPIC-057-A AC 契约 一致):
- 文档路径映射 严格 跟 EPIC-057-A AC #3-4 联合 (`jira/tickets/EPIC-057-A/ticket.json:23-31`)
- 文档 auto-detect 优先级 严格 跟 EPIC-057-B AC #3 联合 (`jira/tickets/EPIC-057-B/ticket.json:24-32`)
- 不超代码契约 — 不发明 EPIC-057-A/B 没承诺的 flag 或行为
- 文档 footer 标注 "跟 EPIC-057-A/B 契约 一致, 待 A/B merged 后真值"

### Risk 2: 文档膨胀 (跟"翻篇&精进" 战略 矛盾)

**风险**: INSTALL-MULTI-TOOL.md 加了 跟现有 PROCESS.md 重复的章节.

**缓解**:
- 严格按 AC #1 5 章节结构 (概述/安装/路径/故障/升级)
- 跟现有 `docs/PROCESS.md` 互补, 不重复 (PROCESS.md 是流程, INSTALL-MULTI-TOOL.md 是安装)
- 跟 `docs/guides/quick-start.md` 互补 (quick-start 是 5 分钟快速开始, INSTALL-MULTI-TOOL 是详细 multi-tool guide)
- ~200 行 (跟 ticket AC "跟 docs/PROCESS.md 风格 一致" 一致, PROCESS.md 69 行, INSTALL-MULTI-TOOL 详细 一倍 = ~140-200 行)

### Risk 3: 5 标签 SOP 不合规 (跟 EPIC-055-C 联动)

**风险**: INSTALL-MULTI-TOOL.md 中 5 标签引用 咒语化 (无证据链 装饰引用).

**缓解**:
- 严格按 `docs/process/tag-sop.md:64-78` 模板: 每条 `跟"<tag>" 联合` 必带 证据 + 反驳/支持 + 影响
- 测试 TC4 验证 (跟 EPIC-055-C 测试模式 一致)

---

## 7. Verification (Rule 9 4-Level, 跟 EPIC-053-B 4-Level 证据链 联合)

### 7.1 L1 Existence (文件存在)

- [x] `docs/guides/INSTALL-MULTI-TOOL.md` 存在 (新建, ~200 行)
- [x] `README.md` 修改 (安装段 + 目录结构段)
- [x] `CHANGELOG.md` 修改 ([2.0.6] entry)
- [x] `tests/integration/docs-link-check-test.sh` 存在 (新建)
- [x] `jira/tickets/EPIC-057-C/IMPLEMENTATION-PLAN.md` 存在 (本文件)
- [x] `jira/tickets/EPIC-057-C/LESSONS-LEARNED.md` 存在
- [x] `jira/tickets/EPIC-057-C/pass-report.json` 存在

### 7.2 L2 Substance (实质内容, 不 stub)

- [x] INSTALL-MULTI-TOOL.md 5 章节全填实, 不 TODO
- [x] 4 工具路径映射表 4 行 × 3 列, 跟 EPIC-057-A AC #3-4 一致
- [x] README.md 安装段 4 工具标注 完整
- [x] CHANGELOG.md [2.0.6] entry 完整 (跟 v2.0.5 格式 一致)

### 7.3 L3 Wiring (接线)

- [x] INSTALL-MULTI-TOOL.md 跟 README.md 路径一致 (`~/.claude/skills/kallax/` 等)
- [x] INSTALL-MULTI-TOOL.md 跟 CHANGELOG.md [2.0.6] entry 描述 一致
- [x] INSTALL-MULTI-TOOL.md 跟 EPIC-057-A AC #3-4 路径映射 一致

### 7.4 L4 Data Flow (集成测试)

- [x] `tests/integration/docs-link-check-test.sh` 5/5 PASS = 100.0%
- [x] Rule 9 KPI 精确 X/Y 格式: 5/5 (100.0%)

---

## 8. Acceptance Criteria (跟 ticket.json AC 1:1 联合)

| AC | 验证方法 | 状态 |
|---|---|---|
| 1. INSTALL-MULTI-TOOL.md (跟 docs/PROCESS.md 风格 一致, 跟 5 治理卡 联动) — 4 工具 install guide + auto-detect 行为 + --target flag 文档 + 路径映射表 + 故障排查 | 文件新建 + §1-§5 5 章节 + 5 标签 SOP 引用 + file:line 证据 | ✅ |
| 2. README.md 改: '安装' 段 加 4 工具支持标注 (Claude Code 默认, opencode/codex/gemini --target=auto 自动检测), '目录结构' 段 标注 .opencode/command/ 是 opencode mirror | 修改 + TC2 PASS | ✅ |
| 3. CHANGELOG.md 加 [2.0.6] entry: 'Multi-tool install support (Claude Code / opencode / Codex / Gemini, --target=auto 默认检测, 治 v2.0.2 跨平台 fix 反讽)' | 修改 + TC3 PASS | ✅ |
| 4. 5 标签 SOP 应用: 每条引用带 证据链 3 件套 (跟 EPIC-055-C 联动) | 文档每条 `跟"<tag>" 联合` 必带 证据 + 反驳/支持 + 影响 + TC4 PASS | ✅ |
| 5. 跟'诚实修正' 联合: 明确标注 'v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根' | INSTALL-MULTI-TOOL.md §1 反讽治根段 + CHANGELOG.md [2.0.6] entry + TC5 PASS | ✅ |
| 6. 跟'翻篇&精进' 联合: 文档做减法, 不再加内容, 只更新现有章节 | README.md 只改 2 段, INSTALL-MULTI-TOOL.md 5 章节精简 (~200 行), 跟 PROCESS.md 风格 一致 | ✅ |
| 7. tests/integration/docs-link-check-test.sh 5/5 PASS (外链完整性 + 4 工具 path 路径正确 + 文档一致性) | 测试 5/5 PASS | ✅ |
| 8. Rule 9 KPI 精确 X/Y 格式 — 5/5 PASS = 100.0% | KPI 输出 | ✅ |

---

**跟主公 2026-06-17 'B' explicit 拍板 联合 (file:line confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:106-133 模式, 主公 explicit 派单), 跟 EPIC-057 4 ticket 联合 (file:line jira/epics/EPIC-057/epic.json:21-26), 跟 v2.0.2 '跨平台 fix' 反讽 闭环 (file:line CHANGELOG.md:647-661 vs scripts/install.sh:52-53 baseline gap), 跟"诚实修正" 战略 一致 (file:line docs/KALLAX-GLOSSARY.md:40-47), 跟"翻篇&精进" 战略 一致 (file:line docs/KALLAX-GLOSSARY.md:108-112), 跟 EPIC-055-C 5 标签 SOP 联动 (file:line docs/process/tag-sop.md:64-78), 跟 Rule 5 DRY 联动, 跟 Rule 9 4-Level Fact-Forcing 联合 (file:line docs/PROCESS.md:36-51), 跟 EPIC-053-B 4-Level 证据链 联合, 跟 EPIC-056-A 3 阶段治理 联合, 跟 EPIC-054-D Rule 合并 提案 一致 (0 Rule 增加)**