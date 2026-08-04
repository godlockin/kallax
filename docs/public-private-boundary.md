# KALLAX Public/Private Boundary

> **EPIC-163**: 借鉴 loopx `docs/public-private-boundary.md` + AGENTS.md Security Rules
> **主公拍板**: 2026-08-05 P1

## 1. 边界定义 (Boundary Definition)

KALLAX treats **boundary as file-state** (tracked vs untracked), not path filtering.

| State | Definition | Git State |
|-------|------------|-----------|
| **Public** | Files safe to commit, share, publish | Tracked by git |
| **Private** | Files must never leave local machine | Untracked / staged only |

---

## 2. Public — Safe to Share

### 2.1 Schema / Type Definitions
- `*.schema.json`, `*.d.ts`, `*.ts` type definitions
- `node/src/types/` — type contracts between components

### 2.2 CLI / Interface Definitions
- `scripts/*.sh` — CLI tools (executable interface)
- `scripts/hooks/pre-commit` — git hook definitions
- `package.json` — npm interface

### 2.3 Adapter Lifecycle
- `scripts/adapters/` — adapter initialization/destroy patterns
- `scripts/install.sh` — deployment lifecycle

### 2.4 Generic Coordination Rules
- `CLAUDE.md` — agent coordination rules
- `CONTRIBUTING.md` — contribution guidelines
- `confluence/decisions/*.md` — governance decisions
- `jira/tickets/*.json` — ticket schema (不含敏感字段)

---

## 3. Private — Never Leave Local Machine

### 3.1 Local Paths
- `/Users/*/`, `/home/*/`
- `~/.local/`, `~/.config/`
- `/tmp/claude-tasks/` — task logs

### 3.2 Raw Logs
- `*.log`, `*.jsonl` > 1MB (raw execution traces)
- `/tmp/**/*.{log,jsonl}`
- `.claude/worktrees/*/tmp/`

### 3.3 Task IDs / Internal Coordinates
- Worktree names: `agent-*/`, `feature/EPIC-*/`
- Internal ticket IDs that expose coordination metadata

### 3.4 Credentials
- `api_key`, `token`, `password`, `secret`
- `OPENAI_API_KEY`, `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`
- AWS/GCP/Azure credentials
- Database connection strings

### 3.5 Person Names
- `GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME`
- Real names in commit metadata
- Human names in any context

### 3.6 Sub-Agent Prompts
- Agent system prompts
- `prompts/` directory content
- Agent instructions sent to LLM

### 3.7 Trajectories
- Agent execution traces
- Tool call logs
- Conversation histories

---

## 4. Enforcement

| Tool | Scope | Exit Code |
|------|-------|-----------|
| `scripts/check-private-context.sh` | Tracked + Untracked | 0=PASS, 1=FAIL, 2=BLOCKED-env |
| pre-commit hook | Staged files only | 0=allow, 1=block |

---

## 5. Security Rules (明文规定)

1. **不授权凭证** — Never commit credentials, tokens, API keys
2. **不代发布** — Never publish on behalf of others
3. **scan before staging** — Run `scripts/check-private-context.sh` before `git add`
