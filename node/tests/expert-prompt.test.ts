import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, describe, expect, it } from 'vitest';
import { loadExpertPrompt } from '../src/core/expert-prompt.js';
import type { Task, Ticket } from '../src/types/index.js';

const roots: string[] = [];
const task = { id: 'TASK-277', ticketId: 'EPIC-277', metadata: {} } as Task;
const ticket = { id: 'EPIC-277', title: 'expert chain', description: 'load profile safely' } as Ticket;

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

describe('loadExpertPrompt', () => {
  it('loads profile under project .claude/agents and builds prompt', async () => {
    const root = await mkdtemp(path.join(tmpdir(), 'kallax-277-'));
    roots.push(root);
    const profilePath = path.join(root, '.claude', 'agents', 'backend.md');
    await mkdir(path.dirname(profilePath), { recursive: true });
    await writeFile(profilePath, 'Prefer tests first.', 'utf8');

    const result = await loadExpertPrompt({ projectRoot: root, resolvedExpertPath: profilePath, task, ticket });

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.prompt).toContain('Prefer tests first.');
      expect(result.value.prompt).toContain('TASK-277');
    }
  });

  it('rejects traversal outside .claude/agents before reading', async () => {
    const root = await mkdtemp(path.join(tmpdir(), 'kallax-277-'));
    roots.push(root);
    const outside = path.join(root, 'secret.md');
    await writeFile(outside, 'secret', 'utf8');

    const result = await loadExpertPrompt({
      projectRoot: root,
      resolvedExpertPath: path.join(root, '.claude', 'agents', '..', '..', 'secret.md'),
      task,
      ticket,
    });

    expect(result.isErr()).toBe(true);
  });
});
