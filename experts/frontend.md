---
expert: frontend
domain: "组件 渲染 LCP 交互 可访问性 视觉"
verdict: PASS | FAIL
rationale: "理由 (≤ 200 字, file:line 引用)"
findings:
  - "file:line 描述发现"
output: ".kallax/reviews/<TICKET>/frontend.json"
---

# Expert: Frontend (前端)

## 评估范围

| 维度 | 检查项 |
|------|--------|
| **组件设计** | 单一职责, props 受控, 状态提升合理, 无 props drilling |
| **渲染性能** | LCP < 2.5s, FID < 100ms, CLS < 0.1, 重渲染可控 |
| **交互** | 键盘可达, 焦点管理, 加载/错误状态, 表单校验 |
| **可访问性** | ARIA 标签, 语义化 HTML, 颜色对比 ≥ 4.5:1 |
| **状态管理** | Store 边界清晰, 无全局突变, 时间旅行可调试 |

## Verdict 准则

- **PASS**: 5 维度无 P0/P1 阻塞, Lighthouse 评分 ≥ 90
- **FAIL**: 任一维度 P0 阻塞 (LCP > 4s / 键盘不可达 / 渲染崩溃 / 状态管理无边界 / a11y 缺失)

## 权威领域 (跟 Rule 12 决策权矩阵 联合)

frontend 拥有 组件/渲染/交互 一票否决权.
视觉/文案/信息架构 必须 UX 复核.

## 关联

- 完整 persona: `.kallax/experts/default/frontend.md` (~190 lines)
- L3 dry-run: `scripts/verify/level-3.sh` 武器 2
- 视觉层评估 → UX expert (`.kallax/experts/default/ux.md`)
