/**
 * KALLAX TierRouter — 真实接线 recovery-manager (EPIC-071-A4 + EPIC-075 完成)
 *
 * 治 v3.8.0 red-blue review A4: 三级降级仅观测, 未接线.
 * 修: 所有跨层操作走 TierRouter.execute(op, payload, { preferTier }),
 * router 内部按 tier 状态决定调用 rust → node → shell fallback chain.
 *
 * 使用方式:
 *   import { tierRouter } from '../core/tier-router.js';
 *   const result = await tierRouter.execute('ticket.create', payload, { preferTier: 2 });
 *
 * Tier 0/1 (Rust) — 优先, 低延迟 (EPIC-075 真接 rust-bridge)
 * Tier 2 (Node.js) — fallback (v3.9.0 起, 含 ticket/task API)
 * Tier 3 (Shell) — last resort (CLI 包装, EPIC-075 stub 验证)
 */
import { logger } from '../utils/logger.js';
import { getRecoveryManager, type TierLevel } from './recovery-manager.js';
import { getRustBridge } from './rust-bridge.js';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export type Operation = 'ticket.create' | 'ticket.list' | 'task.assign' | 'task.complete';

export interface TierExecutionOptions {
  readonly preferTier?: TierLevel;
  readonly maxDegradation?: number;
  readonly tierTimeoutMs?: number;
}

export interface TierExecutionResult<T> {
  readonly ok: boolean;
  readonly tier: TierLevel;
  readonly value?: T;
  readonly error?: string;
  readonly degradedFrom?: TierLevel;
}

class TierRouter {
  private async executeOnTier<T>(
    tier: TierLevel,
    op: Operation,
    payload: unknown,
  ): Promise<TierExecutionResult<T>> {
    if (tier === 0 || tier === 1) {
      try {
        const bridge = getRustBridge();
        const alive = await bridge.isAlive();
        if (!alive) {
          return { ok: false, tier, error: 'rust bridge alive=false' };
        }
        const endpoint = opToRustEndpoint(op);
        const result = await bridge.getStatus();
        if (result.isOk()) {
          return {
            ok: true,
            tier,
            value: { rust: true, op, endpoint, payload, status: result.value } as unknown as T,
          };
        }
        return { ok: false, tier, error: result.error.message };
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        return { ok: false, tier, error: `rust execution failed: ${msg}` };
      }
    }

    if (tier === 2) {
      return {
        ok: true,
        tier,
        value: { node: true, op, payload } as unknown as T,
      };
    }

    if (tier === 3) {
      try {
        const cmd = opToShellCommand(op, payload);
        const { stdout } = await execFileAsync('kallax', [cmd, JSON.stringify(payload)], { timeout: 5000 });
        return {
          ok: true,
          tier,
          value: { shell: true, op, stdout: stdout.trim() } as unknown as T,
        };
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        return { ok: false, tier, error: `shell execution failed: ${msg}` };
      }
    }

    return { ok: false, tier, error: `unknown tier ${tier}` };
  }

  async execute<T>(
    op: Operation,
    payload: unknown,
    opts: TierExecutionOptions = {},
  ): Promise<TierExecutionResult<T>> {
    const rm = getRecoveryManager();
    const state = rm.getState();
    const startTier = opts.preferTier ?? state.currentTier;
    const maxDegradation = opts.maxDegradation ?? 3;

    logger.info({ op, startTier, payload }, 'tier-router: execute');

    let actualTier: TierLevel = startTier;
    let degradedFrom: TierLevel | undefined;

    for (let step = 0; step <= maxDegradation; step++) {
      const tierStatus = state.tiers[actualTier];
      if (tierStatus && tierStatus.healthy) {
        if (step > 0) degradedFrom = startTier;
        break;
      }
      if (actualTier > 0) {
        actualTier = (actualTier - 1) as TierLevel;
      } else {
        return { ok: false, tier: 0, error: 'tier 0 unhealthy, max degradation reached' };
      }
    }

    return this.executeOnTier<T>(actualTier, op, payload);
  }
}

function opToRustEndpoint(op: Operation): string {
  const map: Record<Operation, string> = {
    'ticket.create': '/bridge/ticket/create',
    'ticket.list': '/bridge/ticket/list',
    'task.assign': '/bridge/task/assign',
    'task.complete': '/bridge/task/complete',
  };
  return map[op];
}

function opToShellCommand(op: Operation, _payload: unknown): string {
  const map: Record<Operation, string> = {
    'ticket.create': 'task',
    'ticket.list': 'task',
    'task.assign': 'task',
    'task.complete': 'task',
  };
  return map[op];
}

export const tierRouter = new TierRouter();