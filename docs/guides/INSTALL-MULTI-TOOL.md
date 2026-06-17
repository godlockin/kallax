# KALLAX 多工具安装指南 (v2.0.6 — 4 工具 Skills/Commands 部署)

> **跟主公 2026-06-17 'B' explicit 拍板 联合, 跟 v2.0.2 '跨平台 fix release' 反讽 闭环, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致.**
> **跟 EPIC-057-A (install.sh 实现, file:line `jira/tickets/EPIC-057-A/ticket.json:23-31`) 契约 一致, 跟 EPIC-057-B (onramp.sh tool detection, file:line `jira/tickets/EPIC-057-B/ticket.json:24-32`) 契约 一致.**

## 1. 概述

KALLAX v2.0.6 起, install.sh 支持 **4 工具** 统一安装:

| 工具 | 角色 | 实测 |
|---|---|---|
| Claude Code | Conductor / Performer 默认 (v1.0.0 起) | `~/.claude/` (dir 已存在) |
| opencode | 跨平台 (per v2.0.2 slash command mirror) | `/Users/chenchen/.opencode/bin/opencode` (v1.17.7) |
| Codex | 跨平台 | `~/.codex/skills/` (目录存在, binary 需安装) |
| Gemini | 跨平台 | `/usr/local/bin/gemini` (v0.22.2) |

### 1.1 反讽治根 — v2.0.2 → v2.0.6 闭环

跟"反讽" 联合:
- **证据**: `CHANGELOG.md:647-661` (v2.0.2 release notes 自称"跨平台 fix release")
- **反驳/支持**: `scripts/install.sh:52-53` (v1.0.0 hardcoded `~/.claude/`, 只支持 Claude Code); `jira/epics/EPIC-057/epic.json:11-12` (baseline gap: "opencode 30 文件但 install.sh 没装, codex/gemini 0 reference")
- **影响**: v2.0.2 release 命名"跨平台"实际"单平台" — 命名跟实现不一致 (跟 KALLAX-GLOSSARY.md §1.1 反讽定义 联合, file:line `docs/KALLAX-GLOSSARY.md:30-36`); v2.0.6 install.sh 加 `--target=auto` 检测 + 4 工具 skills/commands 路径映射, 治根

跟"诚实修正" 联合:
- **证据**: 本文档 §1.1 (反讽闭环说明) + CHANGELOG.md `[2.0.6]` entry (标注"治 v2.0.2 跨平台 fix 反讽")
- **反驳/支持**: 看到反讽不装看不见 — 文档明确标注 v2.0.2 gap, 不模糊处理
- **影响**: 主公信任↑, 治理闭环 (跟 KALLAX-GLOSSARY.md §1.2 诚实修正定义 联合, file:line `docs/KALLAX-GLOSSARY.md:40-47`)

### 1.2 auto-detect 默认行为

`--target=auto` 是 **默认** 行为:
- 检测顺序: `claude > opencode > codex > gemini` (跟 EPIC-057-B AC #3 联合, file:line `jira/tickets/EPIC-057-B/ticket.json:27`)
- 检测触发: `which <tool>` CLI 存在 OR `$HOME/.<tool>/` 目录存在 (任一即可, 跟 EPIC-057-A AC #5 联合, file:line `jira/tickets/EPIC-057-A/ticket.json:26`)
- 默认只装检测到的 1 个工具 (Claude Code 优先)

---

## 2. 安装

### 2.1 默认安装 (auto-detect, 1 工具)

```bash
# 克隆仓库
git clone https://github.com/your-org/kallax.git
cd kallax

# 默认 --target=auto 检测 → 装到检测到的工具 (Claude Code 优先)
./scripts/install.sh
```

**输出预期**: 检测到 Claude Code → 装 `~/.claude/skills/kallax/` + `~/.claude/commands/`.

### 2.2 显式单工具安装

```bash
# 显式装 Claude Code
./scripts/install.sh --target=claude

# 显式装 opencode
./scripts/install.sh --target=opencode

# 显式装 Codex
./scripts/install.sh --target=codex

# 显式装 Gemini
./scripts/install.sh --target=gemini
```

### 2.3 多工具安装 (逗号分隔)

```bash
# 装 Claude Code + opencode (2 工具)
./scripts/install.sh --target=claude,opencode

# 装 Codex + Gemini (2 工具)
./scripts/install.sh --target=codex,gemini
```

### 2.4 强制全工具安装

```bash
# --target=all 强制全装 (不管 detection 失败, 4 工具都装)
./scripts/install.sh --target=all
```

### 2.5 Interactive 模式 (跟"诚实修正" 联合)

```bash
# --interactive 进入 prompt, 让用户选择 4 工具
./scripts/install.sh --interactive
```

跟"诚实修正" 联合:
- **证据**: 本文档 §2.5 (interactive prompt 兜底)
- **反驳/支持**: 检测失败 fallback — 不假装成功, 主动问用户
- **影响**: 避免"4 工具都检测失败但 install.sh 报 PASS" (跟 BE-15 假 PASS 模式 联合, file:line `docs/KALLAX-GLOSSARY.md:198-201`)

---

## 3. 4 工具路径映射表

跟 EPIC-057-A AC #3-4 契约 一致 (file:line `jira/tickets/EPIC-057-A/ticket.json:23-26`):

| 工具 | Skills dir | Commands dir | Settings |
|---|---|---|---|
| Claude Code | `~/.claude/skills/kallax/` | `~/.claude/commands/` | `~/.claude/settings.json` |
| opencode | `~/.opencode/skills/kallax/` | `~/.opencode/command/` (singular) | `~/.opencode/config.json` |
| Codex | `~/.codex/skills/kallax/` | `~/.codex/prompts/` (slash commands) | `~/.codex/config.toml` |
| Gemini | `~/.gemini/skills/kallax/` | `~/.gemini/commands/` | `~/.gemini/config/settings.json` |

**注意**:
- opencode commands dir 是 **singular** `~/.opencode/command/` (不是 `commands/`), 跟 v2.0.2 release 30 文件 mirror 路径 一致 (`ls .opencode/command/` 验证)
- Codex commands dir 是 `~/.codex/prompts/` (slash commands) — Codex 把"command" 概念叫"prompt"
- Gemini commands dir 跟 Claude Code 一致 (`~/.gemini/commands/`), 但 skills dir 跟其他工具不同 (`~/.gemini/skills/kallax/`)

### 3.1 路径存在性校验

跟"翻篇&精进" 联合:
- **证据**: 本文档 §3 路径映射表 + EPIC-057-A AC #3-4 契约
- **反驳/支持**: 4 工具路径 实测 (opencode/gemini 已装, claude 全支持, codex 只有 dir 没 binary), 不发明路径
- **影响**: 文档不超代码契约, 跟 EPIC-057-A/B 实现 严格 一致 (跟"诚实修正" 联合, file:line `docs/KALLAX-GLOSSARY.md:40-47`)

---

## 4. 故障排查

### 4.1 4 工具都检测失败

**症状**: install.sh 报 `No AI CLI tool detected`.

**排查步骤**:
1. 检查 binary: `which claude opencode codex gemini`
2. 检查 dir: `ls -la ~/.claude ~/.opencode ~/.codex ~/.gemini`
3. 至少需要 1 个 binary 或 1 个 dir 存在
4. 都没装 → 装 Claude Code (推荐): `curl -fsSL https://claude.ai/install.sh | bash`

跟"诚实修正" 联合:
- **证据**: 本文档 §4.1 (4 工具都失败排查)
- **反驳/支持**: detect 失败 fallback — exit 1 + suggestion "install claude" (跟 EPIC-057-D AC #8 联合, file:line `jira/tickets/EPIC-057-D/ticket.json:35`)
- **影响**: 不假装成功, 主动给安装建议, 跟 BE-15 假 PASS 模式 反向

### 4.2 单工具 SKILL.md 缺失

**症状**: verify_install 报 `SKILL.md missing — skills won't load`.

**排查步骤**:
1. 检查源: `ls .claude/skills/kallax/SKILL.md`
2. 检查目标: `ls ~/.claude/skills/kallax/SKILL.md`
3. 重新安装: `./scripts/install.sh --target=claude`

### 4.3 配置 permissions 失败

**症状**: `jq not available — add this to ~/.claude/settings.json manually`.

**排查步骤**:
1. 装 jq: `brew install jq`
2. 重新跑 install.sh

### 4.4 verify_install 输出 4 工具分项 status

跟 EPIC-057-A AC #6 联合 (file:line `jira/tickets/EPIC-057-A/ticket.json:27-28`):

```
=== Verification ===

[OK] Claude Code: ~/.claude/skills/kallax/ (89 files)
     Commands: ~/.claude/commands/ (30 files)
     Settings: ~/.claude/settings.json (auto-permission configured)

[OK] opencode: ~/.opencode/skills/kallax/ (89 files)
     Commands: ~/.opencode/command/ (30 files)
     Settings: ~/.opencode/config.json (auto-permission configured)

[SKIP] Codex: ~/.codex/skills/kallax/ (not detected, run --target=codex to install)
[SKIP] Gemini: ~/.gemini/skills/kallax/ (not detected, run --target=gemini to install)

Restart Claude Code or open a new window. Then type /kallax-start
```

---

## 5. 升级路径

### 5.1 从 v2.0.5 升级到 v2.0.6

```bash
# 重新跑 install.sh (upgrade mode 自动检测)
./scripts/install.sh --upgrade
```

跟 EPIC-057-A AC #1 联合 (file:line `jira/tickets/EPIC-057-A/ticket.json:23`): `--upgrade` 跟 fresh install 等价 + changelog 输出.

### 5.2 从 v2.0.2 '跨平台 fix release' 升级

跟"翻篇&精进" 联合:
- **证据**: 本文档 §5.2 (v2.0.2 → v2.0.6 升级) + CHANGELOG.md `[2.0.6]` entry
- **反驳/支持**: v2.0.2 自称"跨平台" 但 install.sh 只支持 Claude Code — v2.0.6 治根, 不在 v2.0.2 命名上纠结 (跟"翻篇&精进" 战略 一致, file:line `docs/KALLAX-GLOSSARY.md:108-112`)
- **影响**: v2.0.2 release 命名 不删 (历史 commit 不可改), v2.0.6 治根 + 文档明确标注 gap

### 5.3 跟"翻篇&精进" 联合 — 不再加内容

跟"翻篇" 联合:
- **证据**: 本文档 5 章节 (概述/安装/路径/故障/升级) — 跟 docs/PROCESS.md 风格 一致, 不重复
- **反驳/支持**: 跟 docs/guides/quick-start.md 互补 (quick-start 5 分钟快速开始, INSTALL-MULTI-TOOL 详细 multi-tool guide); 跟 docs/PROCESS.md 互补 (PROCESS.md 流程, INSTALL-MULTI-TOOL.md 安装)
- **影响**: 文档体量 不增, 跟"翻篇&精进" 战略 一致 (跟 EPIC-054-D Rule 合并 模式 一致, file:line `docs/PROCESS.md:62-66` A+B Review 段)

---

## 附录: 跟其他文档的关系

- **`README.md`**: 安装段 + 目录结构段 已加 4 工具支持标注 (跟 AC #2 联合)
- **`CHANGELOG.md [2.0.6]`**: 加 entry "Multi-tool install support (Claude Code / opencode / Codex / Gemini, --target=auto 默认检测, 治 v2.0.2 跨平台 fix 反讽)" (跟 AC #3 联合)
- **`docs/PROCESS.md`**: 流程文档, 不重复
- **`docs/guides/quick-start.md`**: 5 分钟快速开始, 不重复
- **`docs/process/tag-sop.md`**: 5 标签 SOP, 本文档每条标签引用遵循证据链 3 件套 (跟 EPIC-055-C 联动, file:line `docs/process/tag-sop.md:64-78`)
- **`jira/tickets/EPIC-057-A/ticket.json`**: install.sh 实现契约, 本文档路径映射 严格 跟 AC #3-4 一致
- **`jira/tickets/EPIC-057-B/ticket.json`**: onramp.sh tool detection 契约, 本文档 auto-detect 行为 严格 跟 AC #3 一致
- **`jira/tickets/EPIC-057-D/ticket.json`**: integration tests 契约, 跟本文档 §4 故障排查 一致

---

**跟主公 2026-06-17 'B' explicit 拍板 联合 (file:line `jira/epics/EPIC-057/epic.json:21-26`), 跟 EPIC-057 4 ticket 联合 (file:line `jira/epics/EPIC-057/epic.json:27-55`), 跟 v2.0.2 '跨平台 fix' 反讽 闭环 (file:line `CHANGELOG.md:647-661`), 跟"诚实修正" 战略 一致 (file:line `docs/KALLAX-GLOSSARY.md:40-47`), 跟"翻篇&精进" 战略 一致 (file:line `docs/KALLAX-GLOSSARY.md:108-112`), 跟 EPIC-055-C 5 标签 SOP 联动 (file:line `docs/process/tag-sop.md:64-78`), 跟 Rule 5 DRY 联动, 跟 Rule 9 4-Level Fact-Forcing 联合 (file:line `docs/PROCESS.md:36-51`), 跟 EPIC-053-B 4-Level 证据链 联合, 跟 EPIC-056-A 3 阶段治理 联合**