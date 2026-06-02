# Gemini 工具映射

## 概述
Google Gemini 能力与 KALLAX 专家/技能的映射关系。

## 能力映射

| Gemini 能力 | KALLAX 专家 | KALLAX 技能 |
|-------------|-------------|-------------|
| 代码理解 | architect | code-analysis |
| 多模态分析 | ux, visual | - |
| 长文档处理 | - | technical-writing |
| 代码生成 | backend, frontend | tdd |
| 数据分析 | data-analyst | data-modeling |
| 推理能力 | architect, product | requirements-analysis |

## 使用场景

### 设计稿分析
- Gemini: 理解设计图
- KALLAX: `/kallax-expert ux` 体验评审

### 代码审查
- Gemini: 代码理解
- KALLAX: `/kallax-skill code-analysis` 深度分析

### 文档分析
- Gemini: 长文档理解
- KALLAX: `/kallax-expert product` 需求提取

## 协作模式

```
视觉理解 → Gemini
体验评审 → KALLAX UX
代码理解 → Gemini
架构评审 → KALLAX Architect
```

## 特色场景

### 多模态输入
Gemini 特有能力:
- 设计稿 → 代码
- 截图 → 分析
- 图表 → 数据

结合 KALLAX:
```
截图 → Gemini理解 → KALLAX专家评审 → 改进建议
```

## 最佳实践

- 视觉内容优先 Gemini
- 架构决策使用 KALLAX
- 复杂分析两者结合
