/**
 * KALLAX Node.js ↔ Rust data-adapter bridge (跟 EPIC-060-B Phase 3 sub-task 3 联合)
 *
 * Wraps the L1 Rust bridge (`rust/crates/kallax-bridge` / binary
 * `kallax-data-adapter`) so the Node.js side can drive Phase / Epic /
 * ProjectTicket CRUD over an IPC pipe (newline-delimited JSON). Provides the
 * same query / execute / transaction surface that the Rust side exposes and
 * that a future `#[napi]` macro can re-export in-process.
 *
 * Degradation contract (跟 eket 4 级降级 模式 联合):
 *   L1: this Rust CLI (primary)
 *   L2: better-sqlite3 (in-process fallback when the CLI fails to start)
 *
 * The bridge only enables the Rust path when:
 *   - `KALLAX_BRIDGE_ENABLED=1` is set in the environment, OR
 *   - the resolved `kallax-data-adapter` binary is found on disk.
 * Otherwise the factory returns `null` and the caller must fall back to L2.
 */

import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { logger } from '../utils/logger.js';

// ============================================================================
// Types (跟 Rust IpcRequest / IpcResponse 字段 1:1 联合, 0 drift)
// ============================================================================

export type SqlValue =
  | { type: 'Null' }
  | { type: 'Integer'; value: number }
  | { type: 'Real'; value: number }
  | { type: 'Text'; value: string }
  | { type: 'Blob'; value: string };

export interface BridgeRow {
  columns: string[];
  values: SqlValue[];
}

export interface PoolStats {
  max_size: number;
  size: number;
  idle: number;
  waiting: number;
}

export type TxOperation =
  | { op: 'execute'; sql: string; params: SqlValue[] }
  | { op: 'query'; sql: string; params: SqlValue[] };

export type TxResult =
  | { kind: 'execute'; changes: number }
  | { kind: 'query'; rows: BridgeRow[] };

export interface TransactionOutcome {
  results: TxResult[];
}

export type IpcKind = 'query' | 'execute' | 'transaction' | 'pool_stats' | 'ping';

export interface IpcRequest {
  id: number;
  kind: IpcKind;
  sql?: string;
  params?: SqlValue[];
  ops?: TxOperation[];
}

export interface IpcResponse {
  id: number;
  ok: boolean;
  value?: unknown;
  error?: {
    variant: string;
    operation?: string;
    message: string;
  };
}

// ============================================================================
// Constants (跟 Rule 4 0 magic numbers 联合)
// ============================================================================

/**
 * Default path to the Rust CLI relative to this module.
 * repo-root/rust/target/debug/kallax-data-adapter
 */
const REPO_ROOT_FROM_NODE = '../../../';
const CLI_BIN_NAME = 'kallax-data-adapter';
const DEBUG_BUILD_SUBDIR = 'rust/target/debug';
const RELEASE_BUILD_SUBDIR = 'rust/target/release';

/** Process startup timeout (ms). Bridge must respond to `ping` within this window. */
const BRIDGE_STARTUP_TIMEOUT_MS = 5_000;

/** Per-request IPC timeout (ms). One query must complete within this window. */
const BRIDGE_REQUEST_TIMEOUT_MS = 30_000;

/** Default path under the repo root used when no explicit override is supplied. */
const FALLBACK_DB_PATH = '.kallax/kallax.db';

// ============================================================================
// Helpers
// ============================================================================

/**
 * Resolve the absolute path of the Rust CLI binary.
 *
 * Walks up from this file to the repo root and picks `debug` first, then
 * `release`. Returns `null` if the binary has not been built yet — the
 * factory uses that to fall back to better-sqlite3.
 */
function resolveBridgeBinary(): string | null {
  const here = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(here, REPO_ROOT_FROM_NODE);
  for (const sub of [DEBUG_BUILD_SUBDIR, RELEASE_BUILD_SUBDIR]) {
    const candidate = resolve(repoRoot, sub, CLI_BIN_NAME);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

// ============================================================================
// Bridge client
// ============================================================================

/**
 * Long-lived Rust bridge process. Owns one child process per logical
 * database file and reuses it across queries. Closes cleanly on `close()`.
 */
export class DataAdapterBridge {
  private readonly child: ChildProcess;
  private readonly dbPath: string;
  private nextId = 1;
  private readonly pending = new Map<
    number,
    { resolve: (value: IpcResponse) => void; reject: (reason: Error) => void; timer: NodeJS.Timeout }
  >();
  private buffer = '';
  private readonly binaryPath: string;
  private closed = false;

  private constructor(child: ChildProcess, dbPath: string, binaryPath: string) {
    this.child = child;
    this.dbPath = dbPath;
    this.binaryPath = binaryPath;
    this.attachStdio();
  }

  /**
   * Spawn a Rust bridge against `dbPath`. Returns `null` when the binary is
   * not available — caller must fall back to better-sqlite3.
   */
  static open(dbPath: string): DataAdapterBridge | null {
    const bin = resolveBridgeBinary();
    if (!bin) {
      logger.warn(
        { dbPath, searchedAt: [DEBUG_BUILD_SUBDIR, RELEASE_BUILD_SUBDIR] },
        'data-adapter-bridge: rust cli not found, falling back to better-sqlite3',
      );
      return null;
    }
    let child: ChildProcess;
    try {
      child = spawn(bin, [dbPath], { stdio: ['pipe', 'pipe', 'pipe'] });
    } catch (e: unknown) {
      logger.warn({ dbPath, err: serializeError(e) }, 'data-adapter-bridge: spawn failed');
      return null;
    }
    return new DataAdapterBridge(child, dbPath, bin);
  }

  /** Read-only accessor for the resolved binary path (used by tests). */
  get bridgeBinaryPath(): string {
    return this.binaryPath;
  }

  /** Read-only accessor for the bound database path. */
  get databasePath(): string {
    return this.dbPath;
  }

  /** Liveness probe — `true` if the bridge responded to `ping`. */
  async ping(): Promise<boolean> {
    const resp = await this.send({ id: this.claimId(), kind: 'ping' });
    return resp.ok === true && resp.value === true;
  }

  /** Run a parameterised SELECT. */
  async query(sql: string, params: SqlValue[] = []): Promise<BridgeRow[]> {
    const resp = await this.send({ id: this.claimId(), kind: 'query', sql, params });
    if (!resp.ok) throw new BridgeError('query', resp);
    return (resp.value as BridgeRow[]) ?? [];
  }

  /** Run a parameterised INSERT / UPDATE / DELETE; returns rows changed. */
  async execute(sql: string, params: SqlValue[] = []): Promise<number> {
    const resp = await this.send({ id: this.claimId(), kind: 'execute', sql, params });
    if (!resp.ok) throw new BridgeError('execute', resp);
    return Number(resp.value ?? 0);
  }

  /** Atomic transaction over a batch of operations. */
  async transaction(ops: TxOperation[]): Promise<TransactionOutcome> {
    if (ops.length === 0) {
      throw new Error('data-adapter-bridge: empty transaction operations');
    }
    const resp = await this.send({ id: this.claimId(), kind: 'transaction', ops });
    if (!resp.ok) throw new BridgeError('transaction', resp);
    return resp.value as TransactionOutcome;
  }

  /** Current pool health. */
  async poolStats(): Promise<PoolStats> {
    const resp = await this.send({ id: this.claimId(), kind: 'pool_stats' });
    if (!resp.ok) throw new BridgeError('pool_stats', resp);
    return resp.value as PoolStats;
  }

  /** Close the bridge (terminates the child process). */
  close(): void {
    if (this.closed) return;
    this.closed = true;
    for (const [, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(new Error('data-adapter-bridge: closed'));
    }
    this.pending.clear();
    this.child.kill();
  }

  // ── private ────────────────────────────────────────────────────────────

  private claimId(): number {
    const id = this.nextId;
    this.nextId += 1;
    return id;
  }

  private send(req: IpcRequest): Promise<IpcResponse> {
    return new Promise<IpcResponse>((resolveFn, rejectFn) => {
      const timer = setTimeout(() => {
        this.pending.delete(req.id);
        rejectFn(new Error(`data-adapter-bridge: request ${req.id} (${req.kind}) timed out after ${BRIDGE_REQUEST_TIMEOUT_MS}ms`));
      }, BRIDGE_REQUEST_TIMEOUT_MS);
      this.pending.set(req.id, { resolve: resolveFn, reject: rejectFn, timer });
      const line = JSON.stringify(req);
      this.child.stdin?.write(line + '\n');
    });
  }

  private attachStdio(): void {
    this.child.stdout?.setEncoding('utf-8');
    this.child.stdout?.on('data', (chunk: string) => this.onStdout(chunk));
    this.child.stderr?.setEncoding('utf-8');
    this.child.stderr?.on('data', (chunk: string) => {
      logger.warn({ bridgeDbPath: this.dbPath, stderr: chunk.trim() }, 'data-adapter-bridge stderr');
    });
    this.child.on('exit', (code, signal) => {
      const reason = `bridge exited code=${code} signal=${signal ?? 'null'}`;
      for (const [, pending] of this.pending) {
        clearTimeout(pending.timer);
        pending.reject(new Error(`data-adapter-bridge: ${reason}`));
      }
      this.pending.clear();
    });
    this.child.on('error', (e) => {
      logger.error({ err: serializeError(e), bridgeDbPath: this.dbPath }, 'data-adapter-bridge process error');
    });
  }

  private onStdout(chunk: string): void {
    this.buffer += chunk;
    let nl: number;
    while ((nl = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, nl).trim();
      this.buffer = this.buffer.slice(nl + 1);
      if (!line) continue;
      let parsed: IpcResponse;
      try {
        parsed = JSON.parse(line) as IpcResponse;
      } catch (e: unknown) {
        logger.warn({ err: serializeError(e), raw: line.slice(0, 200) }, 'data-adapter-bridge: malformed ipc line');
        continue;
      }
      const pending = this.pending.get(parsed.id);
      if (!pending) continue;
      this.pending.delete(parsed.id);
      clearTimeout(pending.timer);
      pending.resolve(parsed);
    }
  }
}

// ============================================================================
// Error type
// ============================================================================

export class BridgeError extends Error {
  readonly variant: string;
  readonly operation?: string;

  constructor(label: string, resp: IpcResponse) {
    const err = resp.error;
    const detail = err ? `${err.variant}: ${err.message}` : 'unknown bridge error';
    super(`data-adapter-bridge ${label} failed: ${detail}`);
    this.variant = err?.variant ?? 'unknown';
    this.operation = err?.operation;
    this.name = 'BridgeError';
  }
}

// ============================================================================
// Factory
// ============================================================================

export interface BridgeOptions {
  /** Override the auto-detected CLI binary path (mainly for tests). */
  readonly cliPath?: string;
  /** Skip the L1 Rust path entirely (forces L2 better-sqlite3 fallback). */
  readonly disableRust?: boolean;
}

/**
 * Attempt to open a Rust-backed bridge. Returns `null` if the CLI is not
 * available so the caller can transparently fall back to better-sqlite3.
 */
export function createDataAdapterBridge(
  dbPath: string = FALLBACK_DB_PATH,
  opts: BridgeOptions = {},
): DataAdapterBridge | null {
  if (opts.disableRust) return null;
  if (process.env['KALLAX_BRIDGE_ENABLED'] === '0') return null;
  return DataAdapterBridge.open(dbPath);
}

function serializeError(e: unknown): { message: string; name: string } {
  if (e instanceof Error) return { message: e.message, name: e.name };
  return { message: String(e), name: 'UnknownError' };
}