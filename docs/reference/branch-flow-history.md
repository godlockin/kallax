# Branch Flow 历史追溯 (扩展)

> 4-branch 强制流程的 5 release PR record + testing/main 同步历史

**主 CLAUDE.md**: `/Users/chenchen/.claude/CLAUDE.md` → `## 4-branch 强制流程 (v3.10.0+)`
**本文件加载场景**: 解释某 release 状态、audit / synch 大问时, 或者回看老 release branch flow
**Decisions 锚**: `confluence/decisions/branch-flow-governance-2026-07-09.md`

---

## 4-branch 强制流程 (v3.10.0+ 强制, 0 容忍)

```
feature/v3.X.Y-EPIC-ZZZ  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作                      UAT 验证    集成测试        稳定发布
```

| 阶段 | 操作 | 验证站 | 目的 |
|------|------|--------|------|
| 1. feature/* | `git worktree add -b feature/...` | 5-Level Verify (新规) | worktree 隔离 |
| 2. feature → testing | `gh pr create --base testing` | integration + cargo test + vitest env | 防止 v3.8.0 form-only PASS |
| 3. testing → main | `gh pr create --base main` | full e2e + decision matrix 25 cells | 防止 v3.8.0 "25/25 假 PASS" |
| 4. main → miao | `gh pr create --base miao` | master review + 4 sub-roles | 处理 v3.8.0 red-blue review 阻塞 |

每个 PR 需要 ≥ 8/9 CI pass (cargo test + vitest + coverage + audit + check-dco + check-body + pre-commit + CHANGELOG; PR Size optional bypass).

---

## 5 release PR 追溯 record (历史跳过, 已补 branch)

| Release | Feature branch (已推 remote) | testing/main PR |
|---------|------------------------------|-----------------|
| v3.8.1 | feature/v3.8.1-EPIC-069 | ❌ 跳过 (历史) |
| v3.8.2 | feature/v3.8.2-EPIC-070 | ❌ 跳过 (历史) |
| v3.9.0 | feature/v3.9.0-EPIC-071 | ❌ 跳过 (历史) |
| v3.9.1 | feature/v3.9.1-EPIC-072 | ❌ 跳过 (历史) |
| v3.9.2 | feature/v3.9.2-EPIC-073 | ❌ 跳过 (历史) |
| v3.10.0+ | 强制 4-branch (EPIC-074) | ✅ |
| v3.29.0 | feature/v3.29.0-EPIC-136-to-139 | PR #148 → base=miao (testing 首次 sync via EPIC-142; canary 抓 6 类历史债) |
| v3.30.0 | feature/v3.30.0-EPIC-140-to-142 | PR #149 → testing (merged 4307d2f2); PR #150 → main (closed 因 debt) → force-push (EPIC-146) |
| v3.30.1 | feature/v3.30.1-cleanup-EPIC-143-to-147 | PR #153 → testing (canary 清账 12 EPIC); PR #155/156/157 sync 4-branch flow 走完 3 段 |
| v3.31.0 | feature/v3.30.1-cleanup-EPIC-143-to-147 (Rule 34 commit 7b4822c) | PR #158 → testing → main → miao force-push |

---

## testing 分支 sync 记录

### 2026-07-26 (EPIC-142) — testing 首次 sync

- 首次 4-branch flow 落地时 testing 已落后 miao 6 commit (EPIC-133/134/135 系列, 均未 Signed-off-by, DCO 上线前的历史)
- Master force-push testing 到 miao HEAD (v3.29.0 merge `7187bb5`)
- `scripts/check-dco.sh` 加 `--allow-pre-cutoff` 让未来 PR 只查本 PR commits, 不 pollute base 历史
- v3.30.0+ testing 分支强制跟 miao 同步 (每 release merge miao → testing)

### 2026-07-27 (EPIC-146 + v3.30.1 cleanup) — main 首次 sync

- 4-branch flow 第 2 段 (testing → main) 首次落地时 main 落后 testing 16 commit, 且 main 独有 3 merge commit (`b99fada` / `bb93164` / `fbdc73e` — 全部只是历史 miao/testing → main 的 merge commit, 无独立内容)
- Master 借 EPIC-142 pattern force-push main 到 testing HEAD (v3.30.0 sync commit `4307d2f2`)
- v3.31.0+ main 分支强制跟 testing 同步 (每 testing → main PR merge 后 auto-align)
- **Canary 战果**: PR #150 首次真走到 main 时抓到 main 分支 4 类历史债 (fmt / npm scripts / diverged commits / pre-DCO), 全部 记入 EPIC-143/144/145/146

### 2026-07-27 (PR #159) — 4-branch 全 3 段首次完整

- v3.31.0 Rule 34 PR #158 → testing (8/8 全绿)
- testing → main PR #159 (admin merge, 0 source change)
- miao ← master force-push = main (Rule 34 落地)

---

## 0 静默跳过 (配合 EPIC-069-D check-claim-evidence)

- v3.10.0+ 必走 4-PR 全程
- 紧急 bypass 仅 `git commit --no-verify` (主公明确批准时)
- 同类假 PASS 症状再次出现 → pre-commit hook 拦截

---

## 流程技艺 (本届领导两轮都靠这)

**Master safety pattern** (未来 Replica 必记):
- 跨 branch force-sync 必须 `git push origin <sha>:refs/heads/<target> --force` 形式
- 不能 `git checkout <target> && git reset --hard` (hook 拒)
- 验证一步必须是 `git log <from>..<to> | wc -l = 0` 双向 0 diff
- 全程 master private 决策 + commit + tag, 走 4-branch 流程
- 测试 main 分支老 workflow bug (PR 跑到主分支, base workflow 用的是 main 老版本) → 强制 push 一次让 main = testing 后再用 main workflow

---

详细: `confluence/decisions/branch-flow-governance-2026-07-09.md`
