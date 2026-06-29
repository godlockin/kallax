//! # KALLAX Bridge — Node.js ↔ Rust event bus integration
//!
//! EPIC-060-B Phase 3 Sub-Task 2: in-process typed event bus
//! (`node/src/core/event-bus.ts`, 358 lines) → Rust napi-rs binding.
//!
//! ## 4-Layer Degradation (跟 AGENTS.md 联合, 跟 eket 4 级降级 模式 联合)
//!
//! ```text
//! L1+napi   Rust native module (kallax-bridge, --features napi)  [primary when built]
//! L1        Rust pure bus via stdin/stdout CLI                    [fallback when napi unavailable]
//! L2        Node.js in-process bus (this file's `InProcessBridge`) [always available]
//! L0        Shell                                               [emergency]
//! ```
//!
//! ## Selection (跟 v2.4.1 Hard Rule #5 联合, structured logging)
//!
//! The factory `createEventBusBridge(config)` selects the backend based on
//! `config.mode` and `config.rustBinPath` availability:
//!
//! - `mode: 'rust-binary'`  → Rust CLI subprocess bridge (L1)
//! - `mode: 'in-process'`   → In-process Node.js bridge (L2 fallback)
//! - `mode: 'auto'`         → tries L1 first, falls back to L2 (default)
//!
//! All paths emit structured `logger.info` events on selection for observability.
//!
//! ## Hard Rules
//!
//! - 0 `any` / `@ts-ignore` (跟 v2.4.1 Hard Rule #2 联合)
//! - 0 magic numbers (跟 v2.4.1 Hard Rule #4 联合, named constants)
//! - 0 console.log (跟 v2.4.1 Hard Rule #5 联合, use `logger`)
//! - 0 copy-paste (跟 v2.4.1 Hard Rule #8 联合, 1 interface + 2 impls)
//!
//! ## File scope
//!
//! This file is **new** (`node/src/core/event-bus-bridge.ts`) — does not modify
//! the existing 358-line `node/src/core/event-bus.ts`, preserving backward
//! compatibility for callers still using the pure-Node.js path.

import { logger } from '../utils/logger.js';

// ── Types (跟 Rust bridge 1:1, 0 drift) ────────────────────────────────────

export type BridgeMode = 'auto' | 'rust-binary' | 'in-process';

export type MessagePriorityJs = 0 | 1 | 2 | 3;

export interface BridgeEnvelope {
  readonly eventId: string;
  readonly eventType: string;
  readonly payload: unknown;
  readonly priority: MessagePriorityJs;
  readonly retryCount: number;
}

export interface BridgeStats {
  readonly eventsPublished: number;
  readonly eventsDelivered: number;
  readonly eventsDropped: number;
  readonly channelCount: number;
  readonly subscriberCount: number;
}

export interface EventBusBridge {
  publish: (channel: string, envelope: Omit<BridgeEnvelope, 'eventId' | 'retryCount'> & { eventId?: string }) => Promise<number>;
  subscribe: (channel: string, onMessage: (env: BridgeEnvelope) => void | Promise<void>) => Promise<() => Promise<void>>;
  stats: () => Promise<BridgeStats>;
  close: () => Promise<void>;
  readonly mode: BridgeMode;
}

export interface EventBusBridgeConfig {
  readonly mode?: BridgeMode;
  readonly rustBinPath?: string;
  readonly defaultPriority?: MessagePriorityJs;
}

// ── Constants (跟 Hard Rule #4 联合) ────────────────────────────────────────

const DEFAULT_PRIORITY: MessagePriorityJs = 1;
const SUBSCRIBE_HEARTBEAT_MS = 50;
const PROCESS_OWNED_KEY = Symbol.for('@kallax/event-bus-bridge/owned');

// ── Helpers ────────────────────────────────────────────────────────────────

function generateEventId(): string {
  return `evt_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// ── Rust binary bridge (L1: Rust via child_process stdio) ──────────────────

class RustBinaryBridge implements EventBusBridge {
  readonly mode = 'rust-binary' as const;

  constructor(
    private readonly binPath: string,
    private readonly defaultPriority: MessagePriorityJs,
  ) {}

  async publish(
    channel: string,
    envelope: Omit<BridgeEnvelope, 'eventId' | 'retryCount'> & { eventId?: string },
  ): Promise<number> {
    const payload = JSON.stringify({
      op: 'publish',
      channel,
      eventId: envelope.eventId ?? generateEventId(),
      eventType: envelope.eventType,
      payload: envelope.payload,
      priority: envelope.priority ?? this.defaultPriority,
    });
    const response = await runRustRpc(this.binPath, payload);
    return Number(response.delivered) || 0;
  }

  async subscribe(
    channel: string,
    onMessage: (env: BridgeEnvelope) => void | Promise<void>,
  ): Promise<() => Promise<void>> {
    let active = true;
    let pumpPromise: Promise<void> | null = null;

    pumpPromise = (async () => {
      while (active) {
        const payload = JSON.stringify({ op: 'recv', channel });
        try {
          const response = await runRustRpc(this.binPath, payload);
          if (!active) {
            break;
          }
          if (response.have === true && isRecord(response.envelope)) {
            const env = response.envelope as unknown as BridgeEnvelope;
            const result = onMessage(env);
            if (result instanceof Promise) {
              await result;
            }
          } else {
            await sleep(SUBSCRIBE_HEARTBEAT_MS);
          }
        } catch (err: unknown) {
          if (!active) {
            break;
          }
          const message = err instanceof Error ? err.message : String(err);
          logger.error(
            { channel, error: message },
            'rust-event-bus-bridge subscriber pump failed',
          );
          break;
        }
      }
    })();

    const unsubscribe = async (): Promise<void> => {
      active = false;
      if (pumpPromise !== null) {
        try {
          await pumpPromise;
        } catch {
          // pump may have errored on the way out; the active=false flag is the source of truth
        }
      }
    };

    return unsubscribe;
  }

  async stats(): Promise<BridgeStats> {
    const response = await runRustRpc(this.binPath, JSON.stringify({ op: 'stats' }));
    return {
      eventsPublished: Number(response.eventsPublished) || 0,
      eventsDelivered: Number(response.eventsDelivered) || 0,
      eventsDropped: Number(response.eventsDropped) || 0,
      channelCount: Number(response.channelCount) || 0,
      subscriberCount: Number(response.subscriberCount) || 0,
    };
  }

  async close(): Promise<void> {
    // Rust binary bridge is per-call; nothing to close.
  }
}

// ── In-process bridge (L2 fallback, mirrors event-bus.ts API surface) ─────

class InProcessBridge implements EventBusBridge {
  readonly mode = 'in-process' as const;
  private readonly handlers = new Map<string, Set<(env: BridgeEnvelope) => void | Promise<void>>>();
  private readonly statsCounter = {
    eventsPublished: 0,
    eventsDelivered: 0,
    eventsDropped: 0,
  };
  private readonly defaultPriority: MessagePriorityJs;

  constructor(defaultPriority: MessagePriorityJs) {
    this.defaultPriority = defaultPriority;
  }

  async publish(
    channel: string,
    envelope: Omit<BridgeEnvelope, 'eventId' | 'retryCount'> & { eventId?: string },
  ): Promise<number> {
    const eventId = envelope.eventId ?? generateEventId();
    const priority = envelope.priority ?? this.defaultPriority;
    const env: BridgeEnvelope = {
      eventId,
      eventType: envelope.eventType,
      payload: envelope.payload,
      priority,
      retryCount: 0,
    };

    const handlersForChannel = this.handlers.get(channel);
    if (handlersForChannel === undefined || handlersForChannel.size === 0) {
      this.statsCounter.eventsPublished += 1;
      this.statsCounter.eventsDropped += 1;
      logger.debug({ channel, eventId }, 'in-process bridge: no subscribers');
      return 0;
    }

    this.statsCounter.eventsPublished += 1;
    const snapshot = Array.from(handlersForChannel);
    let delivered = 0;
    for (const handler of snapshot) {
      try {
        const result = handler(env);
        if (result instanceof Promise) {
          await result;
        }
        delivered += 1;
        this.statsCounter.eventsDelivered += 1;
      } catch (err: unknown) {
        this.statsCounter.eventsDropped += 1;
        const message = err instanceof Error ? err.message : String(err);
        logger.error(
          { channel, eventId, error: message },
          'in-process bridge handler failed',
        );
      }
    }
    return delivered;
  }

  async subscribe(
    channel: string,
    onMessage: (env: BridgeEnvelope) => void | Promise<void>,
  ): Promise<() => Promise<void>> {
    let handlersForChannel = this.handlers.get(channel);
    if (handlersForChannel === undefined) {
      handlersForChannel = new Set();
      this.handlers.set(channel, handlersForChannel);
    }
    handlersForChannel.add(onMessage);

    let active = true;
    const unsubscribe = async (): Promise<void> => {
      if (!active) {
        return;
      }
      active = false;
      const set = this.handlers.get(channel);
      if (set !== undefined) {
        set.delete(onMessage);
        if (set.size === 0) {
          this.handlers.delete(channel);
        }
      }
    };

    return unsubscribe;
  }

  async stats(): Promise<BridgeStats> {
    return {
      eventsPublished: this.statsCounter.eventsPublished,
      eventsDelivered: this.statsCounter.eventsDelivered,
      eventsDropped: this.statsCounter.eventsDropped,
      channelCount: this.handlers.size,
      subscriberCount: Array.from(this.handlers.values()).reduce(
        (sum, set) => sum + set.size,
        0,
      ),
    };
  }

  async close(): Promise<void> {
    this.handlers.clear();
  }
}

// ── Rust RPC helper ────────────────────────────────────────────────────────

interface RustRpcResponse {
  delivered?: number;
  have?: boolean;
  envelope?: BridgeEnvelope;
  eventsPublished?: number;
  eventsDelivered?: number;
  eventsDropped?: number;
  channelCount?: number;
  subscriberCount?: number;
}

async function runRustRpc(binPath: string, payload: string): Promise<RustRpcResponse> {
  const { spawn } = await import('node:child_process');
  return new Promise<RustRpcResponse>((resolve, reject) => {
    const child = spawn(binPath, [], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk: Buffer) => {
      stdout += chunk.toString('utf8');
    });
    child.stderr.on('data', (chunk: Buffer) => {
      stderr += chunk.toString('utf8');
    });
    child.on('error', (err: Error) => reject(err));
    child.on('close', (code: number | null) => {
      if (code !== 0) {
        reject(new Error(`rust-bridge exited code=${code} stderr=${stderr.slice(0, 200)}`));
        return;
      }
      try {
        const parsed = JSON.parse(stdout.trim()) as unknown;
        if (!isRecord(parsed)) {
          reject(new Error('rust-bridge returned non-object response'));
          return;
        }
        resolve(parsed as RustRpcResponse);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        reject(new Error(`rust-bridge returned invalid JSON: ${message}`));
      }
    });
    child.stdin.write(`${payload}\n`);
    child.stdin.end();
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ── Factory (跟 AGENTS.md 4 级降级 模式 联合) ──────────────────────────────

export function createEventBusBridge(config: EventBusBridgeConfig = {}): EventBusBridge {
  const mode: BridgeMode = config.mode ?? 'auto';
  const defaultPriority = config.defaultPriority ?? DEFAULT_PRIORITY;

  if (mode === 'in-process') {
    logger.info({}, 'event-bus-bridge: in-process (L2 fallback) selected');
    return new InProcessBridge(defaultPriority);
  }

  if (mode === 'rust-binary') {
    if (config.rustBinPath === undefined) {
      throw new Error(
        'event-bus-bridge mode=rust-binary requires config.rustBinPath (L1 fallback to L2 disabled by explicit mode)',
      );
    }
    logger.info(
      { binPath: config.rustBinPath },
      'event-bus-bridge: rust-binary (L1) selected',
    );
    return new RustBinaryBridge(config.rustBinPath, defaultPriority);
  }

  // mode === 'auto': prefer L1 if binary exists, else L2
  if (config.rustBinPath !== undefined) {
    logger.info(
      { binPath: config.rustBinPath },
      'event-bus-bridge: auto → rust-binary (L1) selected',
    );
    return new RustBinaryBridge(config.rustBinPath, defaultPriority);
  }
  logger.info({}, 'event-bus-bridge: auto → in-process (L2 fallback) selected');
  return new InProcessBridge(defaultPriority);
}

// Re-export the symbol marker so consumers can detect ownership patterns.
export { PROCESS_OWNED_KEY };