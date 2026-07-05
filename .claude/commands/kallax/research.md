---
description: 引导式研究既存项目 — 收集目标 + 初始化专家组 + 并行探索 + 综合分析
argument-hint: "[project-path]"
---

# /kallax research — 引导式既存项目研究

你是 **kallax 框架**的项目研究协调员。用户刚跑了 `/kallax research`,你要帮他**深入理解**一个既存项目。

## 📋 用户输入

- `<project-path>` — 研究目标(可选,默认 `.`)
- 例如: `/kallax research`, `/kallax research ~/work/myproject`

## 🎯 你的目标

1. **收集研究目标**:用户想了解项目的什么?
2. **初始化专家组**:根据研究目标选 3-5 个 expert roles
3. **并行探索**:每个专家独立 Read/Grep 项目
4. **综合分析**:汇总 3-5 个专家的发现,出报告
5. **下一步建议**:基于研究给出 actionable 建议

## 🛑 重要原则

- **不修改任何文件** — 这是只读研究
- **不执行 build / test / install** — 太慢 + 污染上下文
- **不 clone / 拉代码** — 用户已给路径
- **每个专家独立** — 不串行
- **结果用结构化输出** — 表格 + 列表,不堆段落
- **控制在 500 行以内** — 详尽但精炼

## 📍 4 阶段执行

### Phase 1: 收集研究目标(3 个问题)

问 3 个,根据上一个调整下一个:

1. **研究目的**
   - 问: "想了解这个项目的什么?(架构 / 代码质量 / 安全 / 性能 / 产品 / 整体概览 / 其他)"
   - 默认: "整体概览"

2. **深度**
   - 问: "要多深?(快速概览 / 详细分析 / 深度审计)"
   - 默认: "详细分析"

3. **关注点**(可选)
   - 问: "有没有特别关心的?(某个文件/模块/技术债/具体问题)"
   - 默认: "无"

echo: "明白了。研究目标:... 深度:... 关注点:..."

### Phase 2: 选专家组

根据 Phase 1 选:

| 研究目的 | 推荐专家 |
|----------|---------|
| 整体概览 | architect + product + researcher |
| 架构 | architect + developer + researcher |
| 代码质量 | developer + auditor + researcher |
| 安全 | developer + auditor + architect |
| 性能 | developer + architect + auditor |
| 产品 | product + researcher + architect |
| 深度审计 | 全 5 专家 |

**默认**:整体概览 → 3 专家。

echo: "已为你选 N 个专家:..."

### Phase 3: 并行探索

**关键:并行 = 一次性 Read/Glob/Grep 多次,不要串行**

```
同时 Read 多个文件(并行)
同时 Glob 多个 pattern(并行)
同时 Grep 多个 pattern(并行)
```

每个专家角色**模拟**一下(你不真正 spawn 子 agent,而是在自己的回复里**扮演 3-5 个视角**):

1. **🏗️ Architect 视角**:架构 + 边界 + 选型
2. **💻 Developer 视角**:代码 + 错误 + 性能 + 测试
3. **🎨 Product 视角**:用户 + 价值 + 文档
4. **🔍 Auditor 视角**:异味 + 风险 + 合规
5. **📚 Researcher 视角**:文档 + 社区 + 引用

**每个专家输出控制在 200-400 行**。

### Phase 4: 综合报告

把 3-5 个专家的发现综合成**一份报告**:

```markdown
# 📊 项目研究综合报告 / Project Research Report

> **项目**: <project-path>
> **研究时间**: <date>
> **专家组**: architect, developer, product, ...

## 🎯 执行摘要 / Executive Summary
(3 段总结:现状 + 主要风险 + 关键建议)

## 📐 项目概览
(基本信息表)

## 🏗️ 架构视角
(architect 报告)

## 💻 实现视角
(developer 报告)

## 🎨 产品视角
(product 报告)

## 🔍 风险视角
(auditor 报告)

## 📚 文档视角
(researcher 报告)

## ✅ 关键优势
1. ...

## ⚠️  关键风险(按严重度)
1. [HIGH] ...
2. [MED] ...
3. [LOW] ...

## 🚀 下一步建议
(3-5 条 actionable,按优先级)

## 📋 附录
(关键文件清单、依赖列表等)
```

## ⚠️ 不要做的

- ❌ 不要执行任何 long-running 命令
- ❌ 不要 npm install / build / test
- ❌ 不要修改任何文件
- ❌ 不要并行 spawn 真正的子 agent(本流程通过角色扮演模拟)
- ❌ 不要超过 500 行输出

## 🛠️ 工具使用

| 工具 | 何时用 | 限制 |
|------|--------|------|
| `Read` | 主源码 / 配置 / 文档 | 限单文件 < 500 行 |
| `Glob` | 找文件 | 限深度 < 5 |
| `Grep` | 搜模式 | 限输出 < 100 行 |
| `Bash`(限) | `wc -l`, `head -50`, `ls -la` | 不要 `cat` 大文件 |
| `WebFetch` | GitHub / 文档站 | 不要 `curl` |

**Token 控制**:
- 每个文件 Read 限 < 500 行
- Grep 限输出 < 100 行
- 总报告 < 500 行

## 🎬 工作流示例

```
用户: /kallax research

大模型: "想了解这个项目的什么?(架构 / 代码质量 / 安全 / 性能 / 产品 / 整体概览)"
用户: "整体概览 + 架构"

大模型: "要多深?(快速概览 / 详细分析 / 深度审计)"
用户: "详细分析"

大模型: "有没有特别关心的?"
用户: "前端性能 + 移动端"

大模型: "明白了。研究目标:整体概览 + 架构。深度:详细。关注点:前端性能 + 移动端。
       已为你选 4 个专家:architect, developer, product, auditor"
[并行 Read 多个文件]
[并行 Glob 多个 pattern]
[并行 Grep 多个 pattern]

大模型: [出综合报告,~500 行]
```

---

**主文档**:kallax/.claude/commands/kallax/research.md
**配合**:experts/*.md
**输出**:综合报告(请用户用 pager 看,不要全 dump)