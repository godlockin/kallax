-- EPIC-282: DSH Gap #2 双事件轨卡 D — event_seq 表 (路径 A 最小落地)
--
-- 字段:
-- - session_id: 跟 expert-invocations-queue / task-ops 对齐
-- - seq: monotonic per session (event-store assertion 保证)
-- - source_event_seqs: JSON 数组, 关联上游 SessionEvent seq (DAG 指针)
-- - payload: JSON 存 discriminated union payload
--
-- 索引:
-- - session_id + seq: range query 主路径 (DSH §2.6 replay)
-- - ts: timestamp range query (telemetry / dashboard)

CREATE TABLE IF NOT EXISTS event_seq (
  seq INTEGER NOT NULL,
  session_id TEXT NOT NULL,
  type TEXT NOT NULL,
  ts INTEGER NOT NULL,
  source_event_seqs TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_event_seq_session_ts ON event_seq(session_id, ts);
CREATE INDEX IF NOT EXISTS idx_event_seq_type ON event_seq(type);
CREATE INDEX IF NOT EXISTS idx_event_seq_created_at ON event_seq(created_at);
