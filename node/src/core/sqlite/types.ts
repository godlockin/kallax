/**
 * KALLAX SQLite Types
 * All interfaces, row types, and row mapping functions
 */

import type { KallaxResult, Task, Ticket, Instance, Message } from '../../types/index.js';

// ── Config ──────────────────────────────────────────────────────────────────

export interface SQLiteConfig {
  readonly path: string;
  readonly readonly?: boolean;
  readonly verbose?: boolean;
}

// ── Manager Interfaces ──────────────────────────────────────────────────────

export interface SQLiteManager {
  // Ticket operations
  createTicket: (ticket: Ticket) => KallaxResult<void>;
  getTicket: (id: string) => KallaxResult<Ticket | null>;
  updateTicket: (id: string, updates: Partial<Ticket>) => KallaxResult<void>;
  listTickets: (filter?: TicketFilter) => KallaxResult<Ticket[]>;

  // Task operations
  createTask: (task: Task) => KallaxResult<void>;
  getTask: (id: string) => KallaxResult<Task | null>;
  updateTask: (id: string, updates: Partial<Task>) => KallaxResult<void>;
  listTasks: (filter?: TaskFilter) => KallaxResult<Task[]>;
  claimTask: (taskId: string, performerId: string) => KallaxResult<boolean>;

  // Instance operations
  registerInstance: (instance: Instance) => KallaxResult<void>;
  getInstance: (id: string) => KallaxResult<Instance | null>;
  updateInstance: (id: string, updates: Partial<Instance>) => KallaxResult<void>;
  listInstances: (filter?: InstanceFilter) => KallaxResult<Instance[]>;
  updateHeartbeat: (id: string) => KallaxResult<void>;
  getStaleInstances: (thresholdMs: number) => KallaxResult<Instance[]>;

  // Message operations
  enqueueMessage: (message: Message) => KallaxResult<void>;
  dequeueMessage: (targetId?: string) => KallaxResult<Message | null>;
  peekMessages: (limit: number) => KallaxResult<Message[]>;

  // Async wrappers for API server
  async: SQLiteManagerAsync;

  // Lifecycle
  close: () => void;
  getStats: () => DatabaseStats;
}

export interface SQLiteManagerAsync {
  createTicket: (ticket: Ticket) => Promise<KallaxResult<void>>;
  getTicket: (id: string) => Promise<KallaxResult<Ticket | null>>;
  updateTicket: (id: string, updates: Partial<Ticket>) => Promise<KallaxResult<void>>;
  listTickets: (filter?: TicketFilter) => Promise<KallaxResult<Ticket[]>>;
  createTask: (task: Task) => Promise<KallaxResult<void>>;
  getTask: (id: string) => Promise<KallaxResult<Task | null>>;
  updateTask: (id: string, updates: Partial<Task>) => Promise<KallaxResult<void>>;
  listTasks: (filter?: TaskFilter) => Promise<KallaxResult<Task[]>>;
  claimTask: (taskId: string, performerId: string) => Promise<KallaxResult<boolean>>;
  registerInstance: (instance: Instance) => Promise<KallaxResult<void>>;
  getInstance: (id: string) => Promise<KallaxResult<Instance | null>>;
  updateInstance: (id: string, updates: Partial<Instance>) => Promise<KallaxResult<void>>;
  listInstances: (filter?: InstanceFilter) => Promise<KallaxResult<Instance[]>>;
  updateHeartbeat: (id: string) => Promise<KallaxResult<void>>;
  getStaleInstances: (thresholdMs: number) => Promise<KallaxResult<Instance[]>>;
  enqueueMessage: (message: Message) => Promise<KallaxResult<void>>;
  dequeueMessage: (targetId?: string) => Promise<KallaxResult<Message | null>>;
  peekMessages: (limit: number) => Promise<KallaxResult<Message[]>>;
  getStats: () => Promise<DatabaseStats>;
}

// ── Filter Interfaces ───────────────────────────────────────────────────────

export interface TicketFilter {
  readonly status?: string;
  readonly priority?: string;
  readonly assigneeId?: string;
  readonly limit?: number;
}

export interface TaskFilter {
  readonly status?: string;
  readonly performerId?: string;
  readonly ticketId?: string;
  readonly limit?: number;
}

export interface InstanceFilter {
  readonly role?: string;
  readonly status?: string;
  readonly limit?: number;
}

// ── Stats ───────────────────────────────────────────────────────────────────

export interface DatabaseStats {
  readonly ticketCount: number;
  readonly taskCount: number;
  readonly instanceCount: number;
  readonly messageCount: number;
}

// ── Team Collaboration Types ─────────────────────────────────────────────────

import type { Epic, Phase, ProjectTicket, TeamInstance, HeartbeatLog } from '../data-adapter/index.js';

// ── Row Types ───────────────────────────────────────────────────────────────

export interface TicketRow {
  id: string;
  title: string;
  description: string;
  status: string;
  priority: string;
  assignee_id: string | null;
  created_at: number;
  updated_at: number;
  estimated_minutes: number | null;
  acceptance_criteria: string;
  labels: string;
  file_scope: string | null;
  worktree_path: string | null;
  parent_ticket_id: string | null;
}

export interface TaskRow {
  id: string;
  ticket_id: string;
  type: string;
  status: string;
  performer_id: string | null;
  created_at: number;
  updated_at: number;
  started_at: number | null;
  completed_at: number | null;
  progress: number;
  output: string | null;
  error: string | null;
  metadata: string | null;
}

export interface InstanceRow {
  id: string;
  role: string;
  status: string;
  hostname: string;
  pid: number;
  started_at: number;
  last_heartbeat: number;
  current_task_id: string | null;
  worktree_path: string | null;
  capabilities: string;
  metadata: string | null;
}

export interface MessageRow {
  id: string;
  type: string;
  payload: string;
  priority: number;
  created_at: number;
  expires_at: number | null;
  processed_at: number | null;
  sender_id: string | null;
  target_id: string | null;
}

// ── Row Mapping Functions ───────────────────────────────────────────────────

export function rowToTicket(row: TicketRow): Ticket {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    status: row.status as Ticket['status'],
    priority: row.priority as Ticket['priority'],
    assigneeId: row.assignee_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    estimatedMinutes: row.estimated_minutes ?? undefined,
    acceptanceCriteria: JSON.parse(row.acceptance_criteria) as string[],
    labels: JSON.parse(row.labels) as string[],
    fileScope: row.file_scope !== null ? (JSON.parse(row.file_scope) as string[]) : undefined,
    worktreePath: row.worktree_path ?? undefined,
    parentTicketId: row.parent_ticket_id ?? undefined,
  };
}

export function rowToTask(row: TaskRow): Task {
  return {
    id: row.id,
    ticketId: row.ticket_id,
    type: row.type as Task['type'],
    status: row.status as Task['status'],
    performerId: row.performer_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    startedAt: row.started_at ?? undefined,
    completedAt: row.completed_at ?? undefined,
    progress: row.progress,
    output: row.output ?? undefined,
    error: row.error ?? undefined,
    metadata: row.metadata !== null ? (JSON.parse(row.metadata) as Record<string, unknown>) : undefined,
  };
}

export function rowToInstance(row: InstanceRow): Instance {
  return {
    id: row.id,
    role: row.role as Instance['role'],
    status: row.status as Instance['status'],
    hostname: row.hostname,
    pid: row.pid,
    startedAt: row.started_at,
    lastHeartbeat: row.last_heartbeat,
    currentTaskId: row.current_task_id,
    worktreePath: row.worktree_path ?? undefined,
    capabilities: JSON.parse(row.capabilities) as string[],
    metadata: row.metadata !== null ? (JSON.parse(row.metadata) as Record<string, unknown>) : undefined,
  };
}

export function rowToMessage(row: MessageRow): Message {
  return {
    id: row.id,
    type: row.type,
    payload: JSON.parse(row.payload) as unknown,
    priority: row.priority,
    createdAt: row.created_at,
    expiresAt: row.expires_at ?? undefined,
    processedAt: row.processed_at ?? undefined,
    senderId: row.sender_id ?? undefined,
    targetId: row.target_id ?? undefined,
  };
}

// ── Team Collaboration Row Types ────────────────────────────────────────────

export interface PhaseRow {
  id: string;
  title: string;
  scope: string;
  status: string;
  start_time: string | null;
  delivery_time: string | null;
}

export interface EpicRow {
  id: string;
  phase_id: string;
  title: string;
  scope: string;
  status: string;
  start_time: string | null;
  delivery_time: string | null;
}

export interface ProjectTicketRow {
  id: string;
  epic_id: string;
  title: string;
  type: string;
  priority: string;
  status: string;
  assignee: string | null;
  file_scope: string | null;
  acceptance_criteria: string;
}

export interface TeamInstanceRow {
  instance_id: string;
  role: string;
  status: string;
  branch: string | null;
  pid: number;
  heartbeat_at: number | null;
  missed_count: number;
}

export interface HeartbeatLogRow {
  id: number;
  instance_id: string;
  tick_at: number;
  status: string;
}

// ── Team Collaboration Row Mapping Functions ────────────────────────────────

export function rowToPhase(row: PhaseRow): Phase {
  return {
    id: row.id,
    title: row.title,
    scope: row.scope,
    status: row.status,
    startTime: row.start_time ?? undefined,
    deliveryTime: row.delivery_time ?? undefined,
  };
}

export function phaseToRow(phase: Phase): PhaseRow {
  return {
    id: phase.id,
    title: phase.title,
    scope: phase.scope,
    status: phase.status,
    start_time: phase.startTime ?? null,
    delivery_time: phase.deliveryTime ?? null,
  };
}

export function rowToEpic(row: EpicRow): Epic {
  return {
    id: row.id,
    phaseId: row.phase_id,
    title: row.title,
    scope: row.scope,
    status: row.status,
    startTime: row.start_time ?? undefined,
    deliveryTime: row.delivery_time ?? undefined,
  };
}

export function epicToRow(epic: Epic): EpicRow {
  return {
    id: epic.id,
    phase_id: epic.phaseId,
    title: epic.title,
    scope: epic.scope,
    status: epic.status,
    start_time: epic.startTime ?? null,
    delivery_time: epic.deliveryTime ?? null,
  };
}

export function rowToProjectTicket(row: ProjectTicketRow): ProjectTicket {
  return {
    id: row.id,
    epicId: row.epic_id,
    title: row.title,
    type: row.type,
    priority: row.priority,
    status: row.status,
    assignee: row.assignee ?? undefined,
    fileScope: row.file_scope !== null ? (JSON.parse(row.file_scope) as { includes: string[]; excludes: string[] }) : undefined,
    acceptanceCriteria: JSON.parse(row.acceptance_criteria) as string[],
  };
}

export function projectTicketToRow(ticket: ProjectTicket): ProjectTicketRow {
  return {
    id: ticket.id,
    epic_id: ticket.epicId,
    title: ticket.title,
    type: ticket.type ?? '',
    priority: ticket.priority,
    status: ticket.status,
    assignee: ticket.assignee ?? null,
    file_scope: ticket.fileScope !== undefined ? JSON.stringify(ticket.fileScope) : null,
    acceptance_criteria: JSON.stringify(ticket.acceptanceCriteria ?? []),
  };
}

export function rowToTeamInstance(row: TeamInstanceRow): TeamInstance {
  return {
    id: row.instance_id,
    role: row.role,
    status: row.status,
    branch: row.branch ?? undefined,
    pid: row.pid,
    heartbeatAt: row.heartbeat_at ?? undefined,
    missedCount: row.missed_count,
  };
}

export function teamInstanceToRow(instance: TeamInstance): TeamInstanceRow {
  return {
    instance_id: instance.id,
    role: instance.role,
    status: instance.status,
    branch: instance.branch ?? null,
    pid: instance.pid,
    heartbeat_at: instance.heartbeatAt ?? null,
    missed_count: instance.missedCount,
  };
}

export function rowToHeartbeatLog(row: HeartbeatLogRow): HeartbeatLog {
  return {
    id: row.id,
    instanceId: row.instance_id,
    tickAt: row.tick_at,
    status: row.status,
  };
}

export function heartbeatLogToRow(log: HeartbeatLog): HeartbeatLogRow {
  return {
    id: log.id,
    instance_id: log.instanceId,
    tick_at: log.tickAt,
    status: log.status,
  };
}
