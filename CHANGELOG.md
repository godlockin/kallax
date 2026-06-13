# Changelog

All notable changes to KALLAX will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Tests: 3 failures → 0 failures
