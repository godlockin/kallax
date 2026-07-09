/**
 * KALLAX Rust Bridge — HTTP client to kallax-server (Rust engine).
 *
 * Uses localhost HTTP to call Rust engine modules.
 * Gracefully degrades when Rust server is unavailable.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface RustBridgeConfig {
  readonly baseUrl: string;
  readonly timeoutMs: number;
}

export interface BridgeStatus {
  readonly status: string;
  readonly modules: Record<string, unknown>;
}

export interface RustBridge {
  /** Check if Rust server is reachable and all modules are healthy. */
  getStatus: () => Promise<KallaxResult<BridgeStatus>>;
  /** Get scheduler status (ready tasks, critical path length). */
  getSchedulerStatus: () => Promise<KallaxResult<{ ready_tasks: number; critical_path_length: number }>>;
  /** Check if bridge is alive (lightweight ping). */
  isAlive: () => Promise<boolean>;
}

const DEFAULT_CONFIG: RustBridgeConfig = {
  baseUrl: 'http://127.0.0.1:3000',
  timeoutMs: 5000,
};

export function createRustBridge(config?: Partial<RustBridgeConfig>): RustBridge {
  const cfg = { ...DEFAULT_CONFIG, ...config };

  async function fetchJson<T>(path: string): Promise<KallaxResult<T>> {
    // EPIC-070-B4: 每次请求新建 AbortController, 避免闭包共享导致一次超时永久失效
    const controller = new AbortController();
    try {
      const timeout = setTimeout(() => controller.abort(), cfg.timeoutMs);
      const resp = await fetch(`${cfg.baseUrl}${path}`, {
        signal: controller.signal,
        headers: { 'Accept': 'application/json' },
      });
      clearTimeout(timeout);

      if (!resp.ok) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          `Rust server returned ${resp.status}: ${resp.statusText}`,
        ));
      }

      const data = await resp.json() as T;
      return ok(data);
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.debug({ error: msg, path }, 'rust bridge request failed');
      return err(new KallaxError(
        KallaxErrorCode.INTERNAL_ERROR,
        `Rust bridge unreachable: ${msg}`,
        { cause: error },
      ));
    }
  }

  return {
    async getStatus(): Promise<KallaxResult<BridgeStatus>> {
      return fetchJson<BridgeStatus>('/bridge/status');
    },

    async getSchedulerStatus(): Promise<KallaxResult<{ ready_tasks: number; critical_path_length: number }>> {
      return fetchJson('/bridge/scheduler');
    },

    async isAlive(): Promise<boolean> {
      const result = await fetchJson<BridgeStatus>('/bridge/status');
      return result.isOk() && result.value.status === 'ok';
    },
  };
}

// Singleton
let defaultBridge: RustBridge | null = null;

export function getRustBridge(config?: Partial<RustBridgeConfig>): RustBridge {
  if (defaultBridge === null) {
    defaultBridge = createRustBridge(config);
  }
  return defaultBridge;
}
