/**
 * KALLAX Validate Runner
 * Reads a JSON file list from stdin, runs all validations, prints formatted results.
 * Called by scripts/validate-all.sh.
 *
 * Stdin format:
 *   {
 *     "phases": ["path/to/phase.json", ...],
 *     "epics":  ["path/to/epic.json", ...],
 *     "tickets": ["path/to/ticket.json", ...],
 *     "states": ["path/to/state.json", ...]
 *   }
 *
 * Exit code: 0 if all pass, 1 if any fail.
 */

import { validateAll, SCHEMA_VERSION } from '../core/schema-validator.js';

interface InputFileList {
  readonly phases?: string[];
  readonly epics?: string[];
  readonly tickets?: string[];
  readonly states?: string[];
}

function readStdin(): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    process.stdin.on('data', (chunk: Buffer) => { chunks.push(chunk); });
    process.stdin.on('end', () => { resolve(Buffer.concat(chunks).toString('utf-8')); });
    process.stdin.on('error', reject);
  });
}

function padRight(s: string, n: number): string {
  return s.length < n ? s + ' '.repeat(n - s.length) : s;
}

async function main(): Promise<number> {
  const raw = await readStdin();
  let input: InputFileList;
  try {
    input = JSON.parse(raw) as InputFileList;
  } catch {
    process.stderr.write(`[FATAL] Invalid JSON on stdin: ${raw.slice(0, 100)}\n`);
    return 1;
  }

  const result = validateAll(
    input.phases ?? [],
    input.epics ?? [],
    input.tickets ?? [],
    input.states ?? [],
  );

  const typeColors: Record<string, string> = {
    phase: '\x1b[36m',  // cyan
    epic: '\x1b[35m',   // magenta
    ticket: '\x1b[33m', // yellow
    state: '\x1b[34m',  // blue
  };
  const RESET = '\x1b[0m';
  const GREEN = '\x1b[32m';
  const RED = '\x1b[31m';
  const BOLD = '\x1b[1m';

  process.stdout.write(`\n${BOLD}KALLAX JSON Schema Validation (v${SCHEMA_VERSION})${RESET}\n`);
  process.stdout.write(`${'='.repeat(58)}\n\n`);

  for (const entry of result.entries) {
    const typeStr = padRight(entry.type.toUpperCase(), 7);
    const color = typeColors[entry.type] ?? '\x1b[37m';
    if (entry.passed) {
      process.stdout.write(`  ${GREEN}PASS${RESET}  ${color}${typeStr}${RESET}  ${entry.filePath}\n`);
    } else {
      process.stdout.write(`  ${RED}FAIL${RESET}  ${color}${typeStr}${RESET}  ${entry.filePath}\n`);
      for (const errMsg of entry.errors) {
        process.stdout.write(`        ${RED}└ ${errMsg}${RESET}\n`);
      }
    }
  }

  process.stdout.write(`\n${'='.repeat(58)}\n`);

  const total = result.total;
  const passed = result.passed;
  const failed = result.failed;
  const color = failed === 0 ? GREEN : RED;
  process.stdout.write(
    `${color}${BOLD}Result: ${String(passed)}/${String(total)} passed, ${String(failed)} failed${RESET}\n\n`,
  );

  return failed === 0 ? 0 : 1;
}

main().then((code) => { process.exit(code); }).catch((error: unknown) => {
  process.stderr.write(`[FATAL] Runner crashed: ${String(error)}\n`);
  process.exit(1);
});
