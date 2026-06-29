/**
 * KALLAX Hook System — barrel export.
 */

export type {
  Hook, HookContext, HookResult, HookPhase,
  CheckRule, CheckRegistry, HookDispatcher, HookStats,
} from './types.js';

export {
  createHookDispatcher, getHookDispatcher, resetHookDispatcher,
  createValidationHook, createLoggingHook,
} from './dispatcher.js';

export { createFactForcingGate } from './fact-forcing-gate.js';
export type { FactForcingConfig, VerifyLevel } from './fact-forcing-gate.js';

export { createPreBashSecurityHook, registerSecurityHooks } from './pre-bash-dispatcher.js';

export { createHookServer } from './http-hook-server.js';
export type { HookServerConfig, HookServer } from './http-hook-server.js';

export {
  createHookEventsStore,
  appendHookEvent,
  HOOK_EVENTS_DEFAULT_PATH,
} from './hook-events-store.js';
export type {
  HookEventEntry,
  HookEventInput,
  HookEventsStore,
  ReplayQuery,
} from './hook-events-store.js';
