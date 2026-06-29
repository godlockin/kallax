/**
 * KALLAX HookDispatcher — chain execution with priority ordering and stats.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type {
  Hook, HookContext, HookResult, HookPhase,
  CheckRule, CheckRegistry, HookDispatcher, HookStats,
} from './types.js';
import {
  appendHookEvent,
  createHookEventsStore,
  type HookEventsStore,
} from './hook-events-store.js';

// ── CheckRegistry ──────────────────────────────────────────────────────────

export function createCheckRegistry(): CheckRegistry {
  const rules = new Map<string, CheckRule>();

  return {
    register(rule: CheckRule): void {
      rules.set(rule.name, rule);
      logger.debug({ ruleName: rule.name, phase: rule.phase }, 'check rule registered');
    },

    unregister(name: string): void {
      rules.delete(name);
      logger.debug({ ruleName: name }, 'check rule unregistered');
    },

    getRules(phase: HookPhase): CheckRule[] {
      return Array.from(rules.values())
        .filter((r) => r.phase === phase)
        .sort((a, b) => (a.severity === 'error' ? -1 : 1) - (b.severity === 'error' ? -1 : 1));
    },

    listRules(): CheckRule[] {
      return Array.from(rules.values());
    },
  };
}

// ── HookDispatcher ─────────────────────────────────────────────────────────

export function createHookDispatcher(
  checkRegistry?: CheckRegistry,
  auditStore?: HookEventsStore,
): HookDispatcher {
  const hooks = new Map<string, Hook>();
  const recentResults: HookStats['recentResults'] = [];
  const MAX_RECENT = 50;
  const checkReg = checkRegistry ?? createCheckRegistry();
  const audit = auditStore ?? null; // default: no audit (opt-in by caller via http-hook-server)

  function recordAudit(
    ctx: HookContext,
    resultCode: 'allow' | 'block' | 'error',
    reason?: string,
  ): void {
    if (!audit) return;
    // Fire-and-forget; failures must not break hook execution
    appendHookEvent(audit, {
      sessionId: ctx.sessionId ?? 'unknown',
      hookType: ctx.phase,
      toolName: ctx.toolName,
      resultCode,
      reason,
      ticketId: ctx.ticketId,
      performerId: ctx.performerId,
      metadata: ctx.metadata,
    }).catch((err: unknown) => {
      logger.warn({
        error: err instanceof Error ? err.message : String(err),
        phase: ctx.phase,
      }, 'hook audit append failed');
    });
  }

  function recordResult(hook: string, phase: HookPhase, allowed: boolean): void {
    recentResults.push({ hook, phase, allowed, timestamp: Date.now() });
    if (recentResults.length > MAX_RECENT) {
      recentResults.shift();
    }
  }

  async function runChecks(ctx: HookContext): Promise<KallaxResult<HookResult>> {
    const rules = checkReg.getRules(ctx.phase);
    const errors: string[] = [];
    const warnings: string[] = [];

    for (const rule of rules) {
      try {
        const result = await rule.check(ctx);
        if (result.isErr()) {
          logger.error({ ruleName: rule.name, error: result.error.message }, 'check rule failed');
          if (rule.severity === 'error') {
            errors.push(`${rule.name}: ${result.error.message}`);
          } else {
            warnings.push(`${rule.name}: ${result.error.message}`);
          }
        } else if (!result.value) {
          const msg = `${rule.name}: ${rule.message}`;
          if (rule.severity === 'error') {
            errors.push(msg);
          } else {
            warnings.push(msg);
          }
        }
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        logger.error({ ruleName: rule.name, error: msg }, 'check rule threw');
        if (rule.severity === 'error') {
          errors.push(`${rule.name}: ${msg}`);
        } else {
          warnings.push(`${rule.name}: ${msg}`);
        }
      }
    }

    if (errors.length > 0) {
      return ok({ allowed: false, reason: errors.join('; '), warnings });
    }

    return ok({ allowed: true, warnings: warnings.length > 0 ? warnings : undefined });
  }

  return {
    register(hook: Hook): void {
      hooks.set(hook.name, hook);
      logger.debug({ hookName: hook.name, phases: hook.phases }, 'hook registered');
    },

    unregister(name: string): void {
      hooks.delete(name);
      logger.debug({ hookName: name }, 'hook unregistered');
    },

    async execute(ctx: HookContext): Promise<KallaxResult<HookResult>> {
      // Phase 1: Run check rules first (fail-fast on errors)
      const checkResult = await runChecks(ctx);
      if (checkResult.isErr()) {
        recordAudit(ctx, 'error', checkResult.error.message);
        return checkResult;
      }
      if (!checkResult.value.allowed) {
        recordAudit(ctx, 'block', checkResult.value.reason);
        return checkResult;
      }

      // Phase 2: Run hooks for this phase, sorted by priority
      const phaseHooks = Array.from(hooks.values())
        .filter((h) => h.phases.includes(ctx.phase))
        .sort((a, b) => a.priority - b.priority);

      let currentParams = ctx.toolParams;
      const allWarnings: string[] = checkResult.value.warnings ?? [];
      const mergedMetadata: Record<string, unknown> = {};

      for (const hook of phaseHooks) {
        try {
          const hookCtx: HookContext = {
            ...ctx,
            toolParams: currentParams,
            metadata: { ...ctx.metadata, ...mergedMetadata },
          };

          const result = await hook.execute(hookCtx);

          if (result.isErr()) {
            logger.error({ hookName: hook.name, error: result.error.message }, 'hook execution failed');
            recordResult(hook.name, ctx.phase, false);
            const reason = `${hook.name}: ${result.error.message}`;
            recordAudit(ctx, 'error', reason);
            return ok({
              allowed: false,
              reason,
              warnings: allWarnings,
            });
          }

          const hr = result.value;
          if (!hr.allowed) {
            recordResult(hook.name, ctx.phase, false);
            const reason = hr.reason ?? `${hook.name}: blocked`;
            recordAudit(ctx, 'block', reason);
            return ok({
              allowed: false,
              reason,
              warnings: [...allWarnings, ...(hr.warnings ?? [])],
            });
          }

          // Merge modifications
          if (hr.modifiedParams) {
            currentParams = { ...currentParams, ...hr.modifiedParams };
          }
          if (hr.warnings) {
            allWarnings.push(...hr.warnings);
          }
          if (hr.metadata) {
            Object.assign(mergedMetadata, hr.metadata);
          }

          recordResult(hook.name, ctx.phase, true);
        } catch (error: unknown) {
          const msg = error instanceof Error ? error.message : String(error);
          logger.error({ hookName: hook.name, error: msg }, 'hook threw unhandled error');
          recordResult(hook.name, ctx.phase, false);
          const reason = `${hook.name}: ${msg}`;
          recordAudit(ctx, 'error', reason);
          return ok({
            allowed: false,
            reason,
            warnings: allWarnings,
          });
        }
      }

      const finalResult: HookResult = {
        allowed: true,
        modifiedParams: currentParams,
        warnings: allWarnings.length > 0 ? allWarnings : undefined,
        metadata: Object.keys(mergedMetadata).length > 0 ? mergedMetadata : undefined,
      };
      recordAudit(ctx, 'allow', undefined);
      return ok(finalResult);
    },

    getHooks(phase: HookPhase): Hook[] {
      return Array.from(hooks.values())
        .filter((h) => h.phases.includes(phase))
        .sort((a, b) => a.priority - b.priority);
    },

    listHooks(): Hook[] {
      return Array.from(hooks.values());
    },
  };
}

// ── Built-in Hooks ─────────────────────────────────────────────────────────

/**
 * Validation hook — validates tool parameters against a schema.
 */
export function createValidationHook(
  name: string,
  phases: HookPhase[],
  validator: (ctx: HookContext) => KallaxResult<boolean>,
  message: string,
  priority = 10,
): Hook {
  return {
    name: `validate:${name}`,
    phases,
    priority,
    async execute(ctx: HookContext) {
      const result = validator(ctx);
      if (result.isErr()) {
        return ok({ allowed: false, reason: result.error.message });
      }
      if (!result.value) {
        return ok({ allowed: false, reason: message });
      }
      return ok({ allowed: true });
    },
  };
}

/**
 * Logging hook — logs all tool use for audit trail.
 */
export function createLoggingHook(phases: HookPhase[]): Hook {
  return {
    name: 'audit:logging',
    phases,
    priority: 100, // run last
    async execute(ctx: HookContext) {
      logger.info({
        phase: ctx.phase,
        toolName: ctx.toolName,
        ticketId: ctx.ticketId,
        performerId: ctx.performerId,
      }, 'hook audit');
      return ok({ allowed: true });
    },
  };
}

// ── Default Dispatcher ─────────────────────────────────────────────────────

let defaultDispatcher: HookDispatcher | null = null;

export function getHookDispatcher(): HookDispatcher {
  if (defaultDispatcher === null) {
    defaultDispatcher = createHookDispatcher();
  }
  return defaultDispatcher;
}

export function resetHookDispatcher(): void {
  defaultDispatcher = null;
}
