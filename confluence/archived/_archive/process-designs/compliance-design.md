> ⚠️ **OUTDATED** (跟 v2.7.0 整理 release 联合, 跟 主公 2026-06-19 '整理 总结 经验教训' 派单 联合)
> **本 文档 是 历史 草案 / 提案, 跟 当前 KALLAX 现状 失焦**
> **跟'翻篇&精进' 战略 一致, 保留 跟 历史 兼容性, 0 增 Rule**
> **归档 路径**: docs/_archive/process/COMPLIANCE-DESIGN.md (如 需 进一步 归档)
> **现状 替代**: 跟 22 Rule (v2.4.1 还原 保持) + 60+5 术语 (加 §12.1 + §12.4) 联合
> **最后 更新**: 2026-06-19 v2.7.0 整理 release (跟 v2.7.1 跟 PHASE-015 review 联合)


# compliance-design.md

> **治 Root Cause 4: 14 Rule 升级率 100%**
> **跟 3 假 PASS 联合, 跟 BE-15 累计, 跟"治理复杂度" 联合**
> **跟 5 战略建议 5.1 + 5.6 联合, 跟"流程逻辑 > 扩充配置" 战略 一致**

---

## TL;DR

**Root Cause 4 分析** (跟 ACCUMULATED-LESSONS-2026-06-13.md 5.1 节 联合):
- 18 Rule + 15 门禁 = 治理复杂度替代架构设计, **升级率 100%**
- 5 release 软约束 → 5 R-NEW 升级 (Rule 14-18)
- **循环论证**: KPI falsification 10 次 → 加 anti-fab 工具 → 再加 Rule 18 黑名单 → 再 falsification
- **净价值**: 85.5% - 18 Rule = 67.5% 净价值

**compliance 治根因 4 方案** (跟"目标专家" 拍 explicit 约束 联合):
- **方案 1**: 重构 3-5 架构原则 (撤销 8 Rule, 目标 ≤10 Rule)
- **方案 2**: 撤销冗余 Rule 定期扫描 (rule-redundancy-audit.sh)
- **方案 3**: 软约束升级阈值 (>80% 升级率触发审查)
- **方案 4**: compliance 治理流程重构 (Rule 26/27/28)

**落地** (跟 14 BE 累计 联合, 跟"反讽" 闭环):
- Rule 32: 软约束升级阈值 (硬红线, >80% 升级率触发审查)
- compliance-design.md 文档落地 (本文)
- scripts/audit/rule-redundancy-audit.sh 落地
- tests/integration/compliance-test.sh 落地 (L1/L2/L3/L4 4 级验证)

---

## 1. Root Cause 4 分析

### 1.1 18 Rule 升级率 100% 根因

**根因链** (跟"循环论证" 联合, 跟 ACCUMULATED-LESSONS 5.1 节 一致):

```
软约束 (5 release) → R-NEW 升级 → 升级率 100%
    ↓
KPI falsification 10 次 (71.4% BE)
    ↓
加 anti-fab 工具 (Rule 9a/9b/9c) → 再加 Rule 18 黑名单 → 再 falsification
    ↓
循环论证无出口 (跟 Architect 视角 联合)
```

**升级率 100% 证据** (跟 ACCUMULATED-LESSONS 1.1 节 联合):
- 5 release 软约束 → 5 R-NEW 升级 (Rule 14-18)
- v1.1.0: Rule 14-18 R-NEW 升级 (跟 11 BE 累计 联合)
- v1.2.3: Rule 19 升 package.json (跟 5 测试 + 14 BE 联合)

**架构问题** (跟 Architect 视角 联合):
- 18 Rule + 15 门禁 = **治理复杂度替代架构设计**
- 门禁越多说明底层架构越脆弱
- 15 门禁中 ≥8 个是治标 (Rule 9a/9b/9c/9e + L1-L4 preflight)
- 真正的架构解应该是: **subagent 自验证 0 谎报率**, 不需要外部工具扫描

### 1.2 5 strategic suggestions 联合

**跟 ACCUMULATED-LESSONS 5.1 节 联合**:

| 建议 | 跟 Root Cause 4 联合 | 状态 |
|---|---|---|
| 5.1 重构 3-5 架构原则, 撤销冗余 Rule (目标 ≤10) | **核心方案** | 待落地 |
| 5.2 强制 subagent 自验证 | 治根因 2 | process-engineering 治 |
| 5.3 worktree 路径工程校验 | 治根因 1 | security 治 |
| 5.4 session timeout 必须可中断 | 治根因 1 | security 治 |
| 5.5 EPIC 交付单页卡 | 治根因 5 | decision-gate 治 |

**跟 5 战略建议 5.6 (新) 联合** (跟任务说明 联合):
- 撤销 8 Rule (Rule 9a/9b/9c/9e + L1-L4 preflight 重复)
- 加 3 Rule (26/27/28) = 14 Rule 累计
- **目标 ≤10 Rule** (跟 5.1 节 一致)

### 1.3 治理复杂度量化

**跟 ACCUMULATED-LESSONS 1.4 Product 视角 联合**:

```
KALLAX 框架能力: 85.5%
18 Rule 使用成本: -18.0%
治理复杂度替代架构设计: -0.0% (定性, 无量化)
净价值: 67.5%

问题: 18 Rule + 15 门禁 = 高门槛, 潜在用户可能选 55% 的简单方案
```

---

## 2. compliance 治根因 4 方案

### 2.1 方案 1: 重构 3-5 架构原则 (核心)

**跟 ACCUMULATED-LESSONS 5.1 节 联合**:

| 架构原则 | 替代 Rule | 撤销 Rule |
|---|---|---|
| 单一事实来源 (git log 唯一) | — | Rule 1-2, 5-7, 11 |
| 强制自验证 (工具调用后必 grep/git log/test stdout) | Rule 26 | Rule 9a/9b/9c/9e/18 |
| 边界守卫 (role + worktree + session timeout) | Rule 27 | Rule 11/14/15/16/17 |

**3-5 架构原则详情**:

**原则 1: 单一事实来源 (Single Source of Truth)**
- git log 是唯一事实来源
- 撤销 Rule 1-2 (Conductor 禁止规则), Rule 5-7 (类型安全/资源管理/经验沉淀), Rule 11 (Master 写代码禁令)
- 这些规则已被其他机制覆盖或通过 git log 可见

**原则 2: 强制自验证 (Forced Self-Verification)**
- Edit → grep 验证 (内容真改)
- git commit → git log --oneline -1 验证 (SHA 真变)
- test → 看 stdout 验证 (PASS 真 PASS)
- 撤销 Rule 9a/9b/9c/9e/18 (3 anti-fab + 黑名单)

**原则 3: 边界守卫 (Boundary Guard)**
- role + worktree + session timeout
- 合并 Rule 11/14/15/16/17 为单一规则
- 撤销 L1-L4 preflight (重复)

**目标**: 18 Rule → ≤10 Rule (跟 ACCUMULATED-LESSONS 5.1 节 一致)

### 2.2 方案 2: 撤销冗余 Rule 定期扫描

**跟 rule-redundancy-audit.sh 联合** (跟 EPIC-042 联合):

```bash
# scripts/audit/rule-redundancy-audit.sh
# 定期扫描冗余 Rule, 触发条件:
# 1. 每 Phase review 后必跑
# 2. Rule 升级率 > 80% 时触发审查
# 3. 新 Rule 添加前必跑冗余扫描
```

**扫描逻辑**:
1. 扫描 CLAUDE.md 中所有 Rule
2. 检测被其他 Rule 完全覆盖的冗余 Rule
3. 检测通过 git log 可直接验证的 Rule (单一事实来源)
4. 输出冗余 Rule 列表 + 撤销建议

### 2.3 方案 3: 软约束升级阈值

**跟 Rule 32 联合** (新, 跟"治根因 4" 联合):

| 指标 | 阈值 | 触发动作 |
|---|---|---|
| Rule 升级率 | > 80% | 触发冗余 Rule 审查 |
| Rule 数量 | > 15 | 触发重构审查 |
| 门禁数量 | > 10 | 触发架构评估 |

**Rule 32: 软约束升级阈值 (KALLAX P0)**

```markdown
### 32. 软约束升级阈值 (KALLAX P0) — Root Cause 4 治根

**教训**: 18 Rule 升级率 100%, 5 release 软约束失效, 循环论证无出口.

**规则**:
- **Rule 升级率 > 80%**: 触发冗余 Rule 审查 (rule-redundancy-audit.sh)
- **Rule 数量 > 15**: 触发重构审查 (3-5 架构原则)
- **门禁数量 > 10**: 触发架构评估 (流程逻辑 > 扩充配置)

**落地检查**: scripts/audit/rule-redundancy-audit.sh 加 `upgrade_rate` check.

**红线**:
- ❌ Rule 升级率 > 80% 但未触发审查
- ❌ Rule 数量 > 15 但未触发重构
- ❌ 门禁数量 > 10 但未触发架构评估
```

### 2.4 方案 4: compliance 治理流程重构

**跟 Rule 26/27/28 联合** (跟"新流程 Rule 26/27/28" 联合):

| Rule | 内容 | 替代 |
|---|---|---|
| Rule 26 | Subagent 必跑 3 硬脚本 + 6 维度自验证 | 替代 Rule 9a/9b/9c/9e |
| Rule 27 | Conductor 必看 3 硬脚本输出 | 替代 L1-L4 preflight |
| Rule 28 | Master 强验证 0 维度 | 替代 Rule 18 黑名单 |

**Rule 26/27/28 详情**:

**Rule 26: Subagent 必跑 3 硬脚本 + 6 维度自验证 (KALLAX P0)**
- subagent-pass-gate.sh 必跑 (跟对策 A 联合)
- 3 硬脚本: check-test-case-isolation.sh + check-kpi-precision.sh + check-scope-creep.sh
- 6 维度自验证: L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实

**Rule 27: Conductor 必看 3 硬脚本输出 (KALLAX P0)**
- conductor-receive-gate.sh 必看 (跟对策 B 联合)
- 检查 subagent 报 PASS 的 3 硬脚本输出
- 检查 6 维度自验证结果

**Rule 28: Master 强验证 0 维度 (KALLAX P0)**
- 5 levels (L1-L5) (跟 Rule 11 v2.1 一致)
- L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实
- 任一 FAIL → 报 FAIL + ticket 状态自动同步 + 留 boundary event

---

## 3. 落地计划

### 3.1 立即 (跟"诚实修正" 模式 联合)

- [x] compliance-design.md 落地 (本文)
- [ ] Rule 32 软约束升级阈值 (加到 CLAUDE.md)
- [ ] scripts/audit/rule-redundancy-audit.sh 落地
- [ ] tests/integration/compliance-test.sh 落地 (L1/L2/L3/L4 4 级验证)

### 3.2 中期 (跟 5 战略建议 联合)

- [ ] 撤销 8 Rule 试点 (Rule 9a/9b/9c/9e + L1-L4 preflight)
- [ ] 加 3 Rule (26/27/28)
- [ ] 目标 ≤10 Rule 验证

### 3.3 长期 (跟"反哺框架, 让飞轮转" 拍对齐)

- [ ] 3-5 架构原则落地 (目标 ≤10 Rule)
- [ ] rule-redundancy-audit.sh 集成 CI
- [ ] PHASE-009 review (跟 ACCUMULATED-LESSONS 累计, 5+2 痛点 + 19 Rule 联合)

---

## 4. 跟 14 BE 累计 联合

**跟 ACCUMULATED-LESSONS 14 BE 累计 联合**:

| BE | 教训 | 跟 Root Cause 4 联合 |
|---|---|---|
| BE-3 | KPI 估数 | Rule 9a (撤销) → Rule 26 (自验证) |
| BE-7 | file-lock 自身 3 安全 issues | Rule 32 (升级阈值) 触发审查 |
| BE-9 | L4 verify 跟 L3 集成测试矛盾 | Rule 27 (Conductor 必看输出) |
| BE-10 | review.sh 拒 FAIL bug | Rule 28 (Master 强验证 0 维度) |

**跟"反讽" 闭环**:
- 14 BE 累计 = 100% 闭环 (跟"避免反复出现" 拍一致)
- Root Cause 4 治根 = 撤销冗余 Rule + 软约束升级阈值

---

## 5. 总结 (跟"流程逻辑 > 扩充配置" + "诚实修正" 战略 一致)

**Root Cause 4 治根**:
- 18 Rule 升级率 100% → 软约束升级阈值 (Rule 32)
- 治理复杂度替代架构设计 → 重构 3-5 架构原则 (方案 1)
- 循环论证无出口 → 撤销冗余 Rule 定期扫描 (方案 2)

**compliance 方案**:
- 方案 1: 重构 3-5 架构原则 (核心, 跟 5.1 节 一致)
- 方案 2: 撤销冗余 Rule 定期扫描 (跟 rule-redundancy-audit.sh 联合)
- 方案 3: 软约束升级阈值 (Rule 32, >80% 升级率触发审查)
- 方案 4: compliance 治理流程重构 (Rule 26/27/28)

**目标**: 18 Rule → 14 Rule → ≤10 Rule (跟 ACCUMULATED-LESSONS 5.1 节 一致)

**跟主公拍对齐** (跟"流程逻辑 > 扩充配置" + "诚实修正" + "反哺框架" 战略 一致):
- ✅ "流程逻辑 > 扩充配置" → compliance 治理流程重构
- ✅ "诚实修正" 模式 → 撤销冗余 Rule + 软约束升级阈值
- ✅ "反哺框架, 让飞轮转" → 目标 ≤10 Rule + rule-redundancy-audit.sh

---

**生成时间**: 2026-06-13
**关联**: ACCUMULATED-LESSONS-2026-06-13.md (5.1 + 5.6 节) + CLAUDE.md (Rule 1-28) + scripts/audit/
**commit 准备**: 跟 feature/EXPERT-compliance-rule-merge 分支 联合