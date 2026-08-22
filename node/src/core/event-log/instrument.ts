/**
 * KALLAX SessionEvent instrumentation — DSH Gap #2 双事件轨卡 D (EPIC-282)
 *
 * 提供 `withSessionTrace` helper. 包装 async 工具调用, emit:
 *   1. card-d/trace-step   (action=start)
 *   2. card-d/expert-activation (绑定 expertId)
 *   3. card-d/trace-complete   (成功 / 失败 + 耗时)
 *
 * 跟 EPIC-277-D 现有 trace log (span-tracer.ts) 集成: 不重复, SessionEvent
 * 走 event_seq 表 + trace 走 trace_logs 表, 共用 sessionId 跨查.
 */

import type { SessionEventEmitter } from './emit.js';

export interface InstrumentOptions {
  readonly sessionId: string;
  readonly expertId: string;
  readonly step: string;
  readonly sourceEventSeqs?: readonly number[];
}

/**
 * Wrap an async 工具调用, 自动 emit SessionEvent trio (start + activation + complete).
 *
 * 用法:
 *   await withSessionTrace(emitter, ctx, {
 *     sessionId: task.sessionId,
 *     expertId: 'architect',
 *     step: 'task-cmd/claim',
 *   }, async () => { ... return result; });
 */
export async function withSessionTrace<T>(
  emitter: SessionEventEmitter,
  opts: InstrumentOptions,
  fn: () => Promise<T>,
): Promise<T> {
  const startedAt = Date.now();
  // 1. trace-step (start): 卡 D 用于"开始埋点"
  emitter.emit(opts.sessionId, {
    type: 'card-d/trace-step',
    step: `${opts.step}/start`,
    payload: { ts: startedAt },
  });
  // 2. expert-activation: 卡 D 用于"expert 触发序列" (Rule 36 #1 数据源)
  emitter.emit(opts.sessionId, {
    type: 'card-d/expert-activation',
    expertId: opts.expertId,
    sourceEventSeqs: opts.sourceEventSeqs,
  });

  try {
    const result = await fn();
    emitter.emit(opts.sessionId, {
      type: 'card-d/trace-complete',
      duration_ms: Date.now() - startedAt,
      expertId: opts.expertId,
    });
    return result;
  } catch (error: unknown) {
    emitter.emit(opts.sessionId, {
      type: 'card-d/trace-complete',
      duration_ms: Date.now() - startedAt,
      expertId: opts.expertId,
    });
    throw error;
  }
}
