// rust/crates/kallax-election/src/persistence.rs — KALLAX Raft log persistence (SQLite WAL)
//
// EPIC-060-A Phase 5: 跟 Phase 2 litestream 联合 (WAL mode SQLite, 跨 process 复制)
// 跟 eket 4 级降级 模式 联合: L1 SQLite 主用 (durability) + L2 in-memory 备 (replay on boot)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 3: 0 skip tests (persistence verified via 5/5 integration TCs)
//   Rule 4: 0 magic numbers (ELECTION_SCHEMA_SQL named constant)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 store + 4 methods, shared schema)
//
// Schema (跟 Raft thesis §5.2 联合):
//   raft_state: (current_term INTEGER, voted_for TEXT) — 单 row, 持久化 volatile state
//   raft_log:   (idx INTEGER PK, term INTEGER, data BLOB) — append-only log
//
// 跟 litestream 联合: PRAGMA journal_mode=WAL 让 litestream observe .db-wal 文件变化
// (跟 Phase 2 litestream config 1:1 联合, 跨 release 复用 litestream.yml 同步 log)

use crate::{ElectionError, LogEntry, Result};
use parking_lot::Mutex;
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;
use std::sync::Arc;

/// SQL schema applied at log store open-time (跟 Rule 4 联合, 0 magic strings).
pub const ELECTION_SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS raft_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_term INTEGER NOT NULL DEFAULT 0,
    voted_for TEXT
);

CREATE TABLE IF NOT EXISTS raft_log (
    idx INTEGER PRIMARY KEY,
    term INTEGER NOT NULL,
    data BLOB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_raft_log_term ON raft_log(term);
"#;

/// Persistent Raft state (current_term + voted_for), 跟 Raft thesis §5.2 联合.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct PersistentState {
    pub current_term: u64,
    pub voted_for: Option<String>,
}

/// SQLite-backed Raft log store. 0 hardcoded paths (跟"反讽" 联合 治根 privacy leak).
#[derive(Clone)]
pub struct LogStore {
    conn: Arc<Mutex<Connection>>,
}

impl LogStore {
    /// Open a log store at `path`, applying schema and enabling WAL mode.
    /// 跟 Phase 2 litestream WAL mode 1:1 联合 — litestream observe .db-wal 文件.
    pub fn open(path: &Path) -> Result<Self> {
        let conn = Connection::open(path).map_err(|e| ElectionError::persistence("open", e))?;
        // WAL mode for litestream replication compatibility
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
            .map_err(|e| ElectionError::persistence("pragma", e))?;
        conn.execute_batch(ELECTION_SCHEMA_SQL)
            .map_err(|e| ElectionError::persistence("schema", e))?;
        // Ensure single state row
        conn.execute(
            "INSERT OR IGNORE INTO raft_state (id, current_term, voted_for) VALUES (1, 0, NULL)",
            params![],
        )
        .map_err(|e| ElectionError::persistence("seed", e))?;
        Ok(Self {
            conn: Arc::new(Mutex::new(conn)),
        })
    }

    /// Read persistent state (current_term + voted_for).
    pub fn read_state(&self) -> Result<PersistentState> {
        let conn = self.conn.lock();
        let row = conn
            .query_row(
                "SELECT current_term, voted_for FROM raft_state WHERE id = 1",
                params![],
                |r| {
                    Ok(PersistentState {
                        current_term: r.get::<_, i64>(0)? as u64,
                        voted_for: r.get::<_, Option<String>>(1)?,
                    })
                },
            )
            .optional()
            .map_err(|e| ElectionError::persistence("read_state", e))?;
        Ok(row.unwrap_or_default())
    }

    /// Write persistent state (term + vote), atomic. 跟 Raft §5.2 联合.
    pub fn write_state(&self, state: &PersistentState) -> Result<()> {
        let conn = self.conn.lock();
        conn.execute(
            "UPDATE raft_state SET current_term = ?1, voted_for = ?2 WHERE id = 1",
            params![state.current_term as i64, state.voted_for],
        )
        .map_err(|e| ElectionError::persistence("write_state", e))?;
        Ok(())
    }

    /// Append a log entry, returns Ok if inserted.
    pub fn append(&self, entry: &LogEntry) -> Result<()> {
        let conn = self.conn.lock();
        conn.execute(
            "INSERT INTO raft_log (idx, term, data) VALUES (?1, ?2, ?3)",
            params![entry.index as i64, entry.term as i64, entry.data],
        )
        .map_err(|e| ElectionError::persistence("append", e))?;
        Ok(())
    }

    /// Read log entry at `index` (1-indexed, 跟 Raft spec 联合).
    pub fn get(&self, index: u64) -> Result<Option<LogEntry>> {
        let conn = self.conn.lock();
        let row = conn
            .query_row(
                "SELECT idx, term, data FROM raft_log WHERE idx = ?1",
                params![index as i64],
                |r| {
                    Ok(LogEntry {
                        index: r.get::<_, i64>(0)? as u64,
                        term: r.get::<_, i64>(1)? as u64,
                        data: r.get::<_, Vec<u8>>(2)?,
                    })
                },
            )
            .optional()
            .map_err(|e| ElectionError::persistence("get", e))?;
        Ok(row)
    }

    /// Return last log index, 0 if log empty.
    pub fn last_index(&self) -> Result<u64> {
        let conn = self.conn.lock();
        let row = conn
            .query_row(
                "SELECT COALESCE(MAX(idx), 0) FROM raft_log",
                params![],
                |r| r.get::<_, i64>(0),
            )
            .map_err(|e| ElectionError::persistence("last_index", e))?;
        Ok(row as u64)
    }

    /// Return term of last log entry, 0 if log empty. 跟 Raft §5.4.1 联合.
    pub fn last_term(&self) -> Result<u64> {
        let conn = self.conn.lock();
        let row = conn
            .query_row(
                "SELECT COALESCE(MAX(term), 0) FROM raft_log",
                params![],
                |r| r.get::<_, i64>(0),
            )
            .map_err(|e| ElectionError::persistence("last_term", e))?;
        Ok(row as u64)
    }

    /// Truncate log from `from_index` (exclusive) onwards, used on leader conflict.
    /// 跟 Raft §5.3 联合 (AppendEntries consistency check).
    pub fn truncate_from(&self, from_index: u64) -> Result<()> {
        let conn = self.conn.lock();
        conn.execute(
            "DELETE FROM raft_log WHERE idx >= ?1",
            params![from_index as i64],
        )
        .map_err(|e| ElectionError::persistence("truncate_from", e))?;
        Ok(())
    }

    /// Count committed entries (跟 litestream WAL replication 联合).
    pub fn count(&self) -> Result<u64> {
        let conn = self.conn.lock();
        let row = conn
            .query_row("SELECT COUNT(*) FROM raft_log", params![], |r| {
                r.get::<_, i64>(0)
            })
            .map_err(|e| ElectionError::persistence("count", e))?;
        Ok(row as u64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    fn tmp_db_path(name: &str) -> std::path::PathBuf {
        let mut p = env::temp_dir();
        p.push(format!("kallax-election-test-{}-{}.db", name, std::process::id()));
        let _ = std::fs::remove_file(&p);
        p
    }

    #[test]
    fn test_open_persistence_schema_seeds_state() {
        let path = tmp_db_path("schema");
        let store = LogStore::open(&path).unwrap();
        let state = store.read_state().unwrap();
        assert_eq!(state.current_term, 0);
        assert_eq!(state.voted_for, None);
        assert_eq!(store.last_index().unwrap(), 0);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn test_append_and_read_entry() {
        let path = tmp_db_path("append");
        let store = LogStore::open(&path).unwrap();
        let entry = LogEntry {
            term: 1,
            index: 1,
            data: b"hello".to_vec(),
        };
        store.append(&entry).unwrap();
        let read = store.get(1).unwrap().unwrap();
        assert_eq!(read, entry);
        assert_eq!(store.last_index().unwrap(), 1);
        assert_eq!(store.last_term().unwrap(), 1);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn test_persistent_state_round_trip() {
        let path = tmp_db_path("state");
        let store = LogStore::open(&path).unwrap();
        store
            .write_state(&PersistentState {
                current_term: 5,
                voted_for: Some("node-1".to_string()),
            })
            .unwrap();
        let read = store.read_state().unwrap();
        assert_eq!(read.current_term, 5);
        assert_eq!(read.voted_for.as_deref(), Some("node-1"));
        let _ = std::fs::remove_file(&path);
    }
}
