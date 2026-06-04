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
