/**
 * KALLAX Output Verifier
 * Verify task output authenticity using Fact-Forcing 4-Level verification
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { err, ok } from 'neverthrow';
import {
  KallaxError,
  KallaxErrorCode,
  type KallaxResult,
  type VerificationResult,
  type VerificationEvidence,
  VerificationLevel,
} from '../types/index.js';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

export interface OutputVerifierConfig {
  readonly projectRoot: string;
  readonly testCommand?: string;
  readonly lintCommand?: string;
}

export interface OutputVerifier {
  verify: (taskId: string, worktreePath: string, level?: VerificationLevel) => Promise<KallaxResult<VerificationResult>>;
  verifyFileExists: (filePath: string) => Promise<KallaxResult<VerificationEvidence>>;
  verifyGitChanges: (worktreePath: string) => Promise<KallaxResult<VerificationEvidence>>;
  verifyTests: (worktreePath: string) => Promise<KallaxResult<VerificationEvidence>>;
  verifyLint: (worktreePath: string) => Promise<KallaxResult<VerificationEvidence>>;
}

/**
 * Execute command and capture output
 */
async function executeCommand(
  cwd: string,
  command: string,
  args: string[]
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  try {
    const { stdout, stderr } = await execFileAsync(command, args, { cwd });
    return { stdout, stderr, exitCode: 0 };
  } catch (error: unknown) {
    const execError = error as { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: execError.stdout ?? '',
      stderr: execError.stderr ?? '',
      exitCode: execError.code ?? 1,
    };
  }
}

export function createOutputVerifier(config: OutputVerifierConfig): OutputVerifier {
  const { projectRoot, testCommand = 'npm test', lintCommand = 'npm run lint' } = config;

  return {
    async verify(
      taskId: string,
      worktreePath: string,
      level: VerificationLevel = VerificationLevel.L4_DATA_FLOW
    ): Promise<KallaxResult<VerificationResult>> {
      logger.info({ taskId, worktreePath, level }, 'starting output verification');

      const evidence: VerificationEvidence[] = [];
      let allPassed = true;

      // L1: Existence Check
      const gitChangesEvidence = await this.verifyGitChanges(worktreePath);
      if (gitChangesEvidence.isOk()) {
        evidence.push(gitChangesEvidence.value);
        if (!gitChangesEvidence.value.passed) {
          allPassed = false;
        }
      } else {
        evidence.push({
          type: 'git',
          description: 'Failed to verify git changes',
          data: gitChangesEvidence.error.message,
          passed: false,
        });
        allPassed = false;
      }

      if (level >= VerificationLevel.L2_SUBSTANCE && allPassed) {
        // L2: Substance Check - verify files have real content
        const changedFiles = await this.getChangedFiles(worktreePath);
        if (changedFiles.isOk()) {
          for (const file of changedFiles.value.slice(0, 10)) { // Check first 10 files
            const substanceResult = await this.verifyFileSubstance(worktreePath, file);
            evidence.push(substanceResult);
            if (!substanceResult.passed) {
              allPassed = false;
            }
          }
        }
      }

      if (level >= VerificationLevel.L3_WIRING && allPassed) {
        // L3: Wiring Check - verify imports/exports
        const lintEvidence = await this.verifyLint(worktreePath);
        if (lintEvidence.isOk()) {
          evidence.push(lintEvidence.value);
          if (!lintEvidence.value.passed) {
            allPassed = false;
          }
        }
      }

      if (level >= VerificationLevel.L4_DATA_FLOW && allPassed) {
        // L4: Data Flow Check - run tests
        const testEvidence = await this.verifyTests(worktreePath);
        if (testEvidence.isOk()) {
          evidence.push(testEvidence.value);
          if (!testEvidence.value.passed) {
            allPassed = false;
          }
        }
      }

      const result: VerificationResult = {
        taskId,
        level,
        passed: allPassed,
        evidence,
        timestamp: Date.now(),
      };

      logger.info(
        { taskId, level, passed: allPassed, evidenceCount: evidence.length },
        'output verification completed'
      );

      return ok(result);
    },

    async verifyFileExists(filePath: string): Promise<KallaxResult<VerificationEvidence>> {
      try {
        const stats = await fs.stat(filePath);
        const evidence: VerificationEvidence = {
          type: 'file',
          description: `File exists: ${filePath}`,
          data: {
            size: stats.size,
            isFile: stats.isFile(),
            modified: stats.mtime.toISOString(),
          },
          passed: stats.isFile() && stats.size > 0,
        };
        return ok(evidence);
      } catch (error: unknown) {
        const evidence: VerificationEvidence = {
          type: 'file',
          description: `File not found: ${filePath}`,
          data: error instanceof Error ? error.message : String(error),
          passed: false,
        };
        return ok(evidence);
      }
    },

    async verifyGitChanges(worktreePath: string): Promise<KallaxResult<VerificationEvidence>> {
      const result = await executeCommand(worktreePath, 'git', ['status', '--porcelain']);

      const hasChanges = result.stdout.trim().length > 0;
      const evidence: VerificationEvidence = {
        type: 'git',
        description: hasChanges ? 'Git changes detected' : 'No git changes found',
        data: {
          status: result.stdout.trim().split('\n').filter((l) => l.length > 0),
          hasChanges,
        },
        passed: hasChanges,
      };

      if (!hasChanges) {
        // Check if there are committed changes not pushed
        const logResult = await executeCommand(worktreePath, 'git', [
          'log',
          '--oneline',
          'origin/main..HEAD',
        ]);
        const hasCommits = logResult.stdout.trim().length > 0;

        evidence.data = {
          ...evidence.data as Record<string, unknown>,
          unpushedCommits: logResult.stdout.trim().split('\n').filter((l) => l.length > 0),
          hasUnpushedCommits: hasCommits,
        };
        evidence.passed = hasCommits;
        evidence.description = hasCommits ? 'Unpushed commits detected' : 'No changes or commits found';
      }

      return ok(evidence);
    },

    async verifyTests(worktreePath: string): Promise<KallaxResult<VerificationEvidence>> {
      const [cmd, ...args] = testCommand.split(' ');
      if (cmd === undefined) {
        return err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, 'Invalid test command'));
      }

      const result = await executeCommand(worktreePath, cmd, args);

      const evidence: VerificationEvidence = {
        type: 'test',
        description: result.exitCode === 0 ? 'Tests passed' : 'Tests failed',
        data: {
          exitCode: result.exitCode,
          stdout: result.stdout.slice(-2000), // Last 2000 chars
          stderr: result.stderr.slice(-1000),
        },
        passed: result.exitCode === 0,
      };

      return ok(evidence);
    },

    async verifyLint(worktreePath: string): Promise<KallaxResult<VerificationEvidence>> {
      const [cmd, ...args] = lintCommand.split(' ');
      if (cmd === undefined) {
        return err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, 'Invalid lint command'));
      }

      const result = await executeCommand(worktreePath, cmd, args);

      const evidence: VerificationEvidence = {
        type: 'lint',
        description: result.exitCode === 0 ? 'Lint passed' : 'Lint failed',
        data: {
          exitCode: result.exitCode,
          stdout: result.stdout.slice(-2000),
          stderr: result.stderr.slice(-1000),
        },
        passed: result.exitCode === 0,
      };

      return ok(evidence);
    },

    async getChangedFiles(worktreePath: string): Promise<KallaxResult<string[]>> {
      const result = await executeCommand(worktreePath, 'git', [
        'diff',
        '--name-only',
        'HEAD~1',
      ]);

      if (result.exitCode !== 0) {
        // Fallback to checking staged changes
        const stagedResult = await executeCommand(worktreePath, 'git', [
          'diff',
          '--cached',
          '--name-only',
        ]);
        return ok(stagedResult.stdout.trim().split('\n').filter((f) => f.length > 0));
      }

      return ok(result.stdout.trim().split('\n').filter((f) => f.length > 0));
    },

    async verifyFileSubstance(worktreePath: string, relativePath: string): Promise<VerificationEvidence> {
      const fullPath = path.join(worktreePath, relativePath);

      try {
        const content = await fs.readFile(fullPath, 'utf-8');
        const lines = content.split('\n');
        const nonEmptyLines = lines.filter((l) => l.trim().length > 0);

        // Check for stub indicators
        const stubPatterns = [
          /TODO/i,
          /FIXME/i,
          /not implemented/i,
          /placeholder/i,
          /stub/i,
        ];

        const hasStubContent = stubPatterns.some((pattern) =>
          content.match(pattern) !== null
        );

        // A file is considered substantial if:
        // - Has more than 5 non-empty lines
        // - Has actual code (not just comments or stubs)
        const isSubstantial = nonEmptyLines.length > 5 && !hasStubContent;

        return {
          type: 'file',
          description: isSubstantial
            ? `File has substantial content: ${relativePath}`
            : `File may be stub or placeholder: ${relativePath}`,
          data: {
            path: relativePath,
            totalLines: lines.length,
            nonEmptyLines: nonEmptyLines.length,
            hasStubContent,
          },
          passed: isSubstantial,
        };
      } catch (error: unknown) {
        return {
          type: 'file',
          description: `Failed to read file: ${relativePath}`,
          data: error instanceof Error ? error.message : String(error),
          passed: false,
        };
      }
    },
  } as OutputVerifier & { getChangedFiles: (worktreePath: string) => Promise<KallaxResult<string[]>>; verifyFileSubstance: (worktreePath: string, relativePath: string) => Promise<VerificationEvidence> };
}
