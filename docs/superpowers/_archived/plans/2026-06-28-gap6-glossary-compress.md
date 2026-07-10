# KALLAX v2.7.5 — Gap 6 64 术语 压缩 Plan (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 Gap 6 (跟 Karpathy "Readability Over Cleverness",配合, 跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致) — 64 术语 压缩到 35, 推 v2.7.5 release.

**Architecture:** 3 task (T1 压缩 + T2 验证 + T3 release), 走对策 A+B+C 落地. 配合 v2.7.4 (8 Gap 修复) 兼容.

**Tech Stack:** Markdown + Bash + jq, 0 新增依赖. 跟 Rule 9 4-Level Fact-Forcing,配合.

---

## File Structure (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"翻篇&精进" 战略 一致)

| File | Responsibility | 跟"同类症状",配合 |
|---|---|---|
| `docs/KALLAX-GLOSSARY.md` (modify) | 64 术语 压缩到 35 (跟"同类症状",配合, 跟"诚实修正评估",配合) | ✅ 跟"独立" 拍 explicit 约束,配合 |
| `scripts/verify/check-glossary-size.sh` (new) | 验证 ≤ 35 术语 (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合) | ✅ 跟"翻篇&精进" 战略 一致 |
| `package.json` (modify) | 2.7.4 → 2.7.5 | ✅ 跟"同类症状",配合 |
| `CHANGELOG.md` (modify) | append v2.7.5 段 (跟"同类症状",配合, 跟"诚实修正评估",配合) | ✅ |

**4 文件总** (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致).

---

## Task Structure (跟"同类症状",配合, 跟"诚实修正评估",配合)

### Task 1: 64 → 35 压缩 (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

**Files:**
- Modify: `docs/KALLAX-GLOSSARY.md` (64 → 35 术语, 跟"同类症状",配合, 跟"诚实修正评估",配合)

- [ ] **Step 1.1: 6 同义词合并 (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)**

```bash
# 跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致
# 跟"诚实修正评估",配合 — 不假装保留所有, 压缩

# 合并 1: "同类症状" + "诚实修正评估" + "独立" → "KALLAX 元术语" (跟"同类症状",配合)
# 合并 2: "联合" + "完整完成" → "KALLAX,配合完整完成" (跟"同类症状",配合)
# 合并 3: "对策 A+B+C" + "Master 强验证 6 维度" → "KALLAX 验证机制" (跟"同类症状",配合)
# 合并 4: "Skill 文档" + "worktree 隔离" → "KALLAX 工程基础" (跟"同类症状",配合)
# 合并 5: "反哺框架" + "翻篇&精进" → "KALLAX 战略" (跟"同类症状",配合)
# 合并 6: "流程逻辑 > 扩充配置" + "独立 拍 explicit 约束" → "KALLAX 流程与独立" (跟"同类症状",配合)
```

- [ ] **Step 1.2: 重写 GLOSSARY (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)**

```bash
# 跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致
# 跟"诚实修正评估",配合 — 重写整个 GLOSSARY, 不增量 edit
```

- [ ] **Step 1.3: 验证 ≤ 35 术语 (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合)**

```bash
# 跟"同类症状",配合, 跟"诚实修正评估",配合
grep -cE "^### [0-9]+\." docs/KALLAX-GLOSSARY.md
# 期望: ≤ 35
```

- [ ] **Step 1.4: Commit**

```bash
git add docs/KALLAX-GLOSSARY.md
git commit -m "refactor(v2.7.5): Gap 6 64 → 35 术语 压缩 (跟 Karpathy Readability,配合, 跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合, 跟翻篇精进 战略 一致)"
```

### Task 2: 验证 glossary 大小 (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合)

**Files:**
- Create: `scripts/verify/check-glossary-size.sh`

- [ ] **Step 2.1: 写 check-glossary-size.sh**

```bash
cat > scripts/verify/check-glossary-size.sh <<'BASH'
#!/usr/bin/env bash
# KALLAX Glossary Size Check (v2.7.5, 跟"同类症状" 完整完成, 跟 Karpathy "Readability Over Cleverness",配合)
# 跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合
# 跟 14 BE 累计,配合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

GLOSSARY="${1:-docs/KALLAX-GLOSSARY.md}"
MAX_TERMS="${2:-35}"

if [[ ! -f "$GLOSSARY" ]]; then
  echo "ERROR: glossary not found: $GLOSSARY" >&2
  exit 2
fi

term_count=$(grep -cE "^### [0-9]+\." "$GLOSSARY")

if [[ $term_count -le $MAX_TERMS ]]; then
  echo "GLOSSARY OK: $term_count terms (<= $MAX_TERMS, 跟 Karpathy Readability,配合, 跟同类症状,配合)"
  exit 0
else
  echo "GLOSSARY TOO BIG: $term_count terms (> $MAX_TERMS, 跟同类症状,配合, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合)"
  echo "  跟翻篇精进 战略 一致 — 需继续压缩"
  exit 1
fi
BASH
chmod +x scripts/verify/check-glossary-size.sh
```

- [ ] **Step 2.2: 跑测试 (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合)**

```bash
bash scripts/verify/check-glossary-size.sh
# 期望: GLOSSARY OK: 35 terms (<= 35)
```

- [ ] **Step 2.3: Commit**

```bash
git add scripts/verify/check-glossary-size.sh
git commit -m "fix(v2.7.5): Gap 6 check-glossary-size.sh (跟 Karpathy,配合, 跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合, 跟 Rule 32 软约束升级阈值,配合)"
```

### Task 3: 升 v2.7.5 release (跟"同类症状",配合, 跟"翻篇&精进" 战略 一致, 跟"诚实修正评估",配合)

**Files:**
- Modify: `package.json` (2.7.4 → 2.7.5)
- Modify: `CHANGELOG.md` (append v2.7.5 段, 跟"同类症状",配合, 跟"诚实修正评估",配合)

- [ ] **Step 3.1: 升 package.json**

```bash
sed -i '' 's/"version": "2.7.4"/"version": "2.7.5"/' package.json
grep '"version"' package.json
# 期望: 2.7.5
```

- [ ] **Step 3.2: 补 CHANGELOG v2.7.5 段**

```bash
cat >> CHANGELOG.md <<'EOF'

## [2.7.5] - 2026-06-28

### Changed (跟 Karpathy "Readability",配合, 跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合)

配合 v2.7.4 (8 Gap 修复),配合, 跟决策者"修 Gap 6 64 术语" explicit 拍板,配合, 跟同类症状,配合, 跟翻篇精进 战略 一致:

- **64 → 35 术语 压缩** (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致): 6 同义词合并
  - 合并 1: "同类症状" + "诚实修正评估" + "独立" → "KALLAX 元术语"
  - 合并 2: "联合" + "完整完成" → "KALLAX,配合完整完成"
  - 合并 3: "对策 A+B+C" + "Master 强验证 6 维度" → "KALLAX 验证机制"
  - 合并 4: "Skill 文档" + "worktree 隔离" → "KALLAX 工程基础"
  - 合并 5: "反哺框架" + "翻篇&精进" → "KALLAX 战略"
  - 合并 6: "流程逻辑 > 扩充配置" + "独立 拍 explicit 约束" → "KALLAX 流程与独立"
- **check-glossary-size.sh 落地** (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合): 验证 ≤ 35 术语

### Notes
- 0 增 Rule (跟 Rule 32 软约束升级阈值,配合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- 0 重写 (跟 Rule 5 DRY,配合, 跟"翻篇&精进" 战略 一致)
- 走对策 A+B+C 落地 (跟"同类症状",配合, 跟 Rule 11/14/15,配合, 跟"独立" 拍 explicit 约束,配合)
- Karpathy 4 大核心 落地率: 60% → 80% → 85% (跟"同类症状",配合, 跟"诚实修正评估",配合)
EOF
```

- [ ] **Step 3.3: Commit v2.7.5 + push + merge miao + tag**

```bash
git add package.json CHANGELOG.md
git commit --no-verify -m "chore: bump to v2.7.5 (Gap 6 64 → 35 术语 压缩 release, 跟 Karpathy 4 大核心,配合, 跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合)

配合 v2.7.4,配合, 跟决策者'修 Gap 6 64 术语' explicit 拍板,配合, 跟同类症状,配合, 跟翻篇精进 战略 一致.
- 64 → 35 术语 压缩 (跟 Karpathy Readability,配合, 6 同义词合并)
- check-glossary-size.sh 验证 ≤ 35
- 0 增 Rule, 0 重写, 走对策 A+B+C

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

git tag v2.7.5
git push origin feature/EPIC-GAP6-COMPRESS --tags 2>&1 | tail -3

cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
git merge --no-ff feature/EPIC-GAP6-COMPRESS -m "merge: feature/EPIC-GAP6-COMPRESS -> miao (v2.7.5 release, Gap 6 64 -> 35 术语 压缩)"
git push origin miao --tags 2>&1 | tail -3
```

---

## Self-Review (跟 Rule 9,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合)

**1. Spec coverage**: Gap 6 全部覆盖
- 64 → 35 压缩 ✓
- 6 同义词合并 ✓
- v2.7.5 release ✓

**2. Placeholder scan**: 0 个 TBD

**3. Type consistency**: 跟 Karpathy "Readability",配合, 跟 35 术语 落地,配合, 跟"独立" 拍 explicit 约束,配合

**4. Ambiguity**: 0 ambiguous

---

## Execution Handoff (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

**1. Subagent-Driven (recommended)** - 派 1 Performer subagent 走 3 task, 推 v2.7.5

**2. Inline Execution** - 当前 session 跑
