/**
 * Snapshot harness runner — DSH Path B regression protection (EPIC-283)
 *
 * Runs an assembled slash command, captures stdout/stderr/exit_code,
 * strips ANSI escapes for stable comparison, and returns a structured
 * Snapshot object suitable for JSON serialization.
 *
 * 0 API key dependency: pure local command execution.
 * 0 mock: invokes the real assembled .sh script via child_process.
 */

import { spawnSync } from 'node:child_process';

// ANSI escape regex matches three forms commonly produced by slash commands:
//   1. Real escape bytes:  ESC[..m
//   2. Literal text "ESC[..m" (some bash scripts echo '\\033[1m' as literal text)
//   3. CSI sequences with parameters
const ANSI_RE = /\x1b\[[0-9;]*[A-Za-z]|\x1b\[[?]?[0-9;]*[A-Za-z]|\\033\[[0-9;]*[A-Za-z]/g;

export interface Snapshot {
  command: string;
  args: string[];
  exit_code: number;
  stdout: string;
  stderr: string;
  stdout_normalized: string;
  stderr_normalized: string;
  recorded_at: string; // ISO 8601
  format_version: '1.0.0';
}

/**
 * Strip ANSI escape codes (real + literal text) from input. Snapshot must be
 * platform-independent; raw \x1b[..m and "\\033[..m" forms both stripped.
 */
export function stripAnsi(input: string): string {
  return input.replace(ANSI_RE, '');
}

/**
 * Run a shell command and return a Snapshot. Uses spawnSync (sync, fail-fast)
 * to keep vitest integration simple. Timeout 5s — slash commands should be quick.
 */
export function runSnapshot(
  command: string,
  args: string[] = [],
  cwd?: string
): Snapshot {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    timeout: 5000,
    env: { ...process.env, NO_COLOR: '1', TERM: 'dumb' }, // disable colors
  });

  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';

  return {
    command,
    args,
    exit_code: result.status ?? -1,
    stdout,
    stderr,
    stdout_normalized: stripAnsi(stdout),
    stderr_normalized: stripAnsi(stderr),
    recorded_at: new Date().toISOString(),
    format_version: '1.0.0',
  };
}

/**
 * Diff two snapshots: returns 0 if structurally equivalent, 1 otherwise.
 * Compares exit_code + stdout_normalized + stderr_normalized.
 * Excludes recorded_at (timestamp drift).
 */
export function diffSnapshots(a: Snapshot, b: Snapshot): { equal: boolean; diffs: string[] } {
  const diffs: string[] = [];

  if (a.exit_code !== b.exit_code) {
    diffs.push(`exit_code: ${a.exit_code} !== ${b.exit_code}`);
  }
  if (a.stdout_normalized !== b.stdout_normalized) {
    diffs.push(`stdout_normalized: ${a.stdout_normalized.length} vs ${b.stdout_normalized.length} chars`);
  }
  if (a.stderr_normalized !== b.stderr_normalized) {
    diffs.push(`stderr_normalized: ${a.stderr_normalized.length} vs ${b.stderr_normalized.length} chars`);
  }

  return { equal: diffs.length === 0, diffs };
}