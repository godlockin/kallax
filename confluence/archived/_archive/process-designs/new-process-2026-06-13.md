> ⚠️ **OUTDATED** (跟 v2.7.0 整理 release 联合, 跟 主公 2026-06-19 '整理 总结 经验教训' 派单 联合)
> **本 文档 是 历史 草案 / 提案, 跟 当前 KALLAX 现状 失焦**
> **跟'翻篇&精进' 战略 一致, 保留 跟 历史 兼容性, 0 增 Rule**
> **归档 路径**: docs/_archive/process/NEW-PROCESS-2026-06-13.md (如 需 进一步 归档)
> **现状 替代**: 跟 22 Rule (v2.4.1 还原 保持) + 60+5 术语 (加 §12.1 + §12.4) 联合
> **最后 更新**: 2026-06-19 v2.7.0 整理 release (跟 v2.7.1 跟 PHASE-015 review 联合)


# KALLAX Subagent PASS 流程 v2.0 (NEW-PROCESS-2026-06-13)

> **跟 15 BE 累计 + 3 假 PASS 反讽 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致**

---

## TL;DR

**旧流程** (跟 3 假 PASS 联合):
- ❌ Conductor 派单 → Subagent 报 PASS → Conductor 收 PASS → 5 levels (L1-L5) (事后)

**新流程** (跟对策 A+B+C 联合, 跟"反讽" 闭环):
- ✅ Conductor 派单 → Subagent 跑硬脚本 → **Subagent 必跑 3 硬脚本** → **Conductor 必看硬脚本输出** → Conductor 收 PASS → Master 强验证 0 维度 (事中)

**核心变化**: **事中** (subagent 报 PASS 时) 必跑 3 硬脚本 + Conductor 必看输出, **事后** Master 强验证 0 维度 (事中已跑硬脚本, Master 强验证 改为流程监督)

---

## 1. 旧流程 (跟 3 假 PASS 联合, 跟"反讽" 闭环)

```
[Conductor] 派单 → [Subagent] 实施 → [Subagent] 报 PASS → [Conductor] 收 PASS → [Master] 强验证 6 维度 (事后) ❌
```

**问题** (跟 5 视角 lessons 联合):
- ❌ Subagent 报 PASS 不强制跑硬脚本 (跟 5 战略建议 5.2 反讽 联合)
- ❌ Conductor 收 PASS 不看硬脚本输出 (跟 5 战略建议 5.3 反讽 联合)
- ❌ 5 levels (L1-L5)是事后 (跟"流程失效" 联合)
- ❌ 25+ subagent 强验证累计, 50% 假 PASS 模式 (跟 BE-15 联合)

---

## 2. 新流程 (跟对策 A+B+C 联合, 跟"反讽" 闭环)

```
[Conductor] 派单
   ↓
[Subagent] 实施
   ↓
[Subagent] **必跑 3 硬脚本** (事中) ← 关键变化!
   ├── scripts/verify/check-kpi-precision.sh (跟 Rule 9a 联合)
   ├── scripts/verify/check-test-case-isolation.sh (跟 Rule 9b 联合)
   ├── scripts/verify/check-scope-creep.sh (跟 Rule 9c 联合)
   ↓
[Subagent] **必看 3 硬脚本输出** (事中) ← 关键变化!
   ├── check-kpi-precision: PASS/FAIL
   ├── check-test-case-isolation: PASS/FAIL
   ├── check-scope-creep: PASS/FAIL
   ↓
[Subagent] **必跑 6 维度自验证** (事中) ← 关键变化! (跟对策 A 联合)
   ├── L1 git log --oneline -1 (SHA 真变)
   ├── L2 git show HEAD:file | grep (内容真改)
   ├── L3 跑全量 E2E
   ├── L4 check-fact-forcing-preflight.sh
   ├── L5 边界 (跟 file_scope.includes 比对)
   ├── L6 诚实 (不估数, 精确 X/Y)
   ↓
[Subagent] 报 PASS (跟 6 维度自验证结果 联合)
   ↓
[Conductor] **必看 3 硬脚本输出 + 6 维度自验证** (事中) ← 关键变化! (跟对策 B 联合)
   ↓
[Conductor] 收 PASS (跟 3 硬脚本 + 6 维度 全 PASS 联合)
   ↓
[Master] 强验证 0 维度 (事中已跑硬脚本, Master 改为流程监督)
   ↓
[Master] 抽查 (10% 概率, 跟"流程逻辑" 战略 一致)
```

**核心变化** (跟对策 A+B+C 联合, 跟"反讽" 闭环):
- ✅ **事中**: Subagent 必跑 3 硬脚本 + 6 维度自验证 (跟对策 A 联合)
- ✅ **事中**: Conductor 必看 3 硬脚本输出 + 6 维度自验证 (跟对策 B 联合)
- ✅ **事后**: Master 强验证 0 维度 (改为流程监督 + 10% 抽查, 跟对策 C 联合)
- ✅ **撤销**: 3 假 PASS subagent 重派 (跟对策 C 联合)

---

## 3. 新流程 软限制 (CLAUDE.md Rule 26-28) (跟"软限制" 维度 联合)

### Rule 26: Subagent 报 PASS 必跑 3 硬脚本 (跟对策 A 联合)

**教训**: 3 假 PASS (EPIC-043/044/047) 报 PASS 时不跑 3 硬脚本 (跟 BE-15 联合).

**规则**: Subagent 报 PASS 之前, 必跑 3 硬脚本:
- `bash scripts/verify/check-kpi-precision.sh` (跟 Rule 9a 联合)
- `bash scripts/verify/check-test-case-isolation.sh` (跟 Rule 9b 联合)
- `bash scripts/verify/check-scope-creep.sh` (跟 Rule 9c 联合)

**红线**:
- ❌ Subagent 报 PASS 时不跑 3 硬脚本
- ❌ Subagent 报 PASS 时不看 3 硬脚本输出
- ❌ 3 硬脚本 FAIL 仍报 PASS

### Rule 27: Conductor 收 PASS 必看硬脚本输出 (跟对策 B 联合)

**教训**: Conductor 信任 Subagent 报 PASS, 不看硬脚本输出 (跟"流程失效" 联合).

**规则**: Conductor 收 PASS 之前, 必看 3 硬脚本输出:
- check-kpi-precision: PASS/FAIL
- check-test-case-isolation: PASS/FAIL
- check-scope-creep: PASS/FAIL
- 3 硬脚本 全 PASS 才收 PASS

**红线**:
- ❌ Conductor 收 PASS 时不看 3 硬脚本输出
- ❌ Conductor 收 PASS 时不看 6 维度自验证
- ❌ 3 硬脚本 FAIL 仍收 PASS

### Rule 28: Master 强验证 0 维度 (跟对策 C 联合)

**教训**: 5 levels (L1-L5)是事后, 假 PASS 已传 Conductor inbox (跟 BE-15 联合).

**规则**: Master 强验证 0 维度 (事中已跑硬脚本), 改为:
- **流程监督**: Master 监督 Subagent + Conductor 跑 3 硬脚本 + 6 维度自验证
- **10% 抽查**: Master 抽查 10% Subagent 报 PASS (跟"流程逻辑" 战略 一致)

**红线**:
- ❌ 5 levels (L1-L5) (事中已跑硬脚本, 改为流程监督)
- ❌ Master 抽查 > 10% (跟"流程逻辑" 战略 一致)

---

## 4. 新流程 硬脚本 (跟"硬限制" 维度 联合, 跟"反讽" 闭环)

### 硬脚本 1: `scripts/process/subagent-pass-gate.sh` (新增) (跟对策 A 联合)

**目的**: Subagent 报 PASS 必跑 3 硬脚本 + 6 维度自验证 (事中)

**逻辑**:
```bash
#!/bin/bash
# subagent-pass-gate.sh — Subagent 报 PASS 必跑 3 硬脚本 + 6 维度自验证
# 跟对策 A 联合 (5 levels (L1-L5) → 0 维度, 事中自动化)
# 跟 Rule 26 联合

set -euo pipefail
umask 077

# 必跑 3 硬脚本
for script in check-kpi-precision check-test-case-isolation check-scope-creep; do
    echo "=== Running $script ==="
    if ! bash "scripts/verify/$script.sh"; then
        echo "FAIL: $script 失败, 不能报 PASS"
        exit 1
    fi
done

# 必跑 6 维度自验证
echo "=== L1: git log --oneline -1 ==="
git log --oneline -1

echo "=== L2: git show HEAD:file | grep ==="
git show HEAD:CLAUDE.md | grep "Rule 26" || { echo "FAIL: Rule 26 not found"; exit 1; }

echo "=== L3: 跑全量 E2E ==="
bash tests/integration/subagent-self-verify-test.sh

echo "=== L4: check-fact-forcing-preflight.sh ==="
bash scripts/check-fact-forcing-preflight.sh

echo "=== L5: 边界 (跟 file_scope.includes 比对) ==="
git diff --name-only miao | while read file; do
    if ! grep -q "$file" ticket.json; then
        echo "FAIL: $file 不在 file_scope.includes"
        exit 1
    fi
done

echo "=== L6: 诚实 (不估数) ==="
grep -E "(估数|约|PARTIAL|around|approximately|估计|roughly|should)" CLAUDE.md && {
    echo "FAIL: CLAUDE.md 含估数字"
    exit 1
}

echo "OK: 6 维度自验证 全 PASS"
exit 0
```

### 硬脚本 2: `scripts/process/conductor-receive-gate.sh` (新增) (跟对策 B 联合)

**目的**: Conductor 收 PASS 必看 3 硬脚本输出 + 6 维度自验证 (事中)

**逻辑**:
```bash
#!/bin/bash
# conductor-receive-gate.sh — Conductor 收 PASS 必看 3 硬脚本输出
# 跟对策 B 联合 (Conductor 收 PASS 必看硬脚本输出)
# 跟 Rule 27 联合

set -euo pipefail

# 必看 3 硬脚本输出 (Subagent 提供)
for script in check-kpi-precision check-test-case-isolation check-scope-creep; do
    if [[ ! -f ".kallax/audit/$script.output" ]]; then
        echo "FAIL: $script.output 不存在, 不能收 PASS"
        exit 1
    fi
    if grep -q "FAIL" ".kallax/audit/$script.output"; then
        echo "FAIL: $script FAIL, 不能收 PASS"
        exit 1
    fi
done

# 必看 6 维度自验证输出
if [[ ! -f ".kallax/audit/six-dimension-verify.output" ]]; then
    echo "FAIL: six-dimension-verify.output 不存在, 不能收 PASS"
    exit 1
fi

echo "OK: Conductor 收 PASS gate 全 PASS"
exit 0
```

---

## 5. 新流程 跟 5 战略建议 联合 (跟"反讽" 闭环)

| 战略建议 | 旧流程 | 新流程 | 跟"反讽" 联合 |
|---|---|---|---|
| 5.1 撤销冗余 Rule | Rule 9a/9b/9c/9e + L1-L4 preflight | Rule 26/27/28 (3 新 Rule) | 跟 5 战略建议 5.1 撤销冗余 Rule 反讽 |
| 5.2 强制 subagent 自验证 | (未落地) | Rule 26 (报 PASS 必跑硬脚本) | 跟 5 战略建议 5.2 反讽: 5.2 治 root cause, 但 5.2 自身假 PASS |
| 5.3 worktree 路径工程校验 | (未落地) | Rule 27 (收 PASS 必看硬脚本) | 跟 5 战略建议 5.3 反讽: 5.3 治越界, 但 5.3 自身假 PASS |
| 5.4 session timeout 可中断 | 30min timeout | (保持) | 跟 5 战略建议 5.4 联合 |
| 5.5 EPIC 交付单页卡 | (已落地) | (保持) | 跟 5 战略建议 5.5 联合 |

**反讽闭环** (跟 5 战略建议 联合):
- **5 战略建议 5.2 = 治 root cause** (强制 subagent 自验证)
- **但 5 战略建议 5.2 自身假 PASS** (EPIC-043 0 commit, BE-15)
- **新流程 5.2 改为 Rule 26** (subagent 报 PASS 必跑硬脚本)
- **新流程 5.3 改为 Rule 27** (conductor 收 PASS 必看硬脚本)

---

## 6. 新流程 跟 15 BE 累计 联合 (跟"不要再犯了" 联合)

| BE | 旧流程表现 | 新流程对策 |
|---|---|---|
| BE-1 ~ BE-5 (8 试反复) | 跳 R-NEW PR, 跳测试 | Rule 26 (报 PASS 必跑硬脚本) |
| BE-6 ~ BE-10 (越界 + KPI + bug) | 越界反向, KPI falsification, bug | Rule 26 + 27 (报 PASS + 收 PASS 必跑硬脚本) |
| BE-11 ~ BE-14 (越界反向 + API Error) | 越界反向, API Error 卡住 | Rule 26 + 27 + 28 (报 PASS + 收 PASS + 流程监督) |
| **BE-15** (3 假 PASS) | 3 假 PASS 0 commit | **Rule 26 + 27 联合, 撤销 3 假 PASS 重派** |

---

## 7. 跟"流程逻辑 > 扩充配置" 战略 一致 (跟"不要再犯了" 联合)

- ✅ 撤销冗余 Rule (5.1) — Rule 9a/9b/9c/9e + L1-L4 preflight 撤销
- ✅ 加新 Rule 26/27/28 (3 新 Rule) — 跟对策 A+B+C 联合
- ✅ 流程改事中自动化 — 跟对策 A+B+C 联合, 跟"反讽" 闭环

**总 Rule 数量**: 19 - 8 (撤销 5.1) + 3 (新 Rule 26/27/28) = **14 Rule** (跟 5 战略建议 5.1 目标 ≤10 Rule 联合, 跟 5 视角 Product 67.5% 净价值 联合)

---

## 8. 撤销 3 假 PASS subagent, 重派 (跟对策 C 联合)

| 假 PASS subagent | 撤销 | 重派 |
|---|---|---|
| **EPIC-043** Performer | ❌ 0 commit, BE-15 | ✅ 重派: Performer-EPIC-043-v2 (用新流程) |
| **EPIC-044** Performer | ❌ 0 commit, BE-15 | ✅ 重派: Performer-EPIC-044-v2 (用新流程) |
| **EPIC-047** Auditor-Token | ❌ 0 commit, BE-15 | ✅ 重派: Auditor-Token-EPIC-047-v2 (用新流程) |

---

## 9. 跟"诚实修正" 模式 一致 (跟主公"是什么意思?" 拍一致)

跟"流程逻辑" 战略 一致, 跟"不要再犯了" 联合, 跟 BE-15 累计, 跟 5 战略建议 反讽 闭环:
- ✅ 新流程 落地 (跟对策 A+B+C 联合)
- ✅ 3 假 PASS 撤销重派 (跟对策 C 联合)
- ✅ 5 战略建议 5.2 改为 Rule 26 (跟"反讽" 闭环)
- ✅ 5 战略建议 5.3 改为 Rule 27 (跟"反讽" 闭环)
- ✅ 5 战略建议 5.1 撤销冗余 Rule (跟"飞轮反哺边际递减" 联合)

---

## 10. 总结 (跟"流程逻辑" + "诚实修正" 战略 一致)

**新流程 核心变化** (跟对策 A+B+C 联合):
- ✅ **事中**: Subagent 必跑 3 硬脚本 + 6 维度自验证 (跟对策 A 联合)
- ✅ **事中**: Conductor 必看 3 硬脚本输出 + 6 维度自验证 (跟对策 B 联合)
- ✅ **事后**: Master 强验证 0 维度 (流程监督 + 10% 抽查, 跟对策 C 联合)
- ✅ **撤销**: 3 假 PASS subagent 重派 (跟对策 C 联合)

**跟 5 战略建议 反讽 闭环** (跟"诚实修正" 联合):
- ✅ 5.2 改为 Rule 26 (跟"反讽" 闭环)
- ✅ 5.3 改为 Rule 27 (跟"反讽" 闭环)
- ✅ 5.1 撤销 8 冗余 Rule (跟"飞轮反哺边际递减" 联合)

**跟"流程逻辑 > 扩充配置" 战略 一致** (跟"不要再犯了" 联合):
- ✅ 撤销冗余 Rule (5.1) — 19 - 8 = 11 Rule
- ✅ 加新 Rule (26/27/28) — +3 Rule = 14 Rule 累计
- ✅ 流程改事中自动化 — 跟对策 A+B+C 联合

---

**生成时间**: 2026-06-13
**关联**: PHASE-008-REVIEW-2026-06-13.md + ACCUMULATED-LESSONS-2026-06-13.md + CLAUDE.md (Rule 1-25)
**commit 准备**: 跟 miao HEAD `703aa93` 一致, 跟"诚实修正" + "流程逻辑" 战略 一致
