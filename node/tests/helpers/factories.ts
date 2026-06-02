/**
 * Test Factories — create valid test data with minimal boilerplate.
 * Every factory returns valid objects with all required fields filled.
 */

import type { Ticket, Task, Instance, Message, TicketStatus, TicketPriority, TaskType, TaskStatus, InstanceRole, InstanceStatus } from '../../src/types/index.js';

export function createTicket(overrides?: Partial<Ticket>): Ticket {
  const now = Date.now();
  return {
    id: `TICKET-${Math.random().toString(36).slice(2, 8)}`,
    title: 'Test Ticket',
    description: 'A test ticket for unit testing',
    status: 'todo' as TicketStatus,
    priority: 'P2' as TicketPriority,
    assigneeId: null,
    createdAt: now,
    updatedAt: now,
    acceptanceCriteria: ['AC1: Should work'],
    labels: ['test'],
    ...overrides,
  };
}

export function createTask(overrides?: Partial<Task>): Task {
  const now = Date.now();
  return {
    id: `task_${Math.random().toString(36).slice(2, 8)}`,
    ticketId: `TICKET-${Math.random().toString(36).slice(2, 8)}`,
    type: 'development' as TaskType,
    status: 'pending' as TaskStatus,
    performerId: null,
    createdAt: now,
    updatedAt: now,
    progress: 0,
    ...overrides,
  };
}

export function createInstance(overrides?: Partial<Instance>): Instance {
  const now = Date.now();
  return {
    id: `inst_${Math.random().toString(36).slice(2, 8)}`,
    role: 'performer' as InstanceRole,
    status: 'active' as InstanceStatus,
    hostname: 'test-host',
    pid: 12345,
    startedAt: now,
    lastHeartbeat: now,
    currentTaskId: null,
    capabilities: ['typescript', 'node'],
    ...overrides,
  };
}

export function createMessage(overrides?: Partial<Message>): Message {
  const now = Date.now();
  return {
    id: `msg_${Math.random().toString(36).slice(2, 8)}`,
    type: 'test',
    payload: { message: 'test message' },
    priority: 1,
    createdAt: now,
    ...overrides,
  };
}
