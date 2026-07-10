# KALLAX 多工具安装指南 (v2.2.0 — 10 工具 + Single Source Symlink 模式)

> **跟主公 2026-06-17 explicit 派单 联合, 跟 v2.1.1 8 工具 → v2.2.0 10 工具 升级, 跟"single source" 模式 联合, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致.**
> **跟主公"把kallax安装到能让本地 claude code、trae、antigravity、opencode 正常调用, 最好使用一份skills/命令文件支持所有的引用" explicit 派单 联合.**

## 1. 概述

KALLAX v2.2.0 起, install.sh 支持 **10 工具** 统一安装 + **single source 模式**:

| # | 工具 | 角色 | 实测 | 支持度 |
|---|---|---|---|---|
| 1 | Claude Code | Conductor / Performer 默认 (v1.0.0 起) | `~/.claude/` (dir 已存在) | full |
| 2 | **Trae** (新) | ByteDance AI IDE | `~/.trae/` (skills + commands) | full |
| 3 | **Antigravity** (新) | Google AI IDE | `~/.antigravity/` (skills + commands) | full |
| 4 | opencode | 跨平台 (per v2.0.2 slash command mirror) | `~/.opencode/` (v1.17.7) | full |
| 5 | Codex | 跨平台 | `~/.codex/skills/` (binary 需安装) | full |
| 6 | Gemini | 跨平台 | `/usr/local/bin/gemini` (v0.22.2) | full |
| 7 | Cursor (v2.1.0) | AI editor (VS Code fork) | `~/.cursor/` | full |
| 8 | Windsurf (v2.1.0) | AI editor (Codeium) | `~/.codeium/windsurf/` | full |
| 9 | Aider (v2.1.0) | CLI pair programming | `~/.aider/` (待装) | config |
| 10 | Continue (v2.1.0) | VS Code AI extension | `~/.continue/` (待装) | config |

**Support levels**:
- `full` — skills + slash commands 都装 (跟现有 4 工具 一致)
- `config` — skills 路径 reference 写进 config 文件 (因 aider/continue 没有 slash command API)

### 1.1 反讽从根源修复 — v2.0.2 → v2.0.6 → v2.1.0 渐进闭环

跟"反讽" 联合:
- **证据 (v2.0.2)**: `CHANGELOG.md:647-661` (release notes 自称"跨平台 fix release", 实际只 Claude Code)
- **证据 (v2.0.6)**: install.sh 加 `--target=auto` 检测 + 4 工具 skills/commands 路径映射 (opencode 30 文件 mirror)
- **证据 (v2.1.0)**: install.sh 加 4 工具 (cursor/windsurf/aider/continue) + 完整 wizard (5 step) + UI 改进
- **影响**: 命名跟实现 一致 (跟 KALLAX-GLOSSARY.md §1.1 反讽定义 联合, file:line `docs/KALLAX-GLOSSARY.md:30-36`)
- **诚实修正**: 文档明确标注 v2.0.2 gap + v2.0.6 从根源修复 + v2.1.0 扩 4 工具, 不模糊处理

### 1.2 auto-detect 默认行为

`--target=auto` 是 **默认** 行为:
- 检测顺序: `claude > opencode > codex > gemini > cursor > windsurf > aider > continue`
- 检测触发: `which <tool>` CLI 存在 OR `$HOME/.<tool>/` 目录存在 (任一即可)
- 默认只装检测到的工具 (按 priority 顺序)

### 1.3 Wizard 5-step 流程 (v2.1.0 新)

`--wizard` (alias `--interactive`) 启动 step-by-step 安装:

1. **Step 1/5** — Tool detection: 列出 8 工具 + ✓/✗ 检测状态
2. **Step 2/5** — Select targets: detected / all 8 / custom (3 选项)
3. **Step 3/5** — Install paths: 列出每个工具的 skills/commands/settings 路径 + 默认接受
4. **Step 4/5** — Upgrade diff: 旧版本号 → 新版本号 预览 (如有)
5. **Step 5/5** — Dry-run preview + final confirm: 列出要装的内容, 默认 Y 接受

每步都有合理默认 — 直接按 Enter 接受。

---

## 2. 安装

### 2.1 默认安装 (auto-detect, 检测到的工具)

```bash
# 克隆仓库
git clone https://github.com/your-org/kallax.git
cd kallax

# 默认 --target=auto 检测 → 装到检测到的工具 (按 priority 顺序)
./scripts/install.sh
```

**输出预期**: 检测到 Claude Code + opencode → 装 `~/.claude/skills/kallax/` + `~/.opencode/skills/kallax/` + 各自 commands dir.

### 2.2 显式单工具安装 (10 工具可选)

```bash
# Full support tools
./scripts/install.sh --target=claude
./scripts/install.sh --target=trae            # 新 (v2.2.0)
./scripts/install.sh --target=antigravity     # 新 (v2.2.0)
./scripts/install.sh --target=opencode
./scripts/install.sh --target=codex
./scripts/install.sh --target=gemini
./scripts/install.sh --target=cursor
./scripts/install.sh --target=windsurf

# Config-only tools
./scripts/install.sh --target=aider
./scripts/install.sh --target=continue
```

### 2.3 多工具安装 (逗号分隔)

```bash
# 装 Claude Code + trae + antigravity + opencode (4 工具, single source 模式推荐)
./scripts/install.sh --symlink --target=claude,trae,antigravity,opencode

# 装 Claude Code + opencode + cursor (3 工具, 混合 full support)
./scripts/install.sh --target=claude,opencode,cursor

# 装 Codex + Gemini + Windsurf (3 工具, 混合 full support)
./scripts/install.sh --target=codex,gemini,windsurf

# 装全部 10 工具
./scripts/install.sh --target=claude,trae,antigravity,opencode,codex,gemini,cursor,windsurf,aider,continue
```

### 2.4 强制全工具安装

```bash
# --target=all 强制全装 10 工具 (不管 detection 失败)
./scripts/install.sh --target=all

# --target=all + --symlink 4 工具 single source 模式 (跟主公"用一份文件" 派单 联合, 推荐)
./scripts/install.sh --symlink --target=all
```

### 2.5 Wizard 模式 (5-step step-by-step, 跟"诚实修正" 联合)

```bash
# --wizard 进入 5-step step-by-step installer (推荐初次使用)
./scripts/install.sh --wizard

# --interactive 是 --wizard 的 alias (v2.0.x compat)
./scripts/install.sh --interactive
```

**5 步流程**:
```
═══ Step 1/5 — Tool Detection ═══
  ✓ claude
  ✓ opencode
  ✗ codex
  ✗ gemini
  ✓ cursor
  ...

═══ Step 2/5 — Select Target Tools ═══
  [1] Install for detected tools only (recommended)
  [2] Install for all 8 tools (force)
  [3] Custom selection (comma-separated: e.g. claude,cursor)
  Choose [1/2/3] (default: 1): _

═══ Step 3/5 — Install Paths ═══
  Default install paths: [列出]
  Accept defaults? [Y/n]: _

═══ Step 4/5 — Upgrade Diff Preview ═══
  claude: v2.0.6 → v2.1.0
  opencode: fresh install → v2.1.0
  ...

═══ Step 5/5 — Dry-Run Preview + Confirm ═══
  Will install: claude, opencode, cursor
  Proceed with install? [Y/n]: _
```

### 2.6 Dry-run 模式 (新, v2.1.0)

```bash
# --dry-run 模拟运行, 不实际安装 (跟"诚实修正" 联合)
./scripts/install.sh --dry-run

# --dry-run + --symlink 测试 single source 模式
./scripts/install.sh --symlink --dry-run --target=claude,trae,antigravity,opencode
```

输出: 完整 dry-run 流程, 退出前打印 "Dry-run complete. No files were installed." — 适合:
- 测试 wizard 流程
- 验证检测逻辑
- CI/automation 试运行

跟"诚实修正" 联合:
- **证据**: 本文档 §2.5 (wizard prompt 兜底) + §2.6 (dry-run)
- **反驳/支持**: 不假装安装, 主动让用户确认
- **影响**: 避免"4 工具都检测失败但 install.sh 报 PASS" (跟 BE-15 假 PASS 模式 联合, file:line `docs/KALLAX-GLOSSARY.md:198-201`)

---

## 3. 10 工具路径映射表

跟 EPIC-057-A AC #3-4 契约 一致 (file:line `jira/tickets/EPIC-057-A/ticket.json:23-26`):

| # | 工具 | Skills dir | Commands dir | Settings | 支持 |
|---|---|---|---|---|---|
| 1 | Claude Code | `~/.claude/skills/kallax/` | `~/.claude/commands/` | `~/.claude/settings.json` | full |
| 2 | **Trae** (v2.2.0) | `~/.trae/skills/kallax/` | `~/.trae/commands/` | `~/.trae/settings.json` | full |
| 3 | **Antigravity** (v2.2.0) | `~/.antigravity/skills/kallax/` | `~/.antigravity/commands/` | `~/.antigravity/settings.json` | full |
| 4 | opencode | `~/.opencode/skills/kallax/` | `~/.opencode/command/` (singular) | `~/.opencode/config.json` | full |
| 5 | Codex | `~/.codex/skills/kallax/` | `~/.codex/prompts/` (slash commands) | `~/.codex/config.toml` | full |
| 6 | Gemini | `~/.gemini/skills/kallax/` | `~/.gemini/commands/` | `~/.gemini/config/settings.json` | full |
| 7 | Cursor | `~/.cursor/skills/kallax/` | `~/.cursor/commands/` | `~/.cursor/settings.json` | full |
| 8 | Windsurf | `~/.codeium/windsurf/skills/kallax/` | `~/.codeium/windsurf/commands/` | `~/.codeium/windsurf/settings.json` | full |
| 9 | Aider | `~/.aider/skills/kallax/` | N/A (no slash command API) | `~/.aider.conf.yml` | config |
| 10 | Continue | `~/.continue/skills/kallax/` | N/A (VS Code extension) | `~/.continue/config.json` | config |

**注意**:
- opencode commands dir 是 **singular** `~/.opencode/command/` (不是 `commands/`) — 跟 KALLAX-GLOSSARY.md §8.7 联合
- Codex commands dir 是 `~/.codex/prompts/` (slash commands) — Codex 把"command" 概念叫"prompt"
- Aider + Continue: 没有 slash command API, install.sh 写 `~/.aider.conf.yml` / `~/.continue/config.json` stub 指向 skills dir
- Source dir (本仓库): `.cursor/` `.codeium/windsurf/` `.trae/` `.antigravity/` 是 `.claude/` 的 symlinks (避免重复, 10 工具源共享)

---

## 4. Single Source 模式 (新, v2.2.0)

跟主公 2026-06-17 "用一份skills/命令文件支持所有的引用" explicit 派单 联合, install.sh 加 `--symlink` flag 实现 single source 模式:

### 4.1 原理

```
~/.local/share/kallax/                (canonical, 1 份源)
├── skills/kallax/                     (14 files, real)
└── commands/                          (56 files: 27 .sh + 27 .md + lib + heartbeat)

        ↓ symlinks ↓
                                   
~/.claude/{skills/kallax,commands}         ─┐
~/.trae/{skills/kallax,commands}            │
~/.antigravity/{skills/kallax,commands}     │  4+ 工具
~/.opencode/{skills/kallax,command}         │  共享 1 份源
~/.codex/skills/kallax                      │  (Codex/Gemini 等
~/.gemini/skills/kallax                     │   也可加)
... (10 工具 user-level paths)             ─┘
```

### 4.2 优势 (跟"翻篇&精进" 联合)

- ✅ **一份文件** — 4 工具共享 1 份源, 不重复
- ✅ **更新一次, 4 工具同时获更新** — 改 canonical, 4 工具立即生效
- ✅ **省 disk** — 4 工具不再 4 份副本, 1 份源 (canonical ~30KB 共享)
- ✅ **一致性** — 4 工具版本永远一致 (symlink 强制, 不可能漂移)
- ✅ **copy 模式保留** — 跟 v2.1.x 兼容, 不破坏现有 install

### 4.3 用法

```bash
# 4 工具 single source 模式 (跟主公派单 一致, 推荐)
./scripts/install.sh --symlink --target=claude,trae,antigravity,opencode

# 4 工具 + dry-run 测试
./scripts/install.sh --symlink --dry-run --target=claude,trae,antigravity,opencode

# 10 工具 single source 模式
./scripts/install.sh --symlink --target=all

# 默认 copy 模式 (跟 v2.1.x 兼容)
./scripts/install.sh --target=claude
```

### 4.4 升级流程 (single source 模式)

1. 改源文件: `~/.local/share/kallax/skills/kallax/SKILL.md` 或 commands
2. 4 工具立即看到更新 (symlink 强制同步, 不需 reinstall)
3. 升级 install.sh: `cd <repo> && git pull && ./scripts/install.sh --symlink --target=claude,trae,antigravity,opencode`

### 4.5 验证 (本地 4 工具)

```bash
$ readlink ~/.claude/skills/kallax
~/.local/share/kallax/skills/kallax

$ readlink ~/.trae/commands
~/.local/share/kallax/commands

$ readlink ~/.antigravity/skills/kallax
~/.local/share/kallax/skills/kallax

$ readlink ~/.opencode/command
~/.local/share/kallax/commands
```

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
- **反驳/支持**: v2.0.2 自称"跨平台" 但 install.sh 只支持 Claude Code — v2.0.6 从根源修复, 不在 v2.0.2 命名上纠结 (跟"翻篇&精进" 战略 一致, file:line `docs/KALLAX-GLOSSARY.md:108-112`)
- **影响**: v2.0.2 release 命名 不删 (历史 commit 不可改), v2.0.6 从根源修复 + 文档明确标注 gap

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

**跟主公 2026-06-17 'B' explicit 拍板 联合 (file:line `jira/epics/EPIC-057/epic.json:21-26`), 跟 EPIC-057 4 ticket 联合 (file:line `jira/epics/EPIC-057/epic.json:27-55`), 跟 v2.0.2 '跨平台 fix' 反讽 闭环 (file:line `CHANGELOG.md:647-661`), 跟"诚实修正" 战略 一致 (file:line `docs/KALLAX-GLOSSARY.md:40-47`), 跟"翻篇&精进" 战略 一致 (file:line `docs/KALLAX-GLOSSARY.md:108-112`), 跟 EPIC-055-C 5 标签 SOP 联动 (file:line `docs/process/tag-sop.md:64-78`), 跟 Rule 5 DRY 联动, 跟 Rule 9 5 levels Fact-Forcing 联合 (file:line `docs/PROCESS.md:36-51`), 跟 EPIC-053-B 5 levels 证据链 联合, 跟 EPIC-056-A 3 阶段治理 联合**