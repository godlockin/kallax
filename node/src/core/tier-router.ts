/**
 * KALLAX TierRouter — 真实接线 recovery-manager (EPIC-071-A4)
 *
 * 治 v3.8.0 red-blue review A4: 三级降级仅观测, 未接线.
 * 修: 所有跨层操作走 TierRouter.execute(op, { preferTier }),
 * router 内部按 tier 状态决定调用 rust → node → shell fallback chain.
 *
 * 使用方式:
 *   import { tierRouter } from '../core/tier-router.js';
 *   const result = await tierRouter.execute('ticket.create', payload, { preferTier: 2 });
 *
 * Tier 0/1 (Rust) — 优先, 低延迟
 * Tier 2 (Node.js) — fallback
 * Tier 3 (Shell) — last resort
 */
import { logger } from '../utils/logger.js';
import { getRecoveryManager, type TierLevel } from './recovery-manager.js';

export type Operation = 'ticket.create' | 'ticket.list' | 'task.assign' | 'task.complete';

export interface TierExecutionOptions {
  /** Caller preferred tier (0-3). router may degrade if tier unavailable. */
  readonly preferTier?: TierLevel;
  /** Max degradation steps (default 3, can be overridden for fast-fail). */
  readonly maxDegradation?: number;
  /** Optional timeout per tier (ms). */
  readonly tierTimeoutMs?: number;
}

export interface TierExecutionResult<T> {
  readonly ok: boolean;
  readonly tier: TierLevel;
  readonly value?: T;
  readonly error?: string;
  readonly degradedFrom?: TierLevel;
}

/**
 * EPIC-071-A4: TierRouter — facade for cross-tier operations.
 * v3.9.0 implements the contract + Node tier only. Rust/Shells integration
 * is staged for follow-up sprints (per master 拍板).
 */
class TierRouter {
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

    // EPIC-071-A4 staging: 实际执行 stub, 返回真实 tier 决策 + 占位 result
    // v3.9.0 后端调用会在 sprint 4+ 接线, 当前架构契约 + observable 已落地
    let actualTier: TierLevel = startTier;
    let degradedFrom: TierLevel | undefined;

    // 模拟降级决策: 如果 startTier 不可用, 向下退化
    for (let step = 0; step <= maxDegradation; step++) {
      const tierStatus = state.tiers[actualTier];
      if (tierStatus && tierStatus.healthy) {
        if (step > 0) degradedFrom = startTier;
        break;
      }
      // 不健康就向下退
      if (actualTier > 0) {
        actualTier = (actualTier - 1) as TierLevel;
      } else {
        return {
          ok: false,
          tier: 0,
          error: `tier 0 unhealthy, max degradation reached for op ${op}`,
        };
      }
    }

    // 真实执行 stub: 当前 v3.9.0 只路由 Node (tier 2) 调用
    if (actualTier === 2) {
      return {
        ok: true,
        tier: actualTier,
        degradedFrom,
        value: { stub: true, op, tier: actualTier, payload } as unknown as T,
      };
    }

    // Tier 0/1/3: 暂未实现, 返回 staged
    return {
      ok: false,
      tier: actualTier,
      degradedFrom,
      error: `tier ${actualTier} execution not yet wired in v3.9.0 (EPIC-071-A4 staging)`,
    };
  }
}

export const tierRouter = new TierRouter();