# Database Schema

> Reference documentation for the KALLAX SQLite database schema.

---

## Tables

### `tasks`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PK | Task identifier (e.g. `TASK-001`) |
| `title` | TEXT | NOT NULL | Short description |
| `status` | TEXT | NOT NULL, CHECK IN | `open` / `claimed` / `in_progress` / `completed` / `failed` |
| `priority` | INTEGER | DEFAULT 0 | Higher = more urgent |
| `assigned_to` | TEXT | FK -> instances.id | Performer assigned |
| `capabilities` | TEXT | | JSON array of required capabilities |
| `metadata` | TEXT | | JSON blob for extensible fields |
| `created_at` | TEXT | DEFAULT CURRENT_TIMESTAMP | ISO 8601 |
| `updated_at` | TEXT | DEFAULT CURRENT_TIMESTAMP | ISO 8601 |

### `instances`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PK | Instance identifier (e.g. `PERF-001`) |
| `role` | TEXT | NOT NULL, CHECK IN | `conductor` / `performer` |
| `status` | TEXT | NOT NULL, DEFAULT 'active' | `active` / `idle` / `offline` |
| `capabilities` | TEXT | | JSON array of capabilities |
| `hostname` | TEXT | | Machine hostname |
| `pid` | INTEGER | | Process ID |
| `last_heartbeat` | TEXT | | ISO 8601 timestamp |
| `created_at` | TEXT | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TEXT | DEFAULT CURRENT_TIMESTAMP |

### `workflows`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PK | UUID |
| `task_id` | TEXT | FK -> tasks.id | Associated task |
| `template` | TEXT | NOT NULL | Workflow template name |
| `status` | TEXT | NOT NULL, CHECK IN | `draft` / `active` / `completed` / `failed` / `cancelled` |
| `current_step` | INTEGER | DEFAULT 0 | Current step index |
| `state` | TEXT | | JSON execution state |
| `created_at` | TEXT | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TEXT | DEFAULT CURRENT_TIMESTAMP |

### `dag_nodes`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PK | Node ID |
| `dag_id` | TEXT | FK -> workflows.id | Parent DAG |
| `label` | TEXT | | Human-readable name |
| `duration_estimate` | INTEGER | DEFAULT 0 | Estimated ms |
| `status` | TEXT | DEFAULT 'pending' | `pending` / `running` / `done` / `failed` |

### `dag_edges`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `from_id` | TEXT | FK -> dag_nodes.id | Predecessor node |
| `to_id` | TEXT | FK -> dag_nodes.id | Successor node |
| `dag_id` | TEXT | FK -> workflows.id | Parent DAG |
| PRIMARY KEY | | (`from_id`, `to_id`) |

### `audit_log`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | PK, AUTOINCREMENT | Sequential ID |
| `action` | TEXT | NOT NULL | Operation name |
| `actor` | TEXT | | Instance ID or user |
| `target` | TEXT | | Affected resource |
| `detail` | TEXT | | JSON payload |
| `created_at` | TEXT | DEFAULT CURRENT_TIMESTAMP |

### `migrations`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `version` | TEXT | PK | Migration version (e.g. `V001`) |
| `applied_at` | TEXT | DEFAULT CURRENT_TIMESTAMP | When applied |

---

## Indexes

```sql
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX idx_instances_role ON instances(role);
CREATE INDEX idx_instances_status ON instances(status);
CREATE INDEX idx_workflows_task ON workflows(task_id);
CREATE INDEX idx_workflows_status ON workflows(status);
CREATE INDEX idx_audit_action ON audit_log(action);
CREATE INDEX idx_audit_created ON audit_log(created_at);
```

---

## Related Files

- `node/src/core/db/migrations/` — SQL migration files
- `node/src/types/index.ts` — TypeScript type definitions
- `docs/guides/sqlite-module.md` — SQLite module guide
