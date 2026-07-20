---
description: Guided research on an existing project — detect tech-stack → 4 guided questions → dispatch roles → alignment report (borrows eket analyze-existing.sh pattern, EPIC-135-A)
argument-hint: "[project-path]"
---

# /kallax-research

用法: `/kallax-research [project-path]`

例:
- `/kallax-research` (默认 `.`)
- `/kallax-research ~/work/myproject`
- `/kallax-research https://github.com/xai-org/grok-build`

详细: `docs/superpowers/specs/2026-07-20-kallax-research-design.md`(EPIC-135-A)
主底: `/Users/chenchen/working/sourcecode/tools/dev-tools/eket/scripts/analyze-existing.sh`(借方法论不借代码,跟 CLAUDE.md "借方法论 不借代码" 联合)

## 🎯 你的目标

帮主公**深入理解**一个既存项目,产出可借鉴报告。借 eket `analyze-existing.sh` 的引导式流程:
**detect tech-stack → 4 guided questions → 角色 dispatch → 综合 alignment 报告**

## 🛑 重要原则

- **不修改任何文件** — 只读研究
- **不执行 build / test / install** — 太慢 + 污染上下文
- **不 clone / 拉代码** — 主公已给路径
- **每个专家独立** — 不串行
- **结果用结构化输出** — 表格 + 列表,不堆段落
- **报告 < 500 行** — 详尽但精炼

## 📍 5 阶段执行

### Step 1: 自动探测 tech-stack (确定性, 0 LLM)

直接调用 `.sh` 脚本:

```bash
bash .claude/commands/kallax-research.sh detect [project-path]
```

输出格式:
```
Tech Stack 探测结果:
  ✓ Node.js / TypeScript   (package.json, 247 packages)
  ✓ Rust                   (Cargo.toml)
  ✓ Python                 (pyproject.toml)
  ✓ Shell                  (*.sh: 35 files)
  ✓ Docs                   (*.md: 142 files)
  - Go / Java / 其他        (未发现)
Git:  3,247 commits / 8 branches / 12 contributors
Last: 2 hours ago
```

### Step 2: 4 个引导问题 (AskUserQuestion tool)

**关键**:用 `AskUserQuestion` 工具(不是 prose),让主公选:

| Q | 标题 | 选项 |
|---|------|------|
| **Q1** | 研究目的 | architecture / code-quality / security / performance / product / overview(默认) |
| **Q2** | 深度 | quick(快速概览) / detailed(详细分析,默认) / deep-audit(深度审计) |
| **Q3** | 关注点(多选) | tech-stack / code-quality / test-coverage / docs / ci-cd / 性能 / 安全(默认无) |
| **Q4** | 角色(多选) | architect / developer / auditor / product / researcher / security / performance / UX(默认按 Q1 自动推荐) |

**多对多映射** (Q1 → 默认 Q4 角色):

| Q1 研究目的 | 默认角色 (Q4) |
|------------|------------|
| architecture | architect + developer + researcher |
| code-quality | developer + auditor + researcher |
| security | developer + auditor + security |
| performance | developer + architect + performance |
| product | product + researcher + architect |
| overview | architect + developer + product |
| deep-audit | 全部 5-7 角色 |

### Step 3: 生成 dispatch 包 (确定性, 0 LLM)

```bash
bash .claude/commands/kallax-research.sh dispatch \
  [project-path] \
  --purpose=architecture \
  --depth=detailed \
  --focus=tech-stack,ci-cd \
  --roles=architect,developer,auditor
```

**输出目录**:`confluence/decisions/research-<date>/`
```
confluence/decisions/research-2026-07-20/
├── DISPATCH.md              # 主入口:综合报告路径 + 角色清单
├── .prompt-architect.md     # 角色 prompt 模板(注入 tech_stack + git_log + dir_tree)
├── .prompt-developer.md
├── .prompt-auditor.md
├── architect-REPORT.md      # 报告占位(LLM 在 Step 4 填充)
├── developer-REPORT.md
├── auditor-REPORT.md
└── alignment.md             # 综合(Step 5 填充)
```

### Step 4: LLM 模拟 N 角色视角 (核心价值)

跟 eket 不同 — **不真 spawn subagent**(避免并发开销 + sandbox 边界)。直接扮演:

| 角色 | 视角 | 输出限制 |
|------|------|---------|
| 🏗️ architect | 架构 + 边界 + 选型 | < 300 行 |
| 💻 developer | 代码 + 错误 + 性能 + 测试 | < 300 行 |
| 🔍 auditor | 异味 + 风险 + 合规 | < 200 行 |
| 📋 product | 用户 + 价值 + 文档 | < 200 行 |
| 📚 researcher | 文档 + 社区 + 引用 | < 200 行 |
| 🛡️ security | 漏洞 + 攻击面 + 供应链 | < 300 行 |
| ⚡ performance | 性能 + 缓存 + 并发 | < 300 行 |

**每个角色**:独立 Read 目标项目 5-10 文件 → 输出 `<role>-REPORT.md`

**关键**:并行 = 一次性 Read/Glob/Grep 多个文件,不要串行。

### Step 5: 综合 alignment.md

汇总 N 角色报告,出:

```markdown
# 📊 Project Research Report

> 项目: <path>
> 研究时间: <date>
> 专家组: <roles>

## 🎯 执行摘要
3 段:现状 / 主要风险 / 关键建议

## ✅ 跨角色共识
(多角色都提到的问题)

## ⚠️ 跨角色冲突
(角色建议矛盾,需权衡)

## 🚀 Top 10 行动项
按优先级

## 💡 可借鉴点 (跟 EKET 借方法论 联合)
每条:
- 来源(哪个角色报告)
- 适配方案(KALLAX 落地)
- 实现状态(待评估 / 建卡 / 已完成)
```

## ⚠️ 不要做的

- ❌ 不要执行 long-running 命令
- ❌ 不要 npm install / build / test
- ❌ 不要修改任何文件
- ❌ 不要并行 spawn 真正的子 agent (本流程通过角色扮演模拟)
- ❌ 不要超过 500 行输出

## 🛠️ 工具使用

| 工具 | 何时用 | 限制 |
|------|--------|------|
| `Read` | 主源码 / 配置 / 文档 | 限单文件 < 500 行 |
| `Glob` | 找文件 | 限深度 < 5 |
| `Grep` | 搜模式 | 限输出 < 100 行 |
| `Bash`(限) | `wc -l`, `head -50`, `ls -la` | 不要 `cat` 大文件 |
| `WebFetch` | GitHub / 文档站 | 不要 `curl` |
| `AskUserQuestion` | Step 2 引导主公 | 必用,不 prose |

## 🎬 工作流示例

```
用户: /kallax-research https://github.com/xai-org/grok-build

[Step 1: bash kallax-research.sh detect]
大模型: "Tech Stack 探测:Python + TypeScript + Rust + 8 docs"

[Step 2: AskUserQuestion 4 问]
Q1 目的 → architecture
Q2 深度 → detailed
Q3 关注 → ci-cd, 性能
Q4 角色 → architect + developer + performance + auditor

[Step 3: bash kallax-research.sh dispatch]
大模型: "✓ DISPATCH.md 已生成 confluence/decisions/research-2026-07-20/"

[Step 4: LLM 模拟 4 视角]
大模型: "正在分析... (并行 Read 8 个文件)"
[4 个 REPORT.md 填充完毕]

[Step 5: alignment.md]
大模型: "📊 Report: 12 共识 / 3 冲突 / 10 行动项"
```

---

**主文档**:`kallax/.claude/commands/kallax/research.md`
**配套脚本**:`kallax/.claude/commands/kallax-research.sh`
**借鉴源**:`eket/scripts/analyze-existing.sh` (借方法论 不借代码)
**联动**:
- EPIC-135-A (本 ticket, 引导式既存项目研究)
- 跟 `/kallax-onramp` (L0 入门) 联合,本命令是 L1 深入
- 跟 `/kallax-takeover` (接手存量项目) 联合,本命令是新建项目参考