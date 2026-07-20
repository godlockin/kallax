/**
 * KALLAX Hook Events Store — append-only audit log for hook executions.
 *
 * Writes hook events to .kallax/audit/hook-events.jsonl (one JSON object per line).
 * Each entry contains a hash-chain compatible with Track A 武器 1 audit log sink.
 *
 * Format (JSONL, one entry per line):
 *   {
 *     "ts": "2026-06-29T12:00:00.000Z",
 *     "seq": 42,                         // monotonic sequence number
 *     "prevHash": "sha256:...",          // hash of previous entry (hash-chain)
 *     "hash": "sha256:...",              // hash of this entry
 *     "sessionId": "session-abc",
 *     "hookType": "pre-tool-use",
 *     "toolName": "Bash",
 *     "resultCode": "allow|block|error",
 *     "reason": "optional",
 *     "ticketId": "optional",
 *     "performerId": "optional",
 *     "metadata": { ... }
 *   }
 *
 * The store is process-local and uses an in-process mutex to serialize writes.
 * Cross-process coordination is delegated to scripts/audit/audit-log-sink.sh
 * (Track A 武器 1) which writes to .kallax/audit/sink/*.log.
 *
 * 这里 we write to .kallax/audit/hook-events.jsonl (NOT .kallax/audit/sink/)
 * to avoid coupling. Track A 武器 1 owns the sink/ directory.
 */

import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { logger } from '../utils/logger.js';

export interface HookEventEntry {
  readonly ts: string;
  readonly seq: number;
  readonly prevHash: string;
  readonly hash: string;
  readonly sessionId: string;
  readonly hookType: string;
  readonly toolName?: string;
  readonly resultCode: 'allow' | 'block' | 'error';
  readonly reason?: string;
  readonly ticketId?: string;
  readonly performerId?: string;
  readonly metadata?: Record<string, unknown>;
}

export interface HookEventInput {
  readonly sessionId: string;
  readonly hookType: string;
  readonly toolName?: string;
  readonly resultCode: 'allow' | 'block' | 'error';
  readonly reason?: string;
  readonly ticketId?: string;
  readonly performerId?: string;
  readonly metadata?: Record<string, unknown>;
}

export interface ReplayQuery {
  readonly sessionId?: string;
  readonly fromTimestamp?: number; // ms epoch
  readonly toTimestamp?: number; // ms epoch
  readonly hookType?: string;
}

export interface HookEventsStore {
  /**
   * EPIC-084 P1-2: append 不再 export 公开
   * 公开 API 走 appendHookEvent (带 withLock 互斥)
   * 这里保留 type-level 仅给内部实现
   */
  readonly _appendInternal: (input: HookEventInput) => HookEventEntry;
  query: (q: ReplayQuery) => HookEventEntry[];
  size: () => number;
  path: () => string;
}

const DEFAULT_REL_PATH = '.kallax/audit/hook-events.jsonl';

// In-process mutex (single Node process). For multi-process safety, callers
// should use scripts/io/file-lock.sh externally — kept simple here to avoid
// coupling with Track A / B deliverables.
let writeLock: Promise<void> = Promise.resolve();

function sha256(input: string): string {
  return 'sha256:' + createHash('sha256').update(input).digest('hex');
}

function canonicalize(entry: Record<string, unknown>): string {
  // Stable JSON for hashing (sort keys at all levels)
  const keys = Object.keys(entry).sort();
  const sorted: Record<string, unknown> = {};
  for (const k of keys) {
    const v = entry[k];
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      sorted[k] = JSON.parse(canonicalize(v as Record<string, unknown>));
    } else {
      sorted[k] = v;
    }
  }
  return JSON.stringify(sorted);
}

// EPIC-082 Perf-1: 缓存最后一条 entry (避免每次 append 都 readFileSync 整个 .jsonl)
// key: filePath → last entry (seq + hash)
const lastEntryCache = new Map<string, { seq: number; hash: string } | null>();

function readLastEntry(filePath: string): { seq: number; hash: string } | null {
  // 缓存命中直接返回 (O(1))
  if (lastEntryCache.has(filePath)) {
    return lastEntryCache.get(filePath) ?? null;
  }
  // 缓存 miss → 读盘 + 解析 (O(N), 仅首次)
  if (!existsSync(filePath)) {
    lastEntryCache.set(filePath, null);
    return null;
  }
  const content = readFileSync(filePath, 'utf-8');
  const lines = content.split('\n').filter((l) => l.trim().length > 0);
  if (lines.length === 0) {
    lastEntryCache.set(filePath, null);
    return null;
  }
  const last = lines[lines.length - 1];
  if (last === undefined || last === '') {
    lastEntryCache.set(filePath, null);
    return null;
  }
  try {
    const parsed = JSON.parse(last) as { seq: number; hash: string };
    const result = { seq: parsed.seq, hash: parsed.hash };
    lastEntryCache.set(filePath, result);
    return result;
  } catch {
    lastEntryCache.set(filePath, null);
    return null;
  }
}

function updateLastEntryCache(filePath: string, entry: { seq: number; hash: string }): void {
  lastEntryCache.set(filePath, entry);
}

function readAllEntries(filePath: string): HookEventEntry[] {
  if (!existsSync(filePath)) return [];
  const content = readFileSync(filePath, 'utf-8');
  const lines = content.split('\n').filter((l) => l.trim().length > 0);
  const out: HookEventEntry[] = [];
  for (const line of lines) {
    try {
      out.push(JSON.parse(line) as HookEventEntry);
    } catch {
      // skip malformed line (should not happen if we only append valid JSON)
      logger.warn({ line: line.slice(0, 80) }, 'hook events store: skip malformed line');
    }
  }
  return out;
}

export function createHookEventsStore(
  options: { filePath?: string; projectRoot?: string } = {},
): HookEventsStore {
  const projectRoot = options.projectRoot ?? process.cwd();
  const filePath = resolve(
    projectRoot,
    options.filePath ?? DEFAULT_REL_PATH,
  );

  function ensureDir(): void {
    const dir = dirname(filePath);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true, mode: 0o700 });
    }
  }


  return {
    // EPIC-084 P1-2: 改名为 _appendInternal, 外部必须走 appendHookEvent (带 withLock 互斥)
    _appendInternal(input: HookEventInput): HookEventEntry {
      // Synchronous append within mutex (we await externally)
      const last = readLastEntry(filePath);
      const seq = last ? last.seq + 1 : 1;
      const prevHash = last ? last.hash : 'sha256:genesis';
      const ts = new Date().toISOString();

      const partial: Record<string, unknown> = {
        ts,
        seq,
        prevHash,
        sessionId: input.sessionId,
        hookType: input.hookType,
        toolName: input.toolName,
        resultCode: input.resultCode,
        reason: input.reason,
        ticketId: input.ticketId,
        performerId: input.performerId,
        metadata: input.metadata,
      };

      const hashInput = canonicalize({ ...partial, hash: undefined });
      const hash = sha256(`${prevHash}|${String(seq)}|${hashInput}`);

      const entry = {
        ts: partial['ts'] as string,
        seq: partial['seq'] as number,
        prevHash: partial['prevHash'] as string,
        sessionId: partial['sessionId'] as string,
        hookType: partial['hookType'] as string,
        toolName: partial['toolName'] as string | undefined,
        resultCode: partial['resultCode'] as 'allow' | 'block' | 'error',
        reason: partial['reason'] as string | undefined,
        ticketId: partial['ticketId'] as string | undefined,
        performerId: partial['performerId'] as string | undefined,
        metadata: partial['metadata'] as Record<string, unknown> | undefined,
        hash,
      } satisfies HookEventEntry;

      ensureDir();
      // EPIC-070-B5: 跨进程并发安全 — 用 atomic rename (tmp + rename) 替换 appendFileSync
      // appendFileSync 多进程并发会两条都拿同一 prevHash+seq 导致链断
      const tmpPath = `${filePath}.tmp.${String(process.pid)}.${String(Date.now())}`;
      const existing = existsSync(filePath) ? readFileSync(filePath, 'utf-8') : '';
      writeFileSync(tmpPath, existing + JSON.stringify(entry) + '\n', { mode: 0o600 });
      // EPIC-082 Perf-1: 更新 last entry 缓存 (避免下次 append O(N) 读盘)
      updateLastEntryCache(filePath, { seq: entry.seq, hash: entry.hash });
      renameSync(tmpPath, filePath);

      return entry;
    },

    query(q: ReplayQuery): HookEventEntry[] {
      const all = readAllEntries(filePath);
      return all.filter((e) => {
        if (q.sessionId !== undefined && e.sessionId !== q.sessionId) return false;
        if (q.hookType !== undefined && e.hookType !== q.hookType) return false;
        const tsMs = Date.parse(e.ts);
        if (q.fromTimestamp !== undefined && tsMs < q.fromTimestamp) return false;
        if (q.toTimestamp !== undefined && tsMs > q.toTimestamp) return false;
        return true;
      });
    },

    size(): number {
      return readAllEntries(filePath).length;
    },

    path(): string {
      return filePath;
    },
  };
}

/**
 * Async wrapper around append() that respects the in-process mutex.
 * Use this from async hooks to avoid interleaved writes.
 */
export async function appendHookEvent(
  store: HookEventsStore,
  input: HookEventInput,
): Promise<HookEventEntry> {
  const prev = writeLock;
  let release!: () => void;
  // EPIC-085 P1-3: writeLock rejection 死锁fix — 用 try/finally 包 prev await
  // 原: await prev 抛错 → writeLock 已设 → 后续 append 等不到 release 死锁
  // 修: try/finally 确保 release() 一定调用
  writeLock = new Promise<void>((r) => { release = r; });
  try {
    await prev;
  } catch (err: unknown) {
    release();
    throw err;
  }
  try {
    return store._appendInternal(input);
  } finally {
    release();
  }
}

export const HOOK_EVENTS_DEFAULT_PATH = DEFAULT_REL_PATH;

// Re-export join for tests that want to construct sibling paths
export { join };