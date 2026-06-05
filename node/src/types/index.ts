/**
 * KALLAX Core Types
 * All types follow strict TypeScript - no `any`, no `@ts-ignore`
 */

import { z } from 'zod';
import type { Result } from 'neverthrow';

// ============================================================================
// Error Types
// ============================================================================

export const KallaxErrorCode = {
  // System errors
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  CONFIG_INVALID: 'CONFIG_INVALID',
  DB_ERROR: 'DB_ERROR',
  REDIS_ERROR: 'REDIS_ERROR',
  FILE_NOT_FOUND: 'FILE_NOT_FOUND',
  PERMISSION_DENIED: 'PERMISSION_DENIED',

  // Task errors
  TASK_NOT_FOUND: 'TASK_NOT_FOUND',
  TASK_ALREADY_CLAIMED: 'TASK_ALREADY_CLAIMED',
  TASK_INVALID_STATE: 'TASK_INVALID_STATE',
  TASK_ISOLATION_CONFLICT: 'TASK_ISOLATION_CONFLICT',

  // Ticket errors
  TICKET_NOT_FOUND: 'TICKET_NOT_FOUND',
  TICKET_INVALID: 'TICKET_INVALID',

  // Instance errors
  INSTANCE_NOT_FOUND: 'INSTANCE_NOT_FOUND',
  INSTANCE_ALREADY_EXISTS: 'INSTANCE_ALREADY_EXISTS',
  INSTANCE_TIMEOUT: 'INSTANCE_TIMEOUT',

  // Worktree errors
  WORKTREE_CREATE_FAILED: 'WORKTREE_CREATE_FAILED',
  WORKTREE_NOT_FOUND: 'WORKTREE_NOT_FOUND',
  WORKTREE_CLEANUP_FAILED: 'WORKTREE_CLEANUP_FAILED',

  // Argument errors
  INVALID_ARGUMENT: 'INVALID_ARGUMENT',

  // Saga errors
  SAGA_STEP_FAILED: 'SAGA_STEP_FAILED',
  SAGA_COMPENSATE_FAILED: 'SAGA_COMPENSATE_FAILED',

  // Verification errors
  VERIFICATION_FAILED: 'VERIFICATION_FAILED',
  OUTPUT_NOT_FOUND: 'OUTPUT_NOT_FOUND',

  // Plugin errors
  PLUGIN_NOT_FOUND: 'PLUGIN_NOT_FOUND',
  PLUGIN_ALREADY_LOADED: 'PLUGIN_ALREADY_LOADED',
  PLUGIN_LOAD_FAILED: 'PLUGIN_LOAD_FAILED',
} as const;

export type KallaxErrorCode = (typeof KallaxErrorCode)[keyof typeof KallaxErrorCode];

export interface KallaxErrorContext {
  readonly code: KallaxErrorCode;
  readonly message: string;
  readonly cause?: unknown;
  readonly metadata?: Readonly<Record<string, unknown>>;
  readonly timestamp: number;
  readonly stackTrace?: string | undefined;
}

export class KallaxError extends Error {
  public readonly code: KallaxErrorCode;
  public override readonly cause?: unknown;
  public readonly metadata: Readonly<Record<string, unknown>>;
  public readonly timestamp: number;

  constructor(
    code: KallaxErrorCode,
    message: string,
    options?: {
      cause?: unknown;
      metadata?: Record<string, unknown>;
    }
  ) {
    super(message);
    this.name = 'KallaxError';
    this.code = code;
    this.cause = options?.cause;
    this.metadata = Object.freeze(options?.metadata ?? {});
    this.timestamp = Date.now();

    // Capture stack trace
    Error.captureStackTrace(this, KallaxError);
  }

  public toContext(): KallaxErrorContext {
    return {
      code: this.code,
      message: this.message,
      cause: this.cause,
      metadata: this.metadata,
      timestamp: this.timestamp,
      stackTrace: this.stack,
    };
  }

  public static fromUnknown(error: unknown, defaultCode: KallaxErrorCode = KallaxErrorCode.INTERNAL_ERROR): KallaxError {
    if (error instanceof KallaxError) {
      return error;
    }

    if (error instanceof Error) {
      return new KallaxError(defaultCode, error.message, { cause: error });
    }

    return new KallaxError(defaultCode, String(error));
  }
}

// ============================================================================
// Result Type Aliases
// ============================================================================

export type KallaxResult<T> = Result<T, KallaxError>;

// ============================================================================
// Ticket Types
// ============================================================================

export const TicketStatus = {
  BACKLOG: 'backlog',
  TODO: 'todo',
  IN_PROGRESS: 'in_progress',
  REVIEW: 'review',
  BLOCKED: 'blocked',
  DONE: 'done',
  CANCELLED: 'cancelled',
} as const;

export type TicketStatus = (typeof TicketStatus)[keyof typeof TicketStatus];

export const TicketPriority = {
  P0_CRITICAL: 'P0',
  P1_HIGH: 'P1',
  P2_MEDIUM: 'P2',
  P3_LOW: 'P3',
} as const;

export type TicketPriority = (typeof TicketPriority)[keyof typeof TicketPriority];

export const TicketSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  description: z.string(),
  status: z.nativeEnum(TicketStatus),
  priority: z.nativeEnum(TicketPriority),
  assigneeId: z.string().nullable(),
  createdAt: z.number(),
  updatedAt: z.number(),
  estimatedMinutes: z.number().optional(),
  acceptanceCriteria: z.array(z.string()),
  labels: z.array(z.string()),
  fileScope: z.array(z.string()).optional(),
  worktreePath: z.string().optional(),
  parentTicketId: z.string().optional(),
});

export type Ticket = z.infer<typeof TicketSchema>;

// ============================================================================
// Task Types
// ============================================================================

export const TaskType = {
  DEVELOPMENT: 'development',
  REVIEW: 'review',
  TESTING: 'testing',
  DOCUMENTATION: 'documentation',
  BUGFIX: 'bugfix',
  REFACTOR: 'refactor',
} as const;

export type TaskType = (typeof TaskType)[keyof typeof TaskType];

export const TaskStatus = {
  PENDING: 'pending',
  CLAIMED: 'claimed',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
} as const;

export type TaskStatus = (typeof TaskStatus)[keyof typeof TaskStatus];

export const TaskSchema = z.object({
  id: z.string().min(1),
  ticketId: z.string().min(1),
  type: z.nativeEnum(TaskType),
  status: z.nativeEnum(TaskStatus),
  performerId: z.string().nullable(),
  createdAt: z.number(),
  updatedAt: z.number(),
  startedAt: z.number().optional(),
  completedAt: z.number().optional(),
  progress: z.number().min(0).max(100),
  output: z.string().optional(),
  error: z.string().optional(),
  metadata: z.record(z.unknown()).optional(),
});

export type Task = z.infer<typeof TaskSchema>;

// ============================================================================
// Instance Types
// ============================================================================

export const InstanceRole = {
  CONDUCTOR: 'conductor',
  PERFORMER: 'performer',
} as const;

export type InstanceRole = (typeof InstanceRole)[keyof typeof InstanceRole];

export const InstanceStatus = {
  INITIALIZING: 'initializing',
  ACTIVE: 'active',
  BUSY: 'busy',
  IDLE: 'idle',
  SHUTDOWN: 'shutdown',
  ERROR: 'error',
} as const;

export type InstanceStatus = (typeof InstanceStatus)[keyof typeof InstanceStatus];

export const InstanceSchema = z.object({
  id: z.string().min(1),
  role: z.nativeEnum(InstanceRole),
  status: z.nativeEnum(InstanceStatus),
  hostname: z.string(),
  pid: z.number(),
  startedAt: z.number(),
  lastHeartbeat: z.number(),
  currentTaskId: z.string().nullable(),
  worktreePath: z.string().optional(),
  capabilities: z.array(z.string()),
  metadata: z.record(z.unknown()).optional(),
});

export type Instance = z.infer<typeof InstanceSchema>;

// ============================================================================
// Configuration Types
// ============================================================================

export const PerformerConfigSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  maxConcurrentTasks: z.number().min(1).max(10).default(1),
  capabilities: z.array(z.string()),
  worktreeBasePath: z.string(),
  pollIntervalMs: z.number().min(1000).default(5000),
  heartbeatIntervalMs: z.number().min(1000).default(10000),
  timeoutMs: z.number().min(60000).default(1800000), // 30 minutes
});

export type PerformerConfig = z.infer<typeof PerformerConfigSchema>;

export const ConductorConfigSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  maxPerformers: z.number().min(1).max(100).default(10),
  heartbeatCheckIntervalMs: z.number().min(1000).default(30000),
  staleInstanceTimeoutMs: z.number().min(60000).default(300000), // 5 minutes
  isolationCheckEnabled: z.boolean().default(true),
});

export type ConductorConfig = z.infer<typeof ConductorConfigSchema>;

export const KallaxConfigSchema = z.object({
  projectRoot: z.string().min(1),
  dataDir: z.string().default('.kallax'),
  logLevel: z.enum(['trace', 'debug', 'info', 'warn', 'error', 'fatal']).default('info'),
  redis: z.object({
    enabled: z.boolean().default(false),
    host: z.string().default('localhost'),
    port: z.number().default(6379),
    password: z.string().optional(),
    db: z.number().default(0),
  }).optional(),
  sqlite: z.object({
    path: z.string().default('kallax.db'),
  }).default({ path: 'kallax.db' }),
  conductor: ConductorConfigSchema.optional(),
  performer: PerformerConfigSchema.optional(),
});

export type KallaxConfig = z.infer<typeof KallaxConfigSchema>;

// ============================================================================
// Isolation Types
// ============================================================================

export const IsolationScopeSchema = z.object({
  taskId: z.string().min(1),
  files: z.array(z.string()),
  directories: z.array(z.string()),
  patterns: z.array(z.string()),
  exclusive: z.boolean().default(true),
});

export type IsolationScope = z.infer<typeof IsolationScopeSchema>;

export interface IsolationConflict {
  readonly taskA: string;
  readonly taskB: string;
  readonly conflictingFiles: readonly string[];
  readonly conflictingDirectories: readonly string[];
  readonly severity: 'error' | 'warning';
}

// ============================================================================
// Message Queue Types
// ============================================================================

export const MessagePriority = {
  LOW: 0,
  NORMAL: 1,
  HIGH: 2,
  CRITICAL: 3,
} as const;

export type MessagePriority = (typeof MessagePriority)[keyof typeof MessagePriority];

export const MessageSchema = z.object({
  id: z.string().min(1),
  type: z.string().min(1),
  payload: z.unknown(),
  priority: z.number().default(MessagePriority.NORMAL),
  createdAt: z.number(),
  expiresAt: z.number().optional(),
  processedAt: z.number().optional(),
  senderId: z.string().optional(),
  targetId: z.string().optional(),
});

export type Message = z.infer<typeof MessageSchema>;

// ============================================================================
// Verification Types
// ============================================================================

export const VerificationLevel = {
  L1_EXISTENCE: 1,
  L2_SUBSTANCE: 2,
  L3_WIRING: 3,
  L4_DATA_FLOW: 4,
} as const;

export type VerificationLevel = (typeof VerificationLevel)[keyof typeof VerificationLevel];

export interface VerificationResult {
  readonly taskId: string;
  readonly level: VerificationLevel;
  readonly passed: boolean;
  readonly evidence: readonly VerificationEvidence[];
  readonly timestamp: number;
}

export interface VerificationEvidence {
  readonly type: 'file' | 'git' | 'test' | 'lint';
  readonly description: string;
  readonly data: unknown;
  readonly passed: boolean;
}

// ============================================================================
// Saga Types
// ============================================================================

export interface SagaStep<TState> {
  readonly name: string;
  readonly execute: (state: TState) => Promise<TState>;
  readonly compensate: (state: TState) => Promise<void>;
}

export interface SagaExecution<TState> {
  readonly id: string;
  readonly steps: readonly SagaStep<TState>[];
  readonly state: TState;
  readonly completedSteps: readonly string[];
  readonly status: 'running' | 'completed' | 'compensating' | 'failed';
  readonly error?: KallaxError;
}

// ============================================================================
// Event Types
// ============================================================================

export const EventType = {
  // Task events
  TASK_CREATED: 'task.created',
  TASK_CLAIMED: 'task.claimed',
  TASK_STARTED: 'task.started',
  TASK_PROGRESS: 'task.progress',
  TASK_COMPLETED: 'task.completed',
  TASK_FAILED: 'task.failed',

  TASK_RELEASED: 'task.released',

  // Instance events
  INSTANCE_REGISTERED: 'instance.registered',
  INSTANCE_HEARTBEAT: 'instance.heartbeat',
  INSTANCE_SHUTDOWN: 'instance.shutdown',
  INSTANCE_TIMEOUT: 'instance.timeout',

  // System events
  SYSTEM_ERROR: 'system.error',
  SYSTEM_WARNING: 'system.warning',
} as const;

export type EventType = (typeof EventType)[keyof typeof EventType];

export interface KallaxEvent {
  readonly id: string;
  readonly type: EventType;
  readonly payload: unknown;
  readonly timestamp: number;
  readonly sourceId: string;
}

// ============================================================================
// Type Guards
// ============================================================================

export function isTicket(value: unknown): value is Ticket {
  return TicketSchema.safeParse(value).success;
}

export function isTask(value: unknown): value is Task {
  return TaskSchema.safeParse(value).success;
}

export function isInstance(value: unknown): value is Instance {
  return InstanceSchema.safeParse(value).success;
}

export function isMessage(value: unknown): value is Message {
  return MessageSchema.safeParse(value).success;
}

export function isKallaxError(value: unknown): value is KallaxError {
  return value instanceof KallaxError;
}

// ============================================================================
// Utility Types
// ============================================================================

export type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object ? DeepReadonly<T[P]> : T[P];
};

export type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

export type RequiredBy<T, K extends keyof T> = T & Required<Pick<T, K>>;
