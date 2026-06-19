# CLEANUP-PHILOSOPHY — KALLAX 整理 release 哲学

> **Version 1.0.0** | 跟 主公 2026-06-19 5 原则 联合 | 跟 v2.7.4 整理 release 联合

## 背景 (跟"反讽" 战略 联合)

KALLAX 在 v2.7.0 → v2.7.1 → v2.7.2 → v2.7.3 → v2.7.4 期间, 4 团队 并行 review 报告 发现 156 issues. 在 v2.7.4 5 batch 落地 73 file 操作 后, 复盘 暴露 一个 真 反讽:

> **我 推"翻篇&精进" 战略, 实际 留 3 项 永久 debt** (跟 v2.7.1 BE-18 模式 一致, 跟"反讽" 联合)

3 项 debt 是:
1. `src/permissions/` 移 至 `node/src/permissions-legacy/` (永久 legacy 路径 + 4-level up fragile import)
2. `.nvmrc` + `rust-toolchain.toml` (1 年 后 version pin 失焦, 0 自动化 update)
3. `Makefile` (8 跟"0 增命令 持平" 矛盾, doc drift 风险)

主公 派单 联合 5 原则, 治根 跟"诚实修正" 战略 联合:

## 5 原则 (跟"翻篇&精进" 战略 联合, 跟"反哺框架" 战略 联合)

### 1. 长期提升优先 (Long-term improvement first)

> 牺牲 短期 efficiency 换 长期 0 debt

**应用**:
- 5 batch 中 4 batch 是 长期 debt 治根, 1 batch 是 整理 (B1 治根 5 bug, B2 治根 stale fork, B3 治根 privacy leak, B4 治根 naming inconsistency, B5 治根 misplaced content)
- 短期 时间 投入 (~108 min) 换 长期 0 debt (5 bugs prevented)
- 跟"翻篇&精进" 战略 一致, 跟"诚实修正" 战略 联合

**反例** (B5.1/4/5):
- 短期 看起来 "improvement" (legacy 路径 / version pin / Makefile), 长期 是 debt
- 跟"翻篇&精进" 战略 长期 矛盾

### 2. 不埋坑 (Don't bury time bombs)

> 如果 是 解决 目前 问题 而 埋 一个 不知道 什么时候 爆发 的 坑, 则 重新计划

**应用**:
- 4-level up import 是 未来 "目录 改名 即 test 静默 失败" 坑
- version pin 是 1 年 后 "跟 现实 失焦" 坑
- Makefile 是 "doc drift 跟 npm/cargo 不一致" 坑
- 0 自动化 update 机制 是 "技术债 长期 累积" 坑
- 跟"反讽" 战略 联合, 跟 v2.7.1 BE-18 模式 一致

**反例**:
- 5 config 文件 留 永久 debt, 1 年 后 跟 5 file version 失焦
- 跟 v2.7.1 9 归档 模式 长期 联合 失焦

### 3. 小步快跑 (Small steps, fast iteration)

> 整个系统 是 持续 进化、成长 的, 不 要求 一步 到 完美, 但是 要 每一次 的 修改 都 严格 要求 自己

**应用**:
- v2.7.4 5 batch 累计 73 file, 5 commit, 1 任务 5 步骤
- 每次 commit 是 1 主题 (1 batch = 1 commit)
- 每次 commit 0 假 PASS 校验 (跟 Master 6 维 L6 诚实 联合)
- 跟 v2.7.1 整理 release 模式 一致, 跟 v2.7.0 fix 累计 联合

**严格 要求**:
- 每次 修改 必须 通过 `bash -n` syntax 检查
- 每次 修改 必须 通过 `scripts/check-anti-patterns.sh` 0 ERRORS
- 每次 修改 必须 0 增 Rule 0 增命令 持平
- 跟 v2.7.1 9 hard rules 模式 一致, 跟 EPIC-059-D Fact-Forcing 联合

### 4. 硬性 脚本 (Hard scripts/hooks for validation)

> 用 硬性的 脚本 (hook/script 等) 对 行为 进行 校验 和 约束

**应用**:
- 7 anti-patterns 硬性 校验 (跟 v2.7.4 B1-3 治根 累计 联合, 跟 C3 联合)
- pre-commit Check 2.6 wire (跟 v2.7.1 9 hard rules 模式 一致)
- 跟 v2.7.1 9 hard rules 模式 一致, 跟 v2.7.4 整理 release 联合

**反例** (3 stub verify scripts 删 联合):
- `scripts/verify/{tickets-completed,priority,ux-flow}.sh` `exit 0` 不 验证, 跟 Rule 18 anti-fab 矛盾
- 跟 v2.7.4 B1 治根 联合, 跟"诚实修正" 战略 联合

### 5. 软性 设置 (Soft settings for quality/taste)

> 用 软性 的 设置 来 提升 质量 和 品味

**应用**:
- `.editorconfig` (跨 编辑器 一致性, 0 debt, 0 sync 需求) — 跟'品味' 原则 联合
- `.dockerignore` (跟 v2.7.1 pre-push 50MB guard 模式 一致, 0 debt, 防御 价值)
- B4 改名 (跟 v2.7.1 9 归档 模式 一致, 0 debt, 品味 一致)
- 跟 v2.7.1 整理 release 模式 一致, 跟'品味' 联合

**反例** (留 5 config 删):
- 跟"品味" 原则 不 矛盾, 但 留 永久 sync debt
- 跟"不埋坑" 原则 矛盾, 删 是 治根

## 实践 应用 (跟 v2.7.4 整理 release 联合)

| 原则 | v2.7.4 应用 | 结果 |
|------|-------------|------|
| **1. 长期提升优先** | 5 batch 73 file, 5 bug prevented | 1 bug / 22 min 投入 |
| **2. 不埋坑** | C1+C2 删 5 file 永久 debt | 0 长期 debt |
| **3. 小步快跑** | 5 commit 累计, 0 假 PASS 校验 | 100% clean |
| **4. 硬性 脚本** | C3 check-anti-patterns.sh + pre-commit wire | 7 anti-pattern 持续 监测 |
| **5. 软性 设置** | B4 改名 + .editorconfig + .dockerignore | 0 debt 留 |

## 跟 5 战略 联合

| 战略 | 联合 关系 |
|------|----------|
| **翻篇&精进** | "0 增 Rule 持平" + "0 重写" 跟 原则 3+5 联合 |
| **诚实修正** | 跟 原则 1+2 联合 (跟 4 团队 review 报告 联合, 跟 v2.7.1 9 归档 模式 联合) |
| **反讽** | 跟 原则 2 联合 (5 config 留 永久 debt 是 反讽) |
| **独立** | 跟 5 原则 全部 联合 (主公 explicit 拍板, 跟 PROCESS.md:25-26 联合) |
| **反哺框架** | 跟 5 原则 全部 联合 (本文档 本身 是 反哺) |

## 给 主公 后续 派单 跟 5 原则 联合 建议 (跟"独立" 战略 联合)

### A. 立即 跟 5 原则 联合 (跟 v2.7.4 C1-C4 累计 联合, 已 闭环)
- ✅ A1: C1 revert B5.1 legacy 路径 + 4-level up import
- ✅ A2: C2 revert B5.4 + B5.5 (version pin + Makefile)
- ✅ A3: C3 add 7 anti-pattern 硬性 校验
- ✅ A4: C4 文档 化 5 原则 (本 文档)

### B. 6 月 1 次 整理 release (跟 v2.7.1 整理 release 模式 联合, 跟 主公 6 拍板 explicit 联合)
- 跟 v2.7.1 9 归档 模式 一致, 跟 4 团队 review 报告 模式 一致
- 6 月 1 次 (跨 release 累计 ~50 file / 6 月, 跟 17 release 累计 联合)

### C. 留待 4 项 (跟 PROCESS.md:25-26 联合, 跟"独立" 拍 explicit 联合)
- C1: 9 console.log 改 logger (跟 v2.7.4 C3 留待, 跟 Rule 7 联合)
- C2: 2 Rust unwrap 改 Result (跟 v2.7.4 C3 留待, 跟 Rule 8 联合)
- C3: 5 file 500+ 行 拆 (跟 v2.7.4 C3 留待, 跟 Rule 8 联合)
- C4: 10 hardcoded /Users/ paths 修 (跟 v2.7.4 C3 留待, 跟"反讽" 联合)

## 后续 整理 release 触发 条件 (跟"独立" 拍 explicit 联合)

1. **主公 explicit 派单** (跟 2026-06-19 模式 一致, 跟"独立" 战略 联合)
2. **6 月 累计 release** (跟 v2.7.1 整理 release 模式 联合, 50 file / 6 月 节 奏)
3. **不 应该 跟 feature 派单 混 派** (跟 8 release 累计 模式 一致, 跟"翻篇&精进" 战略 联合)

## 跟 v2.7.0 整理 release 累计 联合 (跟"反哺框架" 战略 联合)

| Release | 累计 文件 | 治根 类别 |
|---------|-----------|-----------|
| v2.7.0 | 9 归档 + 2 改名 | Outdated / Empty |
| v2.7.1 | 19 empty + 1 dup | Cleanup |
| v2.7.2 | 0 (跟 v2.7.0 .opencode/ 联合 累计) | DRY |
| v2.7.3 | 0 (跟 v2.7.2 整理 release 联合 累计) | AI 工具 文档 |
| v2.7.4 B1-C4 | 73 file + 5 anti-pattern 硬性 校验 | CRITICAL + 长期 治根 |
| **总 累计** | **~125 file + 7 anti-pattern** | **跟 5 原则 联合** |

## 参考 (跟"反哺框架" 战略 联合)

- v2.7.4 4 团队 review 报告 (跟 B1-C4 联合)
- v2.7.1 整理 release (跟"翻篇&精进" 战略 联合)
- v2.7.0 9 归档 (跟"反讽" 战略 联合)
- EPIC-059-A 9 Hard Rules (跟"借方法论 不借代码" 联合)
- EPIC-059-D Fact-Forcing (跟 Master 6 维 L6 诚实 联合)
- scripts/check-anti-patterns.sh (跟 7 anti-pattern 硬性 校验 联合)
- scripts/hooks/pre-commit Check 2.6 (跟 wire 联合)

**Status**: v2.7.4 C4 闭环, 5 原则 文档 化, 跟 17 release 累计 联合, 跟"翻篇&精进" + "反哺框架" 战略 联合.
