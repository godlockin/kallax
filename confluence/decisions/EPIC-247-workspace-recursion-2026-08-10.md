# EPIC-247 — workspace.sh 无限递归修 (local backend SIGSEGV)

- **日期**: 2026-08-10
- **拍板**: 主公 ("A" — 开 EPIC-247 修递归 bug)
- **前置**: EPIC-246 扫 `set -e` 模式时撞到
- **版本**: v3.34.20

## 1. 为什么

EPIC-246 扫 `cmd; rc=$?` 模式时, 为验证 `scripts/lib/workspace.sh` L262 是否真 bug 而真跑 `workspace_exec_snapshot`, 结果:

```
$ workspace_exec_snapshot "exit 3" 5
{
  "command": "exit 3",
  "backend": "local",
  "exit_code": 139,     ← SIGSEGV (栈溢出)
  "elapsed_ms": 5659,   ← 5.6 秒才崩
  "output": "",
}
```

`exit_code: 139` = SIGSEGV. 追进去发现是**无限递归**.

## 2. 根因

```bash
# L155-159
workspace_exec() {
  # Delegates to workspace_exec_backend with current backend
  workspace_exec_backend "$1" "${2:-30}" "$WORKSPACE_BACKEND"   # → 调 backend
}

# L204-207
workspace_exec_backend() {
  case "$backend" in
    local)
      workspace_exec "$cmd" "$timeout"                          # → 又调回来
      ;;
```

`workspace_exec` → `workspace_exec_backend` → `local)` → `workspace_exec` → ... 直到栈溢出.

**`local` 是默认 backend** (`WORKSPACE_BACKEND="${WORKSPACE_BACKEND:-local}"`), 所以**任何调用都会崩**.

## 3. 引入时机

```
$ git log --oneline -S "workspace_exec_backend" -- scripts/lib/workspace.sh | tail -1
a166d500 fix(EPIC-123): fix kallax-tools search bug + TerminalBackend trait
```

`a166d500` (EPIC-123-B) 引入 TerminalBackend trait 时, 把 `workspace_exec` 的本地执行实现挪走了, 改成 "delegate 给 backend", 但 `local)` 分支写成调回 `workspace_exec`.

`a166d500~1` 里的原始实现:

```bash
workspace_exec() {
  local cmd="$1"
  local timeout="${2:-30}"
  if [[ -z "$WORKSPACE_CWD" ]]; then
    echo "ERROR: workspace not initialized. Call workspace_init() first." >&2
    return 1
  fi
  cd "$WORKSPACE_CWD"
  if command -v timeout &>/dev/null; then
    timeout "$timeout" bash -c "$cmd" 2>&1 || { local rc=$?; ...; return $rc; }
  else
    bash -c "$cmd" 2>&1
  fi
}
```

## 4. 修法

`local)` 分支**内联本地执行** (恢复 `a166d500~1` 的实现), 不调 `workspace_exec`:

```diff
   case "$backend" in
     local)
-      workspace_exec "$cmd" "$timeout"
+      if [[ -z "$WORKSPACE_CWD" ]]; then
+        echo "ERROR: workspace not initialized. Call workspace_init() first." >&2
+        return 1
+      fi
+      cd "$WORKSPACE_CWD" || return 1
+      if command -v timeout &>/dev/null; then
+        timeout "$timeout" bash -c "$cmd" 2>&1 || {
+          local rc=$?
+          [[ $rc -eq 124 ]] && echo "ERROR: command timed out after ${timeout}s: $cmd" >&2
+          return $rc
+        }
+      else
+        bash -c "$cmd" 2>&1
+      fi
       ;;
```

`workspace_exec` 保持 delegate 语义 (它是给用户的入口), `workspace_exec_backend` 是实现层.

## 5. 实跑证据

### 5.1 修前 baseline

```
$ . scripts/lib/workspace.sh
$ export WORKSPACE_CWD=/tmp
$ rc=0; out=$(workspace_exec "echo hello" 5 2>&1) || rc=$?
  rc=139
  out=[]
```

连 `echo hello` 都跑不了.

### 5.2 修后

```
$ bash tests/integration/epic-247-workspace-recursion-test.sh
  PASS: TC0 workspace.sh 语法
  PASS: TC1 local) 分支不调 workspace_exec (递归已断)
  PASS: TC2 local) 分支内联本地执行 (bash -c)

[真跑]
  PASS: TC3 workspace_exec 正常执行 (rc=0|out=hello)
  PASS: TC4 workspace_exec_backend local 正常 (rc=0|out=world)
  PASS: TC5 exit code 保留 (rc=3, 修前是 139)
  PASS: TC6 无 SIGSEGV, 正常返回 (rc=0)
  PASS: TC7 snapshot 含 exit_code: 0
  PASS: TC8 未初始化时 fail-closed (rc=1)

Results: 9 pass, 0 fail
```

### 5.3 负向验证 (旧版应 fail)

```
$ git stash push scripts/lib/workspace.sh   # 还原旧版
$ bash tests/integration/epic-247-workspace-recursion-test.sh
  FAIL: TC1 local) 分支仍调 workspace_exec (递归未修)
  FAIL: TC3 workspace_exec 异常: rc=139|out=
  FAIL: TC4 workspace_exec_backend 异常: rc=139|out=
  ...
Results: 1 pass, 8 fail
```

测试能抓到 bug, 不是摆设.

### 5.4 修前/修后对比

| 项 | 修前 | 修后 |
|---|---|---|
| `workspace_exec "echo hello"` | rc=139 (SIGSEGV), 输出空 | rc=0, 输出 `hello` |
| `elapsed_ms` | 5659 (5.6 秒才崩) | 6 |
| exit code 保留 | 拿不到 | rc=3 ✓ |
| snapshot JSON | `exit_code: 139` | `exit_code: 0` |
| 未初始化时 | 崩 | rc=1 + 明确报错 |

## 6. 影响

**正面**:
- `local` backend (默认) 从"任何调用都崩"变成可用
- `workspace_exec_snapshot` 能产出正确的 `exit_code`
- 未初始化时 fail-closed (rc=1 + 报错), 不是崩

**范围**:
- 只改 `workspace_exec_backend` 的 `local)` 分支
- `ssh)` / `docker)` 分支不动 (它们本来就是内联实现, 无递归)
- `workspace_exec` 不动 (保持 delegate 语义)

## 7. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 内联实现跟原版行为有差异 | 低 | 逐行照抄 `a166d500~1`, 加 `cd ... \|\| return 1` (原版缺这个保护) |
| 其他 backend 也有递归 | 低 | `ssh)` / `docker)` 已看过, 都是内联 `timeout bash -c`, 无递归 |
| 调用方依赖"崩"的行为 | 极低 | 崩是 bug, 不可能有人依赖 |
| 测试自身误报 | 低 | 负向验证过 (旧版 8 fail), TC6 断言改成"期望 rc=0"而非"排除 139" |

## 8. TC6 断言的坑 (跟 EPIC-245 同型)

TC6 初版写成:

```bash
if [ "$_out" = "rc=139" ]; then bad ...; else ok ...; fi   # 排除式断言
```

**旧版跑时误报 PASS** — 因为栈溢出时子 shell 本身崩掉, 输出是**空字符串**, `!= "rc=139"` 判定为通过.

改成期望式:

```bash
if [ "$_out" = "rc=0" ]; then ok ...; else bad ...; fi
```

跟 **EPIC-245 的教训同型**: 断言要写**期望值**, 不写**排除值**.

## 9. 调用方: 0 个 (dead code)

```
$ grep -rn "workspace_exec" --include="*.sh" --include="*.ts" . \
    | grep -v "scripts/lib/workspace.sh" | grep -v "tests/integration/epic-247"
(空)
```

**`workspace_exec` / `workspace_exec_backend` / `workspace_exec_snapshot` 全仓 0 调用方**.

这解释了为什么 bug 从 `a166d500` 活到现在: **没人用, 所以没人发现**.

**影响重新评估**:
- 实际生产影响: **0** (dead code)
- 修的价值: 防止未来有人开始用时踩坑 + 递归是明确缺陷不该留

**注**: `scan-dead-code.sh` 的 sentinel 只扫 `node/src/**` 的 TS module, 不扫 `scripts/lib/*.sh`. 所以这个 shell dead code 没被 sentinel 抓到. 这是 sentinel 覆盖盲区, 可另开 EPIC.

## 10. 未验证

- **`ssh` / `docker` backend 真跑** — 需要真实 SSH 主机 / Docker 环境, 本 EPIC 只静态看过代码 (无递归)
- **`workspace.sh` 其他函数** — 只修了递归这一处, 没系统审计整个文件
- **CHANGELOG / recent-epics 补** — 范围外
- **shell dead code 的 sentinel 覆盖** — `scan-dead-code.sh` 不扫 `scripts/**/*.sh`, 需另开 EPIC

## 11. 串联

- **EPIC-123-B (`a166d500`)**: 引入递归的 commit
- **EPIC-246**: 扫 `set -e` 模式时撞到本 bug (那次扫描结论是 "10 处静态 RISK → 0 真 bug", 但撞到这个真 bug)
- **EPIC-245**: 断言写法教训 (期望值 vs 排除值) — TC6 直接用上了

## 12. 0 增 Rule, 0 改 Immutable, 0 改 CLAUDE.md

改 1 个 lib 函数分支 + 加 1 个测试文件 + 本文档.

## 13. 教训

**"delegate 给实现层" 这个重构容易写成环**:

```
入口函数 → 实现层 → (某分支) → 入口函数     ← 环
```

正确做法: 实现层的每个分支都必须**自己实现**, 不能回调入口. 重构时如果把原实现挪走了, 要确认挪到了**正确的层**.

**这个 bug 存活了很久** (`a166d500` 引入), 因为:
1. `workspace_exec` 可能没有测试覆盖
2. 崩的表现是 `exit_code: 139` + 5.6 秒延迟, 不看仔细容易当成"超时"
