# caveman 跟 KALLAX 整合 (P-005 治根 联合)

> 跟 B 组 Attack Review P-005 治根 联合: examples/ 目录 0 README 告知 user 是否需跑
> 跟 README.md §3 步 联合: 第 3 步是 "看 demo" (不需 跑)
> 跟 v3.5.0 P-002 "实战 1 次 evidence byte-identical" 治根 联合, demo 是 真 跑过 案例 (跟 v3.2.0 rtk + caveman 整合 1:1 验证)

## examples/kallax-caveman-demo.md 用途

| 场景 | 是否需跑 | 跟"诚实修正" 联合 |
|------|---------|----------------|
| 装 caveman skill 后 想 看 1 个 demo 了解效果 | ❌ 不需跑, 读 demo doc 即可 | ✅ 跟"诚实修正" 联合, 0 假装 实战 |
| 想 验证 caveman 跟 KALLAX 整合 | ⚠️ 可选 跑 `bash demo/run.sh` | ✅ 跟"实战 1 次" 模式 联合 |
| 想 写 自己 caveman script | 📖 参考 demo 结构 | — |

## demo 跟 README 关系

- README.md (跟 U-004 联合, commit 5c0cc75) Quick Start 3 步 → 第 3 步 指 examples/kallax-caveman-demo.md
- 本文档 P-005-INTEGRATION.md (跟 P-005 联合) → 显式 标注 demo 用途 (避免 user 误解 demo 是 必跑)

## 跟 B 组 P-005 治根 联合

v3.2.0 装入 `.claude/skills/caveman/` 后 examples/ 子目录 0 README — user 不知 demo 是否 需 跑. 本文档 1:1 区分:
- 看 (1 分钟) 了解 效果
- 跑 (5 分钟) 验证 整合
- 参考 (10 分钟) 写 自己 script

跟 v3.5.0 P-002 evidence byte-identical 反讽 联合, demo 跑 跟 "实战 1 次" 模式 1:1 验证 (跟 v3.2.0 rtk + caveman 整合 联合).

---

Co-Authored-By: Claude <noreply@anthropic.com>