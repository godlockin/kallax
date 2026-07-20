# Release Automation — EPIC-128 (2026-07-20)

> **起源**: 2026-07-20 主公发现 `bash scripts/setup.sh --release vX.Y.Z` 不能装上 — 404 (CI 没产 archive)。
> **决策**: 改 `.github/workflows/release.yml` 加 Rust build + archive 打包,改 `scripts/setup.sh` 让 release 模式自动 symlink 到 `~/.local/bin/kallax`,跟 source install UX 对齐。

## 事实 (诊断前)

| 阶段 | 状态 | 引用 |
|------|------|------|
| `release.yml` 推送 Node `node/dist/**` 到 GitHub Release | ✅ 有 | `.github/workflows/release.yml` (改前) |
| `release.yml` 产 `.tar.gz` archive | ❌ 没有 | 原版只用 `softprops/action-gh-release` raw upload |
| `release.yml` 打 Rust binary | ❌ 没有 | Rust 引擎只有 `rust-build.yml` 做 check |
| `scripts/setup.sh` 期望 `kallax-cli-rule-vX.Y.Z.tar.gz` | ✅ 有 (待 archive) | `scripts/setup.sh:140` |
| `scripts/setup.sh` release 模式自动 symlink 到 `~/.local/bin/kallax` | ❌ 没有 | 改前 |

**断链**: 主公跑 `bash scripts/setup.sh --release vX.Y.Z` → curl 下载 → 404 → setup.sh 退出。Node `kallax` CLI 不能从 GitHub Release 一键装。

## 改动 (3 段)

### 1. `.github/workflows/release.yml` — 8 steps

```
1. actions/checkout@v4
2. actions/setup-node@v4 (cache: npm, node 20)
3. Node install + build (npm ci + npm run build)
4. Rust setup toolchain (rustup target add x86_64-unknown-linux-musl)
5. Rust cache (Swatinem/rust-cache@v2)
6. Rust build static binary (cargo build --release 配 fallback debug)
7. Archive package release (tar czf 含 node/dist + rust + scripts + hooks + MANIFEST)
8. Upload release assets (softprops/action-gh-release@v2)
```

**`kallax-cli-rule-vX.Y.Z.tar.gz` 内容**:

```
node/dist/index.js ...          # Node CLI 主程序
node/package.json
rust/kallax-engine              # Linux x86_64 musl 静态二进制 (如构建成功)
scripts/setup.sh                # install 入口
scripts/cli-rule                # rule installer
scripts/init-project.sh         # init 子命令
hooks/exec-task.sh              # hook 实现
hooks/bash-rule-enforcer.sh
hooks/verify-rule.sh
MANIFEST                        # tag / commit / arch 痕迹
```

`MANIFEST` 含 `tag=${TAG} commit=${SHA} built_at ...` 用于 fallback 诊断。

### 2. `scripts/setup.sh` — release 模式 symlink

新增段(改前 191 行后) 在 release 模式 + 仓库校验后:

- 检测 `node/dist/index.js` → 写 `~/.local/bin/kallax` wrapper(同 `kallax-install.sh` 模式)
- 检测 `rust/kallax-engine` → 拷到 `~/.local/bin/kallax-engine`

UX: `bash scripts/setup.sh --release vX.Y.Z` 装完可直接 `kallax --version`,跟 source install 一致。

### 3. `MANIFEST` 文件

为每个 archive 写 `MANIFEST` 含 tag + commit + 架构,方便日后 debug 哪个 release 装了哪个版本。

## 安全考虑 (security-guidance 警告)

按 `@claude-code-plugins/security-guidance` 警告:
- **未用** `github.event.issue.title/body/PR.title` 等 untrusted input
- **只**用 `github.ref_name` (ref slug, GitHub-controlled) + `github.sha` (commit SHA, GitHub-controlled) + `runner.os` — 都是 safe
- 通过 `env:` block 注入到 `run:`,而非直接 `${{ }}` 插值,符合防御建议

## 失败 fallback (Rust 引擎)

`cargo build --release --target x86_64-unknown-linux-musl` 失败时(常见原因:某些 crate 缺 musl target support):

```
1. release → fallback debug build
2. debug 也失败 → `::warning::Rust build failed; Node-only release`,归档不含 rust/
3. setup.sh 检测到没 rust/ → 跳过 `~/.local/bin/kallax-engine` 部署,不报错
```

**fail-closed**: 整个 release job **不**因 Rust 失败而退出 — Node CLI 仍是主入口,Rust 是 L3 降级。

## 测试计划 (下次 release 触发时)

```bash
# 1. 主公打 tag → CI 跑
git tag v3.X.Y && git push origin v3.X.Y

# 2. CI 完工后,验证 5 件
gh release view v3.X.Y --json assets | jq '.assets[].name'
# 期望: ['Source code (zip)', 'Source code (tar.gz)',
#        'kallax-cli-rule-v3.X.Y.tar.gz',
#        'kallax-cli-rule-v3.X.Y.tar.gz.sha256']

# 3. 装一遍
cd /tmp && bash <(curl -fsSL https://raw.githubusercontent.com/godlockin/kallax/main/scripts/setup.sh) --release v3.X.Y
# 验证: ~/.local/bin/kallax --version 应出 v3.X.Y

# 4. (如 Rust 成功) 验证 Rust binary
~/.local/bin/kallax-engine --version
```

## 联动 ticket

- **EPIC-127-B** main branch recovery (2026-07-20, 主分支重建)
- **EPIC-128** release automation (本次)
- v3.X.Y backlog (next release 跑自动化)

## 反模式警告

❌ **禁止**:
- 用 `${{ github.event.* }}` 直接拼到 `run:` (command injection)
- `softprops/action-gh-release@v2` 不带 `files:` (assets 缺失,主公 404 主因)
- Rust build 失败让整个 release 退出 (Node 仍可用)

✅ **必做**:
- 所有 untrusted context 通过 `env:` 注入
- 任何 binary upload 配 `.sha256` (idempotent with setup.sh L164-174)
- 关键步骤失败但**不阻塞 release** 时,使用 `::warning::` 而非 `::error::`

## 已知遗留

- macOS / Windows 二进制未产(cross-compile musl 不支持 mac bundle, 需要 `macos-latest` runner 加 job)
- Docker image 未更新 (Dockerfile 在仓库根,跟 release 解耦)
- 自动 bump version (Cargo.toml + node/package.json) 未联动 (下次 v3.X.Y 手动改)

## 文件变更 (本次)

- ✅ 改 `.github/workflows/release.yml`: 22 行 → 150 行 (新增 6 step)
- ✅ 改 `scripts/setup.sh`: 加 release symlink 段 (~40 行)
- ✅ 新增 `confluence/decisions/release-automation-2026-07-20.md` (本文件)
- ❌ 0 业务代码改动
