/**
 * KALLAX Auto-Scaler
 * Dynamic Performer scaling based on queue depth and idle count.
 * Evaluates farm state and produces scale decisions with cooldown protection.
 */

export interface ScaleConfig {
  readonly minPerformers: number;
  readonly maxPerformers: number;
  readonly targetQueueDepth: number;
  readonly scaleUpThreshold: number;
  readonly scaleDownThreshold: number;
  readonly cooldownMs: number;
}

export interface ScaleDecision {
  readonly action: 'scale_up' | 'scale_down' | 'none';
  readonly currentCount: number;
  readonly targetCount: number;
  readonly reason: string;
  readonly queueDepth: number;
  readonly idleCount: number;
}

export interface FarmState {
  readonly taskQueueDepth: number;
  readonly activePerformers: number;
  readonly idlePerformers: number;
  readonly totalPerformers: number;
}

export interface AutoScaler {
  configure(config: Partial<ScaleConfig>): void;
  evaluate(currentState: FarmState): ScaleDecision;
  getHistory(): ScaleDecision[];
  getStats(): { totalScaleUps: number; totalScaleDowns: number; lastScaleAt?: number };
}

const DEFAULT_CONFIG: ScaleConfig = {
  minPerformers: 1,
  maxPerformers: 10,
  targetQueueDepth: 5,
  scaleUpThreshold: 10,
  scaleDownThreshold: 3,
  cooldownMs: 60000,
};

export function createAutoScaler(initialConfig?: Partial<ScaleConfig>): AutoScaler {
  let config: ScaleConfig = { ...DEFAULT_CONFIG, ...initialConfig };
  const history: ScaleDecision[] = [];
  let lastScaleAt: number | undefined;
  let totalScaleUps = 0;
  let totalScaleDowns = 0;

  function configure(partial: Partial<ScaleConfig>): void {
    config = { ...config, ...partial };
  }

  function evaluate(currentState: FarmState): ScaleDecision {
    const now = Date.now();

    // Cooldown: prevent frequent scaling
    if (lastScaleAt !== undefined && now - lastScaleAt < config.cooldownMs) {
      return recordDecision({
        action: 'none',
        currentCount: currentState.totalPerformers,
        targetCount: currentState.totalPerformers,
        reason: `Cooldown active (elapsed ${String(now - lastScaleAt)}ms < ${String(config.cooldownMs)}ms)`,
        queueDepth: currentState.taskQueueDepth,
        idleCount: currentState.idlePerformers,
      });
    }

    // Scale up: queue depth exceeds threshold
    if (currentState.taskQueueDepth > config.scaleUpThreshold) {
      const desiredCount = Math.max(
        currentState.totalPerformers + 1,
        Math.ceil(currentState.taskQueueDepth / config.targetQueueDepth)
      );
      const targetCount = Math.min(desiredCount, config.maxPerformers);

      if (targetCount <= currentState.totalPerformers) {
        return recordDecision({
          action: 'none',
          currentCount: currentState.totalPerformers,
          targetCount,
          reason: `At max capacity (${String(currentState.totalPerformers)})`,
          queueDepth: currentState.taskQueueDepth,
          idleCount: currentState.idlePerformers,
        });
      }

      totalScaleUps++;
      lastScaleAt = now;
      return recordDecision({
        action: 'scale_up',
        currentCount: currentState.totalPerformers,
        targetCount,
        reason: `Queue depth ${String(currentState.taskQueueDepth)} exceeds threshold ${String(config.scaleUpThreshold)}`,
        queueDepth: currentState.taskQueueDepth,
        idleCount: currentState.idlePerformers,
      });
    }

    // Scale down: too many idle performers above minimum
    if (currentState.idlePerformers >= config.scaleDownThreshold && currentState.totalPerformers > config.minPerformers) {
      const reduceBy = Math.min(
        currentState.idlePerformers - config.scaleDownThreshold + 1,
        currentState.totalPerformers - config.minPerformers
      );
      const targetCount = Math.max(currentState.totalPerformers - Math.max(1, reduceBy), config.minPerformers);

      if (targetCount >= currentState.totalPerformers) {
        return recordDecision({
          action: 'none',
          currentCount: currentState.totalPerformers,
          targetCount,
          reason: `Cannot reduce below minimum (${String(config.minPerformers)})`,
          queueDepth: currentState.taskQueueDepth,
          idleCount: currentState.idlePerformers,
        });
      }

      totalScaleDowns++;
      lastScaleAt = now;
      return recordDecision({
        action: 'scale_down',
        currentCount: currentState.totalPerformers,
        targetCount,
        reason: `Idle performers ${String(currentState.idlePerformers)} exceeds threshold ${String(config.scaleDownThreshold)}`,
        queueDepth: currentState.taskQueueDepth,
        idleCount: currentState.idlePerformers,
      });
    }

    // Steady state: no action needed
    return recordDecision({
      action: 'none',
      currentCount: currentState.totalPerformers,
      targetCount: currentState.totalPerformers,
      reason: 'Steady state',
      queueDepth: currentState.taskQueueDepth,
      idleCount: currentState.idlePerformers,
    });
  }

  function recordDecision(raw: ScaleDecision): ScaleDecision {
    const decision: ScaleDecision = Object.freeze({ ...raw });
    history.push(decision);
    return decision;
  }

  function getHistory(): ScaleDecision[] {
    return [...history];
  }

  function getStats(): { totalScaleUps: number; totalScaleDowns: number; lastScaleAt?: number } {
    return { totalScaleUps, totalScaleDowns, lastScaleAt };
  }

  return { configure, evaluate, getHistory, getStats };
}
