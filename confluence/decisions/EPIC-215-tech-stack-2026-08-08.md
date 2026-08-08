# EPIC-215 manifesto 技术栈现状 (2026-08-08)

> **Decision record**: 在 `confluence/manifesto/01-top-design.md` 加 §5.1 技术栈现状 + 3 层降级架构澄清.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 背景

主公 2026-08-08 拍板问"现在还在用 rust、node、python 的内核脚本吗". 核查实际状态:
- Rust ✅ active (L1 Core, 5 crates)
- Node.js ✅ active (L2 Fallback)
- Python ⚠️ 仅 1 helper (`expert-generate-l3.py`, 非内核)
- Shell + TypeScript ✅ active (6 immutable scripts + Node 配套)

## 2. 落地

文件: `confluence/manifesto/01-top-design.md`

加 §5.1 技术栈现状 + 3 层降级架构澄清:
- **5 种语言表格** (Rust / Node.js / Python / Shell / TypeScript)
- **3 层降级架构图** (Rust → Node.js → Shell)
- **关键澄清** (跟 v3.0.0 era 区别: 双 binary / Python 非内核 / Shell 6 immutable)

## 3. 联动

- EPIC-214 README 重整理 (删 v3.0.0 era 误导段)
- EPIC-160 install.sh Omnibus (95 files deploy)
- EPIC-069-D (5 immutable scripts)
- EPIC-174 (smoke retention 加 1)
- EPIC-131/132 (tsconfig strict + scan-dead-code)

## 4. 0 改 source code / 0 改 Rule / 0 增 immutable script

跟 EPIC-197/199/200/201 docs-only 1:1 pattern.

## 5. 4-PR 流程 (本 EPIC-215, 严格 EPIC-207 v2)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-215-tech-stack (worktree) | 1 file diff (manifesto/01-top-design.md) |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | FF push + master review comment |
| Step 4 | PR-3: main → miao | 独立 PR + 主公亲自 review |

## 6. Reviewer

- 主公 (拍板"在 manifesto 补技术栈")
- master (执行)
- EPIC-214 (README 源) + EPIC-160 (install.sh Omnibus 源)