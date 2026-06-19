> ⚠️ **OUTDATED** (跟 v2.7.0 整理 release 联合, 跟 主公 2026-06-19 '整理 总结 经验教训' 派单 联合)
> **本 文档 是 历史 草案 / 提案, 跟 当前 KALLAX 现状 失焦**
> **跟'翻篇&精进' 战略 一致, 保留 跟 历史 兼容性, 0 增 Rule**
> **归档 路径**: docs/_archive/process/decision-gate-design.md (如 需 进一步 归档)
> **现状 替代**: 跟 22 Rule (v2.4.1 还原 保持) + 60+5 术语 (加 §12.1 + §12.4) 联合
> **最后 更新**: 2026-06-19 v2.7.0 整理 release (跟 v2.7.1 跟 PHASE-015 review 联合)


# Decision-Gate 重构设计 — 治根因 5: ai-copilot 名不副实

> **根因 5**: ai-copilot 模式名不副实, decision-gate.sh 触发 5 类 block (疑似就问), 主公每 5 分钟一次确认请求 = 决策疲劳
> **关联**: ACCUMULATED-LESSONS-2026-06-13.md §1.5 UX 视角 + 5 战略建议 5.1-5.5 + Rule 13
> **状态**: Draft — 待主公拍板

---

## TL;DR

**问题**: decision-gate.sh 5 类 block 决策在 3 模式都触发, ai-copilot 实际变成 "ai-ask-every-step"

**方案**: 重构为"复杂才问" (complex-only), ai-copilot 模式减少 80% block

**Rule 33**: decision-gate 复杂才问 (软限制)

---

## 1. 根因分析 (跟 UX 视角 §1.5 联合)

### 1.1 问题现状

| 指标 | 值 | 来源 |
|---|---|---|
| decision-gate.sh block 类型数 | 5 类 | block.ambiguous_options / performer_failure / rule_exception / epic_critical / high_impact |
| 3 模式都触发 block | 是 | decision-gate.sh: "3 模式都触发" |
| ai-copilot 主公确认频率 | 每 5 分钟 1 次 | ACCUMULATED-LESSONS-2026-06-13.md §1.5 |
| ai-copilot 实际行为 | "ai-ask-every-step" | UX 视角 §1.5 |

### 1.2 根因

**Root Cause**: decision-gate.sh 用"疑似就问"逻辑 — 任何疑似 block 都问主公, 不区分复杂度

**症状** (跟 UX 视角 §1.5 联合):
- ai-copilot 模式下主公被频繁 block, 决策疲劳
- 简单操作 (claim/in_progress) 也触发 block, 应该 AI 自主
- 跟"流程逻辑 > 扩充配置" 战略冲突 (15 门禁 + 8 硬脚本)

### 1.3 对比

| 模式 | 设计意图 (Rule 13) | 实际行为 | 差距 |
|---|---|---|---|
| ai-auto | AI 决策所有事, 仅 block/danger 停下问 | 同左 | 符合 |
| ai-copilot | 简单自主 + 复杂协商 | 疑似就问, 复杂协商 = 0 | -80% |
| manual | 主公确认每阶段 | 同左 | 符合 |

---

## 2. 方案设计 (跟 4 方案对比 联合)

### 2.1 方案对比

| 方案 | 描述 | 跟"复杂才问" 联合 | 跟"软限制 + 硬脚本" 联合 | 复杂度 |
|---|---|---|---|---|
| **方案 1: 复杂才问** | ai-copilot 只在 analysis/test/review 阶段 block | ✅ 直接落地 | ✅ 软限制 | 低 |
| **方案 2: decision-gate 智能分级** | P0/P1/P2 分级, P2 才 block | ✅ 间接落地 | ⚠️ 需硬脚本 | 中 |
| **方案 3: 主公 dashboard 实时同步** | 主公看 dashboard 不被 block | ❌ 不治根 | ❌ 无关系 | 高 |
| **方案 4: decision-gate 流程重构** | 重写 decision-gate.sh, mode 差异化 | ✅ 直接落地 | ✅ 硬脚本 | 高 |

### 2.2 推荐方案

**推荐方案 1: 复杂才问** (跟 5 战略建议 5.1 联合)

**理由**:
- 跟 Rule 13 §6 (ai-copilot "复杂阶段" 判定) 直接对齐
- "claim / in_progress" = 简单 → AI 自主
- "analysis / test / review" = 复杂 → 停下问
- 减少 80% block, 跟 UX 视角 §1.5 需求一致
- 实现简单, 软限制落地快

**实现**:
```bash
# decision-gate.sh 改法 (简化版)
# 读取 mode + stage
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE")
STAGE="${CONTEXT_STAGE:-in_progress}"

# ai-copilot 模式: 只有复杂阶段 (analysis/test/review) 才 block
if [[ "$MODE" == "ai-copilot" ]]; then
    case "$STAGE" in
        claim|in_progress)
            # 简单阶段: AI 自主, 不 block
            exit 0
            ;;
        analysis|test|review)
            # 复杂阶段: 停下问
            ;;
    esac
fi
```

---

## 3. Rule 33: decision-gate 复杂才问 (软限制)

### 3.1 规则

**教训**: decision-gate.sh 触发 5 类 block 在 3 模式都执行, ai-copilot 名不副实 (跟 UX 视角 §1.5 联合).

**规则**: decision-gate.sh 在 ai-copilot 模式下:
- **简单阶段** (claim / in_progress): AI 自主, 不触发 block
- **复杂阶段** (analysis / test / review): 停下问主公

**触发条件**:
| 阶段 | ai-auto | ai-copilot | manual |
|---|---|---|---|
| claim | block | **不 block** | block |
| analysis | block | block | block |
| in_progress | block | **不 block** | block |
| test | block | block | block |
| review | block | block | block |

**减少率**: ai-copilot 模式 block 从 5/5 类 → 3/5 类 = **减少 40%**; 加上"疑似就问" → "复杂才问" 逻辑, 实际减少 80%

### 3.2 红线

- ❌ ai-copilot 模式在简单阶段 (claim/in_progress) 触发 block
- ❌ decision-gate.sh 不区分 mode + stage
- ❌ ai-copilot 变成 "ai-ask-every-step"

### 3.3 关联

- 跟 Rule 13 §6 (ai-copilot "复杂阶段" 判定) 联合
- 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.5 (UX 视角) 联合
- 跟 5 战略建议 5.1 (重构 3-5 架构原则) 联合
- 跟"流程逻辑 > 扩充配置" 战略 一致

---

## 4. 硬脚本设计 (跟"硬脚本" 维度 联合)

### 4.1 decision-gate-complex-only.sh (新增)

**目的**: ai-copilot 模式"复杂才问"实现

**逻辑**:
```bash
#!/usr/bin/env bash
# decision-gate-complex-only.sh — ai-copilot "复杂才问" 实现
# 跟 Rule 33 联合 (软限制落地)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
STAGE="${CONTEXT_STAGE:-in_progress}"

# ai-copilot 模式: 只有复杂阶段才 block
if [[ "$MODE" == "ai-copilot" ]]; then
    case "$STAGE" in
        claim|in_progress)
            # 简单阶段: AI 自主, 不 block
            echo "OK: ai-copilot simple stage $STAGE, no block"
            exit 0
            ;;
        analysis|test|review)
            # 复杂阶段: 触发 decision-gate.sh 原逻辑
            ;;
    esac
fi

# 其他模式 或 复杂阶段: 调用原 decision-gate.sh
exec "$SCRIPT_DIR/decision-gate.sh" "$@"
```

### 4.2 集成

- 跟 Rule 16 §3 (pre-commit hook 串联 decision-gate.sh) 联合
- 替换 `scripts/permission/decision-gate.sh` 调用点
- 跟 stage-gate.sh 联动 (stage-gate.sh 传 STAGE 到 decision-gate)

---

## 5. 测试设计 (跟 4-Level Fact-Forcing L1-L4 联合)

### 5.1 L1 存在性

| 测试 | 期望 |
|---|---|
| `decision-gate-complex-only.sh` 存在 | 文件存在 + 可执行 |

### 5.2 L2 实质性

| 测试 | 场景 | 期望 |
|---|---|---|
| ai-copilot + claim | AI 自主 | exit 0, 不写 ask file |
| ai-copilot + in_progress | AI 自主 | exit 0, 不写 ask file |
| ai-copilot + analysis | 停下问 | exit 2, 写 ask file |
| ai-auto + claim | 停下问 | exit 2, 写 ask file |
| manual + claim | 停下问 | exit 2, 写 ask file |

### 5.3 L3 接线正确

| 测试 | 期望 |
|---|---|
| pre-commit hook 串联 decision-gate-complex-only.sh | 跟 Rule 10 联动 |
| stage-gate.sh 传 STAGE 到 decision-gate | 5 阶段正确分流 |

### 5.4 L4 数据流动

| 测试 | 期望 |
|---|---|
| E2E: ai-copilot + claim → AI 自主 → git commit | 0 ask file, commit 成功 |
| E2E: ai-copilot + analysis → 停下问 → 主公 approve → git commit | 1 ask file, commit 成功 |
| E2E: ai-auto + claim → block → 主公 approve → git commit | 1 ask file, commit 成功 |

---

## 6. 跟 14 BE 累计 联合 (跟"不要再犯了" 联合)

| BE | 跟 decision-gate 联合 |
|---|---|
| BE-6 ~ BE-10 (越界 + KPI + bug) | decision-gate 频繁 block 加重决策疲劳 |
| BE-11 ~ BE-14 (越界反向 + API Error) | decision-gate 治根 5/5 步 缺失 |

**Rule 33 防御**: decision-gate 复杂才问 → 减少主公决策疲劳 → 减少越界事件

---

## 7. 跟 5 战略建议 联合 (跟"反讽" 闭环)

| 战略建议 | 跟 Rule 33 联合 |
|---|---|
| 5.1 重构 3-5 架构原则 | Rule 33 是"复杂才问"架构原则落地 |
| 5.2 强制 subagent 自验证 | 跟 decision-gate 复杂才问 联合减少 block |
| 5.3 worktree 路径工程校验 | 跟 Rule 15 升级 联合 |
| 5.4 session timeout 必须可中断 | 跟 BE-14 联合 |
| 5.5 EPIC 交付单页卡 | 跟文档合并 联合 |

**反讽闭环**:
- 5 战略建议 5.2 = "强制 subagent 自验证" (治 root cause)
- 但 5 战略建议 5.2 自身假 PASS (EPIC-043 0 commit)
- Rule 33 治 ai-copilot 名不副实 (治 root cause 5)
- 跟"反讽" 闭环: 治 root cause ≠ 真治 root cause

---

## 8. 跟"不要再犯了" explicit 约束 联合

**14 BE 防御** (跟之前 4 subagent 越界反向 修复模式 累计):
- ✅ Rule 14 升级 (Conductor 不能越界)
- ✅ Rule 15 升级 (subagent 第一条 = 领卡建 worktree)
- ✅ Rule 16 Step 1-5 (5 步强制流程)
- ✅ Rule 33 (decision-gate 复杂才问) ← 新增

**新流程 Rule 26/27/28** (跟对策 A+B+C 联合):
- ✅ Rule 26: Subagent 必跑 3 硬脚本 + 6 维度自验证
- ✅ Rule 27: Conductor 必看 3 硬脚本输出
- ✅ Rule 28: Master 强验证 0 维度
- ✅ Rule 33: decision-gate 复杂才问 ← 新增

---

## 9. 下一步

- [ ] 主公拍板"同意, 开干"
- [ ] 创 decision-gate-complex-only.sh (硬脚本)
- [ ] 更新 stage-gate.sh 传 STAGE
- [ ] 更新 pre-commit hook 串联
- [ ] 创 tests/integration/decision-gate-test.sh
- [ ] Rule 33 写入 CLAUDE.md

---

**生成时间**: 2026-06-13
**关联**: ACCUMULATED-LESSONS-2026-06-13.md + NEW-PROCESS-2026-06-13.md + CLAUDE.md (Rule 1-32)
**commit 准备**: 跟 miao HEAD `703aa93` 一致, 跟"诚实修正" + "流程逻辑" 战略 一致