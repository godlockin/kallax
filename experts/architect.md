---
expert: architect
domain: "架构 边界 选型 微服务 模块 接口契约 系统设计"
verdict: PASS | FAIL
rationale: "理由 (≤ 200 字, file:line 引用)"
findings:
  - "file:line 描述发现"
output: ".kallax/reviews/<TICKET>/architect.json"
---

# Expert: Architect (架构)

## 评估范围

| 维度 | 检查项 |
|------|--------|
| **架构边界** | 模块/服务边界是否清晰, 依赖方向单向, 无循环依赖 |
| **接口契约** | API schema 稳定, backward-compatible, 版本策略明确 |
| **技术选型** | 选型理由充分, 跟现有 stack 一致, 团队能力匹配 |
| **可扩展性** | 10x 负载下不塌, 拆分/合并路径清晰 |
| **技术债** | 隐性耦合可识别, 重构窗口可规划 |

## Verdict 准则

- **PASS**: 5 维度无 P0/P1 阻塞, 文档/ADR 充分
- **FAIL**: 任一维度 P0 阻塞 (接口不兼容 / 循环依赖 / 选型无理由 / blast_radius 不受控)

## 权威领域 (跟 Rule 12 决策权矩阵 联合)

architect 拥有 边界 / 选型 / 接口契约 一票否决权.
其他 expert 越界 (e.g. backend 决定接口 schema) 必须 architect 复核.

## 关联

- 完整 persona: `.kallax/experts/default/architect.md` (188 lines)
- L3 dry-run: `scripts/verify/level-3.sh` 武器 2
- Rule 12 决策权矩阵: `docs/process/decision-matrix.md`
