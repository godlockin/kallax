/**
 * KALLAX Hook System Types
 */

import type { KallaxResult } from '../types/index.js';

export type HookPhase =
  | 'pre-tool-use'
  | 'post-tool-use'
  | 'pre-compact'
  | 'post-compact'
  | 'pre-permission'
  | 'post-permission'
  | 'session-start'
  | 'session-end'
  | 'task-claim'
  | 'task-complete';

export interface HookContext {
  readonly phase: HookPhase;
  readonly toolName?: string;
  readonly toolParams?: Record<string, unknown>;
  readonly ticketId?: string;
  readonly performerId?: string;
  readonly sessionId?: string;
  readonly metadata: Record<string, unknown>;
}

export interface HookResult {
  readonly allowed: boolean;
  readonly reason?: string;
  readonly modifiedParams?: Record<string, unknown>;
  readonly warnings?: string[];
  readonly metadata?: Record<string, unknown>;
}

export interface Hook {
  readonly name: string;
  readonly phases: HookPhase[];
  readonly execute: (ctx: HookContext) => Promise<KallaxResult<HookResult>>;
  readonly priority: number; // lower = runs first
}

export interface CheckRule {
  readonly name: string;
  readonly description: string;
  readonly phase: HookPhase;
  readonly check: (ctx: HookContext) => Promise<KallaxResult<boolean>>;
  readonly severity: 'error' | 'warning';
  readonly message: string;
}

export interface CheckRegistry {
  register: (rule: CheckRule) => void;
  unregister: (name: string) => void;
  getRules: (phase: HookPhase) => CheckRule[];
  listRules: () => CheckRule[];
}

export interface HookDispatcher {
  register: (hook: Hook) => void;
  unregister: (name: string) => void;
  execute: (ctx: HookContext) => Promise<KallaxResult<HookResult>>;
  getHooks: (phase: HookPhase) => Hook[];
  listHooks: () => Hook[];
}

export interface HookStats {
  readonly totalHooks: number;
  readonly totalChecks: number;
  readonly hooksByPhase: Record<string, number>;
  readonly checksByPhase: Record<string, number>;
  readonly recentResults: Array<{ hook: string; phase: HookPhase; allowed: boolean; timestamp: number }>;
}
