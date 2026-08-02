/**
 * KALLAX JSON Schema Validator
 * EPIC-015-D: Zod schema definitions + validation for jira/ and .kallax/instances/ JSON files.
 *
 * Schemas:
 *  - PhaseSchema      (jira/phases/{star}/phase.json)
 *  - EpicSchema       (jira/epics/{star}/epic.json, backward compat with V0)
 *  - TicketSchema     (jira/tickets/{star}/ticket.json)
 *  - StateSchema      (.kallax/instances/{star}/state.json)
 *
 * All validation functions return neverthrow Result (no thrown exceptions).
 * Types are inferred from Zod schemas -- single source of truth.
 */

import * as fs from 'node:fs';
import { z } from 'zod';
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

// ============================================================================
// Schema Version
// ============================================================================

export const SCHEMA_VERSION = '1.0.0' as const;

// ============================================================================
// PhaseSchema — jira/phases/*/phase.json
// ============================================================================

export const PhaseStatus = {
  ACTIVE: 'active',
  COMPLETED: 'completed',
  PLANNING: 'planning',
  CANCELLED: 'cancelled',
} as const;

export type PhaseStatus = (typeof PhaseStatus)[keyof typeof PhaseStatus];

export const PhaseSchema = z.object({
  id: z.string().min(1, 'phase.id is required'),
  title: z.string().min(1, 'phase.title is required'),
  scope: z.string().min(1, 'phase.scope is required'),
  epics: z.array(z.string()).default([]),
  start_time: z.string().min(1, 'phase.start_time is required'),
  delivery_time: z.string().min(1, 'phase.delivery_time is required'),
  status: z.string().min(1, 'phase.status is required'),
});

export type Phase = z.infer<typeof PhaseSchema>;

// ============================================================================
// EpicSchema — jira/epics/*/epic.json
// Backward compat: accepts both V1 (with id/phase/scope/start_time/delivery_time)
// and V0 legacy format (with epicId/createdAt, no phase/scope/times).
// ============================================================================

const EpicTicketEntrySchema = z.object({
  id: z.string().min(1),
  assignee: z.string().nullable().optional(),
  status: z.string().default('backlog'),
});

export const EpicSchema = z.object({
  // V1 fields (current format)
  id: z.string().optional(),
  phase: z.string().optional(),
  scope: z.string().optional(),
  start_time: z.string().optional(),
  delivery_time: z.string().optional(),

  // V0 legacy fields
  epicId: z.string().optional(),
  createdAt: z.string().optional(),

  // Common fields
  title: z.string().min(1, 'epic.title is required'),
  status: z.string().default('planning'),
  tickets: z.array(EpicTicketEntrySchema).default([]),
});

export type Epic = z.infer<typeof EpicSchema>;

/**
 * Normalize an epic record: map legacy fields (epicId, createdAt) to
 * current fields (id, start_time) for uniform consumption.
 */
export function normalizeEpic(epic: Epic): Epic {
  if (epic.id === undefined && epic.epicId !== undefined) {
    return { ...epic, id: epic.epicId };
  }
  return epic;
}

// ============================================================================
// TicketSchema — jira/tickets/*/ticket.json
// NOTE: Distinct from the internal TicketSchema in types/index.ts.
// This schema validates the JIRA-format ticket files used for project tracking.
// ============================================================================

export const TicketType = {
  FEATURE: 'feature',
  BUG: 'bug',
  CHORE: 'chore',
  DOCS: 'docs',
  TEST: 'test',
  REFACTOR: 'refactor',
  PERF: 'perf',
  SECURITY: 'security',
} as const;

export type TicketType = (typeof TicketType)[keyof typeof TicketType];

export const TicketPriority = {
  P0: 'P0',
  P1: 'P1',
  P2: 'P2',
  P3: 'P3',
} as const;

export type TicketPriority = (typeof TicketPriority)[keyof typeof TicketPriority];

export const TicketStatus = {
  BACKLOG: 'backlog',
  ANALYSIS: 'analysis',
  READY: 'ready',
  GATE_REVIEW: 'gate_review',
  IN_PROGRESS: 'in_progress',
  TEST: 'test',
  PR_REVIEW: 'pr_review',
  DONE: 'done',
  BLOCKED: 'blocked',
  CANCELLED: 'cancelled',
} as const;

export type TicketStatus = (typeof TicketStatus)[keyof typeof TicketStatus];

const FileScopeSchema = z.object({
  includes: z.array(z.string()).default([]),
  excludes: z.array(z.string()).default([]),
});

// ============================================================================
// ExpertBindingSchema — EPIC-157 ticket.json expert binding tracking
// 4 字段: suggested_expert (Master 拆卡建议) + actual_expert (Performer binding)
// + expert_binding_at (ISO8601 timestamp) + binding_change_reason (偏离必填)
// ============================================================================

/**
 * EPIC-157 — Allowed expert pool for binding (Master 建议 + Performer 实际).
 * Pool = 4 default (backend/frontend/ux/product) + 5 extended
 * (security-tool-bypass/process-engineering-self-verify/auditor-independent-witness/
 * compliance-rule-merge/decision-gate-complex-only) + 15 local experts
 * (从 docs/experts/data.json 引用, 此处枚举主框架高频出现的).
 *
 * 备注: 完整 15 local 在 docs/experts/data.json, 这里列代表性子集。
 * validator 接受 ExpertPool + 'custom:<name>' 任意非空字符串 (向后兼容新增 expert).
 */
export const ExpertPool = [
  // 4 default
  'backend', 'frontend', 'ux', 'product',
  // 5 extended
  'security-tool-bypass', 'process-engineering-self-verify',
  'auditor-independent-witness', 'compliance-rule-merge',
  'decision-gate-complex-only',
  // 15 local (主高频子集; 实际接受任意 'custom:<name>')
  'architect', 'sre', 'devops', 'security', 'performance',
  'database', 'aiml', 'mlops', 'data-analyst', 'tester',
  'reviewer', 'docs-writer', 'tech-lead', 'conductor', 'master',
] as const;

export type ExpertPoolMember = (typeof ExpertPool)[number];

const ExpertNameSchema = z
  .string()
  .min(1, 'expert name must be non-empty')
  .refine(
    (v) => v.startsWith('custom:') || (ExpertPool as readonly string[]).includes(v),
    { message: `expert must be one of ExpertPool (${ExpertPool.join(', ')}) or 'custom:<name>'` },
  );

const ISO8601Timestamp = z.string().refine(
  (v) => !Number.isNaN(Date.parse(v)),
  { message: 'expert_binding_at must be valid ISO8601 timestamp' },
);

export const ExpertBindingSchema = z
  .object({
    suggested_expert: ExpertNameSchema.nullable().optional(),
    actual_expert: ExpertNameSchema.nullable().optional(),
    expert_binding_at: ISO8601Timestamp.nullable().optional(),
    binding_change_reason: z.string().nullable().optional(),
  })
  .refine(
    (b) => {
      // 若 actual_expert 已填 且 suggested_expert 已填 且 两者不相等
      // → binding_change_reason 必填非空 (治 silent 改 expert)
      if (
        b.actual_expert != null
        && b.suggested_expert != null
        && b.actual_expert !== b.suggested_expert
      ) {
        return typeof b.binding_change_reason === 'string' && b.binding_change_reason.trim().length > 0;
      }
      return true;
    },
    {
      message:
        'binding_change_reason is required when actual_expert differs from suggested_expert',
      path: ['binding_change_reason'],
    },
  );

export type ExpertBinding = z.infer<typeof ExpertBindingSchema>;

export const TicketSchema = z.object({
  id: z.string().min(1, 'ticket.id is required'),
  epicId: z.string().min(1, 'ticket.epicId is required'),
  phaseId: z.string().min(1, 'ticket.phaseId is required'),
  title: z.string().min(1, 'ticket.title is required'),
  type: z.string().min(1, 'ticket.type is required'),
  priority: z.string().min(1, 'ticket.priority is required'),
  status: z.string().min(1, 'ticket.status is required'),
  created_by: z.string().min(1, 'ticket.created_by is required'),
  created_at: z.string().min(1, 'ticket.created_at is required'),
  updated_at: z.string().optional(),
  performer: z.string().nullable().optional(),
  worktree: z.string().nullable().optional(),
  dependencies: z.array(z.string()).optional(),
  file_scope: FileScopeSchema.optional(),
  acceptance_criteria: z.array(z.string()).default([]),
  estimated_hours: z.number().nonnegative().optional(),
  actual_hours: z.number().nonnegative().optional(),
  // EPIC-157 — expert binding tracking (向后兼容: 4 字段均 optional)
  expert_binding: ExpertBindingSchema.optional(),
});

export type Ticket = z.infer<typeof TicketSchema>;

// ============================================================================
// StateSchema — .kallax/instances/*/state.json
// ============================================================================

export const InstanceStatus = {
  ACTIVE: 'ACTIVE',
  STALE: 'STALE',
  SHUTDOWN: 'SHUTDOWN',
  ERROR: 'ERROR',
  IDLE: 'IDLE',
} as const;

export type InstanceStatus = (typeof InstanceStatus)[keyof typeof InstanceStatus];

export const InstanceRole = {
  CONDUCTOR: 'conductor',
  PERFORMER: 'performer',
  MASTER: 'master',
} as const;

export type InstanceRole = (typeof InstanceRole)[keyof typeof InstanceRole];

const HeartbeatSchema = z.object({
  interval_seconds: z.number().positive(),
  last_beat: z.string().min(1),
  missed_count: z.number().int().nonnegative().default(0),
});

const CurrentTaskSchema = z.object({
  ticket_id: z.string().nullable().default(null),
  worktree_path: z.string().nullable().default(null),
  progress_pct: z.number().nullable().optional(),
});

export const StateSchema = z.object({
  instance_id: z.string().min(1, 'state.instance_id is required'),
  role: z.string().min(1, 'state.role is required'),
  pid: z.number().int().positive(),
  status: z.string().min(1, 'state.status is required'),
  branch: z.string().default('unknown'),
  cwd: z.string().default(''),
  in_worktree: z.boolean().optional(),
  worktree_path: z.string().nullable().optional(),
  created_at: z.string().min(1, 'state.created_at is required'),
  started_at: z.string().optional(),
  heartbeat: HeartbeatSchema,
  current_task: CurrentTaskSchema.optional(),
});

export type State = z.infer<typeof StateSchema>;

// ============================================================================
// Validation helpers
// ============================================================================

/**
 * Read a JSON file and return its parsed content.
 */
function readJsonFile(filePath: string): KallaxResult<unknown> {
  try {
    const raw = fs.readFileSync(filePath, 'utf-8');
    return ok(JSON.parse(raw) as unknown);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return err(new KallaxError(
      KallaxErrorCode.FILE_NOT_FOUND,
      `Failed to read/parse ${filePath}: ${message}`,
      { cause: error },
    ));
  }
}

/**
 * Parse unknown data with a Zod schema, returning KallaxResult.
 * Uses z.output<TSchema> for the result type to correctly handle
 * Zod primitives like .default() whose input and output types differ.
 */
function parseWithSchema<TSchema extends z.ZodTypeAny>(
  schema: TSchema,
  data: unknown,
  label: string,
): KallaxResult<z.output<TSchema>> {
  const parsed = schema.safeParse(data);
  if (parsed.success) {
    // Zod's safeParse output type may not exactly match z.output due to
    // how Zod handles .default() internally, so cast through unknown.
    return ok(parsed.data as unknown as z.output<TSchema>);
  }

  const issues = parsed.error.issues.map((issue) =>
    `${issue.path.join('.')}: ${issue.message}`
  ).join('; ');

  return err(new KallaxError(
    KallaxErrorCode.TICKET_INVALID,
    `${label} validation failed: ${issues}`,
    { metadata: { zodIssues: parsed.error.issues } },
  ));
}

// ============================================================================
// Public Validation Functions
// Each reads a JSON file, parses it with the appropriate Zod schema,
// and returns KallaxResult. Never throws.
// ============================================================================

/**
 * Validate a phase.json file against PhaseSchema.
 */
export function validatePhase(filePath: string): KallaxResult<Phase> {
  const readResult = readJsonFile(filePath);
  if (readResult.isErr()) {
    return err(readResult.error);
  }
  return parseWithSchema(PhaseSchema, readResult.value, 'Phase');
}

/**
 * Validate an epic.json file against EpicSchema.
 * Supports both V1 (current) and V0 (legacy) formats.
 */
export function validateEpic(filePath: string): KallaxResult<Epic> {
  const readResult = readJsonFile(filePath);
  if (readResult.isErr()) {
    return err(readResult.error);
  }
  return parseWithSchema(EpicSchema, readResult.value, 'Epic');
}

/**
 * Validate a ticket.json file against TicketSchema.
 */
export function validateTicket(filePath: string): KallaxResult<Ticket> {
  const readResult = readJsonFile(filePath);
  if (readResult.isErr()) {
    return err(readResult.error);
  }
  return parseWithSchema(TicketSchema, readResult.value, 'Ticket');
}

/**
 * Validate a state.json file against StateSchema.
 */
export function validateState(filePath: string): KallaxResult<State> {
  const readResult = readJsonFile(filePath);
  if (readResult.isErr()) {
    return err(readResult.error);
  }
  return parseWithSchema(StateSchema, readResult.value, 'State');
}

// ============================================================================
// Batch Validation
// ============================================================================

export interface ValidationSummaryEntry {
  readonly filePath: string;
  readonly type: 'phase' | 'epic' | 'ticket' | 'state';
  readonly passed: boolean;
  readonly errors: readonly string[];
}

export interface ValidationSummary {
  readonly total: number;
  readonly passed: number;
  readonly failed: number;
  readonly entries: readonly ValidationSummaryEntry[];
  readonly schemaVersion: string;
}

/**
 * Run a single validation and return a summary entry (never throws).
 */
function runValidation(
  filePath: string,
  type: ValidationSummaryEntry['type'],
  validateFn: (path: string) => KallaxResult<unknown>,
): ValidationSummaryEntry {
  const result = validateFn(filePath);
  if (result.isOk()) {
    return { filePath, type, passed: true, errors: [] };
  }
  return { filePath, type, passed: false, errors: [result.error.message] };
}

/**
 * Validate a list of JSON files, returning a summary with pass/fail counts.
 * Each file is validated independently — one failure does not stop others.
 */
export function validateAll(
  phases: string[],
  epics: string[],
  tickets: string[],
  states: string[],
): ValidationSummary {
  const entries: ValidationSummaryEntry[] = [];

  for (const fp of phases) {
    entries.push(runValidation(fp, 'phase', validatePhase));
  }
  for (const fp of epics) {
    entries.push(runValidation(fp, 'epic', validateEpic));
  }
  for (const fp of tickets) {
    entries.push(runValidation(fp, 'ticket', validateTicket));
  }
  for (const fp of states) {
    entries.push(runValidation(fp, 'state', validateState));
  }

  const total = entries.length;
  const passed = entries.filter((e) => e.passed).length;
  const failed = total - passed;

  return { total, passed, failed, entries, schemaVersion: SCHEMA_VERSION };
}
