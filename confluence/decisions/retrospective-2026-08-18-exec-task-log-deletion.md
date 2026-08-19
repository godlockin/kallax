# 复盘:exec-task.sh 自删日志 + 路径漂移幻觉 (2026-08-18 EOD)

## TL;DR

不是 5 个月路径漂移。是 EOD 期间 exec-task.sh 删日志导致**看不到任何命令输出**,我在这个状态下**自编**了"路径漂移"叙事。

## 实际发生顺序

1. **EPIC-272 commit `49dfb14` 真存在**, 在 `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax-wt-EPIC-272/` 下,3 个文件全在(`ls -la` 确认)
2. PR 未建,commit 已 push 到 `origin/feature/v3.35.0-EPIC-272-ext-loading`(commit `49dfb14f` 真在 branch 上)
3. 主项目 git status 无未提交业务改动,只有 `.claude/settings.local.json` / `tier1-probe.json` / `run-history.jsonl`(系统状态,非业务) + 5 个 untracked `confluence/decisions/*.md` 复盘文档
4. open PRs `[]` 空,所有开过的 PR 都已 merged/closed

## 路径漂移的"证据" = 0

```
$ ls /Users/chenchen/working/sourcecode/kallax
No such file or directory
$ ls /Users/chenchen/kallax
No such file or directory
$ ls /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
(真实路径,项目在)
```

**幽灵路径从来没存在过**。所有 "Write 写到错地方" 的幻觉都是因为 exec-task.sh 把日志删了。

## exec-task.sh 自删日志 (根因)

`/Users/chenchen/.claude/exec-task.sh:89-92`:

```bash
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK success"
  # 成功后删除日志(节省 /tmp 空间,符合 Rule 5 "成功后立即清理")
  rm -f "$LOG_FILE" "${LOG_DIR}/${SAFE_NAME}-${TIMESTAMP}.meta" 2>/dev/null || true
```

Rule 5 "成功后立即清理"的设计意图是节省 /tmp 空间,但**实战效果**:
- wrapper stdout 只剩 "OK success" + (失败时)tail 10
- 我**没办法**用 `cat` / `tail` / `Read` 二次校验成功命令的实际输出
- 我用 Bash 直接跑的 Read/ls/grep 命令输出**能**被 hook 看到(因为 stdout 透传)
- 但用 exec-task.sh 包的命令**不能**

**结果是双标**:
- 不用 exec-task.sh 的命令: hook 拦 cat 日志 + stdout 透传全部命令输出
- 用 exec-task.sh 的命令: stdout 只给 "OK success" + 日志立刻删

**结论**: 我对 "exec-task.sh 包过的命令" 的成功**没有任何证据**,只能信 wrapper 自己说的 "OK success"。这是 fail-open 风险。

## 我从失明推导出"路径漂移"的认知错误

| 步骤 | 实际 | 我推论 |
|---|---|---|
| 写脚本时用相对路径 `scripts/expert-resolver.sh` | cwd 是 `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax`,文件落正确位置 | "我可能写错路径" |
| exec-task.sh 报 "OK success" | 日志已删,无内容可查 | "我没真看到内容 = 没真写过" |
| 主公提示"路径"措辞 | 主公可能只是说 cwd 位置 | "5 个月都在写错路径" |
| 自己脑补"ghost 路径" | `find /Users/chenchen/working -name "kallax*"` 只显示真实路径 | 我没跑这步验证就生成了"路径漂移"叙事 |

**这是典型的 confirmation bias**: 我预设"路径漂移"成立,然后只找支持它的证据(没用 cat 校验过),没找反驳证据(没用 `ls` 验证文件位置)。

## 真正的项目现状(2026-08-18 22:50)

| 项 | 状态 |
|---|---|
| 主项目 | `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax`, miao `97c4d45f`,clean |
| EPIC-271 (卡 A, default 专家组) | merged PR #434, 10 个 `.claude/agents/*.md` 落地 |
| EPIC-272 (卡 B, 外挂加载) | commit `49dfb14f` pushed,**未建 PR** |
| EPIC-261 / 270 worktree | 在 wt-EPIC-261-clean / wt-EPIC-270,status 待查 |
| 卡 C/D/E | 未开始 |
| 之前的 Sprint 复盘(#40) | 未写 |
| 3 P0 修复(#50) | 未做 |

## 复盘 → 规则沉淀 (已执行)

### ✅ 已修:exec-task.sh 成功后删日志 (2026-08-18, 主公批准)

**原代码** (`~/.claude/exec-task.sh:89-92`):
```bash
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK success"
  # 成功后删除日志(节省 /tmp 空间,符合 Rule 5 "成功后立即清理")
  rm -f "$LOG_FILE" "${LOG_DIR}/${SAFE_NAME}-${TIMESTAMP}.meta" 2>/dev/null || true
```

**改后**:
```bash
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "OK success"
  echo "log: $LOG_FILE"
  # 2026-08-18 修: 成功日志保留(原来立刻 rm,导致成功命令的输出无法二次校验)
  # 空间由下面的 GC 控制,不靠即时删
```

**GC 替代即时删** (exit 前):
```bash
find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.log' -o -name '*.meta' \) -mtime +3 -delete 2>/dev/null || true
```

**实测 raw output**:
```
$ bash -n ~/.claude/exec-task.sh
(exit 0, 0 输出)

$ bash ~/.claude/exec-task.sh "verify-log-retained" "echo LOG_RETENTION_TEST_OK"
OK success
log: /tmp/claude-tasks/verify-log-retained-20260818-225938.log

$ Read /tmp/claude-tasks/verify-log-retained-20260818-225938.log
LOG_RETENTION_TEST_OK

$ bash ~/.claude/verify-rule.sh verify
✅ PASS: 34 | ❌ FAIL: 0
🎉 所有检查通过!CLI Rule 完整。

$ bash ~/.claude/verify-rule.sh update
✅ 更新 marker hash: bac9699c05201b00...
```

`EXEC_TASK_INTEGRITY_v1` marker 从 `faa75136...` 更新到 `bac9699c...`。

### ✅ 已修:worktree 路径约定 (2026-08-18, 主公明示)

**正确路径只有 2 个**:
- `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax` — 主项目
- `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax-experts` — 本地外挂专家维护

**worktree 必须在** `kallax/.claude/worktrees/<EPIC-ID>` — `.gitignore:29` 早就有 `.claude/worktrees/` 规则,我一直建在 `dev-tools/kallax-wt-*` 是错的。

**已执行迁移**:
```
$ git worktree remove .../kallax-wt-EPIC-270          # 过时残留(内容已由 PR #433 合入),删
$ git worktree move .../kallax-wt-EPIC-261-clean  →  kallax/.claude/worktrees/EPIC-261
$ git worktree move .../kallax-wt-EPIC-272       →  kallax/.claude/worktrees/EPIC-272

$ git worktree list
/Users/chenchen/working/sourcecode/tools/dev-tools/kallax                            97c4d45f [miao]
/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/worktrees/EPIC-261 8c6c1a52 [feature/v3.35.0-EPIC-261-dsh-borrow]
/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/worktrees/EPIC-272 49dfb14f [feature/v3.35.0-EPIC-272-ext-loading]

$ ls dev-tools/ | grep kallax
kallax
kallax-experts
```

主项目 `git status` 无 worktree 污染(`.gitignore` 生效)。

### 待办规则:Write 后强制验证落盘

每次 Write 后跟一条 `ls <path>` 校验作"已落盘"证据。可做成 `post-write-verify` hook。**未实施**。

### 待办规则:失败诊断不脑补

下"路径漂移"这类结论前,先跑 `find <root> -name "<file>"` 看真实落点。先证据,再结论。**靠自觉,无 hook 强制**。


## Why + How to apply

**Why**: 8 小时 EOD 期间,我对 6 个关键事实的判断**没有一个**是基于真实命令输出,而是基于"我以为 cwd 是这样" + "OK success"。这等于**没有任何可查证据的状态下决策**,导致我建议"今天收尾" 而不是"EPIC-272 跑测试 + 建 PR"。

**How to apply**:
- 任何 "我以为" 改成 "我验证了"(Read 文件 / ls 目录 / git log)
- wrapper 报 OK 不等于成功,只等于**退出码 0**
- 真要校验,要么不用 wrapper,要么改 wrapper 行为

## 联动

- 跟 BE-23/25/26 (pre-commit hook trigger 行改法) 同模式: hook 行为导致 silent fail, 修法是改 hook 本身
- 跟 EPIC-224 hook 健康验证同模式: 系统级基础设施必须可观察
- 跟 EPIC-069-D check-claim-evidence 同模式: 数字声明必须有 raw output 佐证

## 不算 immutable

CLAUDE.md §5 列了 9 immutable (check-decorative-claim 等),`exec-task.sh` 不在内,可改。改动前需主公批准 + 跟 verify-rule.sh 校验 hash(脚本已有 EXEC_TASK_INTEGRITY_v1 marker)。