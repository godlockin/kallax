# SQLite Module Guide

> How to use the KALLAX SQLite module for data persistence.

---

## Overview

KALLAX uses SQLite (via `better-sqlite3`) as its primary data store. The SQLite module provides CRUD operations for tickets, tasks, instances, and messages.

---

## Schema

### Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `tickets` | Work units | id, title, status, priority, assignee_id |
| `tasks` | Execution units | id, ticket_id, type, status, performer_id, progress |
| `instances` | Agent instances | id, role, status, hostname, pid, capabilities |
| `messages` | Inter-agent messages | id, type, payload, priority, target_id |

### Indexes

- `tickets`: status, assignee_id
- `tasks`: status, performer_id, ticket_id
- `instances`: role, status, last_heartbeat
- `messages`: (priority, created_at), target_id

---

## Initialization

The database is initialized automatically when you run any KALLAX command. The schema is created via `initializeSchema()`:

```typescript
import { createSQLiteManager } from '@kallax/node';

const result = createSQLiteManager({
  path: '.kallax/data/kallax.db',
});

if (result.isOk()) {
  const db = result.value;
  // db is ready with WAL mode and foreign keys enabled
}
```

### Pragma Settings

```
journal_mode = WAL     -- Better concurrent reads
synchronous  = NORMAL  -- Balance safety/performance
foreign_keys = ON      -- Referential integrity
```

---

## Operations API

### Tickets

```typescript
// Create
db.createTicket(ticket);

// Read
const ticket = db.getTicket('TICKET-ABC123');
const all = db.listTickets({ status: 'in_progress', limit: 20 });

// Update
db.updateTicket('TICKET-ABC123', { status: 'completed', assigneeId: 'PERF-001' });
```

### Tasks

```typescript
// Create
db.createTask(task);

// Read
const task = db.getTask('TASK-001');
const pending = db.listTasks({ status: 'pending' });

// Claim
const claimed = db.claimTask('TASK-001', 'PERF-001');

// Update
db.updateTask('TASK-001', { progress: 75, status: 'running' });
```

### Instances

```typescript
// Create
db.upsertInstance(instance);

// Read
const performers = db.listInstances({ role: 'performer', status: 'active' });
```

### Messages

```typescript
db.upsertMessage(message);
const urgent = db.listMessages({ targetId: 'PERF-001', limit: 50 });
```

---

## Direct SQL Access

For reporting and ad-hoc queries, use the `sqlite3` CLI:

```bash
sqlite3 .kallax/data/kallax.db

# WAL mode queries
SELECT status, COUNT(*) FROM tickets GROUP BY status;

# Active performers
SELECT id, capabilities FROM instances WHERE status = 'active';

# Average completion time by task type
SELECT type, AVG((completed_at - started_at) / 60000.0) AS avg_minutes
FROM tasks WHERE status = 'completed' GROUP BY type;
```

---

## Backup

```bash
# Automated backup (via script)
scripts/backup-sqlite.sh

# Manual backup
sqlite3 .kallax/data/kallax.db ".backup 'backup.db'"
```

See `docs/ops/backup-restore.md` for detailed backup and restore procedures.

---

## Performance Considerations

- **WAL mode**: Enables concurrent reads during writes without locking.
- **Indexed queries**: All common filter columns are indexed.
- **Connection per process**: `better-sqlite3` is synchronous and single-connection — one instance per process.
- **Never share**: Do not share the database file across processes without coordination (use the KALLAX API server instead).

---

## Related

- `node/src/core/sqlite/schema.ts` — DDL statements
- `node/src/core/sqlite/sync-client.ts` — Database client factory
- `node/src/core/sqlite/ticket-ops.ts` — Ticket CRUD
- `node/src/core/sqlite/task-ops.ts` — Task CRUD
- `node/src/core/sqlite/instance-message-ops.ts` — Instance + message operations
- `node/src/core/sqlite/types.ts` — Type definitions and row mappers
- `docs/ops/backup-restore.md` — Backup and restore guide
