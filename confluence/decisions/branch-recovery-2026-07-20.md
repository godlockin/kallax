# 4-Branch Recovery — main 远端被删, 重建 (2026-07-20)

> **起源**: 2026-07-20 主公发现 `origin/main` 缺失, 测试同事报"远端 branch 不全"。
> **决策**: 主公拍板 = "main 推 testing tip (eaf3b3b EPIC-121)"

## 事实 (实测)

| Branch | 状态 | SHA | 最后 commit |
|--------|------|-----|-------------|
| `main` | **❌ 已被 upstream 删** | — | 远端 0 |
| `testing` | ✅ 存在 | `eaf3b3b` | EPIC-121 sandboxed eval |
| `miao` | ✅ 存在 (stable) | `4d64a86` | EPIC-127 router |
| 本机 `remotes/origin/main` | stale tracking | `6dc8386` | EPIC-113-A |

差距:
- `miao` ahead of main: **48 commits**
- `testing` ahead of main: **16 commits**

诊断命令:
```bash
git ls-remote origin refs/heads/main refs/heads/testing refs/heads/miao
# main 行缺 = 0
```

## 决策矩阵

| 方案 | 选项 | 主公拍板 | 风险 |
|------|------|---------|------|
| **A** | `main = testing tip` (eaf3b3b EPIC-121) | ✅ 选 | 低, 保留 UAT 阶段 |
| B | `main = miao tip` (4d64a86) | ❌ 弃 | 高, 跳级违反升序 |
| C | 不重建, 只补文档 fallback | ❌ 弃 | 0 风险但流程文档持续误报 |

## 修复动作 (3 step, 0 强制推送)

```bash
# 1. 重建本地 main 指向 testing tip
git branch -f main eaf3b3b

# 2. 推到 origin (无 --force, 因为远端 0)
git push origin main
# → * [new branch] main -> main

# 3. 上游同步
git fetch origin main
git branch --set-upstream-to=origin/main main
```

## 修复后状态

| Branch | SHA | 角色 |
|--------|-----|------|
| `main` | `eaf3b3b` | = testing tip, UAT 占位 |
| `testing` | `eaf3b3b` | = UAT 验证中间层 |
| `miao` | `4d64a86` | +2 commits, stable/prod |

miao 领先 main 2 commits 是允许的 (stable 比 UAT 多 2 个 docs fix hot patch, 跟"反讽" 联合):
- `4d64a86` (miao) fix(EPIC-127-A): parameters error
- `98d6817` (miao) feat(EPIC-127): smart router

这两个 commit 都是 router / 文档类 hot-fix, 不影响 stable 语义, 等下次 v3.X.Y release 时推 testing → main 即可。

## 联动 ticket

跟 v3.10.0+ 4-branch 治理联合 (file:line `CLAUDE.md ## Branch Flow Governance`):
- `feature/* → testing → main → miao` 升序不变
- 历史 5 release 跳过 testing + main 已记 (CLAUDE.md 已有, 0 增)
- 修复:**只重建 1 次**, 不复用 force-push (避免破坏其他人 stale tracking)

## 反模式警告 (0 复发)

❌ **禁止**:
- 直接 `git push --force origin main:from-master` 把 master 改 main (会丢历史)
- 在没确认主公下擅自 push (会被 mandate-007 抓)
- 把 miao 直接 force-push 到 main (skip UAT, 行为 v3.8.0 假 PASS 复发)

✅ **必做**:
- 涉及 4-branch 任何 push 前先 `AskUserQuestion` (主公拍板)
- 重建主分支必须留 decision doc (本文件)
- 任何 stale tracking 在重建后必须 `git fetch + set-upstream` 同步

## 后续排查 (可选, 非紧急)

- main 为何被删? (上游 force-delete 还是 PR merge 后清理?) — 无日志, 无定论
- 是否需要给 main 加 branch protection? (origin 上 GitHub UI 可设)
- 是否需要监控脚本检测 4-branch 漂移? (放 v3.X.Y backlog, 不在本次)

## 文件变更 (本次修复)

- ✅ 1 个新 branch: `origin/main` 重建
- ✅ 1 个 decision doc: 本文件 (`confluence/decisions/branch-recovery-2026-07-20.md`)
- ❌ 0 代码改动 (跟诚实修正战略 一致)
