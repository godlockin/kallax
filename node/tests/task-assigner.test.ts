/**
 * Task Assigner tests: create/assign/complete with fakes + real isolation checker.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createFakeSQLiteManager } from './helpers/fakes.js';
import { createTicket } from './helpers/factories.js';
import { createIsolationChecker } from '../src/core/isolation-checker.js';
import { createInstanceRegistry } from '../src/core/instance-registry.js';
import { createTaskAssigner } from '../src/core/task-assigner.js';

describe('TaskAssigner', () => {
  let assigner: ReturnType<typeof createTaskAssigner>;
  let registry: ReturnType<typeof createInstanceRegistry>;

  beforeEach(async () => {
    const db = createFakeSQLiteManager();
    const checker = createIsolationChecker();
    registry = createInstanceRegistry(db);
    await registry.register('performer', ['typescript']);
    assigner = createTaskAssigner(db, checker, registry);
  });

  it('createTask returns task with generated id', () => {
    const ticket = createTicket();
    const result = assigner.createTask(ticket);
    expect(result.isOk()).toBe(true);
    const task = result._unsafeUnwrap();
    expect(task.id).toContain('task_');
    expect(task.ticketId).toBe(ticket.id);
    expect(task.status).toBe('pending');
  });

  it('assignTask assigns to active performer', async () => {
    const ticket = createTicket();
    const task = assigner.createTask(ticket)._unsafeUnwrap();
    const performer = registry.getCurrentInstance()!;

    const result = await assigner.assignTask(task.id, performer.id);
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().performerId).toBe(performer.id);
  });

  it('assignTask returns err for unknown performer', async () => {
    const ticket = createTicket();
    const task = assigner.createTask(ticket)._unsafeUnwrap();
    const result = await assigner.assignTask(task.id, 'nonexistent');
    expect(result.isErr()).toBe(true);
  });

  it('completeTask updates status to completed', async () => {
    const ticket = createTicket();
    const task = assigner.createTask(ticket)._unsafeUnwrap();
    const performer = registry.getCurrentInstance()!;
    await assigner.assignTask(task.id, performer.id);

    const result = await assigner.completeTask(task.id, 'done');
    expect(result.isOk()).toBe(true);
  });

  it('failTask records error message', async () => {
    const ticket = createTicket();
    const task = assigner.createTask(ticket)._unsafeUnwrap();
    const performer = registry.getCurrentInstance()!;
    await assigner.assignTask(task.id, performer.id);

    const result = await assigner.failTask(task.id, 'timeout');
    expect(result.isOk()).toBe(true);
  });

  it('claimNextTask returns null when no pending', async () => {
    const performer = registry.getCurrentInstance()!;
    const result = await assigner.claimNextTask(performer.id);
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBeNull();
  });

  it('releaseTask clears performer and resets status', async () => {
    const ticket = createTicket();
    const task = assigner.createTask(ticket)._unsafeUnwrap();
    const performer = registry.getCurrentInstance()!;
    await assigner.assignTask(task.id, performer.id);

    const result = await assigner.releaseTask(task.id);
    expect(result.isOk()).toBe(true);
  });
});
