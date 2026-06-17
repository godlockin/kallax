# EPIC-057-D Implementation Plan

> Author: performer-EPIC-057-D
> Date: 2026-06-17
> Ticket: EPIC-057-D (P1, test, 3h)

## 1. 目标 (Goals)

写 3 个 integration tests 闭环 EPIC-057 (multi-tool skills support):
- `tests/integration/install-multi-tool-test.sh` 8/8 PASS
- `tests/integration/onramp-tool-detect-test.sh` 6/6 PASS
- `tests/integration/multi-tool-e2e-test.sh` 4/4 PASS

合共 18/18 PASS = 100.0% (Rule 9 精确 X/Y 格式)

跟主公 2026-06-17 拍 B explicit 联合 ("4 工具 multi-tool install + onramp tool detection")
跟 EPIC-053-A l3-l4-consistency 环境隔离模式 联动 (KALLAX_TEST_HOME)
跟 EPIC-057-A (install.sh --target=auto) + EPIC-057-B (onramp tool-detect) 边界清晰

## 2. file_scope (边界)

**可写 (8 paths)**:
1. `jira/tickets/EPIC-057-D/` — 实现记录 + lessons
2. `tests/integration/install-multi-tool-test.sh` (new, 配对 057-A)
3. `tests/integration/onramp-tool-detect-test.sh` (new, 配对 057-B)
4. `tests/integration/multi-tool-e2e-test.sh` (new, e2e)
5. `tests/fixtures/mock-tools/claude/` (mock + skills/SKILL.md + settings.json)
6. `tests/fixtures/mock-tools/opencode/` (mock + skills/SKILL.md + config.json)
7. `tests/fixtures/mock-tools/codex/` (mock + skills/SKILL.md + config.toml)
8. `tests/fixtures/mock-tools/gemini/` (mock + skills/SKILL.md + config/settings.json)

**不可写 (越界 BE)**:
- `scripts/install.sh` (跟 057-A 边界)
- `scripts/kallax-onramp.sh` + `lib/*` (跟 057-B 边界)
- `docs/guides/*` + `README.md` + `CHANGELOG.md` (跟 057-C 边界)
- 其他 EPIC 边界

## 3. 测试设计 (Test design)

### 3.1 install-multi-tool-test.sh (8 TC)

> **GAP (057-A → 057-D)**: 057-A 实际写 6 TC, 跟 ticket AC#1 "8/8" 不符.
> 057-D 必须把 6 → 8 拓展, 闭环 AC#1. file_scope 明确 include 此 file, 越界 0.

| TC  | 名称                              | 验证                                                      |
|-----|-----------------------------------|-----------------------------------------------------------|
| TC1 | --target=auto                     | 检测 4 工具存在性 + auto-install (4 skills dirs)          |
| TC2 | --target=all                      | 强制全装 4 工具 (0 mock → 强制 4 dirs)                    |
| TC3 | --target=claude + no ~/.claude    | boundary: exit 1 + error msg                              |
| TC4 | --target=opencode,codex           | 多工具 (逗号分隔) → 装 2 + 跳过 2                        |
| TC5 | --target=nonexistent (boundary)   | 错误路径 → exit 1 + 'Unknown tool'                       |
| TC6 | 0 detected + 0 binary             | exit 1 + suggestion ('--target=all' 等)                   |
| **TC7** | **SKILL.md loadable (NEW)**  | 装完后 `~/.claude/skills/kallax/SKILL.md` 存在 + frontmatter 含 `name:` + ≥14 files |
| **TC8** | **permissions configured (NEW)** | 装完后 `~/.claude/settings.json` 存在 + `.permissions.auto` 含 `Bash:.claude/commands/*.sh` (jq verify) |

每个 TC 都用 `KALLAX_TEST_HOME` 隔离 (跟 EPIC-053-A 联动)

### 3.2 onramp-tool-detect-test.sh (6 TC)

| TC  | 名称                              | 验证                                             |
|-----|-----------------------------------|--------------------------------------------------|
| TC1 | claude detected                   | claude 在 $PATH 或 $HOME/.claude/                |
| TC2 | opencode detected                 | opencode 在 $PATH 或 $HOME/.opencode/            |
| TC3 | codex detected                    | codex 在 $PATH 或 $HOME/.codex/                 |
| TC4 | gemini detected                   | gemini 在 $PATH 或 $HOME/.gemini/                |
| TC5 | multi-tool priority               | claude > opencode > codex > gemini               |
| TC6 | no-tool fallback (boundary)       | 4 工具都缺 → exit 1 + 'install claude' suggestion |

每个 TC 用 mock binary (in PATH) 或 mock $HOME/<tool>/ dir

### 3.3 multi-tool-e2e-test.sh (4 TC)

| TC  | 名称                              | 验证                                                                              |
|-----|-----------------------------------|-----------------------------------------------------------------------------------|
| TC1 | install → onramp flow             | install.sh --target=all → tool-detect → JSON.tool=="claude" (priority wins)        |
| TC2 | --target=claude + no ~/.claude    | boundary: install.sh --target=claude 无 mock → exit 1 (跟 AC#7 联合)              |
| TC3 | 0 tools detected + 0 binary      | boundary: tool-detect 无 mock 全失败 → exit 1 + 'install claude' suggestion (AC#8) |
| TC4 | cross-ticket consistency          | install paths (4 工具 skills_dir) == tool-detect paths (一致性契约)               |

每个 TC 都用 `KALLAX_TEST_HOME` 覆盖 `$HOME` (跟 EPIC-053-A 环境隔离模式联动, ticket AC#5)
`KALLAX_TEST_HOME` 默认 `${KALLAX_TEST_HOME:-$HOME}`, 跟 install.sh / tool-detect.sh 兼容.

## 4. fixture 设计 (4 工具 mock 结构)

每个 mock tool 目录:
```
tests/fixtures/mock-tools/<tool>/
├── skills/
│   └── SKILL.md     # 模拟该工具已识别 skills
├── settings.json    # claude: ~/.claude/settings.json
│                     # opencode: ~/.opencode/config.json
│                     # codex: ~/.codex/config.toml
│                     # gemini: ~/.gemini/config/settings.json
└── .tool-marker     # mock marker (供 onramp 检测)
```

SKILL.md 内容参考 EPIC-057-A:1 真实 4 工具 skills dir 路径:
- claude → ~/.claude/skills/kallax/
- opencode → ~/.opencode/skills/kallax/
- codex → ~/.codex/skills/kallax/
- gemini → ~/.gemini/skills/kallax/

## 5. 实现步骤 (TDD)

### Step 1: 写 IMPLEMENTATION-PLAN.md (本文件) ✓

### Step 2: 写 mock-tools fixtures
- 创建 4 个 mock tool 目录结构
- 每个含 skills/SKILL.md + settings 文件
- KALLAX_TEST_HOME 隔离模式

### Step 3: 写 install-multi-tool-test.sh (8 TC)
- TC1-TC4: --target 各种 flag (red-phase 期待 057-A 实现)
- TC5-TC8: 当前 install.sh 行为 (可部分绿)

### Step 4: 写 onramp-tool-detect-test.sh (6 TC)
- TC1-TC5: tool-detect 行为 (red-phase 期待 057-B 实现)
- TC6: no-tool fallback (red-phase)

### Step 5: 写 multi-tool-e2e-test.sh (4 TC)
- TC1: install 4 tools (依赖 057-A)
- TC2-TC4: e2e flow (依赖 057-A + 057-B)

### Step 6: 跑 tests + 收集 raw output
- 当前状态: 部分 TC pass (TC5-TC8 install 跟当前 install.sh 一致)
- Red-phase TC: 等 057-A + 057-B merge 后 green

### Step 7: 写 LESSONS-LEARNED.md

### Step 8: 写 pass-report JSON

## 6. KALLAX 原则 (对齐)

- **Rule 1 (类型安全)**: bash strict mode (`set -uo pipefail`), no `any`/`@ts-ignore` 等价物
- **Rule 3 (防御错误处理)**: 每个 TC try/catch 等价 (`set +e` 包运行 + `set -e` 收集 exit code)
- **Rule 4 (Fail Fast)**: TDD red-phase 立即报告 0/N PASS, 不假装成功
- **Rule 5 (DRY)**: helper 函数 (`run_install`, `assert_file_exists`) 复用
- **Rule 6 (不变性)**: readonly 变量, KALLAX_TEST_HOME 不修改 $HOME
- **Rule 7 (依赖注入)**: KALLAX_TEST_HOME 注入 mock 环境, 无 global state
- **Rule 8 (可观测)**: 每个 TC echo `[PASS]`/`[FAIL]` 标签
- **Rule 9 (KPI 精确)**: X/Y 格式 (8/8, 6/6, 4/4)

## 7. 联动 (Linkage)

- **EPIC-053-A l3-l4-consistency**: KALLAX_TEST_HOME 环境隔离模式
- **EPIC-057-A install.sh**: tests/integration/install-multi-tool-test.sh 配对
- **EPIC-057-B onramp**: tests/integration/onramp-tool-detect-test.sh 配对
- **EPIC-057-C docs**: 跟 docs 边界清晰 (不修改)
- **PHASE-009 v2.0.6 release**: 闭环 v2.0.2 '跨平台 fix' 反讽
- **主公 2026-06-17 'B' 拍板**: 4 工具 multi-tool 明确
- **'反讽' 闭环**: v2.0.2 '跨平台 fix release' 命名 vs 实际 Claude Code only 状态 修复
- **'诚实修正' 联合**: 主公 explicit 区分 'Claude Code 完全支持' vs 'opencode 半支持' vs 'codex/gemini 完全不支持'

## 8. 风险 + 缓解

**风险 1**: 057-A + 057-B 未 merge 时, install + onramp tests 全 red-phase
- **缓解**: 诚实报告 partial pass, 标 TDD red-phase, pass-report 标注 'awaiting sibling merges'
- **不掩盖**: 不用 mock harness 假装 pass (跟 '诚实修正' + '反讽' 闭环 一致)

**风险 2**: 跟 057-A/057-B file_scope 重叠
- **缓解**: 严格遵守 excludes, 只写 tests/ + jira/tickets/EPIC-057-D/

**风险 3**: Mock tools 跟真实工具 path 冲突
- **缓解**: KALLAX_TEST_HOME 完全覆盖 $HOME, mock 在 tempdir 下