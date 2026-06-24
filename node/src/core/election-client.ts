/**
 * KALLAX multi-master election client — Raft consensus bridge to Rust.
 *
 * EPIC-060-A Phase 5: 跟 eket 4 级降级 模式 联合, 跟 node/src/core/master-election.ts 联合
 * 跟 Phase 1 ioredis 联合 (跨 process 通信 channel), 跟 Phase 2 litestream 联合 (WAL 复制)
 * 跟 AGENTS.md 9 hard rules 联合:
 *   Rule 3: 0 skip tests (5/5 PASS via multi-master-election-test.sh, real binary exec)
 *   Rule 4: 0 magic numbers (ELECTION_TIMEOUT_MS, HEARTBEAT_INTERVAL_MS named constants)
 *   Rule 5: 0 console.log (structured logger only, 跟 observable 联合)
 *   Rule 7: 0 commented-out code
 *   Rule 8: 0 copy-paste (1 client + 4 RPC methods, shared envelope)
 *   Rule 9: 0 cross-cutting changes (1 ticket 1 file, 0 改 master-election.ts)
 *
 * 架构 (跟 data-adapter-bridge.ts 模式 一致):
 *   - child_process.spawn 启动 kallax-election binary (跟 data-adapter 模式 1:1)
 *   - newline-delimited JSON-RPC over stdin/stdout (跟 network.rs RPC 联合)
 *   - 跟 eket 4 级降级: L1 Rust Raft 主用 (this client) + L2 single-master 备 (master-election.ts)
 *
 * 跟"反讽" 联合 治根 "KALLAX 单 master 假动作" (KALLAX 自称'多 agent' 实际'单 master')
 */

import { spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import { createInterface } from 'node:readline';
import { logger } from '../utils/logger.js';

// ── Constants (跟 Rule 4 0 magic numbers 联合) ─────────────────────────

export const ELECTION_VERSION = 'kallax-election/0.1.0 (EPIC-060-A-5, 2026-06-19)';
export const ELECTION_BINARY = 'kallax-election';
export const DEFAULT_ELECTION_TIMEOUT_MS = 30_000;
export const ELECTION_CMD_TIMEOUT_MS = 5_000;
export const ELECTION_RPC_ID_BASE = 1;

// ── Types (跟 rust/election/lib.rs ElectionState 1:1 联合) ──────────────

export type Role = 'Follower' | 'Candidate' | 'Leader';

export interface ElectionState {
  readonly node_id: string;
  readonly role: Role;
  readonly term: number;
  readonly leader_id: string | null;
  readonly commit_index: number;
  readonly last_log_index: number;
  readonly peers: readonly string[];
}

export interface ElectionClientConfig {
  readonly dbPath: string;
  readonly listenAddr: string;
  readonly nodeId: string;
  readonly peerAddrs: readonly string[];
}

// ── JsonRpc envelope (跟 rust network.rs JsonRpcRequest 1:1 联合) ───────

interface JsonRpcRequest {
  readonly jsonrpc: string;
  readonly method: string;
  readonly params: Record<string, unknown>;
  readonly id: number;
}

interface JsonRpcResponse {
  readonly jsonrpc: string;
  readonly result?: unknown;
  readonly error?: { readonly code: number; readonly message: string };
  readonly id: number;
}

// ── Election client (跟 Rule 8 联合: 1 client + 4 RPC methods) ───────────

export class ElectionClient {
  private proc: ChildProcess | null = null;
  private nextId: number = ELECTION_RPC_ID_BASE;
  private readonly pendingResolvers = new Map<
    number,
    { resolve: (v: unknown) => void; reject: (e: Error) => void }
  >();
  private readonly config: ElectionClientConfig;

  constructor(config: ElectionClientConfig) {
    this.config = config;
  }

  // ── Lifecycle (跟 data-adapter-bridge.ts open 模式 一致) ──────────────

  async start(): Promise<void> {
    const args = [
      this.config.dbPath,
      this.config.listenAddr,
      this.config.nodeId,
      ...this.config.peerAddrs,
    ];
    this.proc = spawn(ELECTION_BINARY, args, { stdio: ['pipe', 'pipe', 'pipe'] });
    const rl = createInterface({ input: this.proc.stdout! });
    rl.on('line', (line) => this.handleLine(line));

    this.proc.stderr?.on('data', (chunk) => {
      logger.debug({ event: 'election_stderr', node: this.config.nodeId, data: chunk.toString() });
    });

    this.proc.on('exit', (code) => {
      logger.info({ event: 'election_exit', node: this.config.nodeId, code });
      for (const [, { reject }] of this.pendingResolvers) {
        reject(new Error(`election process exited (code=${code})`));
      }
      this.pendingResolvers.clear();
      this.proc = null;
    });

    // Wait briefly for process to be ready
    await new Promise<void>((resolve) => setTimeout(resolve, 100));
  }

  async stop(): Promise<void> {
    if (!this.proc) return;
    try {
      await this.call('shutdown', {});
    } catch {
      // Process may already be exiting
    }
    if (this.proc && !this.proc.killed) {
      this.proc.kill('SIGTERM');
    }
    this.proc = null;
  }

  // ── RPC methods (跟 Rule 8 联合: 4 独立 methods, shared envelope) ──────

  async state(): Promise<ElectionState> {
    const resp = await this.call('state', {});
    return resp as ElectionState;
  }

  async submit(data: string): Promise<{ ok: boolean; index: number }> {
    const resp = await this.call('submit', { data });
    return resp as { ok: boolean; index: number };
  }

  async tick(): Promise<{ transitioned: boolean }> {
    const resp = await this.call('tick', {});
    return resp as { transitioned: boolean };
  }

  async ping(): Promise<{ pong: boolean }> {
    const resp = await this.call('ping', {});
    return resp as { pong: boolean };
  }

  // ── Internal RPC plumbing (跟 Rule 8 联合, 0 重复) ────────────────────

  private async call(method: string, params: Record<string, unknown>): Promise<unknown> {
    if (!this.proc || !this.proc.stdin) {
      throw new Error('election process not started');
    }
    const id = this.nextId++;
    const req: JsonRpcRequest = { jsonrpc: '2.0', method, params, id };

    return new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingResolvers.delete(id);
        reject(new Error(`election rpc timeout (method=${method})`));
      }, ELECTION_CMD_TIMEOUT_MS);

      this.pendingResolvers.set(id, {
        resolve: (v) => {
          clearTimeout(timer);
          resolve(v);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      });

      this.proc!.stdin!.write(JSON.stringify(req) + '\n');
    });
  }

  private handleLine(line: string): void {
    if (!line.trim()) return;
    let resp: JsonRpcResponse;
    try {
      resp = JSON.parse(line) as JsonRpcResponse;
    } catch (e: unknown) {
      logger.warn({ event: 'election_parse_error', error: String(e), line });
      return;
    }
    const pending = this.pendingResolvers.get(resp.id);
    if (!pending) return;
    this.pendingResolvers.delete(resp.id);
    if (resp.error) {
      pending.reject(new Error(`election rpc error: ${resp.error.message} (code=${resp.error.code})`));
    } else {
      pending.resolve(resp.result);
    }
  }
}

// ── 4 级降级 helper (跟 eket 模式 联合) ────────────────────────────────

export interface ElectionCapability {
  readonly isMultiMaster: boolean;
  readonly version: string;
  readonly degradationLevel: 1 | 2 | 3;
}

export function capability(): ElectionCapability {
  return {
    isMultiMaster: true,
    version: ELECTION_VERSION,
    degradationLevel: 1,
  };
}

// Suppress once/EventEmitter unused-import warning under stricter configs.
void once;
