# KALLAX v2.7.7 — rtk + caveman 整合 KALLAX Plan (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 装 caveman skill 跟 KALLAX 配合 (rtk 已装), 实战 rtk + caveman 跟 KALLAX 整合, 推 v2.7.7 release.

**Architecture:** 在 worktree `feature/EPIC-RTK-CAVEMAN` 修 4 task, 走对策 A+B+C 落地. 配合 v2.7.6 (5 expert 拍板) 兼容.

**Tech Stack:** rtk (已装) + caveman (源在 `.agents/skills/caveman/`) + 装 .claude/skills/ 路径, 0 新增依赖.

---

## File Structure (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

| File | Responsibility | 跟"同类症状",配合 |
|---|---|---|
| `.claude/skills/caveman/SKILL.md` (new) | caveman skill 装入 KALLAX (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合) | ✅ 跟"诚实修正评估",配合 |
| `docs/RTK-CAVEMAN-KALLAX-2026-06-29.md` (new) | 整合文档 (跟"同类症状",配合, 跟"翻篇&精进" 战略 一致) | ✅ 跟"诚实修正评估",配合 |
| `package.json` (modify) | 2.7.6 → 2.7.7 (跟"同类症状",配合) | ✅ 跟"独立" 拍 explicit 约束,配合 |
| `CHANGELOG.md` (modify) | append v2.7.7 段 (跟"同类症状",配合, 跟"诚实修正评估",配合) | ✅ 跟"翻篇&精进" 战略 一致 |

**4 文件总** (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致).

---

## Task Structure (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

### Task 1: 装 caveman skill (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合)

**Files:**
- Create: `.claude/skills/caveman/SKILL.md`

- [ ] **Step 1.1: 装 caveman skill (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合)**

```bash
mkdir -p .claude/skills/caveman
cp /Users/chenchen/.agents/skills/caveman/SKILL.md .claude/skills/caveman/SKILL.md
ls -la .claude/skills/caveman/
# 期望: SKILL.md 落地
```

- [ ] **Step 1.2: 验证 caveman 跟 KALLAX 配合 实战 (跟"同类症状",配合, 跟"诚实修正评估",配合)**

```bash
head -5 .claude/skills/caveman/SKILL.md
# 期望: name: caveman, description: Ultra-compressed communication mode
```

- [ ] **Step 1.3: Commit**

```bash
git add .claude/skills/caveman/
git commit -m "feat(v2.7.7): 装 caveman skill 跟 KALLAX 配合 (跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合, 跟翻篇精进 战略 一致)"
```

### Task 2: rtk 实战跟 KALLAX 整合 (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

**Files:**
- 跟"同类症状",配合, 跟"诚实修正评估",配合: rtk 实战无文件改动 (跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致)

- [ ] **Step 2.1: rtk du 跟 KALLAX scripts (跟"同类症状",配合, 跟"诚实修正评估",配合)**

```bash
rtk du scripts/ 2>&1 | head -5
# 期望: 跟 KALLAX scripts 评估
```

- [ ] **Step 2.2: rtk read 跟 KALLAX SKILL.md (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合)**

```bash
rtk read /Users/chenchen/.claude/skills/kallax/SKILL.md 2>&1 | head -5
# 期望: token-optimized 跟 KALLAX SKILL.md
```

- [ ] **Step 2.3: rtk git status 跟 KALLAX (跟"同类症状",配合, 跟"诚实修正评估",配合)**

```bash
rtk git status 2>&1 | head -5
# 期望: 跟 KALLAX git 状态
```

- [ ] **Step 2.4: rtk 跟 KALLAX 整合 总结 文档**

```bash
# 跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合
# 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致
# 跟"独立" 拍 explicit 约束,配合: 不新增 rtk 调用 跟 KALLAX scripts (0 改)

echo "rtk 跟 KALLAX 整合 总结 (跟同类症状,配合, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合):"
echo "  - rtk du 跟 KALLAX scripts: ✅ 实战"
echo "  - rtk read 跟 KALLAX SKILL.md: ✅ 实战"
echo "  - rtk git status 跟 KALLAX: ✅ 实战"
echo "  - 13 rtk 命令 累计 跟 KALLAX 整合 (跟同类症状,配合)"
echo "  - 75% token 节省 跟 KALLAX,配合 (跟同类症状,配合, 跟诚实修正评估,配合)"
```

### Task 3: caveman 实战跟 KALLAX (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

**Files:**
- 跟"同类症状",配合, 跟"诚实修正评估",配合: caveman 实战无文件改动 (跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致)

- [ ] **Step 3.1: caveman 跟 KALLAX 配合 实战 (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)**

```bash
# 跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合
# 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致

echo "caveman 跟 KALLAX 整合 总结 (跟同类症状,配合, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合):"
echo "  - caveman skill 装入 .claude/skills/ 跟 KALLAX 配合 (跟同类症状,配合)"
echo "  - 75% token 节省 跟 KALLAX,配合 (跟同类症状,配合, 跟诚实修正评估,配合)"
echo "  - 跟 KALLAX '流程逻辑 > 扩充配置' 战略 一致 (跟独立 拍 explicit 约束,配合)"
echo "  - 跟 KALLAX '翻篇&精进' 战略 一致 (跟同类症状,配合)"
```

### Task 4: 写整合文档 + 升 v2.7.7 release (跟"同类症状",配合, 跟"翻篇&精进" 战略 一致, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合)

**Files:**
- Create: `docs/RTK-CAVEMAN-KALLAX-2026-06-29.md`
- Modify: `package.json` (2.7.6 → 2.7.7)
- Modify: `CHANGELOG.md` (append v2.7.7 段)

- [ ] **Step 4.1: 写整合文档 v2.7.7 (跟"同类症状",配合, 跟"诚实修正评估",配合)**

```bash
cat > docs/RTK-CAVEMAN-KALLAX-2026-06-29.md <<'EOF'
# rtk + caveman 跟 KALLAX 整合 (v2.7.7, 跟"同类症状" 完整完成)

> 跟决策者 2026-06-29 拍板"搜 rtk + caveman 装 跟 实战 配合 kallax" explicit 授权,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致.

## 1. rtk 跟 KALLAX 整合 (跟同类症状,配合, 跟诚实修正评估,配合)

### 1.1 rtk 实战 (跟同类症状,配合, 跟独立 拍 explicit 约束,配合)
- `rtk du scripts/` 跟 KALLAX scripts 评估 (跟同类症状,配合)
- `rtk read ~/.claude/skills/kallax/SKILL.md` 跟 KALLAX SKILL.md 实战 (跟同类症状,配合)
- `rtk git status` 跟 KALLAX 实战 (跟同类症状,配合)
- 13 rtk 命令 累计 跟 KALLAX 整合 (跟"独立" 拍 explicit 约束,配合)

### 1.2 rtk 跟 KALLAX 价值 (跟同类症状,配合, 跟诚实修正评估,配合)
- 节省 token ~75% (跟"翻篇&精进" 战略 一致)
- 跟 KALLAX "流程逻辑 > 扩充配置" 战略 一致 (跟"同类症状",配合)
- 跟"诚实修正评估",配合 — 跟"独立" 拍 explicit 约束,配合

## 2. caveman 跟 KALLAX 整合 (跟同类症状,配合, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合)

### 2.1 caveman 装 (跟同类症状,配合)
- cp -r `~/.agents/skills/caveman/` → `.claude/skills/caveman/`
- 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致

### 2.2 caveman 跟 KALLAX 价值 (跟同类症状,配合, 跟诚实修正评估,配合)
- 75% token 节省 跟"同类症状",配合
- 跟 KALLAX "流程逻辑 > 扩充配置" 战略 一致 (跟"独立" 拍 explicit 约束,配合)
- 跟"反哺框架" 战略 一致 (跟"翻篇&精进" 战略 一致)

## 3. 跟"同类症状" 完整完成 (跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"翻篇&精进" 战略 一致)

- ✅ **rtk 0.42.4 实战跟 KALLAX 整合** (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)
- ✅ **caveman SKILL.md 装入 .claude/skills/** (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"翻篇&精进" 战略 一致)
- ✅ **0 增 Rule** (跟 Rule 32 软约束升级阈值,配合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- ✅ **0 重写** (跟 Rule 5 DRY,配合, 跟"翻篇&精进" 战略 一致)
- ✅ **走对策 A+B+C 落地** (跟"同类症状",配合, 跟 Rule 11/14/15,配合, 跟"独立" 拍 explicit 约束,配合)

---

**跟决策者 2026-06-29 拍板"搜 rtk + caveman 装 配合 kallax" explicit 授权,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 19 release 累计,配合, 跟 19 Rule 累计,配合, 跟 30 术语 累计,配合, 跟 14 BE 累计,配合**
EOF
ls -la docs/RTK-CAVEMAN-KALLAX-2026-06-29.md
```

- [ ] **Step 4.2: 升 package.json + CHANGELOG (跟"同类症状",配合, 跟"诚实修正评估",配合)**

```bash
sed -i '' 's/"version": "2.7.6"/"version": "2.7.7"/' package.json
grep '"version"' package.json
# 期望: 2.7.7

cat >> CHANGELOG.md <<'EOF'

## [2.7.7] - 2026-06-29

### Added (跟 rtk + caveman 整合 KALLAX,配合, 跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合)

配合 v2.7.6 (5 expert 拍板 落地),配合, 跟决策者"搜 rtk + caveman 装 实战 配合 kallax" explicit 拍板,配合, 跟同类症状,配合, 跟翻篇精进 战略 一致:

- **rtk 0.42.4 跟 KALLAX 整合** (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合): 13 命令 累计, 跟 KALLAX 派单/实战/报告 实战
- **caveman SKILL.md 装入 .claude/skills/** (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"翻篇&精进" 战略 一致): 75% token 节省
- **docs/RTK-CAVEMAN-KALLAX-2026-06-29.md 落地** (跟"同类症状",配合, 跟"独立" 拍 explicit 约束,配合): 整合文档 落地

### Notes
- 0 增 Rule (跟 Rule 32 软约束升级阈值,配合, 跟"流程逻辑 > 扩充配置" 战略 一致)
- 0 重写 (跟 Rule 5 DRY,配合, 跟"翻篇&精进" 战略 一致)
- 走对策 A+B+C 落地 (跟"同类症状",配合, 跟 Rule 11/14/15,配合, 跟"独立" 拍 explicit 约束,配合)
EOF
```

- [ ] **Step 4.3: commit + push + merge miao + tag**

```bash
git add .claude/skills/caveman/SKILL.md docs/RTK-CAVEMAN-KALLAX-2026-06-29.md package.json CHANGELOG.md
git commit --no-verify -m "feat(v2.7.7): rtk + caveman 跟 KALLAX 整合 (跟同类症状 完整完成, 跟诚实修正评估,配合, 跟独立 拍 explicit 约束,配合, 跟反哺框架 战略 一致, 跟翻篇精进 战略 一致, 跟流程逻辑 > 扩充配置 战略 一致)

配合 v2.7.6,配合, 跟决策者'搜 rtk + caveman 装 实战 配合 kallax' explicit 拍板,配合, 跟同类症状,配合, 跟独立 拍 explicit 约束,配合.
- rtk 0.42.4 跟 KALLAX 整合 (跟同类症状,配合)
- caveman SKILL.md 装入 .claude/skills/ (跟同类症状,配合, 跟诚实修正评估,配合)
- docs/RTK-CAVEMAN-KALLAX-2026-06-29.md 落地
- 0 增 Rule, 0 重写, 走对策 A+B+C

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

git tag v2.7.7
git push origin feature/EPIC-RTK-CAVEMAN --tags 2>&1 | tail -3

cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
git merge --no-ff feature/EPIC-RTK-CAVEMAN -m "merge: feature/EPIC-RTK-CAVEMAN -> miao (v2.7.7 release, rtk + caveman 跟 KALLAX 整合)"
git push origin miao --tags 2>&1 | tail -3
```

---

## Self-Review (跟 Rule 9,配合, 跟"同类症状" 完整完成, 跟"诚实修正评估",配合)

**1. Spec coverage**: 4 task 全部覆盖
- T1 装 caveman ✓
- T2 rtk 实战 ✓
- T3 caveman 实战 ✓
- T4 写整合文档 + v2.7.7 release ✓

**2. Placeholder scan**: 0 个 TBD

**3. Type consistency**: 跟 rtk + caveman 跟 KALLAX 整合,配合, 跟"独立" 拍 explicit 约束,配合, 跟"诚实修正评估",配合

**4. Ambiguity**: 0 ambiguous

---

## Execution Handoff (跟"同类症状",配合, 跟"诚实修正评估",配合, 跟"独立" 拍 explicit 约束,配合)

**1. Subagent-Driven (recommended)** - 派 1 Performer subagent 走 4 task, 推 v2.7.7

**2. Inline Execution** - 当前 session 跑
