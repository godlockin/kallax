# EPIC-213 一句话介绍 (2026-08-08)

> **Decision record**: 新增 `confluence/manifesto/00-elevator-pitch.md`, 中英双语, 跟 EPIC-171 + EPIC-212 1:1 联合.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 背景

主公 2026-08-08 拍板"写个一句话介绍, 中英文的". 落地路径选择 `confluence/manifesto/00-elevator-pitch.md` (5 个 manifesto 文件前加 00 序号).

## 2. 内容

### 中文

**生产级 Claude Code 治理框架, 让 AI 写的代码像 CI/CD 一样进 prod.**

### English

**Production-grade Claude Code governance framework — CI/CD for AI agents.**

## 3. 落地

- 1 file: `confluence/manifesto/00-elevator-pitch.md` (跟 EPIC-206 5 个 manifesto 文件 1:1)
- 0 改 source code / 0 改 Rule / 0 增 immutable script

## 4. 复用

任何需要一句话介绍的地方 (PR 描述 / Lark 群 / 飞书群 / 邮件签名 / Lark wiki) 都用这 2 句, 跟"0 装饰性宣称"价值观 1:1 联合.

## 5. 4-PR 流程 (本 EPIC-213, 严格 EPIC-207 v2)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-213-elevator-pitch (worktree) | 1 file 新增 |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | FF push + master review comment |
| Step 4 | PR-3: main → miao | 独立 PR + 主公亲自 review |

## 6. Reviewer

- 主公 (拍板"写个一句话介绍")
- master (执行)
- EPIC-171 (positioning 源) + EPIC-206 (manifesto 源) + EPIC-212 (GitHub intro 源)