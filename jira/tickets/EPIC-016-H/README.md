# EPIC-016-H: 重测 + 对比 baseline,输出 reduction 报告

## 需求

EPIC-016 优化全部 ticket（A-I 实施后）跑最终验证，对比 baseline 输出 reduction 报告。

## 接受标准 (AC)

详见 `ticket.json`。4 条 AC：
1. 跑 5 次 `benchmark-init.sh` 优化后版本，取中位数
2. wall_time 减少 ≥ 70%，tokens_est 减少 ≥ 70%
3. 输出 `.kallax/benchmarks/REPORT.md` 含：前后对比表 + 每层优化贡献 + 剩余未优化项清单
4. 未达 70% 时自动开 follow-up ticket

## 技术要点

- 用 `benchmark-init.sh --diff baseline-v0 optimized-final` 模式
- 取中位数而非平均值（避免单次抖动）
- REPORT.md 表格要可读：markdown 表格 + 节省百分比
- "剩余未优化项"是诚实清单：哪些还没动、为什么

## 测试计划

- [ ] 5 次 benchmark 取中位数
- [ ] REPORT.md 含 baseline vs optimized 表格
- [ ] 每层优化贡献拆分（Layer A/B/C）
- [ ] 若未达 70%，开 follow-up ticket 链接

## 依赖

- A, B, C, D, E (5 个 done) — 满足，可开始
- 用户跑 `/kallax 验证优化效果`

## 文件范围

- `.kallax/benchmarks/**` (read)
- `scripts/benchmark-init.sh` (existing, no change)
- `.kallax/benchmarks/REPORT.md` (new)

## 预估工时

1 小时（含 5 次 benchmark 运行）

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 04:45 UTC | backlog | master_main | 初始创建 |
| 2026-06-06 15:30 UTC | ready | master_main | 提升 P1 ready（依赖全满足）|
