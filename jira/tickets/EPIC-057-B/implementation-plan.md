# EPIC-057-B Implementation Plan: kallax-onramp tool detection + dispatch

> Performer: EPIC-057-B | Branch: feature/EPIC-057-B-onramp-tool-detect | base: b2722e4
> 跟"反讽" 闭环, 跟 Rule 5 DRY 联合, 跟 Rule 9 KPI 精确 联合, 跟 Rule 4 Fail Fast 联合

---

## 1. Problem (现状)

`scripts/kallax-onramp.sh:34` 写死:
```bash
PRE_ASSESS_JSON=$(claude --print "${SCAN_DATA}" 2>/dev/null || echo '{}')
```

只支持 `claude` CLI, 主公 B explicit 拍 multi-tool. EPIC-057-A 在 `scripts/install.sh` 侧加 multi-tool auto-detect (claude/opencode/codex/gemini), 但 onramp 这边 Step 2 pre-assess 仍是 single-tool — 不一致.

实际环境:
- claude 2.1.153 (Claude Code) — `/Users/chenchen/.local/bin/claude`
- opencode 1.17.7 — `/Users/chenchen/.opencode/bin/opencode`
- codex — **missing on $PATH**
- gemini 0.22.2 — `/usr/local/bin/gemini`

→ 任何只有 opencode/gemini/codex 环境的机器, onramp Step 2 静默 fallback `'{}'`, 导致 recommend.sh 拿不到 LLM roi/value, 全走 A 简单方案 (跟"反讽" 闭环 — 工具存在却用不上).

---

## 2. Solution (设计)

**拆 2 个 lib + Step 2 改 1 行**:

| File | Role | AC |
|---|---|---|
| `scripts/kallax-onramp/lib/tool-detect.sh` | 检测 4 工具可用性, 输出 JSON | AC#1, AC#4, AC#5, AC#6 |
| `scripts/kallax-onramp/lib/dispatch.sh` | 调度检测到的工具执行 pre-assess prompt | AC#2, AC#5 |
| `scripts/kallax-onramp.sh` | Step 2 改用 dispatch (单行替换) | AC#3 |
| `tests/integration/onramp-tool-detect-test.sh` | 6 case 覆盖 | AC#7 |

**tool-detect.sh 设计**:
- `detect_tool()` 函数 — 按 **claude > opencode > codex > gemini** 优先级扫
- 检测信号 (2 个 AND):
  1. `command -v <tool>` (binary 在 $PATH)
  2. `$HOME/.{tool}/` (config dir 存在 — 表明用户实际用过)
- 命中后写 `KALLAX_DETECTED_TOOL=<name>` + `KALLAX_DETECTED_BINARY=<path>` + `KALLAX_DETECTED_VERSION=<ver>` 等 env vars
- 输出 JSON to stdout:
  ```json
  {"tool":"claude","binary":"/usr/local/bin/claude","version":"1.x.x","skills_dir":"~/.claude/skills/kallax/","commands_dir":"~/.claude/commands/"}
  ```
- 全失败 → stderr `No AI CLI tool detected` + exit 1

**dispatch.sh 设计**:
- `source tool-detect.sh` 拿检测结果
- `dispatch_pre_assess "$scan_json"` 函数:
  - 构造 prompt (跟原 onramp Step 2 同样的 raw scan_data)
  - 按 tool 选 invocation:
    | tool | invocation | 备注 |
    |---|---|---|
    | claude | `claude --print "$prompt"` | 原 onramp 写法 |
    | opencode | `opencode run "$prompt"` | 实测 help, 不是 `--non-interactive` |
    | codex | `codex exec "$prompt"` | binary 缺失时 fallback claude + warning |
    | gemini | `gemini "$prompt"` | 实测 help, positional prompt 默认 non-interactive |
  - 失败 → echo `{}` + warning to stderr (保留 onramp 现有 fallback 语义)

**kallax-onramp.sh Step 2 改动**:
```bash
# Before
PRE_ASSESS_JSON=$(claude --print "${SCAN_DATA}" 2>/dev/null || echo '{}')
# After
PRE_ASSESS_JSON=$(bash "${ONRAMP_LIB}/dispatch.sh" "${SCAN_DATA}")
```

---

## 3. 实测 CLI invocation (跟 AC#3 + AC#5 联合)

| tool | non-interactive flag/subcommand | version 检测 | 验证 |
|---|---|---|---|
| claude | `--print "<prompt>"` | `claude --version` | ✓ help 显示 `-p, --print` |
| opencode | `opencode run "<prompt>"` (subcommand) | `opencode --version` | ✓ `opencode run "PONG"` → "PONG" (实测) |
| codex | `codex exec "<prompt>"` (TBD, binary 缺失) | `codex --version` | ✗ binary missing → fallback |
| gemini | `gemini "<prompt>"` (positional) | `gemini --version` | ✓ help: "positional prompt... one-shot" |

注: 跟 ticket 假设的 `--non-interactive` flag 不同. opencode 实际是 `run` subcommand, gemini 是 positional prompt. 已在 help 验证.

---

## 4. test 6 case (TDD, AC#7)

| Case | Mock | Assertion |
|---|---|---|
| 1. claude detected | `HOME=tmp/.claude` + `PATH=mock:claude` | JSON.tool=="claude", binary 存在, exit 0 |
| 2. opencode detected | `HOME=tmp/.opencode` + `PATH=mock:opencode` | JSON.tool=="opencode", exit 0 |
| 3. codex missing binary fallback | `HOME=tmp/.codex` + no codex on PATH | JSON.tool=="claude" (next in priority) 或 exit 1 (如果也没 claude) |
| 4. gemini detected | `HOME=tmp/.gemini` + `PATH=mock:gemini` | JSON.tool=="gemini", exit 0 |
| 5. multi-tool priority | `HOME=tmp/{.claude,.opencode}` + both on PATH | JSON.tool=="claude" (priority wins) |
| 6. no-tool fallback | `HOME=tmp/none` + empty mock PATH | stderr contains "No AI CLI tool detected", exit 1 |

每 case 都独立 tmpdir, no shared state (Rule 7 Test Isolation).

---

## 5. Boundary (跟 file_scope 联合, 跟 EPIC-057-A/C/D 隔离)

| 路径 | 归属 |
|---|---|
| `jira/tickets/EPIC-057-B/**` | ✅ EPIC-057-B (本卡) |
| `scripts/kallax-onramp.sh` | ✅ EPIC-057-B (本卡) |
| `scripts/kallax-onramp/lib/tool-detect.sh` | ✅ EPIC-057-B (新) |
| `scripts/kallax-onramp/lib/dispatch.sh` | ✅ EPIC-057-B (新) |
| `tests/integration/onramp-tool-detect-test.sh` | ✅ EPIC-057-B (新) |
| `scripts/install.sh` | ❌ EPIC-057-A 边界 |
| `docs/guides/*` `README.md` | ❌ EPIC-057-C 边界 |
| `tests/integration/install-*` `multi-tool-e2e-test.sh` | ❌ EPIC-057-D 边界 |
| `node/ rust/ web/` | ❌ 跟本卡无关 |

boundary_violations = 0.

---

## 6. Anti-patterns avoided

- ❌ background 模式 — 同步跑
- ❌ 越界 file_scope — strict file_scope 守
- ❌ 修改 scripts/install.sh — EPIC-057-A 边界
- ❌ 假设 claude 一定可用 — Case 3 + Case 6 专门测 fallback
- ❌ 简化 6/6 PASS — 6 case 完整, 跟 Rule 9 KPI 联合
- ❌ merge to miao — Performer 禁 (Rule 1)
- ❌ 自审 — Rule 2
- ❌ `expect` / `unwrap` / `panic` — N/A (bash only)
- ❌ `any` 类型 — N/A
- ❌ console.log — N/A (用 echo to stderr)

---

## 7. Rule 9 KPI 精确

| Metric | Target | 验证 |
|---|---|---|
| Tests passed | 6/6 | test runner exit code + grep "Tests: 6 passed" |
| Rule 9 anti-fab | 7/7 | check-*.sh + l3-l4 + kpi-evidence + tool-self-check |
| Boundary violations | 0 | git diff --name-only 仅在 file_scope 内 |
| Real test output | 100% raw | 不省略任何 PASS 行 |

---

## 8. Rollback plan

如果 6/6 不 PASS:
1. 回滚 `scripts/kallax-onramp.sh` Step 2 1 行修改
2. 保留 `tool-detect.sh` `dispatch.sh` 测试覆盖 (作为未来 re-enable 基础)
3. 报 PARTIAL 而非 PASS

---

## 9. Lessons (前置预告)

3-5 lessons 候选:
1. opencode 没有 `--non-interactive` flag, 是 `run` subcommand — 实测很重要, 不要 trust ticket 假设
2. `command -v` + `$HOME/.{tool}/` 双信号比单信号更准 (避免 $PATH 残留未用)
3. fallback 保留 `|| echo '{}'` 语义是关键 — 跟现有 pre-assess.sh fallback 联合, 不打破现有 contract
4. Bash sub-shell + `set -e` 的 exit code propagation — dispatch.sh 不能 `set -e` 因为 `claude --print` 可能 fail 但我们要 fallback
5. 优先级 = install.sh alignment, 减少未来 EPIC-057-A merge 冲突