/**
 * Test Fakes — lightweight in-memory implementations for DI testing.
 * Fakes have the same interface as real implementations but no external dependencies.
 */

import { ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket, Instance } from '../../src/types/index.js';
import type { SQLiteManager } from '../../src/core/sqlite-manager.js';

/**
 * In-memory SQLite Manager fake for unit tests.
 * Stores data in Maps instead of SQLite — fast and no native deps.
 */
export function createFakeSQLiteManager(): SQLiteManager {
  const tickets = new Map<string, Ticket>();
  const tasks = new Map<string, Task>();
  const instances = new Map<string, Instance>();

  return {
    createTicket(ticket: Ticket): KallaxResult<void> {
      tickets.set(ticket.id, ticket);
      return ok(undefined);
    },
    getTicket(id: string): KallaxResult<Ticket | null> {
      return ok(tickets.get(id) ?? null);
    },
    updateTicket(id: string, updates: Partial<Ticket>): KallaxResult<void> {
      const existing = tickets.get(id);
      if (existing) tickets.set(id, { ...existing, ...updates, updatedAt: Date.now() });
      return ok(undefined);
    },
    listTickets(filter?: Record<string, unknown>): KallaxResult<Ticket[]> {
      let result = Array.from(tickets.values());
      if (filter?.['status']) result = result.filter((t) => t.status === filter!['status']);
      if (filter?.['priority']) result = result.filter((t) => t.priority === filter!['priority']);
      if (filter?.['assigneeId']) result = result.filter((t) => t.assigneeId === filter!['assigneeId']);
      if (typeof filter?.['limit'] === 'number') result = result.slice(0, filter!['limit'] as number);
      return ok(result);
    },
    createTask(task: Task): KallaxResult<void> {
      tasks.set(task.id, task);
      return ok(undefined);
    },
    getTask(id: string): KallaxResult<Task | null> {
      return ok(tasks.get(id) ?? null);
    },
    updateTask(id: string, updates: Partial<Task>): KallaxResult<void> {
      const existing = tasks.get(id);
      if (existing) tasks.set(id, { ...existing, ...updates, updatedAt: Date.now() });
      return ok(undefined);
    },
    listTasks(filter?: Record<string, unknown>): KallaxResult<Task[]> {
      let result = Array.from(tasks.values());
      if (filter?.['status']) result = result.filter((t) => t.status === filter!['status']);
      if (filter?.['performerId']) result = result.filter((t) => t.performerId === filter!['performerId']);
      if (filter?.['ticketId']) result = result.filter((t) => t.ticketId === filter!['ticketId']);
      if (typeof filter?.['limit'] === 'number') result = result.slice(0, filter!['limit'] as number);
      return ok(result);
    },
    claimTask(taskId: string, performerId: string): KallaxResult<boolean> {
      const task = tasks.get(taskId);
      if (task && task.performerId === null && task.status === 'pending') {
        tasks.set(taskId, { ...task, performerId, status: 'claimed' as Task['status'], updatedAt: Date.now(), startedAt: Date.now() });
        return ok(true);
      }
      return ok(false);
    },
    registerInstance(instance: Instance): KallaxResult<void> {
      instances.set(instance.id, instance);
      return ok(undefined);
    },
    getInstance(id: string): KallaxResult<Instance | null> {
      return ok(instances.get(id) ?? null);
    },
    updateInstance(id: string, updates: Partial<Instance>): KallaxResult<void> {
      const existing = instances.get(id);
      if (existing) instances.set(id, { ...existing, ...updates });
      return ok(undefined);
    },
    listInstances(filter?: Record<string, unknown>): KallaxResult<Instance[]> {
      let result = Array.from(instances.values());
      if (filter?.['role']) result = result.filter((i) => i.role === filter!['role']);
      if (filter?.['status']) result = result.filter((i) => i.status === filter!['status']);
      if (typeof filter?.['limit'] === 'number') result = result.slice(0, filter!['limit'] as number);
      return ok(result);
    },
    updateHeartbeat(id: string): KallaxResult<void> {
      const existing = instances.get(id);
      if (existing) instances.set(id, { ...existing, lastHeartbeat: Date.now() });
      return ok(undefined);
    },
    getStaleInstances(thresholdMs: number): KallaxResult<Instance[]> {
      const threshold = Date.now() - thresholdMs;
      return ok(Array.from(instances.values()).filter((i) => i.lastHeartbeat < threshold && i.status !== 'shutdown'));
    },
    enqueueMessage(_message: Message): KallaxResult<void> {
      return ok(undefined);
    },
    dequeueMessage(_targetId?: string): KallaxResult<Message | null> {
      return ok(null);
    },
    peekMessages(_limit: number): KallaxResult<Message[]> {
      return ok([]);
    },
    close(): void { /* no-op */ },
    getStats() {
      return { ticketCount: tickets.size, taskCount: tasks.size, instanceCount: instances.size, messageCount: 0 };
    },
  };
}
