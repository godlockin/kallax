#!/usr/bin/env -S npx tsx
/**
 * Snapshot record utility — DSH Path B (EPIC-283)
 *
 * Usage:
 *   record.ts <command> <expected-json-path>
 *
 * Examples:
 *   tsx node/tests/integration/snapshot/record.ts \
 *     .claude/commands/kallax-list.sh \
 *     node/tests/integration/snapshot/expected/kallax-list.json
 *
 *   tsx node/tests/integration/snapshot/record.ts \
 *     .claude/commands/kallax-help.sh \
 *     node/tests/integration/snapshot/expected/kallax-help.json
 *
 * This script is for maintainers only. CI/vitest must NEVER invoke --record.
 * The vitest test files only call runSnapshot() + diffSnapshots().
 *
 * Exit codes:
 *   0 = recorded OK
 *   1 = command failed
 *   2 = file write failed
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { runSnapshot } from './runner.js';

function main(): number {
  const argv = process.argv.slice(2);
  if (argv.length < 2) {
    console.error('Usage: record.ts <command> <expected-json-path>');
    console.error('  command: path to .sh file (e.g. .claude/commands/kallax-list.sh)');
    console.error('  expected-json-path: output JSON path (e.g. expected/kallax-list.json)');
    return 2;
  }

  const [command, expectedPath] = argv;
  const absCommand = resolve(command);
  const absExpected = resolve(expectedPath);

  console.log(`[record] running: ${command}`);
  const snapshot = runSnapshot(absCommand);

  if (snapshot.exit_code !== 0) {
    console.error(`[record] FAIL: command exited ${snapshot.exit_code}`);
    console.error(`[record] stderr: ${snapshot.stderr_normalized.slice(0, 200)}`);
    return 1;
  }

  // Write JSON; create parent dir if missing
  try {
    mkdirSync(dirname(absExpected), { recursive: true });
    writeFileSync(absExpected, JSON.stringify(snapshot, null, 2) + '\n', 'utf8');
  } catch (err) {
    console.error(`[record] FAIL: write error: ${(err as Error).message}`);
    return 2;
  }

  console.log(`[record] OK: wrote ${absExpected}`);
  console.log(`[record]   stdout: ${snapshot.stdout_normalized.length} chars (ANSI stripped)`);
  console.log(`[record]   stderr: ${snapshot.stderr_normalized.length} chars`);
  return 0;
}

process.exit(main());