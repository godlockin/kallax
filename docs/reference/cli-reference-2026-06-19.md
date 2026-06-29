# CLI Reference

> Complete reference for all KALLAX CLI commands.

---

## Usage

```bash
kallax [global-options] <command> [subcommand] [options]
```

### Global Options

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--verbose` | `-v` | `false` | Enable debug-level output |
| `--format` | `-f` | `text` | Output format: `text` or `json` |

---

## Command Tree

### `task` — Ticket and Task Management

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `create` | `--title, --description, --priority, --scope` | Create a new ticket |
| `claim` | `--ticket-id, --performer-id` | Claim a ticket for execution |
| `complete` | `--ticket-id` | Complete a ticket via Saga |
| `list` | `--status` (optional) | List tickets, optionally filtered by status |
| `get` | `ticket-id` | Show ticket details |

**Status filters**: `ready`, `in_progress`, `completed`, `failed`

**Priority levels**: `low`, `normal`, `high`, `critical`

```bash
kallax task create --title "Implement login" --description "..." --priority high
kallax task claim --ticket-id TICKET-ABC123 --performer-id PERF-001
kallax task list --status in_progress
```

### `conductor` — Conductor (Orchestrator) Operations

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `heartbeat` | — | Send a heartbeat, returns status ok |
| `poll` | `--limit <N>` (default: 10) | Poll for ready tickets |
| `status` | — | Show conductor stats (tickets, tasks, performers) |

```bash
kallax conductor heartbeat
kallax conductor poll --limit 5
kallax conductor status
```

### `performer` — Performer (Agent) Operations

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `register` | `--name, --capabilities` | Register a new performer agent |
| `poll` | `--performer-id` | Poll for an available task |
| `list` | — | List all registered performers |
| `get` | `--performer-id` | Get performer details |
| `heartbeat` | `--performer-id` | Update performer heartbeat timestamp |

```bash
kallax performer register --name "fe-dev" --capabilities "react,typescript,css"
kallax performer poll --performer-id PERF-001
kallax performer list
```

### `knowledge` — Knowledge Base Operations

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `index` | `--title, --content, --tags` | Index content into knowledge base |
| `search` | `<query>` | Search the knowledge base |
| `list` | — | List all knowledge entries |

```bash
kallax knowledge index --title "ADR-001" --content "Decision: use Rust for core" --tags "architecture,rust"
kallax knowledge search "error handling patterns"
```

### `system` — System Operations

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `doctor` | — | Run full system diagnostics |
| `stats` | — | Show engine and pool statistics |
| `init` | `--force` | Initialize system (recreate if forced) |

```bash
kallax system doctor
kallax system stats
kallax system init --force
```

### `isolation` — File Isolation Operations

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `check` | — | Detect scope overlaps between performers |
| `validate` | `--performer-id` | Validate a performer's isolation |
| `list-paths` | — | List all claimed worktree paths |

```bash
kallax isolation check
kallax isolation validate --performer-id PERF-001
```

### `verify` — Output Verification

| Subcommand | Arguments | Description |
|------------|-----------|-------------|
| `output` | `--task-id, --pattern` | Verify task output (optionally match pattern) |
| `changes` | `--performer-id, --files` | Verify file changes from a performer |

```bash
kallax verify output --task-id TASK-001
kallax verify output --task-id TASK-001 --pattern "feature complete"
kallax verify changes --performer-id PERF-001 --files "src/ui/,tests/"
```

---

## Node.js Commands (enhanced layer)

When running via `kallax` (Node binary), additional commands are available:

| Command | Description |
|---------|-------------|
| `ticket` | Advanced ticket CRUD (create, get, list, update) |
| `recommend match <taskId>` | Match a task to the best performer via TF-IDF |
| `workflow list` | List available workflow templates |
| `workflow start <template> [ticketId]` | Start a workflow from template |
| `start --role <conductor|performer>` | Start a KALLAX instance |
| `doc` | Documentation management |
| `db` | Database utilities |
| `alerts` | Alert management |

```bash
kallax start --role conductor
kallax recommend match TASK-001 --top 5
kallax workflow start feature-development TICKET-ABC
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generic failure (error logged) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
<<<<<<< HEAD
| `KALLAX_API_KEY` | `<env-required, no default, fail-closed>` | API key for server auth (standalone.ts:21 fail-closed, no default, S-001 + S-004 治根) |
=======
| `KALLAX_API_KEY` | `<required, no default, fail-closed>` | API key for server auth (standalone.ts:21 fail-closed, no default) |
>>>>>>> origin/feature/v31-hotfix-p1
| `KALLAX_LOG_LEVEL` | `info` | Log level (trace/debug/info/warn/error/fatal) |
| `KALLAX_DATA_DIR` | `.kallax` | Data directory path |
