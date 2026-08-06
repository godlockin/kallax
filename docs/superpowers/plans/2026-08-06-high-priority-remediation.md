# 高优先级缺陷修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除已确认的安全、授权、状态、ledger、工作流和验证门禁缺陷。

**Architecture:** 按信任边界拆分四个可独立验收批次。Shell 外部数据保持 argv/stdin，路径与角色由 canonical state 验证；ledger 使用单一 schema 且任何关键写入失败可观察或阻断；验证门禁统一 fail-closed。

**Tech Stack:** Bash、jq、GitHub Actions YAML、Rust、Node.js/TypeScript、Cargo、Vitest。

## Global Constraints

- 不使用 `eval`、可变输入拼接的 `bash -c` 或 `flock -c`。
- 所有不可信 JSON 使用 `jq --arg` / `--argjson` 生成。
- 权限拒绝、ledger 损坏、关键审计 emit 失败默认非零退出。
- 保持已有 CLI 子命令及合法环境变量名称；不安全 bypass 改为明确错误。
- 禁止 `any`、`@ts-ignore`；TypeScript strict。
- 每项先添加可复现的失败测试，再写最小实现；每任务单独提交。

---

### Task 1: 修复 Shell 命令执行、权限与审计边界

**Files:**
- Modify: `scripts/docker-redis.sh`, `scripts/supervisor.sh`, `scripts/heartbeat/run-history.sh`
- Modify: `scripts/lib/workspace.sh`, `scripts/permission/readonly-path.sh`, `scripts/permission/workspace-switch.sh`, `scripts/permission/authz/check.sh`
- Test: `tests/integration/run-history-emit-integration.test.sh`, `tests/integration/workspace-switch-test.sh`
- Create: `tests/integration/security-boundary-regression.test.sh`

**Interfaces:**
- Produces: command execution accepts only argv/stdin; `run-history.sh emit` appends one valid JSONL record without secondary shell parsing; authorization derives role from state; workspace read/write remains inside canonical root.

- [ ] **Step 1: Write failing regression cases**

Add `security-boundary-regression.test.sh` cases which stub `docker`, source workspace helpers, and assert: semicolon-bearing Redis password creates no sentinel; supervisor path with shell metacharacters creates no sentinel; `../../` and absolute workspace paths return nonzero; `KALLAX_CURRENT_ROLE=master` cannot override performer state; protected absolute `miao/` path is read-only; Linux audit target is `${AUDIT_DB}.log`.

- [ ] **Step 2: Verify regressions fail before implementation**

Run: `bash tests/integration/security-boundary-regression.test.sh`
Expected: at least one injection, traversal, role override, or path protection assertion fails.

- [ ] **Step 3: Implement minimal safe boundaries**

Use a Docker argv array:

```bash
local -a docker_args=(run -d --name "$CONTAINER_NAME" -p "${REDIS_PORT}:6379" -v "${REDIS_DATA_DIR}:/data" --restart unless-stopped)
if [[ -n "$REDIS_PASSWORD" ]]; then
  docker_args+=(-e "REDIS_PASSWORD=$REDIS_PASSWORD" redis:7-alpine redis-server --appendonly yes --requirepass "$REDIS_PASSWORD")
else
  docker_args+=(redis:7-alpine redis-server --appendonly yes)
fi
docker "${docker_args[@]}"
```

Replace supervisor string execution with quoted branch-specific subshells. Replace `flock -c` with a file descriptor lock and `printf '%s\n' "$record"`. Build ledger records using `jq -cn --arg ... --argjson payload ...`. Reject non-object payload. Reject absolute/traversal workspace paths and validate canonical containment. Match protected paths against canonical repository root. Ignore environment role overrides in production scripts. Pass audit target as `sh -c` positional argument.

- [ ] **Step 4: Run targeted regressions**

Run: `bash tests/integration/security-boundary-regression.test.sh && bash tests/integration/run-history-emit-integration.test.sh && bash tests/integration/workspace-switch-test.sh`
Expected: all pass; no sentinel file; invalid inputs return nonzero.

- [ ] **Step 5: Commit**

```bash
git add scripts tests
git commit -m "fix(security): harden execution and authorization boundaries"
```

### Task 2: 修复 ticket 状态机与 ledger 完整性

**Files:**
- Modify: `rust/crates/kallax-engine/src/ticket_engine.rs`, related Rust tests
- Modify: `scripts/performer-complete.sh`, `scripts/automation-monitor-todos.sh`
- Modify: `scripts/heartbeat/run-history.sh` and emit callers in `scripts/{binding,heartbeat}/`, `scripts/branch-4pr.sh`, `scripts/post-process.sh`, `scripts/install.sh`, `scripts/skill/skill-manager.sh`
- Test: Rust ticket tests and `tests/integration/run-history-emit-integration.test.sh`

**Interfaces:**
- Produces: one performer has at most one active task; ticket terminal state follows all gates; all ledger events use required central schema and failures are fail-closed/degraded explicitly.

- [ ] **Step 1: Add failing tests**

Add Rust test that a second Ready ticket claimed by same performer returns an error and performer changes Idle→Busy→Idle after completion. Add shell fixtures proving automation-monitor output passes `run-history verify`, invalid payload fails before append, and unavailable ledger makes critical emit nonzero.

- [ ] **Step 2: Verify failures**

Run: `cargo test --manifest-path rust/Cargo.toml ticket_engine && bash tests/integration/run-history-emit-integration.test.sh`
Expected: duplicate claim/schema/fail-open cases fail.

- [ ] **Step 3: Implement state and ledger fixes**

On claim, perform compatible ticket/performer updates with rollback when second update fails; release performer on terminal completion. Move performer-complete `status=done` write after all gates and mark failure `blocked`. Route automation monitor through `run-history.sh emit` using permitted event type and agent ID. Remove `|| true` for critical emits; where explicitly best-effort, emit structured degraded diagnostic and return detectable nonzero/degraded status.

- [ ] **Step 4: Run targeted tests**

Run: `cargo test --manifest-path rust/Cargo.toml ticket_engine && bash tests/integration/run-history-emit-integration.test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add rust scripts tests
git commit -m "fix(governance): preserve ticket and ledger integrity"
```

### Task 3: 修复 daemon、branch flow 与 query 可靠性

**Files:**
- Modify: `scripts/heartbeat/heartbeat-daemon.sh`, `scripts/branch-4pr.sh`, `scripts/heartbeat/run-history.sh`
- Test: `tests/integration/heartbeat-daemon-runtime.test.sh`, `tests/integration/run-history-emit-integration.test.sh`

**Interfaces:**
- Produces: daemon survives tick 12; branch validation covers every Rust workspace crate; bypass requires documented emergency reason; query accepts documented named options and rejects malformed JSONL.

- [ ] **Step 1: Add failing tests**

Add daemon interval-1 regression asserting process remains alive after 13 ticks. Add query `--type=`, `--agent=`, `--ticket=` assertions plus corrupt JSONL failure assertion. Add branch argument test proving `--skip-tests` without `--emergency <reason>` fails.

- [ ] **Step 2: Verify failures**

Run: `bash tests/integration/heartbeat-daemon-runtime.test.sh && bash tests/integration/run-history-emit-integration.test.sh`
Expected: failures expose current lifecycle/query/bypass defects.

- [ ] **Step 3: Implement fixes**

Resolve `active_ticket` before all emit payload branches. Require `cargo test --workspace --release`; parse `--emergency <reason>` and reject test skip without it. Parse only documented query options; use `jq --arg`; validate every JSONL line and return nonzero with line number for malformed data.

- [ ] **Step 4: Run targeted tests**

Run: `bash tests/integration/heartbeat-daemon-runtime.test.sh && bash tests/integration/run-history-emit-integration.test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts tests
git commit -m "fix(workflow): enforce reliable daemon and branch verification"
```

### Task 4: 关闭 CI、证据与 emit 测试 fail-open

**Files:**
- Modify: `.github/workflows/ci.yml`, `.github/workflows/rust-test.yml`, `scripts/hooks/pre-commit`
- Modify: `tests/integration/run-history-emit-integration.test.sh`
- Test: relevant shell test and YAML/static assertions

**Interfaces:**
- Produces: security audit, secret detection, no-default-features, claim evidence and branch emit regressions block success when violated.

- [ ] **Step 1: Add failing static and integration assertions**

Extend test to use an isolated ledger and assert actual branch decision event fields, never only line count. Add shell/static assertions that `ci.yml` security gate has no `continue-on-error: true`, secret hit exits nonzero, Rust no-default feature job blocks, and pre-commit invokes `check-claim-evidence.sh`.

- [ ] **Step 2: Verify failures**

Run: `bash tests/integration/run-history-emit-integration.test.sh`
Expected: branch emit/static gate cases fail on current implementation.

- [ ] **Step 3: Implement fail-closed gates**

Remove security/no-default-feature `continue-on-error`; make secret match exit nonzero; invoke claim-evidence from pre-commit immutable checks. Replace dry-run count assertion with an isolated execution path that asserts appended `decision` event schema and payload.

- [ ] **Step 4: Run targeted tests**

Run: `bash tests/integration/run-history-emit-integration.test.sh && bash scripts/verify/check-claim-evidence.sh`
Expected: PASS on repository state.

- [ ] **Step 5: Commit**

```bash
git add .github scripts tests
git commit -m "fix(verify): close CI evidence and emit test bypasses"
```
