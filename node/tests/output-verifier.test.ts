/**
 * Output Verifier tests: L1-L4 verification with mocked execFile and fs.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockExecFile = vi.hoisted(() => vi.fn());
const mockStat = vi.hoisted(() => vi.fn());
const mockReadFile = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({ execFile: mockExecFile }));
vi.mock('node:fs/promises', () => ({ stat: mockStat, readFile: mockReadFile }));

import { createOutputVerifier } from '../src/core/output-verifier.js';
import { VerificationLevel } from '../src/types/index.js';

function callCb(args: unknown[], err: null | Error, result?: { stdout: string; stderr: string }): void {
  const cb = args[args.length - 1] as (err: null | Error, res: { stdout: string; stderr: string }) => void;
  cb(err, result);
}

describe('OutputVerifier', () => {
  let verifier: ReturnType<typeof createOutputVerifier>;

  beforeEach(() => {
    vi.clearAllMocks();
    verifier = createOutputVerifier({ projectRoot: '/repo', testCommand: 'echo ok', lintCommand: 'echo ok' });
  });

  it('verifyFileExists returns passed for valid file', async () => {
    mockStat.mockResolvedValue({ size: 100, isFile: () => true, mtime: new Date() });
    const result = await verifier.verifyFileExists('/repo/src/a.ts');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().passed).toBe(true);
  });

  it('verifyFileExists returns not-passed for missing file', async () => {
    mockStat.mockRejectedValue(Object.assign(new Error('ENOENT'), { code: 'ENOENT' }));
    const result = await verifier.verifyFileExists('/repo/missing.ts');
    expect(result._unsafeUnwrap().passed).toBe(false);
  });

  it('verifyGitChanges detects changes from porcelain', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: ' M src/a.ts', stderr: '' }));
    const result = await verifier.verifyGitChanges('/repo');
    expect(result._unsafeUnwrap().passed).toBe(true);
  });

  it('verifyGitChanges falls back to unpushed commits when clean', async () => {
    mockExecFile
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'abc123 feat: x', stderr: '' }));
    const result = await verifier.verifyGitChanges('/repo');
    expect(result._unsafeUnwrap().passed).toBe(true);
  });

  it('verifyTests passes on zero exit code', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: 'PASS', stderr: '' }));
    const result = await verifier.verifyTests('/repo');
    expect(result._unsafeUnwrap().passed).toBe(true);
  });

  it('verifyTests fails on non-zero exit code', async () => {
    const err = Object.assign(new Error('tests failed'), { stdout: '', stderr: 'FAIL', code: 1 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));
    const result = await verifier.verifyTests('/repo');
    expect(result._unsafeUnwrap().passed).toBe(false);
  });

  it('verify returns result with evidence array', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: ' M a.ts', stderr: '' }));
    mockStat.mockResolvedValue({ size: 100, isFile: () => true, mtime: new Date() });
    mockReadFile.mockResolvedValue('line1\nline2\nline3\nline4\nline5\nline6\nconst x = 1;\n');

    const result = await verifier.verify('T1', '/repo', VerificationLevel.L1_EXISTENCE);
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().taskId).toBe('T1');
    expect(result._unsafeUnwrap().evidence.length).toBeGreaterThan(0);
  });
});
