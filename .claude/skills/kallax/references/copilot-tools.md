# Copilot 工具映射

## 概述
GitHub Copilot CLI 工具与 KALLAX 专家/技能的映射关系。

## 工具映射

| Copilot 命令 | KALLAX 专家 | KALLAX 技能 |
|--------------|-------------|-------------|
| `gh copilot suggest` | architect, backend, frontend | code-analysis |
| `gh copilot explain` | architect | - |
| Code completion | backend, frontend | tdd, refactoring |
| PR review | architect, backend | code-analysis |
| Test generation | backend, frontend | tdd |
| Documentation | - | technical-writing, api-docs |

## 使用场景

### 代码生成
- Copilot: 行内代码补全
- KALLAX: `/kallax-expert backend` 提供架构建议后再生成

### 代码解释
- Copilot: `gh copilot explain "code"`
- KALLAX: `/kallax-skill code-analysis` 深度分析

### 测试生成
- Copilot: 生成测试代码
- KALLAX: `/kallax-skill tdd` 测试驱动设计

## 协作模式

```
1. 需求理解 → KALLAX Expert Panel
2. 架构设计 → KALLAX Architect
3. 代码实现 → Copilot 补全
4. 代码审查 → KALLAX Code Analysis
5. 文档生成 → Copilot + KALLAX Tech Writing
```

## 最佳实践

- 架构决策使用 KALLAX 专家
- 日常编码使用 Copilot
- 代码审查两者结合
- 文档需求视复杂度选择
