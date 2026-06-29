# 5 levels 模式 (KALLAX, EPIC-059-A)

> **跟 eket MASTER-RULES.md §6 联合, 借方法论 不借代码**
> **跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "Rule 数 通胀" 迷信**
> **跟 KALLAX-GLOSSARY §11.1 联合, 跟 v2.4.1 revert 联合**
> **跟"翻篇&精进" 战略 一致, 跟"诚实修正" + "反讽" 战略 联合**

---

## 1. 背景与定位

**问题**: KALLAX 当前 **20 Rule** (跟 CLAUDE.md 实际 1-18 + 30-31 一致, v2.7.4 D1 拍板 A 22→20 跨 release 留待 4h 实施). Rule 数 多 跟 "治理完成" 不是 因果关系 — v2.4.0 4 合并 (22 → 18) 跟 v2.4.1 revert 实证 净价值 持平 67.0%, 0 实际变化, 治根 "0 实际改变 假动作" 反讽.

**方法**: 借 eket `template/docs/MASTER-RULES.md` §6 模式 — 9 条 Hard Rules 简表 + 反例 + 撤销方法 — **不复制 eket 5 levels 全文**, 提取 模式 + 命名, 适配 KALLAX 20 Rule 现状 (Conductor/Performer + outbox-isolation + tag-sop + ...).

**约束**:
- 0 增 Rule (跟"翻篇&精进" 战略 一致, 跟 v2.4.1 还原 20 Rule 联合, 跟 v2.7.4 D1 拍板 A 22→20 联合)
- 0 重写 (跟 Rule 5 DRY 联合)
- 20 Rule → 9 类别 group 索引 (file:line 1:1 映射, 不删)
- 借方法论 不借代码 (不复制 eket 5 levels 全文)

---

## 2. 5 levels 简表 (跟 eket §6 模式 一致)

| # | 规则 | 要点 | 联合 KALLAX Rule |
|---|------|------|-----------------|
| 1 | **PR 合并后清理 outbox** | `git rm outbox/review_requests/<id>-*.md` | Rule 17 文件并发竞争 |
| 2 | **删除前查反向引用** | `grep -rn "FILE" . --include="*.md"` | Rule 5 DRY (Single Source of Truth) |
| 3 | **Slaver 超时 Release** | 超时→诊断→区分 Performer/任务侧问题→Release 或退回 analysis | Rule 11 + PHASE-013 反思 |
| 4 | **负载分担** | 并行>3 或积压>10 → 委托助理 | Rule 1 并行隔离 |
| 5 | **分配前确认环境** | `node dist/index.js system:doctor` | Rule 8 L4 脚本必须存在 |
| 6 | **文档卫生 (每10轮)** | 检查未追踪 md / 僵尸 ticket / 积压 review | Rule 6 经验沉淀强制 + tag-sop |
| 7 | **新建前先想** | 是否有同类文档可更新？ | Rule 6 文档卫生 + "借方法论 不借代码" 战略 |
| 8 | **Rule of 500** (占位) | 净变更>500行 → 必须 codemod, 或 `Approved-Large-PR-By:` | 跟 EPIC-059-B 联合 |
| 9 | **PR ~100 行上限** (占位) | ≤100 pass, 100-500 warn, >500 fail | 跟 EPIC-059-C 联合 |

---

## 3. 5 levels 详细 解释 (跟 eket §6 模式 一致)

### Rule 1: PR 合并后清理 outbox

**要点**: PR merge 后, 删除 `outbox/review_requests/<id>-*.md`, 避免 outbox 膨胀.

### 反例

- ❌ 提交 PR #42 merge 后, `outbox/review_requests/42-*.md` 仍在, 下一轮 心跳扫描 误判 积压
- ❌ 删 outbox 但未 `git rm`, 文件 仍 在 working tree, 5 轮 后 git status 显示 untracked

### 正例

- ✅ PR merge 后 `git rm outbox/review_requests/42-*.md` + `git commit -m "chore: cleanup outbox after PR #42 merge"`
- ✅ 跟 Rule 17 文件并发竞争 5 步强制流程 联合, outbox-isolation.sh 自检

---

### Rule 2: 删除前查反向引用

**要点**: 删除文件/章节前, `grep -rn "FILE" . --include="*.md"`, 确认无反向引用.

### 反例

- ❌ 删 `docs/process/old-rule.md` 前未 grep, 导致 `CLAUDE.md` + `KALLAX-GLOSSARY.md` 8 处反向引用 全断 (404)
- ❌ grep 但 只查 `*.md`, 漏查 `*.sh` 跟 `*.json`, 落地脚本 反向引用 失效

### 正例

- ✅ `grep -rn "old-rule" . --include="*.md" --include="*.sh" --include="*.json"` 全查
- ✅ 跟 Rule 5 DRY (Single Source of Truth) 联合, 反向引用 改 单一 真相来源

---

### Rule 3: Slaver 超时 Release

**要点**: Performer 超时 → 诊断 → 区分 Performer/任务侧问题 → Release 或退回 analysis.

### 反例

- ❌ Performer 跑 4h 仍无 commit, Master 直接 Release → 0 经验沉淀, 下一轮 同类问题 重现
- ❌ Master 接管 Performer 任务 → 触发 Rule 11 (Master 写代码禁令) 红线

### 正例

- ✅ Performer 超时 → Master 跑 `system:doctor` 诊断 → 区分 Performer (token 撞墙 / API error) 跟 任务侧 (需求 模糊)
- ✅ Release 必带 LESSONS-LEARNED.md (跟 Rule 6 经验沉淀强制 联合, 跟 PHASE-013 反思 联合)

---

### Rule 4: 负载分担

**要点**: 并行>3 或积压>10 → 委托助理 (跟 Rule 1 并行隔离 联合).

### 反例

- ❌ Master 派 5 个 Performer 跑 同 1 file scope, 触发 worktree 冲突, 5 Performer 全 FAIL
- ❌ 积压 12 ticket 未派, Master 直接接管 → 触发 Rule 14 (Conductor 不能越界) 红线

### 正例

- ✅ `kallax isolation:check TASK-001 TASK-002` 检测 file_scope 重叠
- ✅ 积压>10 → 委托 助理 Master (跟 Rule 11 极端情况 联动)

---

### Rule 5: 分配前确认环境

**要点**: 派 Performer 前, `node dist/index.js system:doctor` 确认环境健康 (跟 Rule 8 L4 脚本必须存在 联合).

### 反例

- ❌ 派 Performer 后才发现 Redis down → Performer 全 FAIL, 浪费时间
- ❌ Performer 在 worktree 跑测试发现 binary 缺 → 跟 Rule 8 L4 脚本必须存在 联合 红线

### 正例

- ✅ Master 派单前 `system:doctor` 跑通
- ✅ Performer session_start.sh 自动 跑 system:doctor (跟 Rule 15 Performer Session 自动加载 联合)

---

### Rule 6: 文档卫生 (每10轮)

**要点**: 每 10 轮 心跳, 检查未追踪 md / 僵尸 ticket / 积压 review (跟 Rule 6 经验沉淀强制 + tag-sop 联合).

### 反例

- ❌ 10 轮未检查, 50 个 untracked md 累积, `git status` 失焦
- ❌ 僵尸 ticket (2+ 轮未推进) 未清理, 积压 review 误判

### 正例

- ✅ Master 心跳 Q5 跑 `tag-audit.sh` + `tag-sop-test.sh` (5/5 PASS)
- ✅ 10 轮 必跑 `cleanup-merged-branches.sh` + `worktree-cleaner.sh`

---

### Rule 7: 新建前先想

**要点**: 新建文件/章节 前, 问 "是否有 同类 文档 可更新?" (跟 Rule 5 DRY + "借方法论 不借代码" 战略 联合).

### 反例

- ❌ 新建 `docs/process/9-hard-rules.md` 前未查 已有 rule-merge-proposal.md, 导致 Rule 合并 主题 双文档 重复
- ❌ 新建 eket 5 levels 复制版 → 跟"借方法论 不借代码" 战略 矛盾, 触发 反讽 治根

### 正例

- ✅ 新建前 `grep -rn "Hard Rule" docs/`, 确认 9-hard-rules.md 是 唯一 真相来源
- ✅ 跟 Rule 5 DRY 联合, 引用 KALLAX-GLOSSARY.md §11.1 + PHASE-013-REFLECTION 闭环

---

### Rule 8: Rule of 500 (占位 EPIC-059-B)

**要点**: 净变更>500行 → 必须 codemod, 或 `Approved-Large-PR-By:`. **占位** 等 EPIC-059-B 联合.

### 反例

- ❌ 净变更 800 行单 PR, 无 codemod, 无 approval → 触发 净价值↓ + fatigue_index↑

### 正例

- ✅ 净变更 350 行 → 正常 PR
- ✅ 净变更 800 行 → codemod + `Approved-Large-PR-By: <master_main>` (跟 EPIC-059-B 联合)

---

### Rule 9: PR ~100 行上限 (占位 EPIC-059-C)

**要点**: ≤100 pass, 100-500 warn, >500 fail. **占位** 等 EPIC-059-C 联合.

### 反例

- ❌ PR 1200 行 → 触发 Rule 18 (KPI Falsification 黑名单) + 5 levels 验证 FAIL
- ❌ PR 200 行未拆 → 评审成本↑, fatigue_index↑

### 正例

- ✅ PR 80 行 (1 AC) → PASS
- ✅ PR 350 行 (跨 3 AC) → 拆 3 PR, 跟 Rule 5 DRY 联合

---

## 4. 撤销方法 (跟 v2.4.1 revert 联合)

**触发**: 5 levels 跟 KALLAX 20 Rule 不再 1:1 适配 (e.g. 20 Rule 升 25, 或净价值↓).

**流程** (跟 Rule 6 经验沉淀强制 + Rule 11 Master 写代码禁令 联合):

1. **Step 1**: Master 跑 `check-9-hard-rules.sh --self-test`, 收集 5 工具 输出
2. **Step 2**: 提交 PHASE 反思 ticket (PHASE-XXX-REFLECTION), 跟 KALLAX-GLOSSARY §11.x 联合
3. **Step 3**: 主公拍板 "撤销" 或 "修订", 跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合
4. **Step 4**: revert 跟 v2.4.1 revert 模式 一致 — 0 落地脚本 变化, 0 净价值 损失, 跟"翻篇&精进" 一致
5. **Step 5**: LESSONS-LEARNED.md 标 "5 levels 撤销", 跟 PHASE-013-REFLECTION 联合

**红线**:
- ❌ 不经 主公拍板 Master 自行撤销 5 levels
- ❌ 撤销 不带 LESSONS-LEARNED
- ❌ 撤销 不跑 PHASE 反思 (跟 KALLAX-GLOSSARY §11.1 联合 反讽 模式)

---

## 5. KPI 精确 X/Y 格式 (Rule 9 强制)

**20 Rule → 9 类别 group 整合 = 20/20 = 100.0%** (跟"翻篇&精进" 战略 一致)
**0 增 Rule** (跟 v2.4.1 还原 20 Rule 联合, 跟 v2.7.4 D1 拍板 A 22→20 联合, 跟"诚实修正" + "反讽" 战略 一致)

**验证脚本**: `bash scripts/check-9-hard-rules.sh --self-test` + `bash tests/integration/check-9-hard-rules-test.sh` (5/5 PASS)

---

## 6. 闭环 (跟 KALLAX-GLOSSARY §11.1 联合)

**§11.1**: "Rule 数 ≠ 治理完成" — 治理完成信号 是 净价值 持平 + 0 增命令 + 0 增 Rule, 不是 "Rule 数 ≤ 阈值 15" (迷信).

**5 levels 简化 跟 §11.1 联合**:
- 5 levels 是 模式 (Pattern), 不是 Rule 数 减 13 (22 → 9)
- 20 Rule 仍 落地 (file:line 1:1 映射), 5 levels 是 group 索引 (索引表, 不删 Rule)
- 跟 v2.4.0 4 合并 反思 联合, 治根 "0 实际改变 假动作" 反讽
- 跟 PHASE-013-REFLECTION 联合, 跟"反讽" + "诚实修正" 战略 一致

**闭环 KPI**: 20 Rule → 9 类别 group = 20/20 = 100.0% 落地, 0 增 Rule, 0 重写, 净价值 持平 67.0%

---

> **来源**: EPIC-059-A (主公 2026-06-18 explicit 派单 "需要都建卡并行处理") + eket `template/docs/MASTER-RULES.md` §6 (借方法论 不借代码) + PHASE-013-REFLECTION-2026-06-18.md (跟 v2.4.1 revert 联合) + KALLAX-GLOSSARY §11.1 (跟 "Rule 数 ≠ 治理完成" 联合)