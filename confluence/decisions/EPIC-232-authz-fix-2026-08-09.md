# EPIC-232 — authz state.json 路径 + HOOK_BYPASS 失效 + exit 码语义

- **日期**: 2026-08-09
- **拍板**: 主公 ("继续")
- **前置**: EPIC-231 §7.2 + §7.3 (诊断出但未修), EPIC-068-A (state.json 路径约定), EPIC-227 (worktree hook)
- **版本**: v3.34.9

## 1. 为什么

EPIC-231 期间 commit 被 pre-commit 拦, 报"授权拒绝":

```
BLOCKED: Authorization denied by authz check.
Branch: feature/EPIC-231-pr-gate (action: worktree.commit)
Actor:  master
```

实际不是授权问题。诊断出 4 个独立 bug, 本 EPIC 全修。

## 2. 5 个 bug

### 2.1 `session_start.sh` 写双层 `.kallax/.kallax/`

`KALLAX_ROOT` 在本仓库有**两种互斥语义**, 同名同变量:

| 语义 | 含义 | 正确拼法 | 用在哪 |
|---|---|---|---|
| A | 仓库根 | `$KALLAX_ROOT/.kallax/state/` | 9 个 authz 脚本 |
| B | `.kallax` 目录本身 | `$KALLAX_ROOT/state/` | `session_start.sh` |

`session_start.sh` 第 25 行是语义 B:

```bash
KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"     # 正确
```

但 EPIC-068-A 加 state.json 双写时按语义 A 拼:

```bash
mkdir -p "${KALLAX_ROOT}/.kallax/state"                    # → .kallax/.kallax/state
_STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"      # → 多一层
```

**实测**:

```
$ find . -name state.json -path "*state*" -not -path "*/node_modules/*" | head -1
./.kallax/.kallax/state/state.json          ← 多一层 .kallax
$ ls .kallax/state/state.json
ls: ...: No such file or directory
```

**扫描范围**: 13 个脚本用语义 B 默认值, 其中只有 `session_start.sh` 1 个文件 4 处
同时拼了 `/.kallax/` (双层 bug), 其余 12 个拼法正确。

**附带发现 (第 3 处错)**: `_KDB` 不只双层, 还缺 `data/` 子目录:

```bash
_KDB="${KALLAX_ROOT}/.kallax/kallax.db"     # 算出 .kallax/.kallax/kallax.db
# 真实位置: .kallax/data/kallax.db
```

因为是 fail-open (`[ -f "$_KDB" ]` 不存在则 skip), 这个 EPIC-113-A 的
triple-write 从加进来那天起**一直静默不生效**, 无任何报错。

**修法**: 不改 `KALLAX_ROOT` 定义 (会崩语义 B 的 3 行), 引入显式命名的变量:

```bash
KALLAX_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
KALLAX_STATE_DIR="${KALLAX_REPO_ROOT}/.kallax/state"
```

### 2.2 worktree 里没有 state.json, 且无机制创建

即使路径修对, worktree 里仍然失败:

```
$ cd .claude/worktrees/agent-epic232
$ bash scripts/permission/authz/check.sh --action worktree.commit --actor master
$ echo $?
2
```

`authz/check.sh` 用 `SCRIPT_DIR/../../..` 算 `KALLAX_ROOT`, 在 worktree 里就指向
worktree 自己, 而那里从来没有 `state.json` — 没有任何机制创建它。

**判断**: `state.json` 含 `pid` / `heartbeat` / `instance_id`, 是 runtime 状态。
一个 master 进程跑在一处, 不该因为进了 worktree 就变成"没角色"。所以应**共享**,
而不是每个 worktree 复制一份。

**修法**: 本地找不到时回退到主仓库:

```bash
_common_dir="$(git -C "$KALLAX_ROOT" rev-parse --git-common-dir 2>/dev/null || echo "")"
# --git-common-dir 可能返回相对路径 ".git", 先转绝对
if [[ "$_common_dir" != /* ]]; then
  _common_dir="$(cd "$KALLAX_ROOT/$_common_dir" 2>/dev/null && pwd || echo "")"
fi
_shared_state="$(dirname "$_common_dir")/.kallax/state/state.json"
```

### 2.3 `jq` exit 2 在 `set -e` 下中断, 友好报错永远打不出

原代码看起来已经处理了这个情况:

```bash
ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"
if [[ -z "$ROLE" ]]; then
  echo "ERROR: No role in state.json ($STATE_FILE)" >&2   # ← 永远到不了
  exit 1
fi
```

但 `set -euo pipefail` 下, `jq` 返回 2 使整个赋值语句非零, 脚本在赋值那行就中断。
第 113-115 行的友好报错从未执行, 调用方只看到 `rc=2`。

**后果**: pre-commit 的 `if ! bash "$AUTHZ_CHECK"` 把任何非零当"授权拒绝",
所以显示"你没权限"而真因是"配置文件缺失" — **错误信息指向了错误的方向**。

**修法**: 先显式检查文件存在, 再 `|| true` 兜住 `jq`:

```bash
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state.json not found: $STATE_FILE" >&2
  echo "  这不是授权拒绝, 是配置缺失. 检查 .kallax/state/ 是否存在." >&2
  exit 1
fi
ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null || true)"
```

### 2.4 `HOOK_BYPASS` 变量设了但没人读

```
$ KALLAX_HOOK_BYPASS=1 git commit -F <msg>
WARN: pre-commit bypass via KALLAX_HOOK_BYPASS=1      ← bypass 生效了
BLOCKED: Authorization denied by authz check.          ← 但仍被拦
COMMIT_RC=1
```

`pre-commit` 第 23-36 行设 `HOOK_BYPASS=1` 并打印 WARN, 但 Check 0 (authz) 和
Check 0.5 (conductor-scope) **不引用这个变量** (grep 0 处命中)。bypass 只对后面的
4 immutable-law 检查有效 (它们用 `if [[ "$HOOK_BYPASS" -eq 0 ]]`)。

**修法**: Check 0 / Check 0.5 补 `HOOK_BYPASS` 判断, 并把 `rc=1` (真拒绝) 跟
`rc>=2` (脚本没跑成) 分开报 — 仍然拦 (fail-closed 不变), 但说对原因。

## 2.5 bug 5 — EPIC-227 那一行自己有运算符优先级 bug

修完前 4 个后不用 bypass 提交, 撞到**新**错误:

```
BLOCKED: AUTHZ_CHECK not found or not executable.
Script: /Users/.../agent-epic232
/Users/.../agent-epic232/scripts/permission/authz/check.sh
       ↑ 路径出现了两次
```

**根因**在 EPIC-227 声称"修好"的那一行:

```bash
KALLAX_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../.." && pwd)"
```

bash 里 `||` 和 `&&` 优先级相同、左结合, 所以这解析为:

```
$(A || (cd B && pwd))     ← 不是想要的 $((A) || (cd B && pwd))
```

`git rev-parse` **成功**时, `||` 短路跳过 `cd B`, 但 `&& pwd` 仍然执行 —
于是命令替换输出**两行** (toplevel 一行, pwd 一行)。

**复现**:

```
$ R="$(git rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../.." && pwd)"
LINES=2
VALUE=[/Users/.../agent-epic232
/Users/.../agent-epic232]

$ # 正确写法
$ R2="$(git rev-parse --show-toplevel 2>/dev/null)"
$ if [ -z "$R2" ]; then R2="$(cd "$SCRIPT_DIR/../.." && pwd)"; fi
LINES=1
```

`KALLAX_ROOT` 成了 `"路径\n路径"`, 拼出的 `AUTHZ_CHECK` 路径非法, 落到
"AUTHZ_CHECK not found" 的 fail-closed 分支。

**修法**: 拆成两句, 不依赖 `||` / `&&` 优先级。

**同类扫描**: `grep -rn 'dev/null . cd .*&& pwd' scripts/ .kallax/hooks/ .git/hooks/`
→ 0 处其他实例 (这个写法只在 EPIC-227 那一行出现过)。

**为什么 EPIC-227 没发现**: EPIC-227 当时用了 `KALLAX_HOOK_BYPASS=1` 提交
(见 EPIC-226 §6 记录的 bypass 先例链), 所以那行代码从未在真实 commit 路径上跑过。
**bypass 掩盖了它要修的东西自己是坏的。**

## 3. 实跑证据

### 3.1 测试

```
$ bash tests/integration/epic-232-authz-fix-test.sh
Results: 21 pass, 0 fail, 1 skip
```

skip 项是 TC22 (hook-health 进 all-checks) — 那是 EPIC-231 的改动, PR #333
未合入 main 时不适用, 标 skip 而非假 FAIL。

### 3.2 worktree authz 从 exit 2 → 0

```
$ bash scripts/permission/authz/check.sh --action worktree.commit --actor master
PASS: record_authz_event
rc=0
```

### 3.3 配置缺失时报对原因 (exit 1 而非 2)

在隔离临时目录 (无 state.json 也不在 git repo 内) 跑:

```
$ bash /tmp/.../check.sh --action worktree.commit --actor master
ERROR: state.json not found: /var/folders/.../.kallax/state/state.json
  这不是授权拒绝, 是配置缺失. 检查 .kallax/state/ 是否存在.
rc=1
```

### 3.4 扫描范围确认

```
$ grep -rl 'KALLAX_ROOT="${KALLAX_ROOT:-\.kallax}"' scripts/ .kallax/hooks/ | wc -l
13
$ # 其中同时拼 /.kallax/ 的:
  4  .kallax/hooks/session_start.sh
```

## 4. 修正 EPIC-231 §7.3 的一个判断错误

EPIC-231 文档把"`install.sh --verify` 未接进 CI required check"列为待办项 4。
**这是错的** — 实测 CI 已经在跑:

```
$ grep -n "install.sh" .github/workflows/ci.yml
41:          for h in pre-commit pre-push commit-msg install.sh; do
50:          if bash scripts/hooks/install.sh --verify; then
61:          bash scripts/hooks/install.sh
62:          bash scripts/hooks/install.sh --verify
```

EPIC-224 的 `--verify` + `cmp -s` STALE 检测都是真实现的, `hook-health` job 真在跑,
EPIC-231 又把它补进了 `all-checks.needs`。这项**不需要额外改动**, 本 EPIC 只加
TC19-TC22 做回归保护。

**另一个 STALE 相关发现**: 主仓库工作区的 `scripts/hooks/install.sh` 和
`.github/workflows/dco-check.yml` 都是**未 pull 的旧版**。跑 `install.sh --verify` 时
旧版忽略了 `--verify` 参数直接执行了安装 — 副作用是它顺手把 `.git/hooks/` 里的
STALE 副本 (EPIC-227 修复前的 `KALLAX_ROOT` 写法) 更新成了新版。
这不是设计行为, 属于运气。真正的教训是: **本地工作区落后于 remote 时,
"跑脚本验证"可能跑的是旧代码**。

## 5. 影响

**正面**:
- worktree 内 commit 不再被误拦
- 配置缺失跟授权拒绝的错误信息分开, 可诊断
- `KALLAX_HOOK_BYPASS=1` 名副其实
- EPIC-113-A 的 SQLite triple-write 首次真正生效 (原先 fail-open 静默跳过)

**代价**:
- `session_start.sh` 下次运行会在正确位置创建 `.kallax/state/state.json`,
  旧的 `.kallax/.kallax/` 目录成为孤儿 (未删, 留作审计)
- authz 多一次 `git rev-parse --git-common-dir` 调用 (仅当本地无 state.json 时)

## 6. 风险

| 风险 | 缓解 |
|---|---|
| `KALLAX_REPO_ROOT` 在非 git 目录为空 | `|| pwd` fallback |
| `--git-common-dir` 返回相对路径拼错 | 显式转绝对路径 (TC8 覆盖) |
| bypass 现在能跳过 authz — 权限被削弱 | bypass 需显式设环境变量, 且打印 WARN 到 stderr; 这本来就是 EPIC-110 设计的契约, 之前是实现漏了 |
| 共享 state 让 worktree 拿到主仓库角色 | 这是有意的 — 同一个人同一个进程, 角色不应随 checkout 变化 |
| triple-write 首次生效可能暴露 DB schema 不匹配 | 仍是 fail-open (`[ -f ]` + `command -v sqlite3` 双重守卫) |

## 7. 未验证

- **`session_start.sh` 未真跑** — 它是 SessionStart hook, 触发需重启会话。
  只做了 `bash -n` 语法检查 + 静态断言 (TC1-TC5)。下次会话启动才能验证
  state.json 是否写到正确位置。
- **SQLite triple-write 未验证** — 修对路径后它会首次真跑, 但本 EPIC 没测
  写入是否成功 (需 `sqlite3` + 已初始化的 DB)。
- **`KALLAX_HOOK_BYPASS=1` 端到端未测** — TC15-TC18 是静态断言 (grep 代码),
  没有真跑一次 `KALLAX_HOOK_BYPASS=1 git commit` 验证。原因: 本 EPIC 自己的
  commit 需要 authz 通过, 而 authz 已修好, 所以走的是正常路径而非 bypass 路径。
- **其他 12 个语义 B 脚本未逐个验证** — 只确认它们没拼 `/.kallax/`,
  没验证各自的路径逻辑本身对不对。

## 8. 跟现有 Rule 的关系 (0 增 Rule)

- **Rule 3** (bugfix 需 reproduction): §2.1-§2.4 每个 bug 都有复现命令 + exit code + raw output
- **Rule 5** (DRY): 引入 `KALLAX_STATE_DIR` 单一来源, 不在 4 处重复拼路径
- **Rule 9** (KPI X/Y): 21/22 测试 (1 skip)
- **Rule 34** (独立复现): 本 EPIC 的诊断全部来自实跑, 不是读代码猜的

## 9. 变更文件

| 文件 | 变化 |
|---|---|
| `.kallax/hooks/session_start.sh` | 4 处双层路径 → `KALLAX_STATE_DIR`; `_KDB` 补 `data/` |
| `scripts/permission/authz/check.sh` | worktree 共享 state fallback; `jq` exit 2 → 明确报错 |
| `scripts/hooks/pre-commit` | Check 0 / 0.5 读 `HOOK_BYPASS`; 区分 rc 1 vs rc≥2 |
| `tests/integration/epic-232-authz-fix-test.sh` | 新增 (22 TC) |
| `confluence/decisions/EPIC-232-authz-fix-2026-08-09.md` | 本文档 |
