# KALLAX 安全策略 / Security Policy

## 报告漏洞 / Reporting a Vulnerability

- **首选渠道**: GitHub Private Vulnerability Reporting — [`godlockin/kallax/security/advisories/new`](https://github.com/godlockin/kallax/security/advisories/new)
- **备用**: 通过 GitHub 直接 mention `@godlockin` (私信 / 独立 issue 中不披露细节先约谈)
- 请**不要**在公开 issue / PR 中披露安全问题, 也不要在 discussion / gist / social 上先行公开

## 支持版本 / Supported Versions

只对最近两个 minor 版本提供安全修复; 更早版本请先升级到受支持范围内再报告.

| Version   | Supported          |
|-----------|--------------------|
| v3.28.x   | :white_check_mark: |
| v3.27.x   | :white_check_mark: |
| < v3.27   | :x: (请先升级)     |

当前最新 release: `v3.28.0` (见 `git tag -l 'v*' --sort=-v:refname` 首行).

## SLA (响应时间)

- **10 工作日内**: 维护者确认收到 + 初步严重度判断 (Critical / High / Medium / Low)
- **90 天协调披露窗口**: 修复 + advisory 发布 (可协商延长, 但需双方书面同意)
- **7 天无响应**: 报告者可换渠道催 (直接给主公 GitHub handle 发私信, 或在另一个 repo 的 issue 里 mention 但不披露细节)

## 请提供的信息

为加速定位, 请在报告中包含:

- **KALLAX 版本**: `kallax --version` 输出 (含 rust binary + node scripts 双侧版本)
- **平台**: macOS / Linux / Windows + 版本号
- **PoC / reproduction steps**: 最小可复现路径, 附命令行 / 配置文件
- **影响面**: 本地 dev-only? CI/CD 相关? 用户数据泄露? 权限提升? Supply-chain?
- **建议修复方向** (可选)

## 公开策略

- Fix 发布后, 通过 GitHub Security Advisory 公开细节
- CVE 由报告者或 KALLAX 维护者向 MITRE / GitHub 申请, 双方协商 credit
- 邀请报告者进 advisory credits (匿名或署名, 由报告者选择)
- Fix commit + advisory 同步发布, 不做 silent patch

## 边界 (Threat Model)

- KALLAX 是 dev tool, **假设运行在受信开发者环境** (macOS/Linux workstation, developer 本人有 shell 访问权)
- 不承诺 sandbox 逃逸类漏洞: KALLAX 明确要求 worktree 隔离 + manual permission review (见 `CLAUDE.md` Worktree 隔离 + Q18 decision matrix)
- Supply-chain 类 (CVE in `Cargo.lock` / `package-lock.json` deps) 走标准披露, 与本文档流程一致
- 用户数据 (jira/tickets/ / .kallax/state/) 由用户在本地管理, KALLAX 不上传; 泄露风险由用户自行评估

---

> 相关文档: [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md) / [borrow-from-cindy 2026-07-26](confluence/decisions/borrow-from-cindy-2026-07-26.md)
