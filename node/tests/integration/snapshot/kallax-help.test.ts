/**
 * Snapshot regression test — /kallax-help (EPIC-283, DSH Path B)
 *
 * Replays the real assembled /kallax-help slash command and diffs against
 * the recorded snapshot in expected/kallax-help.json. ANSI escape codes
 * (real bytes + literal "\\033[..m" text) are stripped before compare.
 *
 * Zero-key input: no API key, network, or external state required.
 * Real assembled command: invokes .claude/commands/kallax-help.sh via
 * spawnSync (no mock, no fixture).
 *
 * If this test fails:
 *   1. Intentional change? Run: tsx node/tests/integration/snapshot/record.ts \
 *        .claude/commands/kallax-help.sh \
 *        node/tests/integration/snapshot/expected/kallax-help.json
 *   2. Regression? Investigate .claude/commands/kallax-help.sh + _kallax_common.sh
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runSnapshot, diffSnapshots, type Snapshot } from './runner.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '../../../..');
const SCRIPT_PATH = resolve(REPO_ROOT, '.claude/commands/kallax-help.sh');
const EXPECTED_PATH = resolve(__dirname, 'expected/kallax-help.json');

describe('snapshot: /kallax-help', () => {
  it('replays against recorded snapshot (0 diff)', () => {
    // Load recorded expected (recorded_at is metadata, compared separately)
    const expected: Snapshot = JSON.parse(readFileSync(EXPECTED_PATH, 'utf8'));

    // Replay — spawnSync on the real assembled command
    const actual = runSnapshot(SCRIPT_PATH);

    // Diff structural fields only (exit_code + normalized stdout/stderr)
    const { equal, diffs } = diffSnapshots(expected, actual);
    expect(diffs).toEqual([]);
    expect(equal).toBe(true);
  });

  it('captures grouped cheat-sheet (smoke)', () => {
    const snap = runSnapshot(SCRIPT_PATH);
    expect(snap.exit_code).toBe(0);
    expect(snap.stdout_normalized.length).toBeGreaterThan(800);
    // Smoke check: contains canonical section headers (regression detector)
    expect(snap.stdout_normalized).toContain('Quick Commands');
    expect(snap.stdout_normalized).toContain('Performer Commands');
    expect(snap.stdout_normalized).toContain('Conductor Commands');
  });
});