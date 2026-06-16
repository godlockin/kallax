/**
 * KALLAX Role Command Registration
 * Wraps permission scripts with CLI registration
 *
 * P0 修复项:
 * - set -euo pipefail (bash 层)
 * - fail-closed: 任何错误 exit 1 deny
 * - role 名称 validation
 *
 * EPIC-055-B 升级:
 * - role decide <change_type> <tier> — 3 级路由 (P0 阻塞 / P1 备案 / P2 放手)
 * - role classify <change_type> <tier> — 返回 P0/P1/P2
 * - role audit-p0 — P0 漏拍审计
 * - role fatigue — 拍板疲劳指数
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2 + §4
 * 跟 confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
 * 跟 PROCESS.md:25-26 "Master 不能自己升级红线" 联合
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

  // EPIC-055-B: 3 级路由 — role decide <change_type> [tier]
  // 跟 PROCESS.md:25-26 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合
  role
    .command('decide <ticket_id> <change_type> [tier]')
    .description('Route decision per P0/P1/P2 tier (EPIC-055-B, Master 阻塞/备案/放手)')
    .action((ticketId: string, changeType: string, tier?: string) => {
      try {
        const projectRoot = process.cwd();
        const scriptPath = path.join(projectRoot, 'scripts', 'audit', 'approval-tiering.sh');
        const tierArg = tier ?? '2';
        const classifyResult = execFileSync('bash', [scriptPath, 'classify', ticketId, changeType, tierArg], { encoding: 'utf8' }).trim();

        // Map P0/P1/P2 to route command
        const routeCmd = `route-${classifyResult.toLowerCase()}`;
        logger.info({
          event: 'role_decide',
          ticketId,
          changeType,
          tier: tierArg,
          classified: classifyResult,
        }, `classified as ${classifyResult}, routing via ${routeCmd}`);

        // P0 = exit 2 (blocked, require explicit approval); P1/P2 = continue
        if (classifyResult === 'P0') {
          execFileSync('bash', [scriptPath, routeCmd, ticketId], { stdio: 'inherit' });
          logger.warn({ ticketId }, 'P0 BLOCKED — waiting for 主公 explicit approval (PROCESS.md:25-26)');
          process.exit(2);
        }

        execFileSync('bash', [scriptPath, routeCmd, ticketId], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error, ticketId, changeType }, 'role decide failed');
        process.exit(1);
      }
    });

  // EPIC-055-B: role classify — 仅返回 P0/P1/P2 不路由
  role
    .command('classify <change_type> [tier]')
    .description('Classify a decision as P0/P1/P2 (EPIC-055-B)')
    .action((changeType: string, tier?: string) => {
      try {
        const projectRoot = process.cwd();
        const scriptPath = path.join(projectRoot, 'scripts', 'audit', 'approval-tiering.sh');
        const tierArg = tier ?? '2';
        const result = execFileSync('bash', [scriptPath, 'classify', 'CLI', changeType, tierArg], { encoding: 'utf8' }).trim();
        process.stdout.write(`${result}\n`);
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error, changeType }, 'role classify failed');
        process.exit(1);
      }
    });

  // EPIC-055-B: role audit-p0 — 历史 P0 漏拍审计
  role
    .command('audit-p0')
    .description('Audit historical P0 missed decisions (EPIC-055-B)')
    .action(() => {
      try {
        const projectRoot = process.cwd();
        const scriptPath = path.join(projectRoot, 'scripts', 'audit', 'approval-tiering.sh');
        execFileSync('bash', [scriptPath, 'audit-p0'], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error }, 'role audit-p0 failed');
        process.exit(1);
      }
    });

  // EPIC-055-B: role fatigue — 拍板疲劳指数
  role
    .command('fatigue')
    .description('Calculate 拍板疲劳 index + recommendation (EPIC-055-B, 跟 Rule 32 联动)')
    .action(() => {
      try {
        const projectRoot = process.cwd();
        const scriptPath = path.join(projectRoot, 'scripts', 'audit', 'approval-tiering.sh');
        execFileSync('bash', [scriptPath, 'fatigue'], { stdio: 'inherit' });
      } catch (error: unknown) {
        if (error instanceof Error && 'status' in error) {
          process.exit((error as { status: number }).status);
        }
        logger.error({ error }, 'role fatigue failed');
        process.exit(1);
      }
    });
}