import { promises as fs } from 'node:fs';
import path from 'node:path';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

export interface ExpertPromptContext {
  readonly profilePath: string;
  readonly profile: string;
  readonly prompt: string;
}

export interface ExpertPromptInput {
  readonly projectRoot: string;
  readonly resolvedExpertPath: string;
  readonly task: Task;
  readonly ticket: Ticket;
}

function isInside(parent: string, candidate: string): boolean {
  const relative = path.relative(parent, candidate);
  return relative === '' || (relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative));
}

export async function loadExpertPrompt(
  input: ExpertPromptInput,
): Promise<KallaxResult<ExpertPromptContext>> {
  const agentsRoot = path.resolve(input.projectRoot, '.claude', 'agents');
  const requestedPath = path.resolve(input.resolvedExpertPath);
  if (!isInside(agentsRoot, requestedPath)) {
    return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Expert profile path is outside .claude/agents', {
      metadata: { resolvedExpertPath: input.resolvedExpertPath },
    }));
  }

  try {
    const [realAgentsRoot, realProfilePath] = await Promise.all([
      fs.realpath(agentsRoot),
      fs.realpath(requestedPath),
    ]);
    if (!isInside(realAgentsRoot, realProfilePath)) {
      return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Expert profile symlink escapes .claude/agents'));
    }
    const profile = await fs.readFile(realProfilePath, 'utf8');
    const prompt = [
      `You are the assigned expert for task ${input.task.id}.`,
      `Ticket: ${input.ticket.id} — ${input.ticket.title}`,
      `Ticket description: ${input.ticket.description}`,
      `Expert profile:\n${profile}`,
      'Return actionable analysis grounded in repository evidence. Do not claim tests you did not run.',
    ].join('\n\n');
    return ok({ profilePath: realProfilePath, profile, prompt });
  } catch (error: unknown) {
    return err(new KallaxError(KallaxErrorCode.FILE_NOT_FOUND, 'Failed to load expert profile', {
      cause: error,
      metadata: { resolvedExpertPath: input.resolvedExpertPath },
    }));
  }
}
