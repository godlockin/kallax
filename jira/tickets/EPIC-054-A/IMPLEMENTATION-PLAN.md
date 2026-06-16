# EPIC-054-A Implementation Plan

> Worktree 根目录统一 (4 套 → 1 套, 跟 git worktree list 一致, 治 H5)
> P1 | 8h | branch: feature/EPIC-054-A-worktree-unify
> Performer: performer-EPIC-054-A | base SHA: 7f88823

---

## 1. 目标 (跟 AC 1:1 对齐)

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | 4 套根目录 → 1 套 (默认 `.kallax/worktrees/`), 跟 `git worktree list` 输出 1:1 一致 | 跑 `unify-roots.sh --dry-run` + 比较 `git worktree list` |
| AC2 | `scripts/worktree/unify-roots.sh` 实现 — 自动迁移 50+ worktree, 改 `.git/worktrees/` 内部指针 + worktree `.git` 文件 | 单元 + 集成测试 |
| AC3 | `.gitignore` 加 `.claude/worktrees/`, `.worktrees/`, `/performer-EPIC-*/` 忽略 | 验证 .gitignore 3 行 + 测试 |
| AC4 | `scripts/detect-stale-worktrees.sh` 升级 — 改 1 套根目录扫描 | 验证脚本逻辑 + 测试 |
| AC5 | `tests/integration/worktree-unify-test.sh` 6/6 PASS | 跑测试 |
| AC6 | `git worktree list` 输出跨 1 套根目录 | 集成测试验证 |
| AC7 | Rule 9 KPI 精确 X/Y 格式 — 6/6 = 100.0% | 测试报告 X/Y 格式精确数字 |

---

## 2. 设计 (4 套 → 1 套)

### 2.1 当前根目录分布 (从 `git worktree list` 实测)

```
.claude/worktrees/  →  6 worktree (ONRAMP × 5 + PHASE-003-up4)
.git/worktrees/     →  1 worktree (EPIC-031-debt-fixes) — git 内部 bookkeeping, 不迁移
.kallax/worktrees/  →  50+ worktree (EPIC/PHASE/auditor 默认标准)
.worktrees/         →  1 worktree (EPIC-033-dispatch-80)
performer-EPIC-034/ →  3 nested (performer-035-A/036-A/037-A)
```

**4 套可迁移根目录** = `.claude/` + `.kallax/` (当前默认) + `.worktrees/` + `performer-EPIC-*/`

**1 套目标根目录** = `.kallax/worktrees/` (跟 20+ 历史 EPIC 一致)

### 2.2 核心语义: 单一真相来源 (跟 `git worktree list` 1:1)

`git worktree list` 输出的每个非 main 行, 路径必须都在 `.kallax/worktrees/` 下. 任何散落到其他 3 套根目录的 worktree 视为"未统一", unify-roots.sh 必须迁移.

### 2.3 接口

```bash
# scripts/worktree/unify-roots.sh
# Usage: unify-roots.sh [--dry-run] [--target-root=<path>]
# Default target: .kallax/worktrees/
# Actions:
#   1. 列出所有非 main worktree + 分类到 4 套根目录
#   2. 对每个非 .kallax/worktrees/ 的 worktree:
#      - git worktree move <old> <new>
#      - 验证 .git/worktrees/<id>/gitdir 指针更新
#      - 验证 worktree/.git 文件指针更新
#   3. 输出 git worktree list 验证 1:1 一致
# --dry-run: 只打印计划, 不执行迁移
```

### 2.4 atomic write + 备份 + 回滚 策略

- 迁移前: `cp -a <old> <backup-dir>/$(basename <old>)-$(date +%s)` (整个目录备份)
- 迁移: `git worktree move <old> <new>` (git 原生 move, 内部指针自动更新)
- 回滚: 检测失败 → 恢复备份 → 重写 .git 文件指针
- 不动: worktree 内部内容 (只动根目录)

### 2.5 边界: 实际迁移 ≠ Performer 责任

- **Performer 交付**: 脚本 + 测试 + .gitignore + detect-stale-worktrees.sh 升级
- **Master 责任**: 在 merge 后执行 `unify-roots.sh` 实际迁移 50+ worktree (避免 Performer 越界写 miao 边界外的文件)
- **理由**: 50+ worktree 跨越多个 parent worktree, 修改会破坏其他 EPIC ticket 的隔离边界

---

## 3. 步骤 (15 步中我的子集)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 验证 worktree (Master 已建) | ✓ |
| 2 | 读 ticket.json | ✓ |
| 3 | 加载 expert profile (backend) | ✓ (隐式) |
| 4 | 深度分析 (git worktree list / .gitignore / detect-stale-worktrees / enter-worktree / EPIC-053 pattern) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 (6 case) | 待执行 |
| 7 | 写实现 unify-roots.sh + .gitignore + detect-stale-worktrees.sh 升级 | 待执行 |
| 8 | 跑测试 6/6 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-054-A.json) | 待执行 |
| 13-15 | Master 强验证 / merge (Master/Conductor 责任) | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建** (3 new):
- `scripts/worktree/unify-roots.sh` — 核心迁移脚本
- `tests/integration/worktree-unify-test.sh` — TDD 6 case 集成测试
- `jira/tickets/EPIC-054-A/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-054-A/LESSONS-LEARNED.md` — 教训沉淀

**修改** (2 modified):
- `.gitignore` — 确认 3 套忽略规则已存在 (检查后如缺失则补)
- `scripts/detect-stale-worktrees.sh` — 升级为单根目录扫描

**不动** (边界):
- docs/PROCESS.md (跟 EPIC-056-A 边界)
- CLAUDE.md (跟 EPIC-054-D 边界)
- 现有 50+ worktree 内部内容
- 其他 EPIC ticket / node/ rust/ web/

---

## 5. 测试设计 (AC5 6 case)

| Case | 描述 | 验证 |
|------|------|------|
| 1 | 4 套根目录 mock | 检测脚本能正确分类 4 类根目录 |
| 2 | 50+ worktree 迁移 (atomic write + git mv) | 模拟 50 个 worktree, 迁移后路径 100% 在 target |
| 3 | 1 套根目录验证 | 跑脚本后 `git worktree list` 输出全部在 `.kallax/worktrees/` |
| 4 | `.git/worktrees/` 内部指针正确性 | 迁移后 .git/worktrees/<id>/gitdir 指向新路径 |
| 5 | worktree `.git` 文件正确性 | 迁移后 worktree/.git 内容指向 .git/worktrees/<id>/ |
| 6 | 集成 — 4 套 → 1 套 + git worktree list 一致 | E2E 完整流程验证 |

**子检查**: AC7 — 6/6 = 100.0% (精确 X/Y, no estimate).

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| 50+ worktree 迁移中断导致部分状态损坏 | atomic write + 备份 + 回滚 机制 (跟 EPIC-041-C 联合) |
| Performer 越界改 miao 边界外 worktree 内容 | 只交付脚本 + 测试, 实际迁移由 Master 在 merge 后执行 |
| 复制其他 EPIC 迁移工具 | 只参考 naming/style, 实现从零写 |
| boundary 越界 | 用 `check-scope-creep.sh EPIC-054-A` 验证 (5 文件全在 scope) |
| KPI falsification | 测试报告用 X/Y 精确格式 (6/6 = 100.0%) |
| 自审 | A/B review 跳过 (本 ticket 范围内不在 Performer 责任) |
| 跑测试不报 PASS | pass-report 含 raw test_output |

---

## 7. 与 EPIC-054-B/C/D 接口

| Ticket | 责任 | 跟 EPIC-054-A 联动 |
|--------|------|--------------------|
| EPIC-054-B | Instance TTL | 用统一后的 `.kallax/worktrees/` 路径做 instance 管理 |
| EPIC-054-C | Epic state machine | 同上 |
| EPIC-054-D | Rule merge (CLAUDE.md 整理) | EPIC-054-A 不动 CLAUDE.md, 边界清晰 |

---

## 8. 验收检查清单 (AC × 7)

- [ ] AC1: 4 套 → 1 套 — `unify-roots.sh --dry-run` 显示迁移计划, 目标 `.kallax/worktrees/`
- [ ] AC2: `unify-roots.sh` 实现 — git worktree move + 内部指针自动更新 + 备份回滚
- [ ] AC3: `.gitignore` — 3 套忽略规则存在
- [ ] AC4: `detect-stale-worktrees.sh` — 扫描改为单根目录
- [ ] AC5: 集成测试 6/6 PASS
- [ ] AC6: `git worktree list` 一致性 (测试用例 6)
- [ ] AC7: KPI 6/6 = 100.0%
