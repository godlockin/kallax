/**
 * KALLAX Pre-Bash Security Dispatcher — validates shell commands before execution.
 */

import { ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { Hook, HookContext } from './types.js';

// ── Forbidden patterns ─────────────────────────────────────────────────────

const FORBIDDEN_PATTERNS: Array<{ pattern: RegExp; reason: string }> = [
  { pattern: /rm\s+-rf\s+\//, reason: 'recursive root removal blocked' },
  { pattern: />\s*\/dev\/sd[a-z]/, reason: 'raw disk write blocked' },
  { pattern: /mkfs\./, reason: 'filesystem format blocked' },
  { pattern: /dd\s+if=/, reason: 'raw disk operations blocked' },
  { pattern: /:\(\)\s*\{\s*:\|:&\s*\};:/, reason: 'fork bomb pattern blocked' },
  { pattern: /chmod\s+777/, reason: 'world-writable permissions blocked' },
  { pattern: /curl.*\|\s*(ba)?sh/, reason: 'curl-pipe-shell pattern blocked' },
  { pattern: /wget.*\|\s*(ba)?sh/, reason: 'wget-pipe-shell pattern blocked' },
  { pattern: /git\s+push\s+--force.*main/, reason: 'force push to main blocked' },
  { pattern: /git\s+push\s+--force.*master/, reason: 'force push to master blocked' },
  { pattern: /git\s+reset\s+--hard/, reason: 'hard reset requires confirmation' },
  { pattern: /docker\s+rm\s+-f/, reason: 'force remove container blocked' },
  { pattern: /docker\s+system\s+prune/, reason: 'docker system prune blocked' },
  { pattern: /kubectl\s+delete\s+namespace/, reason: 'namespace deletion blocked' },
  { pattern: /eval\s+/, reason: 'eval usage requires review' },
  { pattern: /__proto__/, reason: 'prototype pollution pattern' },
  { pattern: /constructor\s*\(/, reason: 'suspicious constructor access' },
];

// ── Allowlist bypass ───────────────────────────────────────────────────────

const ALLOWLIST_PATTERNS: RegExp[] = [
  /^git\s+status/,
  /^git\s+diff/,
  /^git\s+log/,
  /^git\s+branch/,
  /^git\s+add\s/,
  /^git\s+commit/,
  /^git\s+checkout\s+-b\s/,
  /^git\s+worktree\s+add/,
  /^npm\s+test/,
  /^npm\s+run\s+(test|lint|build|typecheck)/,
  /^npx\s+(tsx|tsc|vitest|eslint)/,
  /^cargo\s+(test|build|check|clippy|fmt)/,
  /^ls\s/,
  /^cat\s/,
  /^find\s/,
  /^grep\s/,
  /^mkdir\s/,
  /^cp\s/,
  /^mv\s/,
  /^echo\s/,
  /^node\s/,
  /^python3\s/,
  /^which\s/,
  /^whoami/,
];

// ── Hook Factory ───────────────────────────────────────────────────────────

export function createPreBashSecurityHook(): Hook {
  return {
    name: 'pre-bash-security',
    phases: ['pre-tool-use'],
    priority: 1, // run FIRST — security gate before anything else
    async execute(ctx: HookContext): Promise<KallaxResult<{ allowed: boolean; reason?: string; warnings?: string[] }>> {
      // Only check Bash tool calls
      if (ctx.toolName !== 'Bash') {
        return ok({ allowed: true });
      }

      const command = ctx.toolParams?.['command'] as string | undefined;
      if (!command || typeof command !== 'string') {
        return ok({ allowed: true });
      }

      // Check allowlist first — bypasses all checks
      for (const pattern of ALLOWLIST_PATTERNS) {
        if (pattern.test(command.trim())) {
          logger.debug({ command: command.slice(0, 100) }, 'bash command in allowlist');
          return ok({ allowed: true });
        }
      }

      // Check forbidden patterns
      for (const { pattern, reason } of FORBIDDEN_PATTERNS) {
        if (pattern.test(command)) {
          logger.warn({ command: command.slice(0, 200), pattern: pattern.source, reason }, 'forbidden bash pattern detected');
          return ok({
            allowed: false,
            reason: `Security: ${reason}. Command: ${command.slice(0, 100)}`,
          });
        }
      }

      // Suspicious: not in allowlist — warn but allow (for development)
      logger.warn({ command: command.slice(0, 200) }, 'bash command not in allowlist, allowing with warning');

      return ok({
        allowed: true,
        warnings: [`Command not in allowlist: ${command.slice(0, 80)}`],
      });
    },
  };
}

/**
 * Register all default security hooks on a dispatcher.
 */
export function registerSecurityHooks(
  register: (hook: Hook) => void,
): void {
  register(createPreBashSecurityHook());
}
