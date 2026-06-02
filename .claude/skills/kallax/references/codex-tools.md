# Codex 工具映射

## 概述
OpenAI Codex 能力与 KALLAX 专家/技能的映射关系。

## 能力映射

| Codex 能力 | KALLAX 专家 | KALLAX 技能 |
|------------|-------------|-------------|
| 代码生成 | backend, frontend | tdd |
| 代码翻译 | backend | refactoring |
| 代码解释 | architect | code-analysis |
| 代码调试 | backend, frontend | - |
| 文档生成 | - | technical-writing |
| SQL生成 | database | data-modeling |

## 使用场景

### 复杂代码生成
- Codex: 基于描述生成代码
- KALLAX: 先 `/kallax-expert architect` 设计，再生成

### 代码重构
- Codex: 语法转换
- KALLAX: `/kallax-skill refactoring` 结构重构

### 数据库操作
- Codex: SQL 生成
- KALLAX: `/kallax-expert database` 优化建议

## 协作模式

```
高层设计 → KALLAX
代码实现 → Codex
代码优化 → KALLAX + Codex
文档补充 → Codex
```

## 注意事项

- Codex 擅长语法层面
- KALLAX 擅长设计层面
- 复杂任务建议先 KALLAX 再 Codex
