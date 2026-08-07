# EPIC-121 — 沙箱 Eval + Tiered Memory (SWE-bench + LangChain 借鉴)

> Date: 2026-07-14/15 | 2 tickets (A/B)

## 起源

主公 2026-07-14 研究 OpenAI/Anthropic/SWE-bench/LangChain 后 explicit "开"。

## 来源 1: SWE-bench — 沙箱隔离

**SWE-bench 3 层 Docker 架构**:
```
Base image (共享核心)
Environment image (per-language configs)
Instance image (per-issue deps)
→ 可重现的沙箱隔离执行
```

**KALLAX 现状**: `pr-eval.sh` 在 host 上跑，test-live 靠 `skipIf(!env.X_LIVE)` 隔离。

**改进**: `pr-eval.sh --docker` 在容器内跑 lint+tsc+vitest，自动清理。

## 来源 2: LangChain — Tiered Memory

**5 层 Memory**:
- **Buffer**: 最近 N 轮
- **BufferWindow**: 滑动窗口
- **Summary**: 超过阈值生成摘要
- **VectorStore**: 语义检索长期存储
- **KBQA**: 知识库问答

**KALLAX 现状**: performer mastery 只靠 SQLite 30-day lookback，无 semantic retrieval。

**改进**: performer profile 加 VectorStore-backed abandonment history + skill embedding。

## Ticket A: pr-eval.sh --docker

| 当前 | 改进后 |
|------|--------|
| host 上跑 lint/tsc/vitest | 容器内跑，自动清理 |
| test-live 靠 skipIf 隔离 | Docker 网络隔离 |
| 无环境重现性 | Dockerfile.eval 保证环境一致 |

## Ticket B: Performer VectorStore Profile

| 当前 | 改进后 |
|------|--------|
| SQLite 30-day lookback | VectorStore 长期 history |
| 无 semantic retrieval | embedding-based skill match |
| 冷启动 | warm profile |

## 联动

- EPIC-120 (pr-eval 框架)
- EPIC-118 (expertise-aware dispatch)
- EPIC-119 (tool taxonomy)
- SWE-bench (patch-centric eval)
- LangChain Memory (tiered memory)

## 来源

```
SWE-bench: https://github.com/SWE-bench
LangChain Memory: https://blog.csdn.net/weixin_42475060/article/details/143479970
```
