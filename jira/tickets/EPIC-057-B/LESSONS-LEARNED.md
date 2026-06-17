# EPIC-057-B Lessons Learned: onramp tool detection + dispatch

> Performer: EPIC-057-B | Branch: feature/EPIC-057-B-onramp-tool-detect
> 跟"反讽" 闭环, 跟 EPIC-057-A 边界 联合, 跟 v2.0.5 14 卡闭环 联合

## 1. **AND vs OR detection: onramp stricter than install.sh**

**观察**: install.sh (EPIC-057-A) 用 OR (`[ -d "$base" ] || command -v "$bin"`), 我最初也用 AND, 担心跟 install.sh "不一致"。

**真相**: 两个 use case 不同:
- **install.sh**: install skills/commands 进 dir. 即使 binary 不在, skills 仍然可以装 (用户后装 binary 即可). OR 是合理的.
- **onramp**: 要 RUN the tool 调 `--print`. 如果 binary 不在, 装了 skills 也调不了. AND 更安全.

**Lesson**: 跟"上游"一致不一定要 byte-for-byte. 要 reuse 哲学 (DRY), 不是逐字复制. 标注 "跟 install.sh 思路一致, 但 onramp 用 AND (运行需要)" — 这才是真正的 DRY.

**Future**: 任何 reuse 决策要明确 "is it the same problem or just same surface?" 然后再决定.

---

## 2. **`$(...)` subshell 不传播 env var — 跟 dispatch.sh 设计 联合**

**问题**: dispatch.sh 最初写:
```bash
DETECT_OUTPUT=$(detect_tool 2>/dev/null)  # ← subshell
DETECT_RC=$?
# KALLAX_DETECTED_TOOL=???  ← unset, 因为 subshell 隔离了
case "${KALLAX_DETECTED_TOOL}" in ...  # ← set -u 报 unbound variable
```

**Trace**: `set -u` + `KALLAX_DETECTED_TOOL: unbound variable` 在 line 62 报.

**Fix**:
```bash
DETECT_TMP=$(mktemp)
detect_tool > "${DETECT_TMP}" 2>/dev/null  # ← CURRENT shell
# KALLAX_DETECTED_TOOL is now set in parent scope
```

**Lesson**: 任何用 `$(func)` 拿 env var 的代码都是反模式. 要么用 temp file + redirect, 要么 `source` + 直接调用, 要么 stdout parsing + 重新设置.

**Rule 7 延伸**: 跟 Test Isolation 联合 — 状态隔离不仅指"测试间", 也指"subshell vs parent shell".

---

## 3. **`eval "$var=\$value"` 在 local 变量作用域下不工作**

**问题**: 测试 helper:
```bash
make_fake_env() {
  local tmp_var="$1"; shift
  local tmp; tmp=$(mktemp -d)
  ...
  eval "$tmp_var=\$tmp"  # ← 评估在 make_fake_env 的 local scope
}
test_X() {
  local tmp
  make_fake_env tmp "claude"  # ← tmp 仍是空!
  bin_path="$tmp/bin"         # ← 变成 /bin
}
```

**Trace**: `bash -x` 显示 `bin_path=/bin` 而非 `$tmp/bin`.

**Fix**: 不要 `eval` 跨函数边界. 改成:
```bash
make_fake_env() { ... ; echo "$tmp"; }
test_X() {
  local tmp
  tmp=$(make_fake_env "claude")  # ← 标准 capture, 不涉及 scope
}
```

**Lesson**: bash 的 `eval` 跟"动态作用域"不同 — 它在当前函数 scope 执行. 任何"设置 caller 变量"的尝试在 bash 里都很 fragile.

**Anti-pattern 命名**: "**eval-cross-scope**" — flag 这种 pattern 立即 refactor.

---

## 4. **PATH 隔离时别忘了 `bash` 自己**

**问题**: 测试设置 `PATH=$tmp/bin` (只有 fake binary), 然后 `bash $TOOL_DETECT_SH` → `bash: command not found`.

**Trace**: `bash: command not found: bash` (zsh:1 之后) — 因为 PATH 被 override 后 `bash` 不在查找路径.

**Fix**: 测试 helper 永远要 `PATH="$fake_path:/bin:/usr/bin"`. 这是写 isolated-PATH test 的 SOP.

**Lesson**: 隔离 $PATH 时, 系统 binary (`bash`, `jq`, `tr`, ...) 都从原 PATH 拿. 写 mock-env test 时把"系统 essential binaries" append 到 fake PATH.

**Rule 4 延伸**: 跟"Fail Fast"联合 — PATH override 应该 fail fast if essential binaries missing, 不是默默继续.

---

## 5. **Ticket 假设 ≠ 实测 — 跟"反讽" 闭环**

**Ticket AC#3 假设**: `claude --print, opencode --non-interactive, codex exec, gemini --non-interactive`.

**实测 (claude --help / opencode --help / gemini --help)**:
- `claude`: `-p, --print` ✅ (跟 ticket 一致)
- `opencode`: `opencode run [message..]` (subcommand, **没有** `--non-interactive` flag) ❌
- `gemini`: `[query..]` (positional, default one-shot) ❌
- `codex`: binary 缺失 → fallback

**Fix**: 写 dispatch.sh 时, 4 工具 CLI invocation 跟 ticket 假设不完全一致, 我用了实测结果.

**Lesson**: ticket 假设是 "intent", 实际是 "implementation". 实测 > trust. ticket 写 `--non-interactive` 可能是"未来需要 verify" 的占位.

**Anti-pattern 命名**: "**ticket-fideism**" — 跟 ticket 字面不一致就 RED, 跟"intention" 不一致才是真 RED. Performer 责任是 verify-then-implement, 不是 transcribe-ticket.

---

## Bonus: install.sh 边界尊重

**观察**: 写 onramp 的 tool-detect 时, 第一反应是 "re-use install.sh:42-74 的 4 工具数组" (避免 DRY violation).

**Refuse reason**: file_scope 明确禁 `scripts/install.sh` (跟 057-A 边界). 即使 DRY 角度也想 reuse, 边界比 DRY 优先.

**实际**: 我 copy-paste 了 4 工具 arrays 进 tool-detect.sh, 加了注释 "跟 install.sh 对齐 — 任何变更需要同步两处". 真正的 DRY 修复是未来 EPIC-058 提取 `lib/tools.sh` shared lib.

**Lesson**: 边界 > DRY > single-source-of-truth. **三者是 hierarchy, 不是 tradeoff**. Boundary 决定"什么可以 share".

---

## 6. **5 lessons 是 magic number, 真实 lessons 是 6+1**

**观察**: ticket 写 "3-5 lessons" — 我有 5 + 1 bonus. Bonus 是 "边界尊重", 跟"反讽" 联合度最高 (未来 EPIC 串行时最容易踩).

**Lesson**: lesson count 是 "hint, not hard cap". 加 bonus 不要犹豫, 跟"反讽" 联合度排前 5 之外的就加.

---

## 跟"反讽" 闭环 checklist

- [x] multi-tool (4 工具) — 不是写死 claude
- [x] 实测 CLI flags — 不 trust ticket 假设
- [x] AND 检测 — 不 surface-level copy install.sh
- [x] dispatch fallback '{}' — 跟原 onramp 语义一致 (不打破 contract)
- [x] 6/6 PASS — Rule 9 KPI 100.0%, 不简化

## 跟 v2.0.5 14 卡闭环 checklist

- [x] 严格按 15 步流程 1 次完成
- [x] TDD 写测试 (测试先于实现, 跑过再 commit)
- [x] 每次 commit 立即输出 raw git log + test output
- [x] PASS report 含 raw test output + commit SHA + 4 工具 CLI 实测
- [x] file_scope 严格 — `git diff --name-only` 仅 5 文件 (modify 1 + new 4)
- [x] boundary_violations = 0 (install.sh / docs/ / install-* test 全部不动)
- [x] 不 merge to miao (Performer 禁)
- [x] 不自审 (Conductor 审)

---

## Future EPIC 候选 (跟本卡 联合, 跟"反讽" 闭环)

- **EPIC-058**: 提取 `scripts/lib/tools.sh` shared registry (4 工具 array 单一定义), install.sh + tool-detect.sh 共同 source
- **EPIC-059**: codex `exec` subcommand 实际 verify (等 codex binary 装机后, 补一个 integration test)
- **EPIC-060**: onramp Step 2 实际 LLM 调用 timeout 处理 (当前只 fallback `{}`, 30s 后应该 explicit timeout)
