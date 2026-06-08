/**
 * KALLAX Init Command — `kallax init [path]`
 * One-shot project directory initialization via kallax-init.sh
 */

import type { Command } from 'commander';
import { execFileSync } from 'node:child_process';
import * as path from 'node:path';
import * as fs from 'node:fs';

const SCRIPTS_DIR = path.resolve(import.meta.dirname, '../../../scripts');
const SCRIPT_NAME = 'kallax-init.sh';

function getScriptPath(): string {
  return path.join(SCRIPTS_DIR, SCRIPT_NAME);
}

function getDefaultStructure(): string {
  return [
    '',
    '=== KALLAX Init (dry-run) ===',
    '',
    'Project: <target-path>',
    '',
    'Will create directories:',
    '  .kallax/instances/',
    '  .kallax/hooks/',
    '  .kallax/config/',
    '  .kallax/queue/',
    '  .kallax/schemas/',
    '  confluence/memory/',
    '  confluence/decisions/',
    '  confluence/runbooks/',
    '  jira/phases/',
    '  jira/epics/',
    '  jira/tickets/',
    '  jira/schemas/',
    '',
    'Will create files:',
    '  jira/phases/phase_index.json',
    '  jira/epics/epic_index.json',
    '  .kallax/schemas/directory-structure.md',
    '',
    'Already existing items will be skipped (use --force to overwrite).',
    '',
  ].join('\n');
}

function validateProjectRoot(targetPath: string): string {
  const resolvedPath = path.resolve(targetPath);

  if (!fs.existsSync(resolvedPath)) {
    process.stderr.write(`[FAIL] Target directory does not exist: ${resolvedPath}\n`);
    process.exit(1);
  }

  const stat = fs.statSync(resolvedPath);
  if (!stat.isDirectory()) {
    process.stderr.write(`[FAIL] Target path is not a directory: ${resolvedPath}\n`);
    process.exit(1);
  }

  return resolvedPath;
}

export function registerInitCommands(program: Command): void {
  const initCmd = program.command('init').description('Initialize project directory structure');

  initCmd
    .argument('[path]', 'Target project root path (defaults to current directory)')
    .option('--dry-run', 'Preview what would be created without actually creating anything')
    .option('--force', 'Overwrite existing files')
    .action((targetPath?: string, opts?: { dryRun?: boolean; force?: boolean }) => {
      try {
        const resolvedPath = validateProjectRoot(targetPath ?? process.cwd());
        const dryRun = opts?.['dryRun'] ?? false;
        const force = opts?.['force'] ?? false;

        if (dryRun) {
          const preview = getDefaultStructure().replace(
            '<target-path>',
            resolvedPath,
          );
          process.stdout.write(preview);
          process.stdout.write(
            `Run without --dry-run to execute initialization.\n`,
          );
          return;
        }

        const scriptPath = getScriptPath();

        if (!fs.existsSync(scriptPath)) {
          process.stderr.write(
            `[FAIL] Init script not found: ${scriptPath}\n`,
          );
          process.exit(1);
        }

        const args: string[] = [resolvedPath];
        if (force) {
          args.unshift('--force');
        }

        execFileSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
      } catch (error: unknown) {
        process.stderr.write(
          `[FAIL] Init failed: ${
            error instanceof Error ? error.message : String(error)
          }\n`,
        );
        process.exit(1);
      }
    });
}
