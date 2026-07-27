/**
 * KALLAX Install Command — `kallax install`
 * Deploys expert-resolver + skill symlink + Node CLI link
 */
import type { Command } from 'commander';
import { execFileSync } from 'node:child_process';
import * as path from 'node:path';
import * as fs from 'node:fs';

const SCRIPTS_DIR = path.resolve(import.meta.dirname, '../../../scripts');
const SCRIPT_NAME = 'kallax-install.sh';

function getScriptPath(): string {
  return path.join(SCRIPTS_DIR, SCRIPT_NAME);
}

export function registerInstallCommands(program: Command): void {
  const installCmd = program.command('install').description('Deploy KALLAX framework (expert-resolver + skill + CLI)');

  installCmd
    .option('--force', 'Overwrite existing symlinks')
    .action((opts?: { force?: boolean }) => {
      const scriptPath = getScriptPath();

      if (!fs.existsSync(scriptPath)) {
        process.stderr.write(`[FAIL] Install script not found: ${scriptPath}\n`);
        process.exit(1);
      }

      const args: string[] = [];
      if (opts?.['force'] === true) {
        args.push('--force');
      }

      try {
        execFileSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
      } catch (error: unknown) {
        process.stderr.write(
          `[FAIL] Install failed: ${error instanceof Error ? error.message : String(error)}\n`,
        );
        process.exit(1);
      }
    });
}
