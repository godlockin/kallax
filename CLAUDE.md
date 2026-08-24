# KALLAX v3.36.0

> **CLAUDE.md 治理 2.0 (EPIC-159)**: 主文件 ≤ 200 行 (Anthropic 硬阈值). 低频 / reference 内容移 `.claude/rules/*.md` path-scoped lazy load.

## 1. CLI 执行规范 (每次工具调用, 失败成本最高)

**来源**: whisper-cpp 10 段全失败未发现 (wrapper 无 fail-fast + 未主动 grep FAILED)

**5 条强制**:
1. **后台执行** — 所有 CLI 命令后台跑 (run_in_background: true 或 bash ~/.claude/exec-task.sh)
2. **日志到 /tmp** — 输出重定向到 /tmp/claude-tasks/<task>-<ts>.log
3. **检查 exit code** — 必须显式 if ! cmd; then
4. **返回 OK/FAILED + 自动 tail** — 成功只返回一行，失败自动 tail 最后 10 行
5. **禁止监控日志** — tail -f / tail -F / less +F / watch

**Fail-Fast 强制**: 禁止 cmd || true 吞错误，必须 if ! cmd; then exit 1; fi

## 2. 5-Level Verify 新规 (EPIC-069-D)

| Level | 之前 | 之后 (v3.8.1+) |
|-------|------|---------------|
| L1 git | commit + push | + raw test output 在 PR 描述 |
| L2 stdout | cargo build | cargo test --workspace --release 0 errors |
| L3 4-expert | master review | + expert 提供 raw test 输出 |
| L4 independent | 脚本 | + 脚本真跑 (cache 失效) |
| L5 boundary | Rule check | + check-claim-evidence.sh 扫数字 |

**禁止**: X/Y 格式无 raw_output / 5-Level Verify 但 L2 是 cargo build / 全过/全绿等裸数字宣称

**新 EPIC 必跑**: bash scripts/scan-dead-code.sh + cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run tests/dead-code-sentinel-*.test.ts

**硬化**: 详见 .claude/rules/strict-tsconfig.md

## 3. Rule 34 — Bugfix 必须独立复现 (EPIC-152)

1. **Master 建 ticket 必含 3 字段**: reproduction_command / reproduction_exit_code / reproduction_raw_output
2. **Performer 收到 ticket 必做独立复现**: 不吻合 → STOP, blocked
3. **0 source change 也是 valid conclusion**

### 3.1. Rule 35 — Sprint 时间盒 (EPIC-190)

1. **Sprint 容量**: 最多 5 EPIC, 每 EPIC 最多 10 commits, 每 commit ≤ 500 行
2. **0 超大任务**: ≥ 4 模块 / ≥ 5 文件 → 拆 EPIC
3. **时间盒**: 单 EPIC 必走 4-PR 全程
4. **0 跨 Sprint 累积**: 未完成 EPIC 必在当前 Sprint 关闭

### 3.2. Rule 36 — Sprint 结束必跑 4 北极星 (EPIC-194)

1. **expert_activation_rate ≥ 5** — 每 EPIC 触发 ≥ 5 distinct experts
2. **cross_epic_reuse_rate ≥ 40%** — file_scope.includes 中 ≥ 40% 已被覆盖 (EPIC-277-H: 60%→40%)
2b. **cross_epic_docs_reuse_rate ≥ 40%** (EPIC-253 副指标)
3. **ab_hit_rate < 15%** — A+B review 吻合率 ≥ 85%
4. **mis_dispatch_rate < 10%** — 派单错率 < 10% (multi_spec_intentional: true 可豁免)

**0 静默跳过**: Sprint 结束时必跑 scripts/metrics/sprint-metrics.sh --epic EPIC-XXX; docs-only 用 --docs-only (exit 3 SKIP)

## 4. Branch Flow Governance (EPIC-074)

feature/v3.X.Y-EPIC-ZZZ → testing → main → miao

| 阶段 | 操作 | 合并权 (EPIC-275) |
|------|------|---------------------|
| 1. feature | worktree + 开发 | — |
| 2. feature→testing | gh pr | master 自审自合 |
| 3. testing→main | gh pr | master review 后自合 |
| 4. main→miao | gh pr | 主公亲自 (EPIC-242) |

**Review 分级 (EPIC-270)**:
- **T1**: 0 源码 + ≤100 行 + 单 commit
- **T2**: 有源码 或 >100 行 (单 subagent 核实)
- **T3**: ≥5 文件 或 >500 行 或 改 immutable/Rule/CI (多 subagent 核实)

**T2/T3 必附内联 review_summary**.

**conflict check**: git merge-tree --write-tree (老式两参数是 trivial-merge, 冲突恒为 0)
**smoke retention**: bash scripts/check-smoke-retention.sh
**禁 squash/rebase**: allow_squash_merge=false (EPIC-273)

详细规则: .claude/rules/review-tier.md / branch-flow.md

## 5. 10 不可更改 法律 (immutable scripts) + 2 smoke 辅助

> **数字对齐 (EPIC-223/224/225/277-E/280)**: 曾出现 4/5/6/7 四个互不相同数字, 已统一.
> **完整清单**: 详见 .claude/rules/immutable-scripts.md

**10 immutable** (fail-closed, 改动需主公亲自):
- **原 5**: check-decorative-claim / check-narrative / check-fail-closed / check-self-heal (4-law loop) + check-claim-evidence
- **EPIC-224 接入 3**: check-disclaimer + snapshot-claude-md (advisory) + check-ticket-schema
- **EPIC-225 新增 1**: check-jargon (黑名单扫 staged)
- **EPIC-280 新增 1**: verify-agent-note-format (Agent Note schema)

**hook 体系健康**: bash scripts/hooks/install.sh --verify exit 0 才算生效
**commit-msg gate**: DCO Signed-off-by + Conventional Commits type + header ≤100 字符

## 6. Recent EPICs

> **EPIC-209 trim**: 详情移 .claude/rules/recent-epics.md, 主 CLAUDE.md 维持 ≤ 200 行

## 6.4. Rule 37 — 小 effort auto-approve (EPIC-216)

> 主公拍板: effort 比较小的直接 auto-approve (不等主公亲自). 详见 .claude/rules/rule-37.md

## 7. 引用

- **Anthropic Memory**: https://code.claude.com/docs/en/memory
- **Path-scoped rules**: .claude/rules/{state-json,testing,branch-flow,strict-tsconfig,recent-epics,immutable-scripts,retrospective,review-tier}.md
- **Reference docs** (24): branch-flow-history.md / cli-reference.md / 等
- **Manifesto** (5): 01-top-design.md / 等
