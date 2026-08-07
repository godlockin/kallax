# KALLAX 最佳实践 (Best Practices)

> **来源**: 19 EPIC (157-187) + 4-PR 流程 + 5-Level Verify + 4 北极星 + 5 immutable scripts
> **作者**: master | **审核**: 主公 2026-08-08 (EPIC-206)

## 1. EPIC 规划 (Rule 35 时间盒)

| # | 最佳实践 | 验证 |
|---|---------|------|
| 1 | **≤ 5 EPIC / Sprint** | Sprint 计划 review 必查 |
| 2 | **≤ 10 commits / EPIC** | `git log --oneline EPIC-XXX \| wc -l` ≤ 10 |
| 3 | **≤ 500 行 / commit** | Rule 8 Rule-of-500 (跟 EPIC-131/132 联合) |
| 4 | **拆 EPIC 不单 PR 兜底** | 触及 4 模块 / 5 文件 = 必拆 |
| 5 | **时间盒 4-PR 全闭环** | testing/main/miao 任一未走 = 阻塞 |

## 2. 4-PR 工作流 (EPIC-074 + EPIC-181/182)

### 2.1 4 阶段 × 5 验证站

| 阶段 | 验证站 | 验证命令 |
|------|--------|---------|
| **feature/* 工作** | L1 git + L5 boundary | `git log --oneline -1` + smoke |
| **feature → testing** | L2 stdout + integration | `cargo test --workspace` (docs-only 用 EPIC-198 exempt) |
| **testing → main** | L3 4-expert + e2e | expert:run 4 parallel |
| **main → miao** | L4 independent + master review | `kallax witness:spawn --independent` |

### 2.2 PR wrapper 硬化 (EPIC-181 R1-R5)

```bash
bash scripts/branch-4pr.sh --epic EPIC-XXX
# R1: --epic 必填
# R2: base 同步校验
# R3: state 验证
# R4: 默认删 branch
# R5: 退出码契约 0/1/2/3
```

### 2.3 9 类破坏性拦 (EPIC-180-A frame-task)

无论档位 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX), 9 类操作默认停下问:
1. 删文件 / rm -rf / git rm
2. reset --hard / checkout -- <file>
3. push --force / --force-with-lease / -f
4. rebase / merge --no-ff
5. 主分支 push (testing/main/miao)
6. 公开化路径 (README.md / CHANGELOG.md)
7. Rule 改 (CLAUDE.md / SKILL.md)
8. immutable scripts (5 verify + 1 hook = 6)
9. 网络发布 (gh pr create / npm publish / docker push)

## 3. 5-Level Verify (EPIC-069-D + Rule 2)

### 3.1 5 级别

| Level | 名称 | 验证命令 | 失败症状 |
|-------|------|---------|---------|
| **L1** | git | `git log --oneline -1` | Amend SHA 没变 |
| **L2** | stdout | `cargo test --workspace --release 2>&1 \| tee /tmp/stdout.log` | "should work" 估数 |
| **L3** | 4-expert | `kallax expert:run {arch,backend,frontend,security}` | 自审 |
| **L4** | independent | `kallax witness:spawn TICKET --independent` | 瞒报 |
| **L5** | boundary | `kallax test:boundary/exception/concurrent` | happy path only |

### 3.2 5 不可更改法律 (immutable scripts)

| Script | Path | 职责 | 退出码 |
|--------|------|------|--------|
| check-decorative-claim.sh | scripts/verify/ | 0 装饰性引用 | 0/1 |
| check-narrative.sh | scripts/verify/ | 0 narrative 包装 | 0/1 |
| check-fail-closed.sh | scripts/verify/ | 0 fail-open | 0/1 |
| check-self-heal.sh | scripts/verify/ | self-heal pattern | 0/1 |
| check-claim-evidence.sh | scripts/hooks/ | README/CHANGELOG 数字带 raw_output | 0/1 |

**契约**: 0=PASS, 1=FAIL (fail-closed, 禁止 print FAIL + exit 0).

## 4. 4 北极星指标 (Rule 36 + EPIC-204)

### 4.1 4 指标 + 阈值

```bash
bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX
# 1. expert_activation_rate ≥ 5 distinct experts
# 2. cross_epic_reuse_rate ≥ 60% 跨 EPIC 复用
# 3. ab_hit_rate (mismatch) < 15% 2-Group review 一致率
# 4. mis_dispatch_rate < 10% Performer 派单错率
# docs-only EPIC: --docs-only flag + exit 3 DOCS_ONLY_SKIP
```

### 4.2 exit 退出码契约

| Exit | 含义 | 何时触发 |
|------|------|---------|
| 0 | All 4 PASS | Sprint 闭环 |
| 1 | At least 1 FAIL | 必修复 |
| 2 | NO_DATA on all | 数据源缺失, 触发 ASK |
| 3 | DOCS_ONLY_SKIP | docs-only EPIC, 跟 EPIC-198 一致 |

### 4.3 Sprint 闭环 (跟 Rule 35 时间盒 联合)

1. 跑 `sprint-metrics.sh --epic EPIC-XXX`
2. **0/1 → fix → re-run**, **2 → ASK 主公**, **3 → docs-only PASS**
3. 4 指标全 PASS 才算 Sprint 闭环

## 5. docs-only 治理 (EPIC-198 + EPIC-204)

### 5.1 docs-only PR 跳过 CI 检查 (EPIC-198)

```bash
# docs-only PR 不需要 cargo test, 但需要:
# - check-internal-refs.cjs (扫 .md/.html/.json refs)
# - check-claim-evidence.sh (扫 README/CHANGELOG 数字)
# - 4-PR 全闭环 (跟 code EPIC 一致)
```

### 5.2 5-Phase audit flow (EPIC-196/197/199/200/201)

```
Phase 1: Discovery (100% Read, 8 类 issue 分类)
Phase 2: Deletion (sha256sum 二次验证, SoT 归并)
Phase 3: Refresh (git mv + DEPRECATED header + internal refs)
Phase 4: Sweep (4 agent 并行扫孙目录)
Phase 5: Extension (tool scope 扩 + DEPRECATED index)
```

## 6. 知识管理 (跟 EPIC-023-A 联合)

### 6.1 lessons-lookup

```bash
# 跨项目教训查询
python3 ~/.claude/lessons-lookup.py <keyword>

# 主公 ~/.claude/CLAUDE.md 索引
cat ~/.claude/knowledge/index.md
grep -r "关键词" ~/.claude/knowledge/
```

### 6.2 4 北极星跟踪

- **expert_activation ≥ 5**: EPIC 必触发 ≥ 5 distinct experts
- **cross_epic_reuse ≥ 60%**: file_scope.includes 中 ≥ 60% 已被其他 EPIC 覆盖
- **ab_hit_rate < 15%**: A+B 2-Group review 推荐 跟 final outcome 一致率 ≥ 85%
- **mis_dispatch_rate < 10%**: ticket 未被派单或跨 specialization < 10%

## 7. Retrospective Routine (EPIC-161 + EPIC-205)

### 7.1 6 阶段 routine

```bash
bash scripts/retrospective-routine.sh --dry-run
# 1. retrospect     — 列最近 N release
# 2. consolidate    — 合并重复 docs / 移除 dead refs
# 3. review-docs    — 验证 lazy-load + path-scoped rules
# 4. upgrade        — deps / tool version / install.sh Omnibus
# 5. archive        — 移 deprecated → _archived/
# 6. delete         — 0-use files / unused exports
```

### 7.2 触发模式

- **release**: 每次 release 节点
- **quarter**: 季度整理 (每 3 月)
- **governance-debt**: 治理债 threshold 触发
- **all**: 默认 (跟 EPIC-205 跑批一致)

## 8. 心跳 + 后台 (跟 Rule 1 联合)

```bash
# 后台跑 (Rule 1 §1.1)
bash ~/.claude/exec-task.sh "<name>" "<cmd>"

# 日志到 /tmp (Rule 1 §1.2)
LOG="/tmp/claude-tasks/<name>-$(date +%Y%m%d-%H%M%S).log"

# 检查 exit code (Rule 1 §1.3)
if ! cmd; then echo "error"; exit 1; fi

# 返回 OK/FAILED + 自动 tail (Rule 1 §1.4)
# 成功: OK success / 失败: FAILED + last 10 lines

# 禁止监控日志 (Rule 1 §1.5)
# ❌ tail -f / tail -F / less +F / watch
```

## Reference

- [01-top-design.md](01-top-design.md) — 顶层设计
- [04-lessons.md](04-lessons.md) — 经验教训
- [CLAUDE.md](../../CLAUDE.md) — cold start 入口
- [docs/process/](../../docs/process/) — 流程治理 (post-process / doc-audit / smoke-retention)