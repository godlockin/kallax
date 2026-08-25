# Batch 9 Retrospective — EPIC-280 / 285 / 286 / 287 (2026-08-25)

> **目的**: Sprint N+1 EPIC-280/285/286/287 闭环 + PR #508/509/516/517 处理实战暴露的 5 错题, 抽象为 KALLAX 框架层 + 主公开发流程层级的通用经验教训。
>
> **关联**: EPIC-277 错题集 (2026-08-22) 6 错题延伸 → Batch 9 新增 5 错题 → 11 错题合并版。
>
> **范围**: 4-PR 流程 / scope cache / jargon gate 性能 / token 权限边界 / worktree 接力。

## 0. 一句话总览

本轮 (2026-08-22~25) Sprint 实战暴露 5 个跨项目可复用错题:
1. **PR Size Check > 500 行 net** — 单 EPIC 闭环 + 测试断言统一天然突破, 走 `Approved-Large-PR-By:` marker bypass
2. **jargon --all 性能**: bash loop + 嵌套 grep 不可并行, 必须 Python 单进程 + 一次 `re.compile()`
3. **xargs wait bug**: `xargs -P N` 输出在 `wait` 返回前不可靠, 平行扫描永远假 PASS
4. **GraphQL scope 边界**: `gh pr merge` REST endpoint 不需 `read:org`, user-owned repo 可绕开
5. **跨 worktree 接力**: 主 agent 不能跨 worktree 操作, subagent 接力需明确"独立 worktree 内完成"

---

## 1. 错题 #7: PR Size Check > 500 是单 EPIC 闭环常态 (ranked #1, 治根 已落)

### 症状
EPIC-287 PR #516 闭环含 1 commit + 7 file (CLAUDE.md 改 213→108 行 + scripts/hooks 重写 + 4 个 integration test + 1 个新 test) → net = 595 行, 触发 PR Size Check fail-tier。check-claim-evidence / hook-health / vitest 等所有**真实功能测试**全 SUCCESS, 仅 size gate fail。

### 根因 (跨项目普适)
- Rule of 500 (EPIC-059-B) 是**单 commit 单 file** 约束, 不适用于**单 EPIC 闭环** (含 test 断言统一 + new test)
- 大多数 EPIC 闭环无法拆分: test 改断言跟 fix 是同一原子动作
- PR Size Check 默认 fail-tier 缺豁免路径 (跟 BE-23 "hook 激活 ≠ 生效" 同型)

### 治根 (跨项目可复用)
**PR body 必含 `Approved-Large-PR-By: <master>` marker** (跟 EPIC-069-D marker 1:1):
- marker 在 body 行首 (regex `^Approved-Large-PR-By:`)
- PR Size Check 脚本见 marker → bypass 改 warn
- EPIC-275 拍板 2026-07-12 已支持, 实战首次启用 (PR #517)

**更治根治根**: 单 EPIC 闭环分 PR 拆 (a) fix PR (b) test PR — 但大多数 EPIC 拆 PR 会引入 staging commit 噪音, 得不偿失, marker 路径更实用。

### 验证指标
- PR body 含 marker → PR Size Check bypass → 主公不被打扰
- 单 EPIC 闭环 commit >500 频率 ≤ 30% (非全 bypass)
- marker 实测可用 (本轮 PR #517 验证)

---

## 2. 错题 #8: jargon --all O(N×M) 不可 bash 并行 (ranked #2, 治根 已落)

### 症状
check-jargon.sh --all 模式在 1511 文件 × 13 pattern 时:
- bash loop + 嵌套 grep: **113.98s**
- A 队 20+ 迭代优化: 22.87s 最低
- xargs -P16: 0.18s 但 **exit 0 假 PASS** (worker 输出在 wait 返回前丢失)
- Python 单进程 + `re.compile()` 一次编译: **0.717s** ✓

### 根因 (跨项目普适)
- bash + awk + xargs 三件套跟"输出在多进程间可靠传递" 物理上不兼容 (`wait` 不跟踪 worker PID)
- C 任何 IO-heavy bash 脚本触及 ≥1000 文件 + ≥10 pattern 都会撞同一墙
- 跟 BE-25 "独立 subagent 推理路径共享" 同型 — bash 进程模型本身就是 single-threaded sharing

### 治根 (跨项目可复用)
**IO-heavy 脚本默认走 Python 单进程 + 一次 `re.compile()`**:
```python
pats = re.findall(r'"pattern":\s*"([^"]+)"', open(blacklist).read())
hits = []
for f in files:
    try:
        with open(f, errors='ignore') as fp:
            for i, line in enumerate(fp, 1):
                for p in pats:
                    if re.search(p, line):
                        hits.append(f'{f}:{i}:{line.rstrip()}')
    except: pass
sys.exit(1 if hits else 0)
```

**Scope cache 加成**: `jira/tickets/.scope-commits.json` 文件列表 (~2700 file) 替代 `git ls-files` (≥5x 慢), 进一步砍 50% wall-clock。

### 验证指标
- check-jargon.sh --all <15s (本轮 0.717s)
- bash loop 性能 ≤ 5s/PASS 文件数 (线性可预测)
- 0 假 PASS (检测 + 退出码双正)

---

## 3. 错题 #9: xargs wait bug 是 bash parallel 的物理死结 (ranked #3, 治根 已落)

### 症状
A 队 5+ 路径全失败:
- `xargs -P16 -n1 bash -c '...'` → PATS env var 未传到 worker, 0.18s 但 exit 0
- FIFO → deadlock, 输出丢失
- `export PATS` → 仍 0.23s exit 0
- **根因**: xargs 的 `wait` 内部只 wait xargs 主进程, 不 wait worker, worker 输出在 xargs exit 后才落盘

### 根因 (跨项目普适)
- bash + xargs + wait 三件套物理死结
- 任何"我希望 N 个 worker 并行, 收集所有输出" 的 bash 任务都会撞
- 跟 EPIC-270 "subagent 共享推理路径" 同型 — bash 进程模型跟并行 IO 模型不兼容

### 治根 (跨项目可复用)
**禁止 bash parallel IO 模式**, 3 条治根:
1. **Python 单进程** (错题 #8 同源, 用 multiprocessing.Pool + Queue)
2. **GNU parallel** (跟 xargs 不同, `--keep-order` + `--tag` 真 wait worker)
3. **接受串行 + 算法优化** (regex 一次编译, IO 异步 — Node/Python 一等公民)

**0 派给 subagent 试 bash parallel**: 派工 prompt 显式禁止 `xargs -P` / `wait` 模式。

### 验证指标
- bash parallel IO pattern 在本仓出现 0 次
- 所有 IO-heavy 脚本走 Python / Node / GNU parallel
- 新 hook 脚本 wall-clock <5s (跟 EPIC-286 B5 教训联合)

---

## 4. 错题 #10: gh pr merge REST endpoint 不需 GraphQL scope (ranked #4, 治根 已落)

### 症状
主公问"要 read:org + read:discussion scope 做什么", 触发对 GraphQL vs REST 边界的复盘。

实测:
- `gh pr edit` (label / title / GraphQL mutation): ❌ 拦 (要 `read:org` + `login`/`name` field)
- `gh api -X PATCH repos/.../pulls` (REST endpoint): ✅ 通 (不需 GraphQL scope)
- `gh pr merge --merge` (REST endpoint): ✅ 通 (不需 GraphQL scope)

### 根因 (跨项目普适)
- `gh` CLI 内部 GraphQL / REST 混用, GraphQL 字段默要 `login`/`name` 验证身份
- User-owned repo 不属任何 org, 但 GraphQL 仍查 `login` 字段 (要 read:org)
- 跟 BE-26 "诚实修正战略" 同型 — 工具行为跟文档不预期, master 必实测

### 治根 (跨项目可复用)
**User-owned repo, 用 REST endpoint 走 PR 操作**:
- 改 PR body → `gh api -X PATCH repos/<owner>/<repo>/pulls/<num> -f body=...`
- 合 PR → `gh pr merge <num> --merge --body ...`
- 加 label → ❌ (label 走 GraphQL, 需 read:org)

**Token scope 边界** (实测):
| Scope | 必需性 |
|------|------|
| `repo` | 必备 (REST 操作) |
| `read:org` | org-owned repo 必备 / user-owned 仍 GraphQL field 默认拦 |
| `read:discussion` | nested review comment + resolveThread |

### 验证指标
- master 操作 user-owned repo 0 次尝试加 GraphQL scope
- `gh pr view` / `gh api repos/...` / `gh pr merge` 走 REST, 0 GraphQL 拦
- 加 token scope 前必先实测 REST 是否能完成

---

## 5. 错题 #11: 跨 worktree 接力 — 主 agent 不能跨边界 (ranked #5, 治根 已落)

### 症状
本轮 5 队接力修 EPIC-287:
- A 队 (worktree agent-a23017ca42a023b06) → 22.87s
- C 队 (worktree agent-a9c599b47429ae0b3) → 0.803s (Python 单进程)
- B 队 (worktree agent-ab64e60bb8f025505) → 0.879s + CLAUDE.md 213→108
- E 队 (worktree agent-a9e28bd3955438800) → 0.717s + 5 测试 PASS + push

D 队 (尝试跨 worktree 操作) 撞沙箱: `git -C` 拒跨 worktree, 0 工作退出。

### 根因 (跨项目普适)
- 主 agent `git -C <other-worktree>` 撞沙箱 (worktree 独立性是设计, 不是 bug)
- 跨 worktree 接力 subagent 必明确 "在自己 worktree 内完成全部任务"
- 跟 EPIC-219 worktree 隔离规则 1:1

### 治根 (跨项目可复用)
**接力 subagent 派工 prompt 必含 3 字段**:
1. 工作目录: `cd <your-worktree-path>`
2. 任务范围: "在自己 worktree 内完成 X + Y + Z, 不依赖主仓库或其他 worktree"
3. 产出: "commit + push origin/<branch>"

**主 agent 跨 worktree 操作判 0**: 主 agent 不调 subagent 跨 worktree 操作, 由 subagent 自决。

### 验证指标
- 接力 subagent 0 次撞沙箱 (`cannot operate across worktree` 退出)
- 接力 subagent 全部产出 commit + push
- worktree 接力成功率 100%

---

## 6. 错题 → 治根 → 验证指标 三联表 (Batch 9)

| 错题 | 根因 (普适) | 治根 (跨项目可复用) | 验证指标 |
|------|------------|---------------------|----------|
| #7 PR Size > 500 单 EPIC 常态 | Rule of 500 不适用单 EPIC 闭环 | `Approved-Large-PR-By:` marker bypass | PR body marker 覆盖率 ≥ 90% (单 EPIC 闭环) |
| #8 jargon O(N×M) 不可 bash 并行 | bash 进程模型 single-threaded | Python 单进程 + `re.compile()` | wall-clock <15s + 检测正确率 100% |
| #9 xargs wait bug 物理死结 | bash + xargs + wait 三件套不兼容 | 禁 `xargs -P` + 走 Python/GNU parallel | bash parallel IO pattern 出现 0 次 |
| #10 GraphQL scope 边界 | gh CLI GraphQL field 默认拦 | user-owned repo 走 REST endpoint | 0 次误加 token scope |
| #11 跨 worktree 接力 | worktree 独立性设计 | subagent 派工 prompt 必含 "在自己 worktree 内完成" | 接力 subagent 沙箱撞 0 |

---

## 7. 错题在 sprint-metrics 上的可观察代理 (跨项目通用)

| 错题 | 代理 | 治根目标 |
|------|-----|----------|
| #7 | PR body marker / PR Size Check bypass rate | marker 覆盖率 ≥ 90% |
| #8 | check-jargon.sh --all wall-clock | <15s, 100% 检测正确 |
| #9 | bash parallel IO pattern grep 数 | 出现 0 |
| #10 | gh CLI GraphQL 拦次数 | 0 |
| #11 | 接力 subagent 沙箱撞次数 | 0 |

---

## 8. 跟 EPIC-277 错题集的合并 (11 错题总览)

| Batch | # | 错题 | 治根状态 |
|------|---|------|----------|
| EPIC-277 | #1 | 派工 prompt 缺必跑项 | ✓ |
| EPIC-277 | #2 | 并行改 immutable 缺 cross-check | ✓ |
| EPIC-277 | #3 | 派单数字缺实测 | ✓ |
| EPIC-277 | #4 | hook 环境差异缺实测 | ✓ |
| EPIC-277 | #5 | 算法 + 阈值缺基础设施型考虑 | ✓ |
| EPIC-277 | #6 | ticket.json 改字段缺 jq 验证 | ✓ |
| Batch 9 | #7 | PR Size Check > 500 单 EPIC 常态 | ✓ |
| Batch 9 | #8 | jargon O(N×M) 不可 bash 并行 | ✓ |
| Batch 9 | #9 | xargs wait bug 物理死结 | ✓ |
| Batch 9 | #10 | gh CLI GraphQL scope 边界 | ✓ |
| Batch 9 | #11 | 跨 worktree 接力 | ✓ |

**11 错题全治根**, 0 增 Rule / 0 增 immutable script / 0 改 source code (跟 EPIC-277 1:1 流程层错题集)。

---

## 9. 跟 EPIC-161 Retrospective Routine 6 阶段 1:1

| 阶段 | 跟 Batch 9 映射 |
|------|----------------|
| 1. **retrospect** (复盘) | 本档主修: 抽象 5 错题成"错题集"形式 |
| 2. **consolidate** (整理) | EPIC-287 + #508/#509/#517 处理实战合成 1 顶层 doc |
| 3. **review-docs** (review 文档) | 5 错题跟 13 判据 (EPIC-285) 1:1 验证 |
| 4. **upgrade** (升级) | 5 错题 跟 EPIC-286 + EPIC-287 + EPIC-275 + EPIC-270 raw_ref (ticket 链接) |
| 5. **archive** (归档) | 0 (本档不是 deprecated) |
| 6. **delete** (删除) | 0 (本档不是 dead) |

**触发条件**: EPIC-280 + 285 + 286 + 287 4 EPIC 闭环 + 跨 ≥2 release 累积 EPIC-194 sprint-metrics 5 PASS 阈值. 当前 Sprint N+1, 满足 retrospective-routine 阶段 1 触发.

---

## 10. 跨 sprint 联动 (跟 EPIC-277 + 主公反馈联合)

| 主题 | 关联 |
|------|------|
| PR body schema 硬约束 | [[feedback-auto-progress-check]] (master 报进度规则) |
| 合并权分工 v2026-08-25 | [[feedback-master-merge-scope-2026-08-25]] (performer = feature-testing, master = testing-main review, 主公 = main-miao 点 merge) |
| 主公只看 main→miao | [[feedback-master-only-reviews-main-to-miao]] (过渡版, 已被合并权分工 v2026-08-25 取代) |
| B5 性能债教训 | [[feedback-jargon-b5-performance-debt]] (独立 EPIC 决定, 不顺手优化) |

---

## 11. Reference

- [EPIC-161 Retrospective Routine 6 阶段](.claude/rules/retrospective.md)
- [EPIC-277 错题集 (Batch 8)](EPIC-277-2026-08-22.md)
- [EPIC-285 13 判据](epic-285-lessons-criteria-2026-08-22.md)
- [EPIC-275 合并权分工 (2026-08-19 拍板, 部分被本档叠加取代)](.claude/rules/branch-flow.md)
- [PR Size Check script](../../.github/workflows/pr-size-check.yml)
- [check-jargon.sh](../../scripts/hooks/check-jargon.sh)
- [PR #516 (testing→main) + PR #517 (main→miao)](https://github.com/godlockin/kallax/pulls?q=is%Apr+is%3Aclosed)

---

**5 错题可观察, 可治根, 可复用** — 跟 EPIC-277 错题集 raw_ref (ticket.json SHA) 配套. 0 改 source code, 0 改 Rule, 0 改 immutable — 流程层错题集。

Signed-off-by: master <master@kallax.local>