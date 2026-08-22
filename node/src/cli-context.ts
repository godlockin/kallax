/**
 * KALLAX CLI Context — shared bootstrap state for all command registrations.
 */
import type { SQLiteManager } from './core/sqlite/index.js';
import type { WorktreeManager } from './core/worktree-manager.js';
import type { OutputVerifier } from './core/output-verifier.js';
import type { IsolationChecker } from './core/isolation-checker.js';
import type { InstanceRegistry } from './core/instance-registry.js';
import type { TaskAssigner } from './core/task-assigner.js';
import type { ExpertResolverBridge } from './core/expert-resolver-bridge.js';
import type { ExpertInvocationsQueue } from './core/expert-invocations-queue/types.js';
import type { TraceLog } from './core/span-tracer.js';
import type { GitService } from './core/git-service.js';
import type { SessionEventEmitter } from './core/event-log/index.js';

export interface AppContext {
  readonly db: SQLiteManager;
  readonly worktreeManager: WorktreeManager;
  readonly outputVerifier: OutputVerifier;
  readonly isolationChecker: IsolationChecker;
  readonly instanceRegistry: InstanceRegistry;
  readonly taskAssigner: TaskAssigner;
  readonly gitService: GitService;
  /** EPIC-277: production wiring for expert activation + trace. */
  readonly expertResolver?: ExpertResolverBridge;
  readonly expertInvocationsQueue?: ExpertInvocationsQueue;
  readonly traceLog?: TraceLog;
  /** EPIC-282 (DSH Gap #2): card-d SessionEvent 埋点. 可选, 不注入则跳过 emit. */
  readonly sessionEventEmitter?: SessionEventEmitter;
}
