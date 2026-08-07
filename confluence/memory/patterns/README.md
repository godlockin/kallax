# L3 — 全局模式 (Global Patterns)

> **Layer**: **L3** 全局模式 (Global Patterns) — 跟 `../LAYERS.md`,配合
> **升级路径**: L2 (confluence/memory/lessons/) 跨 release 累计 ≥ 3 → **L3** (本目录, patterns/) → L4 (confluence/memory/research/) PHASE review 升级
> **已存在 files** (跟"借鉴方法论而非直接复制代码",配合, 0 重写):
> - `isolation-strategy.md` — Worktree + File Scope 并行隔离策略
> - `rust-node-bridge.md` — Rust HTTP bridge over napi-rs 模式
>
> **作者**: master (EPIC-059-H 拍板, 2026-06-18)
> **最近更新**: 2026-06-18 (EPIC-059-H 落地 L3 分层标记)
> **下次整理触发**: 跨 3+ release 累计新 pattern / PHASE-016 review

---

## L3 升级判据 (跟 LAYERS.md §3,配合)

- ✅ 跨 ≥ 3 release 引用同一 lessons
- ✅ Master 拍板 (跟 PROCESS.md:25-26,配合)
- ✅ 写 `confluence/memory/patterns/{pattern-name}.md` + frontmatter layer: L3

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) — `../../CLAUDE.md`
