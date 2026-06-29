# KALLAX × Claude Code — Hook Server Configuration Example

> **v3.1.0 Track 4 (武器 5)**: 用户级 Claude Code hook server 配置 example
>
> Source: `docs/guides/claude-code-integration.md` 1:1 镜像 (集成文档 + 配置文件 双真相源)

---

## 文件

- `claude-code-settings.example.json` — 完整 6 phase hook 配置

---

## 用法

### 1. 用户级 (推荐, 全项目生效)

```bash
# 复制 example 到用户级 Claude Code settings.json
cp .kallax/hooks/examples/claude-code-settings.example.json \
   $HOME/.claude/settings.json

# 验证 JSON 有效
jq . $HOME/.claude/settings.json > /dev/null && echo "OK"
```

### 2. 项目级 (只当前项目生效)

```bash
# 项目级 settings.local.json (不入 git)
cp .kallax/hooks/examples/claude-code-settings.example.json \
   .claude/settings.local.json

# 加入 .gitignore (项目级)
grep -q 'settings.local.json' .gitignore || \
  echo '.claude/settings.local.json' >> .gitignore
```

---

## 启动 KALLAX Hook Server

```bash
# 启动 server (port=8787, audit log 写入 .kallax/audit/hook-events.jsonl)
KALLAX_API_KEY="your-secret-here" \
  bun node/src/hooks/server-entry.ts \
    --port 8787 \
    --api-key "$KALLAX_API_KEY" \
    --audit-store .kallax/audit/hook-events.jsonl
```

或参考 `tests/integration/real-claude-code-e2e.sh:setup_fixture()` 用法 (boot script 模式)。

---

## ⚠️ 不要 commit

- `$HOME/.claude/settings.json` (含 `${KALLAX_API_KEY}` 引用, 触发 env 即可, 但其他 secret 不要存)
- `.claude/settings.local.json` (项目级, 跟项目 root 共存)
- 任何含 `--api-key` 的真实 secret 的脚本

只 commit:
- ✅ `.kallax/hooks/examples/claude-code-settings.example.json` (template, 无 secret)
- ✅ `docs/guides/claude-code-integration.md` (集成指南)

---

## 验证集成

```bash
# 跑真实 E2E 验证 (curl mock Claude Code)
bash tests/integration/real-claude-code-e2e.sh

# 期望: 20/20 PASS
#   Phase 1: 6 phase endpoints 全 200
#   Phase 2: sha256 chain valid (genesis → sha256:...)
#   Phase 3: GET /hooks/audit → total=6
#   Phase 4: POST /hooks/replay → 6 replayed, all allowed=true
#   Phase 5: 5 错误用例 (401/401/405/404/400)
```

---

## 跟集成文档联合

`docs/guides/claude-code-integration.md` 跟本文件 1:1 镜像:
- § 2 (启动 server) 跟 "启动 KALLAX Hook Server" 1:1
- § 3 (settings.json 实战) 跟 `claude-code-settings.example.json` 1:1
- § 4 (Bearer token) 跟 `${KALLAX_API_KEY}` 引用 1:1
- § 9 (跟 6-weapons-e2e-test.sh 联合) 跟 "验证集成" 1:1