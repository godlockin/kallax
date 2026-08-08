# EPIC-212 GitHub 项目介绍 (2026-08-08)

> **Decision record**: README.md top 重写 v3.0.0 → v3.34.6, 跟 EPIC-171 positioning + EPIC-206 manifesto 1:1 联合.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 范围

主公 2026-08-08 拍板"顺便写一下 github 的项目介绍". 范围:
1. **README.md top 重写** (v3.0.0 era → v3.34.6 current)
2. **新增 GitHub 项目介绍入口** (跟 manifesto 1:1 链接)
3. **0 改 source code / 0 增 Rule / 0 增 immutable script**

## 2. 落地

### 2.1 README.md top

新 top 段:
- **生产级 Claude Code 治理框架** (跟 EPIC-171 positioning 1:1)
- **Why KALLAX?** 1 段 elevator pitch
- **快速入口**: 5 个 manifesto 文件 (跟 EPIC-206 1:1)
- **安装**: `bash install.sh`
- **文档结构**: 跟 EPIC-197 SoT 归并 1:1

保留 v3.0.0 era 段 (架构图/集成测试/时间线), 跟 ARCHITECTURE.md DEPRECATED 1:1 pattern. 后续 EPIC 治理.

## 3. 联动

- EPIC-171 (战略沉淀 — 3 视角定位): README top 用 "Why vs Claude Code?" elevator pitch
- EPIC-206 (manifesto 5 文件): README top 链 5 个文件入口
- EPIC-197 (SoT 归并): 文档结构段引用 confluence/ + docs/ 分层
- EPIC-160 (install.sh Omnibus): 安装段引用 95 files deploy
- EPIC-211 (CI 修复): README top 跟"0 装饰性宣称"价值观 1:1

## 4. 4-PR 流程 (本 EPIC-212, 严格 EPIC-207 v2)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-212-github-intro (worktree) | README.md top rewrite |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | FF push + master review comment |
| Step 4 | PR-3: main → miao | 独立 PR + 主公亲自 review |

## 5. Reviewer

- 主公 (拍板"顺便写一下 github 的项目介绍")
- master (执行)
- EPIC-171 (positioning 源) + EPIC-206 (manifesto 源)