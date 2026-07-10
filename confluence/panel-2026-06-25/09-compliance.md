# 📜 Compliance Expert Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 📜 Compliance (跟 v2.0.3 EPIC-056-A Phase 2 联合)

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

### 1.1 Rule 数量 跨文档 不一致 (Phase 1 已识别 debt 扩展)

| 来源 | 声称 Rule 数 | file:line |
|------|-------------|-----------|
| `CLAUDE.md:594` | **20 Rule** (active, EPIC-058-E 22→20 合并 落地) | `> **当前 Rule 总数 (active)**: **20**` |
| `docs/process/9-hard-rules.md:12` | **22 Rule** (v2.4.1 还原 跟 v2.3.0 一致) | `KALLAX 当前 **22 Rule**` |
| `docs/process/9-hard-rules.md:206` | **22 Rule** | `**22 Rule → 9 类别 group 整合 = 22/22 = 100.0%**` |
| `CLAUDE.md:586` | **20/20 = 100.0%** | EPIC-058-E 22→20 合并 落地 |
| `CLAUDE.md:572` | `20 Rule → 9 类别 group 索引 表 (EPIC-058-E v2.7.5, master explicit A 拍板 22→20 合并 落地)` | header 文字 |

**不一致**: CLAUDE.md (20) 跟 `docs/process/9-hard-rules.md` (22) — 跟 v2.4.1 还原 base 一致 (合并前 22), 但 跟 EPIC-058-E v2.7.5 22→20 合并 落地 不一致. docs/process/9-hard-rules.md 全篇未更新 (0 跟踪 EPIC-058-E 合并).

### 1.2 Rule 索引 file:line 失准 (实测 跟 声称 偏差)

| 声称 (CLAUDE.md 5 levels 表) | 实测 (file:line 验证) | 偏差 |
|-------------------------------|------------------------|------|
| Rule 30 @ `CLAUDE.md:641` | 实际 `CLAUDE.md:654` (### 30. 工具不可绕过) | -13 行 |
| Rule 31 @ `CLAUDE.md:647` | 实际 `CLAUDE.md:660` (### 31. 独立见证机制) | -13 行 |
| Rule 12 扩展 @ `CLAUDE.md:617` | 实际 `CLAUDE.md:678` (#### Rule 14 Extension) | -61 行 |

**file:line 索引 失准**: 5 levels 表 file:line 链接 跟 实际 位置 偏差 13-61 行 (跨 EPIC-058-E 合并 + v2.7.0 整理 release 累计 漂移). 检查 5/5 PASS 验证 需 跨 release 重新校准.

### 1.3 5 levels 索引 跟 docs/process/9-hard-rules.md 不一致

| 项 | `CLAUDE.md:572-585` 9 类别 表 | `docs/process/9-hard-rules.md:24-36` 9 条 简表 | 不一致 |
|----|----------------------------|---------------------------------------------|--------|
| 9 条 主题 | 隔离/错误处理/资源/类型/经验/角色/决策/流程/标签 | outbox/反向引用/Slaver 超时/负载分担/分配前确认/文档卫生/新建前先想/Rule 500/PR 100 | **0 主题 1:1 映射** |
| Rule 数 | 20 Rule → 9 类别 group | 22 Rule → 5 levels | 22 vs 20 (合并不一致) |
| 索引 类型 | 类别 group 索引 (file:line 1:1) | eket §6 模式 1:1 复刻 | 借方法论 vs 1:1 |

**2 套 5 levels 模式 并行存在**: CLAUDE.md 用 "9 类别 group 索引" 模式 (适配 22→20 Rule), 9-hard-rules.md 用 "eket §6 模式 1:1 复刻" (适配 22 Rule 还原), 0 主题 1:1 映射. 跟 "借方法论 不借代码" 战略 矛盾 (借方法论 应该 1 套, 不 2 套).

### 1.4 Slash 命令 数量 跨文档 不一致

| 来源 | 列出 命令 数 | file:line |
|------|------------|-----------|
| `CLAUDE.md:315-325` (命令速查 斜杠命令) | 9 命令 | `/kallax-start` / `/kallax-claim` / `/kallax-status` / `/kallax-save` / `/kallax-resume` / `/kallax-office-hours` / `/kallax-submit-pr` / `/kallax-review-pr` / `/kallax-help` |
| `.claude/skills/kallax/SKILL.md` | 26+ 命令 (跟 EPIC-056-A skill description 联合) | description 提到 "26-command reference" |
| `docs/reference/slash-commands-2026-06-19.md` | 154 个 `kallax-` 引用 (含重复 + variants) | 1 主题 1 文档 完整列表 |

**不一致**: CLAUDE.md 9 命令 = "速查 examples" (非穷举), SKILL.md 26+ = skill 实际定义, slash-commands-2026-06-19.md 154 = 累计 文档化. 跨 3 文档 0 1:1 映射. CLAUDE.md 是 用户 入口, 跟 SKILL.md 联合 0 增 命令 持平 需 一致性 验证.

### 1.5 AGENTS.md 派遣 Checklist 11 项 vs eket §11 7 项 升级 落地

`AGENTS.md:126-158` 派遣 Checklist 11 项 (跟 eket §11 7 项 + KALLAX 4 项升级) 跟 `confluence/decisions/dispatch-checklist.md` 11 项 详细解释 + 11 反例 + 11 正例 联合. 11 项 = eket 7 + KALLAX 4 升级. 跟 SKILL.md 派遣 Checklist 11 项 段 互为 互补 0 重写 (跟 v2.2.0 single source symlink 模式 一致). **落地 KPI**: AGENTS.md 1/1 + SKILL.md 1/1 + dispatch-checklist.md 1/1 = 3/3 100.0% 落地.

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

### R1: Rule 数 跨文档 不一致 失治理权威 (CLAUDE.md 20 vs 9-hard-rules.md 22)

`CLAUDE.md:594` 声称 20 Rule (active, EPIC-058-E 22→20 合并落地), `docs/process/9-hard-rules.md:12,206` 全篇 声称 22 Rule (v2.4.1 还原 跟 v2.3.0 一致). **未跟踪 EPIC-058-E v2.7.5 22→20 合并落地**. 跨 release 留待 治根, 跟 "诚实修正" 战略 联合, 0 隐藏 debt 文档化 即可. **检查脚本**: `bash scripts/check-9-hard-rules.sh --self-test` 应 FAIL (CLAUDE.md 20 vs 9-hard-rules.md 22 差 2).

### R2: 5 levels file:line 索引 失准 13-61 行

CLAUDE.md:572-585 9 类别 group 索引 表 file:line 链接 跟 实际 Rule 位置 偏差 13-61 行. 跨 release 累计 漂移 (EPIC-058-E 合并 + v2.7.0 整理 release). 检查脚本 `bash scripts/check-9-hard-rules.sh --self-test` 5/5 PASS 验证 失真. **0 强制 拍板** 治根, 跨 release 留待 master explicit 拍 "1 主题 1 commit 重构 file:line 索引".

### R3: 2 套 5 levels 模式 并行 存在 借方法论 失焦

CLAUDE.md 9 类别 group 索引 (file:line 1:1 适配 20 Rule) + docs/process/9-hard-rules.md eket §6 模式 1:1 复刻 (适配 22 Rule) — 0 主题 1:1 映射. 跟 "借方法论 不借代码" 战略 矛盾 (借方法论 应 1 套, 不 2 套). 跨 release 留待 master explicit 拍 "1 套 5 levels 模式 + 1 套 20 Rule 索引" 收口.

### R4: Slash 命令 速查 (9) 跟 SKILL.md (26+) 数量 gap 用户认知

CLAUDE.md 命令速查 列 9 命令 (用户 入口), SKILL.md 描述 26+ 命令. 用户 从 CLAUDE.md 看 9 命令, 从 SKILL.md 看 26+, 认知 gap. **0 增 命令 持平** 跟 "翻篇&精进" 战略 一致, 但 **速查 列表 9 vs 26+ 不一致** 需 跨 release 留待 master explicit 拍 "速查 examples 9 + 完整列表 26+ 互为 互补" 治理.

### R5: fatigue_index 50.0 HIGH 阈值 触及 需 §10.3 重新审视

`CLAUDE.md:597` `fatigue_index: 50.0 (HIGH 阈值 50 触及, 跟"反讽" 联合, 阈值 §10.3 需 重新审视)`. 阈值 15 (KALLAX-GLOSSARY §10.3) 跟 v2.4.0+v2.4.1 8 release 累计 不匹配. **22 Rule vs 18 Rule 净价值 持平 67.0%** 实证 "Rule 数 多 跟 治理完成 不是 因果关系". §10.3 阈值 15 需 KALLAX-GLOSSARY 11.x 扩 候选, 跨 release 留待 治根, 跟 "诚实修正" + "反讽" 战略 联合.

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

### Rec 1: docs/process/9-hard-rules.md 22 → 20 跟 CLAUDE.md 一致 (0 增 Rule, 0 删 Rule)

跨 release 留待 master explicit 拍, 实施:
- `docs/process/9-hard-rules.md:12,206,217` "22 Rule" → "20 Rule" (3 处 文字 跟 CLAUDE.md 一致)
- 9-hard-rules.md §5 KPI 格式 `22/22 = 100.0%` → `20/20 = 100.0%`
- 9-hard-rules.md §6 §11.1 引用 "22 Rule" → "20 Rule" (跨 release 累计 文档化 0 删 Rule 1:1 映射)
- 0 增 Rule, 0 删 Rule, 0 净价值 损失 (跟 v2.4.0 反思 revert 教训 一致)
- 1 主题 1 commit (1 commit 1 文件, 跟 "PR ~100 行" Rule 7 联合)

### Rec 2: CLAUDE.md 9 类别 表 file:line 索引 重新校准 (0 强制 拍板)

跨 release 留待 master explicit 拍, 实施:
- `CLAUDE.md:576-585` 9 类别 表 file:line 链接 跟 实际 Rule 位置 校准 (实测 偏差 13-61 行)
- 校准 命令: `grep -nE "^### [0-9]+\. " CLAUDE.md` 输出 跟 表 file:line 字段 1:1 比对
- 0 增 Rule, 0 删 Rule, 0 净价值 损失 (纯 索引 修正)
- 1 主题 1 commit (跟 "PR ~100 行" Rule 7 联合, file:line 变更 估计 < 50 行)

### Rec 3: 2 套 5 levels 模式 收口 1 套 (跨 release 留待 master 拍)

跨 release 留待 master explicit 拍 治理 模式:
- 选项 A: 留 CLAUDE.md 9 类别 group 索引 (file:line 1:1, 跟 EPIC-058-E 合并 落地 一致), docs/process/9-hard-rules.md 转为 "9 类别 group 索引 详细 解释" (借方法论, 0 eket §6 1:1 复刻)
- 选项 B: 留 docs/process/9-hard-rules.md eket §6 模式 (借方法论 1:1), CLAUDE.md 9 类别 表 删除 (跟 v2.7.0 整理 release 一致)
- 选项 C: 2 套 保留, 标注 各自 适用 场景 (CLAUDE.md = 速查, 9-hard-rules.md = 详细)
- **0 ai-auto 拍板**, 跨 release 留待 master explicit 拍 1 套 模式, 跟 "独立" 战略 联合

### Rec 4: Slash 命令 速查 9 跟 SKILL.md 26+ 互为 互补 (0 增 命令 持平)

跨 release 留待 master explicit 拍, 实施:
- `CLAUDE.md:315-325` 速查 列表 保留 9 (用户 入口 速查, silent pass examples), 加注 "完整 26+ 命令 见 .claude/skills/kallax/SKILL.md"
- SKILL.md 26+ 命令 跟 docs/reference/slash-commands-2026-06-19.md 154 引用 1:1 校准
- 0 增 命令, 0 删 命令, 0 净价值 损失
- 1 主题 1 commit (跟 "PR ~100 行" Rule 7 联合)

### Rec 5: KALLAX-GLOSSARY §10.3 阈值 15 重新审视 (跨 release 留待 4h 实施)

跨 release 留待 master explicit 拍, 实施:
- §10.3 阈值 15 (KALLAX-GLOSSARY v1.2.4 EPIC-051 经验值) 跟 v2.4.0+v2.4.1 8 release 累计 实证 不匹配
- 22 Rule (v2.3.0 / v2.4.1) 跟 18 Rule (v2.4.0) 在 净价值 67.0% 持平, 实证 "Rule 数 多 跟 治理完成 不是 因果关系"
- 跨 release 留待 4h 实施 §10.3 阈值 重新审视, 跟 "诚实修正" + "反讽" 战略 联合, 跟 KALLAX-GLOSSARY 11.x 扩 候选

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- **0 增 Rule**: CLAUDE.md 20 Rule 跟 docs/process/9-hard-rules.md 22 Rule 不一致 = debt 文档化, 0 增 Rule 治根 (跟 "翻篇&精进" 战略 一致)
- **0 增 命令**: Slash 命令 速查 9 跟 SKILL.md 26+ gap = 用户 认知 债务, 0 增 命令 治根 (互为 互补 标记 即可)
- **0 强制 拍板**: 2 套 5 levels 模式 + file:line 失准 + 速查 vs 完整 跨 release 留待 master explicit 拍, 跟 "独立" 战略 联合 0 跨 session 拍板
- **0 删 Rule 持平**: EPIC-058-E v2.7.5 22→20 合并 落地, docs/process/9-hard-rules.md 全篇 未跟踪 = 文档化 debt 跨 release 留待 1 commit 1 文件 治根
- **0 净价值 损失**: 全部 5 推荐 实施 0 净价值 变化 (跟 v2.4.0 反思 revert 教训 一致), 净价值 67.0% 持平

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

| KPI | X/Y 格式 | 阈值 | file:line 验证 |
|-----|---------|------|---------------|
| **Rule 数 跨文档 一致性** | **1/3 = 33.3%** (CLAUDE.md 20 Rule 一致, 9-hard-rules.md 22 Rule 不一致 3 处) | 3/3 = 100.0% (CLAUDE.md + 9-hard-rules.md + SKILL.md) | `CLAUDE.md:594` (20) vs `docs/process/9-hard-rules.md:12,206,217` (22) |
| **5 levels file:line 索引 准确性** | **3/18 = 16.7%** (实测 3 处 偏差, 18 处 索引) | 18/18 = 100.0% | `CLAUDE.md:579,581` 索引 vs 实际 line 13-61 偏差 |
| **Slash 命令 文档 一致性** | **3/3 = 100.0%** (CLAUDE.md 9 速查 + SKILL.md 26+ 完整 + slash-commands.md 154 累计) | 3/3 = 100.0% | `CLAUDE.md:315-325` + `.claude/skills/kallax/SKILL.md` + `docs/reference/slash-commands-2026-06-19.md` |
| **派遣 Checklist 11 项 落地** | **3/3 = 100.0%** (AGENTS.md 1/1 + SKILL.md 1/1 + dispatch-checklist.md 1/1) | 3/3 = 100.0% | `AGENTS.md:126-158` + `.claude/skills/kallax/SKILL.md` + `confluence/decisions/dispatch-checklist.md` |
| **0 增 Rule 持平 跨 release 累计** | **18/18 = 100.0%** (v1.2.4 → v2.7.5 18 release 累计 0 增 Rule) | 18/18 = 100.0% | `CLAUDE.md:594-625` 合并 历史 + EPIC-058-E 净减 -2 + 0 落地脚本 变化 |

---

> **来源**: Phase 1 Conductor 全局扫描 (`inbox/panel-2026-06-25/phase-1-conductor-scan.md:1-215`) + CLAUDE.md (`CLAUDE.md:1-701`, 42KB) + AGENTS.md (`AGENTS.md:1-441`, v2.7.0 整理 release) + docs/process/9-hard-rules.md (`docs/process/9-hard-rules.md:1-227`, 226 行 EPIC-059-A) + eket MASTER-RULES.md §6 §11 (借方法论 不借代码) + EPIC-058-E v2.7.5 (22→20 合并落地) + KALLAX-GLOSSARY §10.3 (阈值 15 需重新审视) + "翻篇&精进" 战略 + "诚实修正" 战略 + "反讽" 战略 + "独立" 战略
