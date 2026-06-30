# caveman skill — Quick Start

> v3.5.0 hotfix (跟 B 组 Attack Review U-004 + P-005 治根 联合): 加 README 入口
> 跟 v3.2.0 rtk + caveman KALLAX 整合 1:1 联合 (commit f9fa197)
> 跟 v3.1.0 P-006 "12 Operational Summaries" 1:1 联合

caveman skill 提供 75% token 节省的 Claude Code 简化输出模式, 跟 KALLAX 6 命令 (kallax-*) 完全兼容.

## 3 步上手

1. **读 [SKILL.md](./SKILL.md)** — auto-trigger 关键词列表 (e.g. "caveman mode", "token 节省", "75%")
2. **读 [KALLAX-INTEGRATION.md](./KALLAX-INTEGRATION.md)** — 跟 KALLAX 6 命令 (kallax-init / kallax-start / kallax-task / kallax-review-pr / kallax-merge / kallax-status) 整合
3. **看 [examples/kallax-caveman-demo.md](./examples/kallax-caveman-demo.md)** — 实战 1 次 案例 (跟 v3.5.0 P-002 "实战 1 次 evidence byte-identical" 治根 联合, demo 是 真 跑过 案例)

## 跟 KALLAX 的关系

| 概念 | 说明 |
|------|------|
| caveman | 简化输出模式, 75% token 节省 |
| KALLAX | 6 命令多 agent 协作框架 (Conductor + Performer 1+4) |
| rtk | Rust Token Killer CLI (token 优化 proxy) |
| 整合 | rtk + caveman 跟 KALLAX v3.2.0+ 整合 (commit f9fa197) |

## 使用触发

```
/caveman              # 切换到 caveman 模式 (本 session)
/caveman + /kallax-*  # caveman 模式 + KALLAX 命令 组合
```

## 文档索引

- [SKILL.md](./SKILL.md) (2.2K) — auto-trigger 关键词 + 输出规则
- [KALLAX-INTEGRATION.md](./KALLAX-INTEGRATION.md) (5.2K) — 跟 KALLAX 6 命令整合
- [examples/kallax-caveman-demo.md](./examples/kallax-caveman-demo.md) (3.8K) — 实战 demo

## 跟 B 组 U-004 治根 联合

v3.2.0 装入 `.claude/skills/caveman/` 后, 3 文件 (SKILL.md + KALLAX-INTEGRATION.md + examples/) 缺 README 入口 — 用户不知先读哪个. 本 README 加 "Quick Start 3 步" 解决.

跟 v3.1.0 P-006 "12 Operational Summaries" 模式 1:1: 给用户 1 页入口, 不读 4 文件.

## 跟 B 组 P-005 治根 联合

examples/ 目录 之前 0 README 告知 user 是否需跑 — 本 README §3 步明确 第 3 步是 "看 demo" (不需 跑), 跟 "实战 1 次" 模式 联合, 避免用户误解 demo 是必跑.

---

Co-Authored-By: Claude <noreply@anthropic.com>