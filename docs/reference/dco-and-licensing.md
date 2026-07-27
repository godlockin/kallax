# DCO Governance + Apache-2.0 LICENSE 切换

> 主 CLAUDE.md 引用, 不展开

**主 CLAUDE.md**: root, 表格 "细节文档" 段引用本文件
**本文件加载场景**: DCO CI fail / LICENSE 切换 review / 外部贡献者初次接触

---

## Apache-2.0 切换 (v3.29.0)

KALLAX v3.29.0 (PR #148) 从 MIT 切 Apache-2.0:
- `LICENSE`: 标准 Apache-2.0 全文
- `NOTICE`: Apache §4(d) 格式, "Copyright 2024-2026 Steven Chen", developer + GitHub owner attribution
- 3 version sources bump: root package.json, node/package.json, rust/Cargo.toml (workspace.version = X.Y.Z) 都对齐

LICENSE 不需"DCO required", 因为 DCO 是 commit-level 跟 LICENSE 无关.

---

## DCO Governance (v3.29.0 EPIC-137-A/B/C)

3 文件 + 3 闸门 + 1 grace:
- `DCO` — Linux Foundation DCO 1.1 verbatim
- `.github/dco.yml` — DCO App 配置 (allowRemediationCommits 启用, require.members: true 严格)
- `NOTICE` — attribution + SBOM 路径

**3 闸门**:
- **Hook** — `.githooks/prepare-commit-msg` 自动追加 Signed-off-by (committer ident, 非 author, 防 --author= 代签)
- **CI workflow** — `.github/workflows/dco-check.yml` 跑 `scripts/check-dco.sh`
- **CLI** — `scripts/check-dco.sh` 扫所有 commit 的 Signed-off-by + committer email match trailer email

**1 grace**:
- `--allow-pre-cutoff [<sha>]` 跳过 pre-DCO-era (default cutoff = v3.29.0 merge `7187bb5`)
- 防止 4-branch flow base 分支历史债污染新 PR 检查

---

## 跟 Rule 34 联合

- DCO 闸门是 commit-level Rule
- Rule 34 是 ticket-level Rule
- 两者 orthogonal: bugfix ticket 必须含 reproduction (Rule 34) AND commit 必须 Signed-off-by (DCO)

---

## Borrow 来源

Cindy v1.0.0 的 governance chain (X.D. Network 心动网络). KALLAX 借方法论不借代码.

参考: `confluence/decisions/borrow-from-cindy-2026-07-26.md`
