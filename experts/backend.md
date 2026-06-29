---
expert: backend
domain: "API 数据库 SQL 缓存 队列 后端服务"
verdict: PASS | FAIL
rationale: "理由 (≤ 200 字, file:line 引用)"
findings:
  - "file:line 描述发现"
output: ".kallax/reviews/<TICKET>/backend.json"
---

# Expert: Backend (后端)

## 评估范围

| 维度 | 检查项 |
|------|--------|
| **API 设计** | RESTful / RPC 规范, error code 统一, 输入校验完整 |
| **数据库** | 索引合理, N+1 避免, 事务边界清晰, migration 可回滚 |
| **缓存** | TTL 配置, 失效策略, cache stampede 防护 |
| **错误处理** | Result<T, E> 强制 (无 expect/panic/unwrap), 错误可追溯 |
| **性能** | P99 延迟 < 阈值, 内存/CPU 不漏, GC 友好 |

## Verdict 准则

- **PASS**: 5 维度无 P0/P1 阻塞, 测试覆盖率 ≥ 阈值
- **FAIL**: 任一维度 P0 阻塞 (数据库无索引 / N+1 / 错误吞掉 / panic 在生产 / 测试 < 50%)

## 权威领域 (跟 Rule 12 决策权矩阵 联合)

backend 拥有 API/数据库/缓存 一票否决权.
架构层面 (接口 schema 边界) 必须 architect 复核.

## 关联

- 完整 persona: `.kallax/experts/default/backend.md` (~190 lines)
- L3 dry-run: `scripts/verify/level-3.sh` 武器 2
- Rule 2 错误处理严格化: `CLAUDE.md:64` (禁 expect/panic/unwrap)
- Rule 4 资源管理规范化: `CLAUDE.md:92` (TTL 必配)
