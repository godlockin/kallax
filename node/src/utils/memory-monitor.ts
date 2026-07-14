/**
 * KALLAX Memory Monitor
 * Track memory usage and prevent leaks
 */

import { logger } from './logger.js';

interface MemorySnapshot {
  readonly timestamp: number;
  readonly heapUsed: number;
  readonly heapTotal: number;
  readonly external: number;
  readonly arrayBuffers: number;
  readonly rss: number;
}

interface MemoryMonitorConfig {
  readonly checkIntervalMs: number;
  readonly warningThresholdMb: number;
  readonly criticalThresholdMb: number;
  readonly maxSnapshots: number;
}

interface MemoryMonitor {
  start: () => void;
  stop: () => void;
  getSnapshot: () => MemorySnapshot;
  getHistory: () => readonly MemorySnapshot[];
  getStats: () => MemoryStats;
}

export interface MemoryStats {
  readonly current: MemorySnapshot;
  readonly min: number;
  readonly max: number;
  readonly avg: number;
  readonly trend: 'increasing' | 'decreasing' | 'stable';
}

const DEFAULT_CONFIG: MemoryMonitorConfig = {
  checkIntervalMs: 30000, // 30 seconds
  warningThresholdMb: 512,
  criticalThresholdMb: 1024,
  maxSnapshots: 100,
};

export function createMemoryMonitor(config: Partial<MemoryMonitorConfig> = {}): MemoryMonitor {
  const finalConfig: MemoryMonitorConfig = { ...DEFAULT_CONFIG, ...config };
  const snapshots: MemorySnapshot[] = [];
  let intervalId: ReturnType<typeof setInterval> | null = null;

  function takeSnapshot(): MemorySnapshot {
    const mem = process.memoryUsage();
    return {
      timestamp: Date.now(),
      heapUsed: mem.heapUsed,
      heapTotal: mem.heapTotal,
      external: mem.external,
      arrayBuffers: mem.arrayBuffers,
      rss: mem.rss,
    };
  }

  function bytesToMb(bytes: number): number {
    return Math.round((bytes / 1024 / 1024) * 100) / 100;
  }

  function checkMemory(): void {
    const snapshot = takeSnapshot();
    snapshots.push(snapshot);

    // Keep only recent snapshots
    while (snapshots.length > finalConfig.maxSnapshots) {
      snapshots.shift();
    }

    const heapUsedMb = bytesToMb(snapshot.heapUsed);
    const rssMb = bytesToMb(snapshot.rss);

    if (heapUsedMb >= finalConfig.criticalThresholdMb) {
      logger.error(
        { heapUsedMb, rssMb, threshold: finalConfig.criticalThresholdMb },
        'critical memory usage'
      );
    } else if (heapUsedMb >= finalConfig.warningThresholdMb) {
      logger.warn(
        { heapUsedMb, rssMb, threshold: finalConfig.warningThresholdMb },
        'high memory usage'
      );
    } else {
      logger.debug({ heapUsedMb, rssMb }, 'memory check');
    }
  }

  function calculateTrend(): 'increasing' | 'decreasing' | 'stable' {
    if (snapshots.length < 5) {
      return 'stable';
    }

    const recentCount = 5;
    const recent = snapshots.slice(-recentCount);
    const older = snapshots.slice(-recentCount * 2, -recentCount);

    if (older.length === 0) {
      return 'stable';
    }

    const recentAvg = recent.reduce((sum, s) => sum + s.heapUsed, 0) / recent.length;
    const olderAvg = older.reduce((sum, s) => sum + s.heapUsed, 0) / older.length;

    const changePercent = ((recentAvg - olderAvg) / olderAvg) * 100;

    if (changePercent > 10) {
      return 'increasing';
    }
    if (changePercent < -10) {
      return 'decreasing';
    }
    return 'stable';
  }

  return {
    start(): void {
      if (intervalId !== null) {
        logger.warn({}, 'memory monitor already running');
        return;
      }

      checkMemory(); // Initial check
      intervalId = setInterval(checkMemory, finalConfig.checkIntervalMs);
      logger.info({ intervalMs: finalConfig.checkIntervalMs }, 'memory monitor started');
    },

    stop(): void {
      if (intervalId !== null) {
        clearInterval(intervalId);
        intervalId = null;
        logger.info({}, 'memory monitor stopped');
      }
    },

    getSnapshot(): MemorySnapshot {
      return takeSnapshot();
    },

    getHistory(): readonly MemorySnapshot[] {
      return [...snapshots];
    },

    getStats(): MemoryStats {
      const current = takeSnapshot();

      if (snapshots.length === 0) {
        return {
          current,
          min: current.heapUsed,
          max: current.heapUsed,
          avg: current.heapUsed,
          trend: 'stable',
        };
      }

      const heapValues = snapshots.map((s) => s.heapUsed);
      const min = Math.min(...heapValues);
      const max = Math.max(...heapValues);
      const avg = heapValues.reduce((sum, v) => sum + v, 0) / heapValues.length;

      return {
        current,
        min,
        max,
        avg,
        trend: calculateTrend(),
      };
    },
  };
}

// Default singleton monitor
let defaultMonitor: MemoryMonitor | null = null;

export function getDefaultMemoryMonitor(): MemoryMonitor {
  defaultMonitor ??= createMemoryMonitor();
  return defaultMonitor;
}

/**
 * Force garbage collection if available (requires --expose-gc flag)
 */
export function forceGC(): boolean {
  const globalWithGC = global as typeof globalThis & { gc?: () => void };
  if (typeof globalWithGC.gc === 'function') {
    globalWithGC.gc();
    logger.debug({}, 'forced garbage collection');
    return true;
  }
  return false;
}
