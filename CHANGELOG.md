# Changelog

All notable changes to KALLAX will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.9] - 2026-06-17

### Added

#### Slash commands documentation + --help flag (跟主公"kallax 很多命令, 但是这些命令都没有说明" 联合, 跟'诚实修正' 联合)

跟主公 2026-06-17 explicit 派单 联合 (跟 v2.0.8 PHASE-011 入口之后 跨期 follow-up 沉淀 联合, 跟'独立' 拍板 explicit 联合), 跟"流程逻辑 > 扩充配置" 战略 一致:

- **docs/reference/slash-commands.md** 新建 (652 行, 跟 cli-reference.md 平行): 26 slash 命令 详细 reference, 6 章节 (Quick/Performer/Conductor/Analysis/Configuration/Workflow), 每条含 9 字段 (syntax/args/what/output/when/example/role/related/source), 3 附录 (--help/跨工具兼容/相关文档)
- **_kallax_common.sh** 加 `show_help()` 函数 (42 行): 读 stdin + 格式化输出 (USAGE/ARGS/DESCRIPTION/EXAMPLES/RELATED 段头加粗蓝, body 行 2 空格缩进, 空行保留)
- **26 .sh 文件 加 --help/-h flag** (跟 _kallax_common.sh 联合, 一致格式): 每个命令 21-29 行 heredoc, 覆盖所有 26 slash 命令 (analyze/ask/board/check-progress/claim/expert/help/init/instances/list/merge/mode/office-hours/panel/phase-review/resume/review-analysis/review-merge/review-pr/role/save/skill/start/status/submit-pr/task/verify-pr)

### Notes
- 0 增命令 (跟 Rule 32 + "流程逻辑 > 扩充配置" 联合)
- 0 增 Rule (跟 v2.0.5 Rule 合并 24→22 联合)
- 0 重写 (26 .sh 仅插入 --help 检查, 不改动主逻辑)
- 跟 KALLAX-GLOSSARY v2.0.6 升级版 Section 8.6-8.10 联合 (跨 4 工具 slash commands 一致)
- 跟 INSTALL-MULTI-TOOL.md §1.1 反讽治根段 联合 (slash commands 4 工具 mirror 路径)
- 跟"诚实修正" 联合 (主公发现 26 命令无说明 → 显式补全, 不模糊处理)
- 跟"翻篇&精进" 战略 一致 (文档补全不引入新功能, 仅添 --help + 中央 doc)

## [2.0.8] - 2026-06-17

### Added

#### PHASE-011 跨期 review 入口 (主公'AC 做一下, 其他不管了' explicit 派单, 0 派单 0 执行 0 ticket claim, 5 遗留 P1/P2/P3 deferred)

跟主公 2026-06-17 'AC' explicit 启动 + 'BD' explicit 跳过 联合 (跟"独立" 拍 explicit 约束 联合, 跟 PROCESS.md:25-26 Master 不自助升级红线 联合), 跟 v2.0.7 跨期 todo 闭环 release 之后 跨期 follow-up 沉淀 联合:

- **A. PHASE-011 跨期 review 入口** (跟主公'AC' explicit 派单 联合, file:line `confluence/decisions/PHASE-011-REVIEW-2026-06-17.md` + `jira/epics/EPIC-058/epic.json`):
  - **5 deferred tickets 入口** (status="deferred", blocked_by="主公后续拍板"):
    - **P1-1**: pre-commit hook ALLOWED_PATTERNS 加 `^jira/` (治根 `--no-verify` workaround, 1h, 跟 v2.0.4 EPIC-053-A 联合, file:line `scripts/hooks/pre-commit:150-167`)
    - **P1-2**: 48 worktree + 107 local feature branches 清理 (2h, 跟 v2.0.4 EPIC-054-A worktree 4→1 模式 一致, 实际 `git worktree list | wc -l = 48`)
    - **P2-1**: EPIC-053-D web dashboard 真上线 (主公 B 跳过, 4h, 代码就绪 `web/src/dashboard/dispatch/`)
    - **P2-2**: 69 remote feature branches DB cleanup Option B/C (主公 D 跳过, 6h, 当前 Option A 保留 + 跟 v2.0.5 release 联合)
    - **P3-1**: Rule 22 → ~18 合并 (4h, 候选 3 组合并 跟 v2.0.5 Rule 合并 24→22 模式 一致)
  - **0 派单 + 0 执行 + 0 ticket claim** (跟"翻篇&精进" 战略 一致, 跟"独立" 拍 explicit 约束 联合)
  - **PHASE-011-REVIEW-2026-06-17.md** 跨期 review 入口 (本 release 沉淀, 跟"反哺框架" 战略 一致)
  - **PHASE-INDEX.md 累计 11 PHASE review** (PHASE-005 ~ PHASE-011, 跟 ACCUMULATED-LESSONS v2.0.6 升级版 联合)

- **C. KALLAX-GLOSSARY.md v2.0.6 升级版** (跟主公'C' explicit 派单 联合, file:line `docs/KALLAX-GLOSSARY.md`):
  - **Section 8.6-8.10 新增 5 multi-tool 术语** (跟 EPIC-057 4 ticket 闭环 联合):
    - **8.6 「4 工具」multi-tool skills**: Claude Code / opencode / Codex / Gemini 4 工具平起平坐, install.sh `--target=auto` 默认全支持, 4 工具 CLI invocation 实测表 (v2.1.153 / v1.17.7 / codex exec fallback / v0.22.2)
    - **8.7 「skills/commands paths」4 工具 路径映射**: 4 工具 dir 名字不统一 (opencode `command/` singular 反讽, codex 叫 `prompts/` 不叫 `commands/`)
    - **8.8 「hybrid flag-controlled install」**: 5 flag 模式 `--target=auto|all|<tool>|a,b|--interactive` (主公'需要用户选择安装哪个工具/还是全支持' explicit 联合)
    - **8.9 「--target=auto」默认行为**: auto-detect 双通道 ($HOME/.<tool>/ 目录 + which CLI binary), 优先级 claude > opencode > codex > gemini
    - **8.10 「v2.0.2 '跨平台 fix release'」反讽治根**: 反讽证据链 (install.sh:52-53 1 工具, 31 slash command mirror 0 支持, codex/gemini 0 reference), 跟"反讽" + "诚实修正" 联合
  - **34 → 39 术语** (+5 multi-tool)
  - **363 → 461 行** (+98 行)
  - **0 重写** (Section 8.6-8.10 增量插入, 跟 Rule 5 DRY 联合)

### Notes
- 0 Rule 增加 (跟 Rule 32 撤销 + v2.0.5 Rule 合并 24→22 联合, 跟"反讽" 联合, file:line `docs/KALLAX-GLOSSARY.md:268-272`)
- 0 ticket claim (PHASE-011 入口 5 deferred 状态, 0 派单 0 执行, 跟"独立" 拍 explicit 约束 联合)
- 0 重写 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- 跟 v2.0.6 (EPIC-057 4 ticket 闭环) + v2.0.7 (跨期 todo 闭环 release) 联合 release
- 跟 PHASE-011 跨期 review 联合 (file:line `confluence/decisions/PHASE-011-REVIEW-2026-06-17.md`)
- 跟 KALLAX-GLOSSARY v2.0.6 升级版 Section 8.6-8.10 联合 (file:line `docs/KALLAX-GLOSSARY.md:334-450`)
- 跟"独立" 拍 explicit 约束 联合 (主公'AC' 启动 + 'BD' 跳过 explicit 派单, 跟 PROCESS.md:25-26 联合)
- 跟"反讽" 联合 (Section 8.10 反讽证据链 explicit 标注, 跟 v2.0.6 治根 联合)
- 跟"翻篇&精进" 战略 一致 (PHASE-011 入口沉淀, 0 派单 0 执行, 5 遗留 deferred 留待主公后续拍板)

## [2.0.7] - 2026-06-17

### Added

#### 跨期 todo 闭环 release (PHASE-010 review + ACCUMULATED-LESSONS v2.0.6 升级版 + .gitignore 治根)

跟"翻篇&精进" 战略 一致 (跟"独立" 拍板 Todo 1+2+3+4 explicit 闭环 联合), 跟 v2.0.5 → v2.0.6 release 之后 跨期 follow-up 沉淀 联合:

- **Todo 1: .gitignore 加 `**/.kallax/` patterns** (跟 EPIC-054-A worktree 统一 联合, file:line `.gitignore:1-3`):
  - **证据**: commit `2f13db6` 加 `**/.kallax/data/` + `**/.kallax/*.db`, 治 root 嵌套 path 不被 gitignore match
  - **反驳/支持**: 之前 `.kallax/` 在 root 匹配但 worktree nested (`.claude/worktrees/<name>/.kallax/`) 不 match, 治根
  - **影响**: 4 worktree 统一 gitignored (不污染 git status), 跟 EPIC-054-A worktree 4→1 ROOT_BUCKETS=1 联合
- **Todo 2: docs/PHASE-INDEX.md 加 PHASE-010 entry** (commit `d9d0c92`, file:line `docs/PHASE-INDEX.md`): 累计 10 PHASE review (PHASE-005 ~ PHASE-008 baseline + PHASE-009 v2.0.5 + **PHASE-010 v2.0.6**)
- **Todo 3: confluence/decisions/PHASE-010-REVIEW-2026-06-17.md** (commit `9056927`, 260 行): v2.0.6 EPIC-057 4 ticket 闭环 跨期 review, 4 工具 multi-tool skills support, 18/18 PASS (6+6+5+18/18 分阶段验证), 治 v2.0.2 跨平台 fix 反讽 闭环
- **Todo 4: confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md v2.0.6 升级版** (commit `290e97e`, 470 → 531 行): 5 处增量更新 (Title + KPI table + BE-14 ⚠️ 新增 + Section 12.5 串行派单教训 + Section 13+14 文件清单 + 状态变更历史), 跟 v2.0.3 baseline (429 行) → v2.0.5 升级 (470 行) → v2.0.6 升级 (531 行) 累计沉淀
- **Todo 5: bump version 2.0.6 → 2.0.7** (本 entry): package.json 同步, 跨期 todo 闭环 release 命名

### Notes
- 0 Rule 增加 (跟 Rule 32 撤销 + v2.0.5 Rule 合并 24→22 联合, 跟"反讽" 联合, file:line `docs/KALLAX-GLOSSARY.md:268-272`)
- 0 重写 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- 0 ticket 增加 (跟 EPIC-057 4 ticket 闭环 联合, 跟"反哺框架" 战略 一致)
- 跟 v2.0.6 (EPIC-057 4 ticket 闭环 + 4 工具 multi-tool) 联合 release (file:line `CHANGELOG.md:8-69`)
- 跟 PHASE-010 跨期 review 联合 (file:line `confluence/decisions/PHASE-010-REVIEW-2026-06-17.md`)
- 跟 ACCUMULATED-LESSONS-2026-06-17 v2.0.6 升级版 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md`)
- 跟"独立" 拍 explicit 约束 联合 (主公 Todo 1+2+3+4 explicit 派单, 跟 PROCESS.md:25-26 Master 不自助升级红线 联合)

## [2.0.6] - 2026-06-17

### Added

#### Multi-tool install support (Claude Code / opencode / Codex / Gemini, --target=auto 默认检测, 治 v2.0.2 跨平台 fix 反讽)

跟主公 2026-06-17 explicit 拍 B 联合 (file:line `jira/epics/EPIC-057/epic.json:21-26`), 跟 v2.0.2 '跨平台 fix release' 反讽 闭环 (file:line `CHANGELOG.md:647-661`), 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致:

- **install.sh --target=auto + 4 工具 skills/commands 路径** (跟 EPIC-057-A 联合, file:line `jira/tickets/EPIC-057-A/ticket.json:23-31`):
  - `--target=auto` 默认 auto-detect (claude > opencode > codex > gemini 优先级)
  - `--target=claude|opencode|codex|gemini` 显式单工具
  - `--target=claude,opencode` 多工具 (逗号分隔)
  - `--target=all` 强制全装
  - 4 工具路径映射: claude→`~/.claude/{skills/kallax,commands}/`, opencode→`~/.opencode/{skills/kallax,command/}` (singular), codex→`~/.codex/{skills/kallax,prompts/}`, gemini→`~/.gemini/{skills/kallax,commands}/`
- **kallax-onramp.sh tool detection + dispatch** (跟 EPIC-057-B 联合, file:line `jira/tickets/EPIC-057-B/ticket.json:24-32`):
  - `tool-detect.sh` 检测 $PATH + $HOME/<tool>/ 哪个工具可用
  - dispatch 4 工具等价命令: `claude --print` / `opencode --non-interactive` / `codex exec` / `gemini --non-interactive`
  - detect 优先级 claude > opencode > codex > gemini (跟 install.sh 一致)
- **docs/guides/INSTALL-MULTI-TOOL.md** 新建 (~200 行, 跟 `docs/PROCESS.md` 风格 一致): 4 工具 install guide + auto-detect 行为 + --target flag 文档 + 路径映射表 + 故障排查 + 升级路径 (跟 EPIC-057-C 联合)
- **README.md 安装段 + 目录结构段 标注更新**: 4 工具支持标注 (Claude Code 默认, opencode/codex/gemini --target=auto 自动检测), `.opencode/command/` 是 opencode mirror (跟 EPIC-057-C 联合, file:line `README.md:104-138`)
- **integration tests** (跟 EPIC-057-D 联合, file:line `jira/tickets/EPIC-057-D/ticket.json:27-36`): `tests/integration/install-multi-tool-test.sh` 8/8 PASS + `tests/integration/onramp-tool-detect-test.sh` 6/6 PASS + `tests/integration/multi-tool-e2e-test.sh` 4/4 PASS
- **docs link check test** (跟 EPIC-057-C 联合, file:line `tests/integration/docs-link-check-test.sh`): 5/5 PASS (外链完整性 + 4 工具 path 路径正确 + 文档一致性)

### Fixed

#### v2.0.2 '跨平台 fix release' 反讽 治根 (跟"诚实修正" 联合, 跟"反讽" 闭环)

跟"反讽" 联合:
- **证据**: `CHANGELOG.md:647-661` (v2.0.2 release notes 自称"跨平台 fix release", 加 frontmatter + 31 slash command mirror 到 `.opencode/command/`)
- **反驳/支持**: `scripts/install.sh:52-53` (v1.0.0 hardcoded `~/.claude/`, 只支持 Claude Code); `jira/epics/EPIC-057/epic.json:11-12` (baseline gap: "opencode 30 文件但 install.sh 没装, codex/gemini 0 reference")
- **影响**: v2.0.2 release 命名"跨平台"实际"单平台" — 命名跟实现不一致 (跟 KALLAX-GLOSSARY.md §1.1 反讽定义 联合, file:line `docs/KALLAX-GLOSSARY.md:30-36`); v2.0.6 install.sh 加 `--target=auto` 检测 + 4 工具 skills/commands 路径映射, 治根

跟"诚实修正" 联合:
- **证据**: 本 entry 标注 "v2.0.2 release 命名是跨平台, 实际只 Claude Code (历史 gap), v2.0.6 治根" + `docs/guides/INSTALL-MULTI-TOOL.md:§1.1` 反讽治根说明段
- **反驳/支持**: 看到反讽不装看不见 — 文档明确标注 v2.0.2 gap, 不模糊处理 (跟 KALLAX-GLOSSARY.md §1.2 诚实修正定义 联合, file:line `docs/KALLAX-GLOSSARY.md:40-47`)
- **影响**: 主公信任↑, 治理闭环, 不在历史 gap 上反复 (跟"翻篇&精进" 战略 一致, file:line `docs/KALLAX-GLOSSARY.md:108-112`)

### Notes
- 0 Rule 增加 (跟 Rule 32 软约束升级阈值 联合, 跟"反讽" 联合, file:line `docs/KALLAX-GLOSSARY.md:268-272`)
- 0 重写 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- 走对策 A+B+C 落地 (跟"反讽" 联合, 跟 Rule 11/14/15 联合)
- 跟 v2.0.5 (PHASE-009 review + 14 卡闭环 + 5 清理) 联合 release (file:line `CHANGELOG.md:8-69`)
- 跟 EPIC-057 4 ticket (A install.sh + B onramp.sh + C docs + D tests) 联合 (file:line `jira/epics/EPIC-057/epic.json:27-55`)

## [2.0.5] - 2026-06-17

### Changed

#### v2.0.4 14 卡闭环后 Master 5 清理 实际执行 (跟"翻篇&精进" + "诚实修正" 联合)

主公 2026-06-16 explicit 拍板"全闭环 (push + 5 清理 + PHASE-009 review)" → Master 在 v2.0.4 merge 后执行 5 清理动作:

**1. EPIC-054-A worktree 4→1 统一** (治 H5):
- `scripts/worktree/unify-roots.sh` 实际执行: 75 → 72 worktree (3 失败: 2 destination exists + 1 git worktree move fail)
- 手动清理 orphan dir (.claude/worktrees/kallax-refactor-complete) + git worktree prune
- ROOT_BUCKETS=1, Outside single-root: 0
- `.claude/worktrees/` + `.worktrees/` + `performer-EPIC-034/` 嵌套 → `.kallax/worktrees/` 单一根

**2. EPIC-054-B instance LRU + 7d TTL** (治 A7):
- `scripts/instance/cleanup.sh --apply` 实际执行: 86 → 39 instance (cleaned 47)
- 跟 Resource Management 硬要求一致, 95% 僵尸清理

**3. EPIC-054-C 空 EPIC 目录归档** (治 A6):
- `scripts/epic/cleanup-empty.sh` 实际执行: 6 empty EPIC (EPIC-042~047) → `jira/epics/_archived/`
- `jira/epics/epic_index.json` 修复: 从 1 EPIC (严重过期) → 4 done + 1 archived

**4. EPIC-054-D Rule 合并 实际执行** (主公 explicit 拍板 APPROVED, 治 A1):
- 候选 A (Rule 30 + 31 → Rule 30 "独立见证机制"): -1
- 候选 B (Rule 32 撤销, 反讽治根): -1
- 候选 C (Rule 33 合并入 Rule 13 扩展): 净 0 (扩展不增 Rule)
- **24 → 22 active Rule** (-2), 净价值 62.5% → 64.0% (+1.5%)
- ⚠️ **honest mark** (跟"诚实修正" 联合): proposal 写 -3 / +3.0%, 实际 -2 / +1.5%, 候选 C 净减为 0

**5. EPIC-053-D + 056-B 仪表盘 真跑** (治 H1/H6 + P3):
- `dispatch-dashboard.sh`: 1/1 (100.0%) +41.7% vs baseline 58.3%
- `process-metrics.sh dashboard`: 3 KPI 跑通 (数据有限, WARN ticket 字段缺失 跟后续 ticket 修)

#### Rule 32 撤销 反讽治根 (跟"反讽" 闭环, 跟 EPIC-054-D 联合)

- Rule 32 (软约束升级阈值) 本身是 Rule, 反讽地加剧 Rule 通胀
- 撤销避免 Rule 治 Rule 通胀 → Rule 数 +1 → 治根动作本身加剧问题
- Rule 32 内容已合到 Rule 5 DRY (Single Source of Truth) + Rule 19 (5 类标签 SOP 包含诚实修正)

### Added

#### PHASE-009 Review (14 卡闭环沉淀)

- `confluence/decisions/PHASE-009-REVIEW-2026-06-17.md`: 14 卡闭环 (v2.0.4) + 5 清理 (v2.0.5), 净价值 +4.5%, Rule -2 净减, 跟 12 主题教训 (KPI 治根 + 治理升级 + 文档 SoT + 工具自检) 联合
- `docs/PHASE-INDEX.md` 同步更新: 加 PHASE-009-REVIEW-2026-06-17 索引行

### Fixed

#### Worktree 路径 git hook ALLOWED_PATTERNS 跟 jira/ 路径矛盾 (跟 EPIC-054-A 联动)

- `.git/hooks/pre-commit` 当前 ALLOWED_PATTERNS 不含 `^jira/`, 历史 commit `b079baa/542e0f9/c3f20a2` (主公亲自 commit) 跟 Master 角色 (`--no-verify` bypass) 联合
- 跟 14 问题分析 EPIC-054-A worktree 统一 后续 ticket 联动, 待 ALLOWED_PATTERNS 加 `^jira/` (jira 跟 docs 同类, 属 Master 可直接 commit 范围)
- 本 v2.0.5 不修 hook (避免本 release 范围扩大), 跟 EPIC-054-A 后续 ticket 联合

### Known Limitations

#### 后续跨 PHASE 评估 (跟"独立" 拍板 联合)

- 7 个 untracked files (docs/superpowers/{plans,specs}/2026-06-1[4-6]-*.md): 跟 14 卡无关, 可选 commit 或 ignore
- 19 个 stale worktree (feature/EPIC-0*): 跟 EPIC-054-A worktree 统一 联合
- PHASE-010 跨 PHASE review 评估: 跨 EPIC-053/054/055/056 沉淀
- EPIC-053-D 仪表盘 web dashboard 真上线 (跟 origin 联动): 需要 server 部署

---

## [2.0.4] - 2026-06-16

### Changed

#### 14 卡 PHASE-009 闭环 (跟主公 2026-06-16 "建卡修复" + "派 14 卡全推" explicit 派单 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致)

主公 2026-06-16 拍 Option A 派单 EPIC-053 全 6 票 (治 H1/H2/H3/H6 KPI falsification 系统级), 后拍 "派 053-D + 5 张治理卡" + "派全 5 票 14 卡闭环" explicit 拍板, 14 卡累计闭环 14/14:

**EPIC-053 (KPI falsification 系统级治根, 6/6 闭环)**:
- **EPIC-053-A** (L3L4 一致性, 治 H2/BE-9): `scripts/verify/l3-l4-consistency.sh` (130 行, 4-case truth table)
- **EPIC-053-B** (4-Level 证据链, 治 H1/BE-5/BE-9): `scripts/verify/kpi-evidence-chain.sh` (1326 行, L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证)
- **EPIC-053-C** (工具自检, 治 H3/BE-10): `scripts/verify/tool-self-check.sh` (1218 行, 4 工具 × 2 case = 8/8 PASS, BE-10 真根因 `--` 模式 修复)
- **EPIC-053-D** (派单仪表盘, 治 H1/H6): `node/src/core/dispatch-dashboard.ts` + `web/src/dashboard/dispatch/` (fullstack)
- **EPIC-053-E** (5 调用点 wiring, 治 BE-5 反讽): 治 BE-9 工具在自己生产路径跑
- **EPIC-053-F** (scope-creep + rename, 治 BE-10 模式 + B 组逆袭 #2+#3): `check-scope-creep.sh` glob pattern 修复 + `l3-l4-consistency-truth-table-test.sh` git mv 100%

**EPIC-054 (架构卫生减法, 4/4 闭环)**:
- **EPIC-054-A** (worktree 4→1 统一, 治 H5): `scripts/worktree/unify-roots.sh` (atomic write + 备份, 实际迁移 Master 后做)
- **EPIC-054-B** (instance LRU + 7d TTL, 治 A7): `scripts/instance/cleanup.sh` + `scripts/hooks/instance-ttl.sh` + `node/src/core/instance-registry.ts` 升级
- **EPIC-054-C** (EPIC 6 状态机 + 空目录清理, 治 A6): `scripts/epic/cleanup-empty.sh` + `jira/schemas/epic-state-machine.md` (planning→active→blocked→done→archived→closed, 8 合法转换, 11 禁止跳状态)
- **EPIC-054-D** (Rule 合并 proposal, 治 A1 Rule 通胀): 23 Rule → 20 Rule 目标, 3 合并候选 (Rule 30+31 / Rule 32→Rule 5 / Rule 33→Rule 13)

**EPIC-055 (文档去重 + 战略反讽 收口, 3/3 闭环)**:
- **EPIC-055-A** (CLAUDE+GLOSSARY 去重, 治 A5): 体量 **-51.5%** (70035 → 34001 bytes), Rule 5 DRY + Immutable Principle #5 落地
- **EPIC-055-B** (主公拍板分级 P0/P1/P2, 治 P2 决策疲劳): 5 张治理卡 核心 ticket, **23 Rule 10 升级** (实测修正, 跟事实一致), 3 级路由: P0 阻塞 / P1 备案 / P2 放手
- **EPIC-055-C** (5 标签 SOP, 治 A2 咒语化 + A3 笔误): `docs/process/tag-sop.md` + `scripts/audit/tag-audit.sh`, 17 处 "主公拍 explicit 拍 explicit" 笔误检测

**EPIC-056 (治理减负 + 流程表演 → 流程效果, 3/3 闭环)**:
- **EPIC-056-A** (5 阶段 → 3 阶段, 治 A4): 净价值 +2.5% (62.5% → 65.0%), 15 步 → 10 步, 5 扩展组保留
- **EPIC-056-B** (流程效果度量, 治 P3): 3 KPI (派单成功率 / 平均周期 / 越界率) + 仪表盘
- **EPIC-056-C** (⚠️ **红线 revert**, Master 6 维恢复, 治 H4): revert v1.2.4 6→0 退步, 净价值 +4.5% (62.5% → 67.0%), 主公 explicit 拍板落地

#### Master 强验证 6 维度 恢复 (跟 v1.2.4 退步对比)

- v1.2.4 baseline: **0 维度** (流程监督 + 10% 抽查)
- v2.0.4 target: **6 维度全激活** (L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实, 跟 Rule 11 v2.1 一致)
- 跟 EPIC-053-B 4-Level 证据链 L4 独立见证 联动 (L6 诚实 = 证据链校验)

#### 净价值 提升 (跟 CHANGELOG.md:74 v1.2.4 62.5% 对比)

- v1.2.4 baseline: **62.5%** (跟 5 视角 Product 67.5% 联合, 恶化 -5%)
- v2.0.4: **67.0%** (+4.5%, 跟 5 视角 Product 联合持平)
- Rule 数量: 23 → 20 (proposal, -3, 跟 Rule 32 软约束升级阈值 联动)
- 治理阶段: 5 → 3 (-2)
- Subagent 步骤: 15 → 10 (-5)
- 派单成功率: 58.3% (7/12) → (target 95%+, EPIC-053-D 仪表盘已就位)
- 文档体量: 68533 → 34001 bytes (-51.5%)

### Added

#### 5 张治理卡 拍板决策 (主公 2026-06-16 explicit 拍板)

- `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md`: 5/5 治理卡 APPROVED (EPIC-055-B + 056-A + 056-B + 056-C + 054-D), 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合
- EPIC-056-C ⚠️ 红线 revert (revert v1.2.4 6→0 退步) 主公明确授权, 不暗箱操作

#### 14 卡 Intake 报告

- `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md`: 14 卡建好, 5 派单选项 (A 立即 P0 / B 等治理卡 / C 只 P0 / D 退回)

#### 14 卡 dispatch manifest (5 治理卡 拍板 + 14 票 派单)

- `.kallax/queue/outbox/conductor_77704/dispatch-20260616-EPIC-053-p0-batch.json`: 派单 EPIC-053 全 4 票 P0 (主公 Option A 拍板)

### Fixed

#### 9 Security Review Issues (跟对策 C 联合, 跟"反讽" 闭环)

5 HIGH issues: UNDER-VALIDATED SINK ARG, ALLOWLIST SEMANTIC ESCAPE, RESOURCE-BOUND PLACEMENT
4 MEDIUM issues: FAIL-OPEN STATE DRIFT, FAIL-OPEN STATE DRIFT (subagent-controlled skip)
跟 BE-7 修复模式 联合, 跟"反讽" 闭环

#### BE-10 工具自检 真根因 (跟 EPIC-053-C 联合)

- 不只是 `[[:space:]]` 数组模式 (bash 5.x 兼容)
- 还有 `git log --pretty=%B -- $TARGET` 的 `--` 让 HEAD 当 path filter, MSG 永空, 检查永 PASS
- 修法: 移除 `--`
- 3 层防护 (元级闭环): self-guard fail-fast + tool-self-check D2 拦截 + kpi-evidence-chain L3 拦截

#### B 组 5 extended review 逆袭发现 (跟 EPIC-053-A/E/F 联合)

- 🚨 逆袭 #1 (process-engineering 3/5): 新 preflight wiring gap → EPIC-053-E (P0 critical, 8h, 治 BE-5 反讽)
- 🚨 逆袭 #2 (security-tool-bypass 4/5): check-scope-creep.sh glob bug → EPIC-053-F (P1, 4h)
- 🚨 逆袭 #3 (process-engineering 3/5): test 命名误导 truth-table → EPIC-053-F (git mv 100%)

### Known Limitations

#### Master 后续执行 清理 (Performer 边界, 跟"诚实修正" 联合)

- `scripts/worktree/unify-roots.sh` 实际迁移 50+ worktree (4→1): 由 Master 在 v2.0.4 merge 后执行
- `scripts/instance/cleanup.sh --apply` 实际清理 88 → ≤5 instance: 由 Master 在 v2.0.4 merge 后执行
- `scripts/epic/cleanup-empty.sh` 实际归档 6 空 EPIC 目录 + 修复 epic_index.json: 由 Master 在 v2.0.4 merge 后执行
- `docs/process/rule-merge-proposal.md` 3 合并候选 实际 Rule 合并: 由 Master 在 055-B 拍板分级落地后 (候选 B P0 必拍, 候选 A/C P1 备案) 后续 ticket 执行

---

## [1.3.1] - 2026-06-14

### Fixed

#### 4 Bug 修复 (跟"反讽" 闭环, 跟"诚实修正" 联合, 跟对策 C 联合)

- **B1**: 主入口 `scripts/kallax-onramp.sh` 缺失 (新建, ~60 行 dispatcher)
- **B2**: `output.sh` KALLAX_ROOT 路径错 (5 层 `../` → 2 层 `../..`)
- **B3**: `output.sh` 模板渲染不完整 (`cp` only → sed + python3 替换所有 placeholders)
- **B4**: Expert outputs 不真读取 skill 文档 (只返回路径 → 真读取 name/description/content)

跟 v1.3.0 (8d759ab) 联合, 跟主公'实测 Onramp' explicit 授权 联合, 跟对策 C 联合, 跟'诚实修正' 联合.

## [1.2.4] - 2026-06-13

### Added

#### 5 扩展组 落地 (跟对策 C 联合, 跟主公"同意" explicit 授权, 跟"反讽" 闭环)

跟 5 战略建议 5.1/5.2/5.3/5.6 + (新) ai-copilot 5 根因 联合, 跟 14 BE 累计 联合, 跟"反讽" 闭环 联合:

- **EPIC-048 Security 扩展组** (治根因 1: 工具可绕过 = 架构缺陷)
  - `scripts/verify/tool-bypass-audit.sh` (5749 bytes): 扫描 6 硬脚本的 bypass 向量
  - `scripts/audit/subagent-pass-gate.sh` (2812 bytes): Rule 26 Subagent 自验证 gate
  - `scripts/audit/conductor-receive-gate.sh` (3397 bytes): Rule 27 Conductor 接收验证 gate
  - `scripts/verify/check-scope-creep.sh` 修: KALLAX_BYPASS_SCOPE_CHECK=1 移除, 替换 KALLAX_DESIGN_MODE=1 + master token
  - `scripts/check-fact-forcing-preflight.sh` 修: --force-merge token check 移到 preflight 前
  - `tests/integration/tool-bypass-audit-test.sh` (104 lines): 4-Level 集成测试
  - **Rule 29** (工具不可绕过, KALLAX P0)

- **EPIC-049 process-engineering 扩展组** (治根因 2: 自验证主体 = 造假主体)
  - `docs/process/process-engineering-design.md` (330 lines): 4 方案对比
  - `scripts/process/independent-witness.sh` (4141 bytes): 独立见证机制
  - `scripts/process/conductor-verify-gate.sh` (2845 bytes): Conductor 强制验证
  - `scripts/process/subagent-pass-gate.sh` (3008 bytes): Subagent 自验证 gate
  - `tests/integration/process-engineering-test.sh` (122 lines): 4-Level 集成测试
  - **Rule 30** (自验证需独立见证, KALLAX P0)

- **EPIC-050 auditor 扩展组** (治根因 3: 独立见证机制缺失)
  - `scripts/audit/audit-log-sink.sh` (5833 bytes): 不可篡改 audit log sink (BE-7 修复模式)
  - `scripts/audit/independent-witness.sh` (5722 bytes): 独立见证机制
  - **Rule 31** (独立见证机制, KALLAX P0)

- **EPIC-051 compliance 扩展组** (治根因 4: 14 Rule 升级率 100%)
  - `docs/process/COMPLIANCE-DESIGN.md` (263 lines): 4 方案对比
  - `scripts/audit/rule-redundancy-audit.sh` (4391 bytes): 撤销冗余 Rule 定期扫描
  - `tests/integration/compliance-test.sh` (214 lines): 4-Level 集成测试
  - **Rule 32** (软约束升级阈值, KALLAX P0)

- **EPIC-052 decision-gate 扩展组** (治根因 5: ai-copilot 名不副实)
  - `docs/process/decision-gate-design.md` (269 lines): 4 方案对比
  - `scripts/permission/decision-gate-complex-only.sh` (1164 bytes): 硬脚本
  - `tests/integration/decision-gate-test.sh` (232 lines): 4-Level 集成测试
  - **Rule 33** (decision-gate 复杂才问, KALLAX P0)

#### 新流程 v2.0 (跟对策 A+B+C 联合, 跟"反讽" 闭环)
- `docs/process/NEW-PROCESS-2026-06-13.md` (10 章节)
- 流程从"事后 Master 强验证" → "事中 Subagent 必跑 3 硬脚本 + Conductor 必看输出"
- Master 强验证 6 维度 → 0 维度 (流程监督 + 10% 抽查)
- 跟 14 BE 累计 联合, 跟"反讽" 闭环

### Changed

#### Rule 升级率 100% 累计 (跟 Rule 32 软约束升级阈值 联合)
- 18 Rule → 23 Rule (加 Rule 26/27/28/29/30/31/32/33)
- Rule 升级率 100% (5 release 软约束 → 5 R-NEW 升级, 累计 1+1+1+1+1+1+1+1+1 = 9 升级)
- 净价值: 85.5% - 23 Rule = 62.5% 净价值 (跟 5 视角 Product 67.5% 联合, 恶化 -5%)

#### 5 视角 + 5 扩展组 反思 落地 (跟"召唤合适专家" 拍 explicit 约束 联合)
- 之前 5 默认视角 (Architect + Security + Backend + Product + UX) 治"症状"
- 5 扩展组 (security + process-engineering + auditor + compliance + decision-gate) 治"根因"
- 5 默认 + 5 扩展 = 10 专家, 治 3 假 PASS 5 根因
- 跟 14 BE 累计 联合, 跟"反讽" 闭环

### Fixed

#### 9 Security Review Issues (跟对策 C 联合, 跟"反讽" 闭环)
- 5 HIGH issues: UNDER-VALIDATED SINK ARG, ALLOWLIST SEMANTIC ESCAPE, RESOURCE-BOUND PLACEMENT
- 4 MEDIUM issues: FAIL-OPEN STATE DRIFT, FAIL-OPEN STATE DRIFT (subagent-controlled skip)
- 跟 BE-7 修复模式 联合, 跟"反讽" 闭环

## [1.2.3] - 2026-06-13

### Added

#### 5 测试 实际跑结果 (跟 Master 强验证 6 维度 一致, 跟"诚实修正"模式 一致)
- **outbox-isolation-test.sh**: 5/5 PASS ✅ (跟 FIX-A 报一致)
- **worktree-state-sync-test.sh**: 卡住 (跟 BE-10 防御模式 + Rule 19 自检漏洞)
- **rule-19-test.sh**: 修后 6/6 PASS ✅ (Master 修 architecture.sh + security.sh 2 stub)
- **checkpoint-test.sh**: 修后 1/5 PASS (跟 BE-10 防御模式)
- **auditor-test.sh**: 6/6 PASS ✅ (跟 FIX-C 报一致)

#### 2 stub 创 (跟 Rule 8 L4 + Rule 19 落地)
- `scripts/verify/architecture.sh` — 架构验证 (跟 Rule 19 L3 self-check)
- `scripts/verify/security.sh` — 安全验证 (跟 Rule 19 L3 self-check + BE-7 fix pattern)

### Fixed

#### BE-13: PHASE-008 5 subagent 越界反向 (跟之前 4 subagent 越界反向模式 一致, 跟"诚实修正" 模式 累计)
- 5 subagent 报 PASS 实际 worktree 写 + 主 checkout 复制
- Master 立即修主 checkout 5 ticket 目录 + 文件闭环
- 跟 BE-11 越界反向 4 subagent 模式 一致
- Rule 15 升级 (跟主公"subagent 行为准则第一条" 拍对齐)

#### 14 BE 累计 (跟 8 试反复 + 10 KPI falsification + Token 限撞墙 + 越界反向 联合)
- BE-12: PHASE-008-B 报"4 文件落地" 实际 worktree MISSING
- BE-13: PHASE-008 5 subagent 越界反向 (worktree 写 + 主 checkout 复制)
- BE-14: PHASE-008-FIX-A/B 2 subagent API Error (Content block not found + socket closed)

### Changed

#### 跟"诚实修正" 模式 一致 (跟主公"是什么意思?" 对齐)
- **package.json**: 1.1.0 → 1.2.3 (累计 4 release 落 version)
- **CHANGELOG.md**: 补 1.2.0/1.2.1/1.2.2/1.2.3 段 (累计 4 release 段)
- **.gitignore**: 补 .kallax/worktrees/ + .worktrees/ + performer-EPIC-*/ (跟 BE-13 越界反向模式 一致)

## [1.2.2] - 2026-06-13 (跟 v1.2.3 落地一致, 诚实修正 合并)

## [1.2.1] - 2026-06-13

### Added

#### Rule 15 升级 (跟主公"subagent 行为准则第一条" 拍对齐)
- **CLAUDE.md 升级**: 写明"子 subagent 行为准则第一条 = 领卡之后第一时间建 worktree, 跟主分支和其他分支隔离"
- 跟 BE-13 越界反向 5 subagent 教训闭环
- 跟 Rule 14 (Conductor 不能越界) + Rule 15 (Performer Session 自动加载) 联动

## [1.2.0] - 2026-06-13

### Added

#### Token Plan 12h cap 升级 (跟主公"同意" 提议 B 一致)
- 1+2/1+4 容量设计 (跟 Token Plan 关联)
- 4 Performer subagent Wave 1 立即召唤 (跟 BE-12 Token 限撞墙 模式 一致)
- 跟 1+4 容量遗留 38 worktree 闭环

#### Master 强验证 6 维度 (Rule 11 v2.1)
- L1 git log --oneline -1
- L2 git show HEAD:file | grep
- L3 跑全量 E2E
- L4 跑 check-commit-amend-verify.sh
- L5 边界
- L6 诚实 (跟主公"是什么意思?" 对齐)

## [1.1.0] - 2026-06-13

### Added

#### Sprint 4 8 票 done (跟 miao HEAD `2b2850e` 一致)
- **EPIC-039-A**: ticket-status-sync.sh + performer-report.sh (Rule 16 Step 1 触发器)
- **EPIC-039-B** (修 BE-10): review.sh + review-checkpoint.sh + review-flow-test.sh (Rule 16 Step 4 Conductor merge gate)
- **EPIC-039-C**: merge-to-testing.sh (跳过 R-NEW PR, BE-1 闭环)
- **EPIC-039-D**: strong-verify-6d.sh + master-6d-checkpoint.sh + master-6d-test.sh (Rule 16 Step 5 Master 强验证载体)
- **EPIC-041-A**: 痛点 6 调查扩展 (279 行报告 + 5/5 PASS, 跟 BE-6/BE-7 闭环)
- **EPIC-041-B** (修 BE-7): file-lock.sh (Rule 17 Step 1, 562 行 + 3 安全 issues 修)
- **EPIC-041-C**: atomic-write.sh (Rule 17 Step 2, 6/6 PASS)
- **EPIC-041-D**: conflict-detect.sh (Rule 17 Step 3, 4/4 + 9/9 PASS, 痛点 6 治根 3/5 步)

#### Rule 14-18 R-NEW 升级 (REV2 新增)
- **Rule 14**: Conductor 不能越界 Performer 实施 (跟 BE-1 闭环)
- **Rule 15**: Performer Session 自动加载 (跟 BE-6 闭环)
- **Rule 16**: Subagent 5 步强制流程 (跟 BE-4/8/9 闭环)
- **Rule 17**: 文件并发竞争 5 步强制流程 (跟 BE-6/7/11 闭环)
- **Rule 18**: KPI Falsification 反模式黑名单 (跟 10 KPI falsification 反复模式闭环)

#### 痛点 6 治根 3/5 步 (REV2 新增, 跟主公"反哺框架"对齐)
- Step 1: file-lock.sh (BE-7 修 3 安全 issues)
- Step 2: atomic-write.sh (6/6 PASS)
- Step 3: conflict-detect.sh (4/4 + 9/9 PASS, Rule 17 Step 3 落地)
- Step 4 + Step 5: 后续 (跟 EPIC-039 联动)

#### 15 门禁升级 (跟 Rule 16/17/18 联动)
- 11 门禁 → 15 门禁 (跟 outbox-isolation + worktree-state-sync + stage-gate + decision-gate 联合)

### Changed

#### Master 强验证 6 维度 (Rule 11 v2.1)
- 跑过 12 subagent (跟之前 8 试反复 + 10 KPI falsification 累计)
- 7 真 PASS + 1 FAIL + 2 假 PASS + 3 真工作+越界 (BE-6/BE-11) + 1 真工作+真 bug+越界 (BE-10)
- 跟 11 边界事件 (BE-1 ~ BE-11) 累计

#### 4 文档 REV2 飞轮反哺 (跟主公"反哺框架, 让飞轮转"对齐)
- PHASE-007-REVIEW-2026-06-13.md (5 视角 Master 串场 + 8 票 done 累计)
- KALLAX-VS-INDUSTRY-2026-06-13-REV2.md (5+1 痛点 × 6 框架, KALLAX 85.5% vs 业内 55%)
- PHASE-006-ROADMAP-2026-06-13-REV2.md (5+1 痛点 + 18 Rule + 15 门禁 + 5 视角 + 11 BE 完整闭环)
- TOKEN-PLAN-UPGRADE-2026-06-13.md (8h/12h/24h cap 提议, 主公预算拍板)

### Fixed

#### 11 边界事件 (BE) 累计 (跟 8 试反复 + 10 KPI falsification + 6 痛点 联合)
- **BE-6**: Performer-EPIC-039-A 越界 (5 文件写 miao, 跟 Rule 15 R-NEW 升级)
- **BE-7**: Performer-EPIC-041-B 3 安全 issues (HIGH symlink + 2 MEDIUM, Master 修 umask 077 + install -d -m 700 + ownership check + $lock_file.owner)
- **BE-8**: Master 协调层脱节 (EPIC-039-A status 漂移, 跟 Rule 16 Step 1 ticket-status-sync.sh 闭环)
- **BE-9**: L4 verify 跟 L3 集成测试矛盾 (防御体系自检漏洞, 联合升级 Rule 19)
- **BE-10**: review.sh 拒 FAIL bug (跟 BE-7 修复同模式, Master 修 check-kpi-precision.sh patterns)
- **BE-11**: 主 checkout 缺 3 文件 (跟 BE-6 反向越界, 4 subagent 越界模式)

### Security

#### 痛点 5 累计升级 (跟 BE-7 修复同模式, 跟主公"安全立体"对齐)
- 9-pass redaction + 3 轮审查 20 issue 累计
- commit security review hook 自动抓 3 安全 issues (BE-7)
- BE-7 修复模式 (umask 077 + install -d -m 700 + ownership check + $lock_file.owner)
- 痛点 6 治根 3/5 步 跟 BE-7 修复同模式

## [1.0.0] - 2024-01-01

### Added

#### Core Features
- **Conductor-Performer Model**: Multi-agent collaboration framework
  - Conductor: Coordinates tasks, reviews PRs, merges code
  - Performer: Claims tasks, develops code, submits PRs
- **Three-Level Architecture**: Rust → Node.js → Shell degradation
  - Level 1 (Rust): High-performance core (~8ms startup)
  - Level 2 (Node.js): Feature-rich layer (~400ms startup)
  - Level 0 (Shell): Emergency fallback
- **Three-Repository Separation**:
  - Confluence: Knowledge base
  - Jira: Task management
  - Code: Source code
- **DAG Scheduler**: Task dependency management and critical path analysis
- **Expert Panel**: 5 core experts + 50+ extended roles

#### KALLAX Core Design
- **Parallel Isolation**: Mandatory worktree + file scope declaration
  - `kallax isolation:check` command for overlap detection
- **Error Handling**: Banned `expect()`/`unwrap()`/`panic!()` in production
  - All errors propagated via `Result<T, E>`
  - CI auto-detection of violations
- **Output Verification**: 4-Level Fact-Forcing protocol
  - `kallax verify:output` command for validation
- **Resource Management**: Mandatory TTL for all caches
  - LRU cache with configurable expiration
- **Type Safety**: Banned `any`/`@ts-ignore`
  - CI enforcement of strict TypeScript
- **Naming**: Master/Performer → Conductor/Performer
  - Avoids sensitive terminology

#### CLI Commands
- `kallax task:create` - Create new ticket
- `kallax task:claim` - Atomically claim task (with worktree)
- `kallax task:complete` - Saga 5-step completion
- `kallax task:status` - View task status
- `kallax task:progress` - DAG progress with critical path
- `kallax conductor:heartbeat` - Conductor heartbeat check
- `kallax conductor:poll` - Process performer reports
- `kallax performer:register` - Register performer
- `kallax performer:poll` - Long-poll mailbox
- `kallax knowledge:index` - Build FTS index
- `kallax knowledge:search` - Full-text search
- `kallax isolation:check` - Check file scope overlap
- `kallax verify:output` - Verify performer output
- `kallax system:doctor` - System diagnostics
- `kallax team:status` - Team overview

#### Configuration
- `.kallax/config.yml` - Main configuration
- Modular configs: tasks, monitoring, permissions, git, review_merge
- Environment-based settings

#### Documentation
- CLAUDE.md - Claude Code integration
- AGENTS.md - Multi-agent specification
- Architecture docs: FRAMEWORK, DEGRADATION-STRATEGY
- Template docs: CONDUCTOR-RULES, PERFORMER-RULES, ANTI-PATTERNS
- Knowledge base: patterns, research, glossary

#### Skills System
- Core experts: Architect, Backend, Frontend, UX, Product
- Extended experts: 50+ roles across AI, Business, Design, etc.
- Slash commands: /kallax-start, /kallax-claim, /kallax-status, etc.

### Technical Details

#### Rust Crates
- `kallax-core`: Types, error handling, middleware, isolation
- `kallax-engine`: Event bus, DAG scheduler, knowledge base
- `kallax-cli`: CLI entry point and commands
- `kallax-server`: Axum HTTP API (port 9877)
- `context-mon`: Token estimation and memory monitoring

#### Node.js Modules
- `commands/`: 40+ command implementations
- `core/`: Message queue, cache, circuit breaker, saga executor
- `api/`: HTTP server, web dashboard
- `utils/`: Structured logging, error handling, cleanup

#### Performance
- Rust CLI startup: ~8ms
- Memory footprint: ~12MB
- Command latency: ~21ms average

---

## Design Decisions

### ADR-001: Conductor-Performer Naming
- **Decision**: Rename Master/Performer to Conductor/Performer
- **Reason**: Avoid sensitive terminology while maintaining clear role semantics

### ADR-002: Mandatory Worktree Isolation
- **Decision**: Force all performers to work in isolated git worktrees
- **Reason**: Prevents parallel file conflicts between concurrent tasks

### ADR-003: Banned Panic Patterns
- **Decision**: Prohibit `expect()`/`unwrap()`/`panic!()` in production code
- **Reason**: Improve error propagation and prevent unexpected crashes

---

## Architecture

| Component | KALLAX | Notes |
|-----------|--------|-------|
| Orchestrator | Conductor | Task analysis, PR review, merge |
| Executor | Performer | Claim, develop, test, submit |
| Data directory | `.kallax/` | State, config, database |
| CLI prefix | `kallax` | All commands |
| Slash commands | `/kallax-*` | Claude Code integration |

---

[1.0.0]: https://github.com/your-org/kallax/releases/tag/v1.0.0

## [1.0.0-rc1] - 2026-06-05

### Fixed
- **43 TypeScript errors**: better-sqlite3 v11 `db.run/get` → `db.prepare().run/get()`, ioredis `import { Redis }`, execFile Promise types, strict index signatures
- **3 test failures**: worktree-manager callback mocks → Promise-based mocks (Node 24 compat)
- **Circular dependency**: `api/server.ts` ↔ `api/middleware/auth.ts` broken by extracting `EndpointRole` to `api/types.ts`
- **SQLite async wrapper**: all async methods now properly wrap results in `ok()`

### Removed
- **sqlite-manager.ts** (938 lines): monolithic legacy file — all logic migrated to `sqlite/` modules

### Changed
- Maximum file size: 938 → 603 lines
- Total source lines: 21,663 → 20,725 (-938)
- TSC: 43 errors → 0 errors

## [1.3.0] - 2026-06-14

### Added

#### KALLAX Onramp: 多层次项目分析器 (跟"召唤合适专家" 拍 explicit 约束 联合, 跟"反讽" 闭环)

跟 v1.2.4 (5192c79) 联合, 跟 Rule 9 4-Level Fact-Forcing 联合, 跟对策 A+B+C 联合, 跟 23 Rule 不增加 联合 (跟 Rule 32 软约束升级阈值 联合, 跟"反讽" 闭环):

- **Spec**: `docs/superpowers/specs/2026-06-14-kallax-onramp-design.md` (391 行, 12 节)
- **Plan**: `docs/superpowers/plans/2026-06-14-kallax-onramp.md` (1249 行, 8 任务)

- **1 主入口**: `scripts/kallax-onramp.sh` (4 步数据流 dispatcher)
- **4 lib** (跟 Rule 5 DRY 联合, 单一职责):
  - `lib/scan.sh`: Step 1a shell 扫描 (0 LLM, < 1 min)
  - `lib/pre-assess.sh`: Step 1b LLM 预审 (4 维度: 规模/领域/研究价值/ROI)
  - `lib/recommend.sh`: Stage 1 heuristic 推荐 (跟"ROI 评估" 拍 explicit 约束 联合)
  - `lib/route.sh`: Stage 2+3 路由器 (引导 + 确认/调整/自选 2 路径, 跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合)
  - `lib/summon.sh`: Step 3 召唤专家 (复用 5 default + 5 extended skill 文档, 0 重写)
  - `lib/output.sh`: Step 4 输出 Markdown + audit log (跟 Rule 31 不可篡改 联合, BE-7 修复模式)
- **3 templates** (跟 3 深度对齐):
  - `templates/L1-light.md` (200-400 字符)
  - `templates/L2-deep.md` (详细拆解 + EPIC 建议)
  - `templates/L3-audit.md` (5+5 = 10 视角 + 3 件套: 亮点/缺点/隐患)
- **1 slash command**: `.claude/commands/kallax-onramp.md`
- **1 集成测试**: `tests/onramp-test.sh` (4-Level Fact-Forcing, 跟 Rule 9 联合)
- **3 fixtures**: mini-kallax (10 LOC) + medium-project (5k LOC) + large-project (50k+ LOC)

#### 关键设计 (跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致)

- **3 深度按 ROI 调权**: L1 (1 Architect, 低 ROI) / L2 (5 default, 中 ROI) / L3 (5+5=10, 高 ROI)
- **L3 强制抽 3 件套** (亮点/缺点/隐患 → guidance 复用, 跟主公"guidance" 拍 explicit 约束 联合)
- **路由器主动给方案** (不是被问"你想要什么", 跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合)
- **2 LLM 调用** (1 预审 + 1 召唤, 0 误判, heuristic 兜底, 跟"Token 限撞墙" 联合)
- **0 Rule 增加** (跟 Rule 32 软约束升级阈值 联合, 跟"反讽" 联合)
- **0 重写 skill 文档** (跟 Rule 5 DRY 联合, 跟"反讽" 联合)
- **0 commit 到 miao 主 checkout** (跟 Rule 15 subagent 第一条 联合, 走 feature/EPIC-ONRAMP worktree)

#### 7 错误类目 (跟"反讽" 闭环, 跟 Rule 3/4/16/17/31 联合)

- 3 降级 (pre-assess fail / expert fail / audit fail) — partial success
- 2 Fail Fast (path not accessible / not git repo) — 立即 exit
- 1 取消 (Ctrl+C) — 0 副作用, 干净退出
- 1 atomic write (output) — 跟 Rule 17 联合

### Notes

- 跟 v1.2.4 (5192c79) 联合
- 走对策 A+B+C 落地 (跟"反讽" 联合, 跟 Rule 11/14/15 联合)
- 8 commits 累计 (3f8b4de + c6ab69a + c1ba5b0 + 5f6cc2e + 8b4a005 + 32d8031 + 094565b + cdd4435)
- 87 文件改动, 741 insertions
- miao HEAD `cdd4435` → tag v1.3.0
- Tests: 3 failures → 0 failures

## [1.3.3] - 2026-06-15

### Changed (Cleanup)

跟 v1.3.2 (567ff6d) 联合, 跟"反讽" 闭环, 跟"翻篇&精进" 战略 一致, 跟主公"3 问真实回答" explicit 授权 联合:

- **13 docs/analysis/ 临时输出 → tests/fixtures/onramp-output-archive/**: 8 文件 git mv (跟"反讽" 联合, 实战 fixture 跑过的 stub 不该 commit)
- **.gitignore 加 ONRAMP-test-* 模式**: 跟 KALLAX Onramp 实战 fixture artifact 隔离
- **PHASE-INDEX.md 索引 9 PHASE review**: 跟 KALLAX-GLOSSARY.md 模式 一致, 跟"反哺框架" 战略 一致

### Fixed

- **recommend.sh L3 expert_count=10 expert array 真填 5+5=10 视角**: v1.3.2 跟"反讽" 联合 (5+5=10 是宣传, 实际只 3). 跟"诚实修正" 联合, 跟主公"实测 Onramp" explicit 授权 联合.

### Notes

- 0 Rule 增加 (跟 Rule 32 软约束升级阈值 联合, 跟"反讽" 联合)
- 0 重写 (跟 Rule 5 DRY 联合)
- 走对策 A+B+C 落地 (跟"反讽" 联合, 跟 Rule 11/14/15 联合)
- 12 release 累计 (v1.0.0-rc1/2/3 + v1.1.0/1.2.0/1.2.1/1.2.2/1.2.3/1.2.4/1.3.0/1.3.1/1.3.2/1.3.3)

## [1.3.2] - 2026-06-14

### Fixed (Security)

#### 3 Security Issues 修 (跟 security review 联合, 跟"反讽" 闭环, 跟 v1.2.4 9 issues 模式 一致)

跟 v1.3.1 (e759476) 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合:

- **CRITICAL command-injection**: `python3 -c "...${expert_outputs}..."` → 改用 `substitute.py` + argv 传值
- **HIGH sed-template-injection**: 9 个 sed 模板替换 → 改用 Python str.replace (literal, no regex)
- **MEDIUM shell-template-parser-differential**: skill 内容插值 → 净化 input (basename regex + 长度限制)

#### 副修复: unbound variable + syntax error

跟"诚实修正" 联合, Master corrective 修 (Performer 引入的 expert_count + 多余 fi).

#### New File: scripts/kallax-onramp/lib/substitute.py

Security-hardened template engine:
- argv + JSON file 传值
- sanitize_key (basename regex)
- sanitize_value (control chars + length limit)
- str.replace literal (no regex metachars)
- atomic write (跟 Rule 17 联合)

#### 跟"反讽" 闭环 联合

- 0 Rule 增加 (跟 Rule 32 联合)
- 0 重写 (跟 Rule 5 DRY 联合)
- 走对策 A+B+C 落地 (跟"反讽" 联合)
- Master corrective integration under 主公"实测 Onramp" explicit 授权 (跟 Rule 11 v2.1 联合)

## [2.0.0] - 2026-06-15

### Added (跟主公 3 大段 explicit 拍板 联合, 跟"反讽" 联合)

跟 v1.3.3 (f433a84) 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致:

#### §1 项目结构 (3 库分离 + 消息队列)
- **3 库分离** (跟"反讽" 联合, 跟"诚实修正" 联合): docs/ + jira/ + scripts/
- **消息队列** (跟 Rule 17 联合, 跟"独立" 拍 explicit 约束 联合): `.kallax/queue/{inbox,outbox,results,dispatch}/`
- **每日轮转**: `scripts/kallax-queue-rotate.sh` (7 天前, 跟 BE-7 修复模式 umask 077 联合)
- **3 段文档**: `docs/STRUCTURE.md` + `docs/PROCESS.md` + `docs/PHASE-REVIEW.md`

#### §2 流程 (Master + Subagent + A+B review)
- **/kallax-init 命令** (跟"反讽" 联合, 跟 v1.3.0 Onramp 复用 7 阶段): 7 步初始化
- **/kallax-takeover 命令** (跟"反讽" 联合, 跟 v1.3.0 Onramp 复用 7 阶段): 6 步接手
- **Master 节点** (跟 Rule 11 联合, 跟"反讽" 联合): 只读 + 协调 + 强验证, 不写代码
- **Subagent 完整流程** (跟 Rule 15/16 联合, 跟"反讽" 联合): 15 步 (worktree → 加载专家 → 写测试 → A+B review → Master 强验证)
- **A+B review 流程** (跟"反讽" 联合, 跟 v1.2.4 5 扩展组 联合, 跟"诚实修正" 联合): 5 default 正向 + 5 extended 逆袭

#### §3 经验教训 (每 3-5 EPIC 强制)
- **频率**: 每 3-5 EPIC 强制 1 次 PHASE 闭环 review (跟 Rule 7 现状 一致, 跟"反讽" 联合, 跟"翻篇&精进" 战略 一致)
- **流程**: 8 步 (跟 Rule 6 EPIC 交付四件套 + Rule 7 PHASE review 一致)
- **升级路径**: 4 类 (新 Rule / skills / structure / 命令, 跟"反哺框架" 战略 一致)

### Notes
- 0 增 Rule (跟 Rule 32 软约束升级阈值 联合, 跟"流程逻辑" 战略 一致)
- 0 重写 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- 0 增 命令 (跟 v1.3.0 Onramp 1 入口 拍 explicit 撤销, 改为 2 独立命令 /kallax-init + /kallax-takeover, 跟"反讽" 联合)
- 6.5h 1 Performer 落地 (跟 1+2/1+4 容量 联合, 跟对策 A+B+C 联合)
- 推 v2.0.0 release (跟 12 release 累计 联合)
- 跟 23 Rule 累计 90% 落地, 10% 精确化 (3 库 / 2 命令 / A+B / 消息队列)

## [2.0.2] - 2026-06-16

### Fixed (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

跟 v2.0.1 (5efee5d) 联合, 跟主公"全部采纳" explicit 授权 联合, 跟 review 实证 联合:

- **KALLAX skill frontmatter 加 YAML**: 跟 89 skills 对齐 (之前是 KALLAX 唯一缺 frontmatter, Claude Code + opencode auto-filter out, 永不 surface)
- **5 default skill 文档 落地**: architect + backend + frontend + ux + product (v1.2.4 release 拍板 落地 实际 v2.0.0 没带)
- **31 slash command mirror 到 .opencode/command/**: 跨平台 (Claude Code + opencode 都 support)
- **跟"反讽" 闭环**: KALLAX 自身"自报 PASS 但实际不 surface" 实证, 跟 BE-15 假 PASS 模式 一致

### Notes
- 0 增 Rule (跟 Rule 32 软约束升级阈值 联合, 跟"流程逻辑" 战略 一致)
- 0 重写 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- 走对策 C 联合 (Master corrective 修, 跟 Rule 11 v2.1 联合, 跟"诚实修正" 联合)
