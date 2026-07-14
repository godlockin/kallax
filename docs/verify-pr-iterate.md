# verify-pr-iterate — Evaluator-Optimizer Loop (EPIC-117-D)

> Anthropic《Building Effective Agents》Evaluator-Optimizer:
> generate → evaluate → refine, 循环直到 findings=0 或 max rounds.

## 用法

```bash
scripts/verify-pr-iterate.sh <PR#> [--max-rounds 3] [--interval 60]
```

## 流程

1. Fetch PR head SHA
2. 本地跑 eslint + tsc (best-effort)
3. Findings=0 → converged, exit 0
4. Findings>0 → 发 comment 到 PR (含 tail 20 行日志)
5. 轮询 PR head 直到出现新 commit
6. 回到 step 2, 最多 max-rounds

## 为什么

之前 `/kallax-verify-pr` 是单次判决 pass/fail 阻塞。Anthropic Evaluator-Optimizer 模式适合本场景:
- 有清晰评估标准 (eslint / tsc 返回码)
- 反馈能显著提升输出 (findings → 定向修改)
- LLM 能产出可比反馈 (报告 tail)

## Exit codes

| Code | 含义 |
|------|------|
| 0 | Converged, findings=0 |
| 1 | Max rounds 未收敛 |
| 2 | 参数 / 环境错误 |

## 限制

- 只跑 node/ 的 eslint + tsc (rust cargo test 需 CI 环境, 本地成本高)
- 轮询间隔默认 60s, 20 次超时 (20 分钟)
