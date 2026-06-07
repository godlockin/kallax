/**
 * KALLAX Role Command Registration
 * Wraps permission scripts with CLI registration
 *
 * P0 修复项:
 * - set -euo pipefail (bash 层)
 * - fail-closed: 任何错误 exit 1 deny
 * - role 名称 validation
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2 + §4
 */

import { Command } from 'commander';
import { execFileSync } from 'node:child_process';
import * as path from 'node:path';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

function getScriptPath(scriptName: string): string {
  const projectRoot = process.cwd();
  return path.join(projectRoot, 'scripts', 'permission', scriptName);
}

export function registerRoleCommands(program: Command, _ctx: AppContext): void {
  const role = program.command('role').description('Role management');

  role
    .command('list')
    .description('List all available roles')
    .action(() => {
      try {
        const scriptPath = getScriptPath('list.sh');
        execFileSync('bash', [scriptPath], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error }, 'role list failed');
        process.exit(1);
      }
    });

  role
    .command('whoami')
    .description('Show current role + permissions')
    .action(() => {
      try {
        const scriptPath = getScriptPath('whoami.sh');
        execFileSync('bash', [scriptPath], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error }, 'role whoami failed');
        process.exit(1);
      }
    });

  role
    .command('check <action>')
    .description('Check if current role has permission for action')
    .action((action: string) => {
      try {
        const scriptPath = getScriptPath('check.sh');
        execFileSync('bash', [scriptPath, action], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error, action }, 'role check failed');
        process.exit(1);
      }
    });
}