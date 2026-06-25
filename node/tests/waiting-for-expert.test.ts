/**
 * WaitingForExpert unit tests — EPIC-030-C
 *
 * 7 test cases mirroring EPIC-030-A/B test patterns:
 *   AC1 Auto-degradation: recordNoMatch writes to state file when TrustScore==0
 *   AC2 Inbox hint: writeInboxHint creates `.kallax/inbox/waiting-<expert>.md`
 *   AC3 1:1 TrustScore wiring: recordNoMatch picks best score/layer from TrustScoreResult[]
 *   AC4 Increment retries: re-recording same ticket bumps retries (no overwrite)
 *   AC5 Priority order: getPriorityOrder returns tickets sorted by retries DESC
 *   AC6 Clear: clear(ticketId) removes ticket from state + isWaiting() returns false
 *   AC7 Validation: invalid ticketId/expertise throws; no state written on validation failure
 *
 * Run: npx vitest run tests/waiting-for-expert.test.ts
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  createWaitingForExpert,
  type WaitingForExpert,
} from '../src/core/waiting-for-expert.js';
import { TrustScore, type ExpertProfile, type TicketProfile } from '../src/core/trust-score.js';

let tmpDir: string;
let stateFile: string;
let inboxDir: string;
let fixedNow: Date;
let clockNow: () => Date;
let tracker: WaitingForExpert;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'kallax-waiting-for-expert-'));
  stateFile = path.join(tmpDir, 'state', 'waiting-for-expert.json');
  inboxDir = path.join(tmpDir, 'inbox');
  fixedNow = new Date('2026-06-25T12:00:00.000Z');
  clockNow = () => new Date(fixedNow.getTime());
  tracker = createWaitingForExpert({
    stateFile,
    inboxDir,
    inboxPrefix: 'waiting-',
    now: clockNow,
  });
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

const buildTrustResult = (
  overrides: Partial<{
    ticketId: string;
    expertId: string;
    matchedLayer: 'exact' | 'keyword_threshold' | 'vector_cosine' | null;
    score: number;
    exactHit: boolean;
    keywordOverlap: number;
    cosine: number;
  }> = {},
) => ({
  ticketId: overrides.ticketId ?? 'T-1',
  expertId: overrides.expertId ?? 'backend',
  matchedLayer: overrides.matchedLayer ?? null,
  score: overrides.score ?? 0,
  breakdown: {
    exactHit: overrides.exactHit ?? false,
    keywordOverlap: overrides.keywordOverlap ?? 0,
    cosine: overrides.cosine ?? 0,
  },
});

describe('WaitingForExpert — auto-degradation (EPIC-030-A 1:1)', () => {
  it('AC1: recordNoMatch writes state file with retries=1 + bestScore/bestLayer from TrustScore', () => {
    const trustResults = [
      buildTrustResult({ expertId: 'backend', score: 0, matchedLayer: null }),
      buildTrustResult({ expertId: 'frontend', score: 0, matchedLayer: null }),
      buildTrustResult({ expertId: 'ux', score: 0.05, matchedLayer: null }),
    ];

    const result = tracker.recordNoMatch({
      ticketId: 'EPIC-030-C-T1',
      requiredExpertise: 'rust-bridge',
      trustResults,
    });

    expect(result.entry.ticketId).toBe('EPIC-030-C-T1');
    expect(result.entry.requiredExpertise).toBe('rust-bridge');
    expect(result.entry.retries).toBe(1);
    expect(result.entry.bestScore).toBe(0.05);
    expect(result.entry.bestLayer).toBeNull();
    expect(result.entry.lastAttempt).toBe('2026-06-25T12:00:00.000Z');

    expect(fs.existsSync(stateFile)).toBe(true);
    const persisted = JSON.parse(fs.readFileSync(stateFile, 'utf-8')) as Record<
      string,
      { retries: number; requiredExpertise: string; bestScore: number }
    >;
    expect(persisted['EPIC-030-C-T1']?.retries).toBe(1);
    expect(persisted['EPIC-030-C-T1']?.requiredExpertise).toBe('rust-bridge');
    expect(persisted['EPIC-030-C-T1']?.bestScore).toBe(0.05);
  });
});

describe('WaitingForExpert — inbox 提示 (.kallax/inbox/waiting-<expert>.md)', () => {
  it('AC2: writeInboxHint creates markdown at `<inboxDir>/waiting-<expert>.md` with retry context', () => {
    const result = tracker.recordNoMatch({
      ticketId: 'EPIC-030-C-T2',
      requiredExpertise: 'postgres',
      trustResults: [buildTrustResult({ expertId: 'backend', score: 0 })],
    });
    const inboxPath = tracker.writeInboxHint(result);

    expect(inboxPath).toBe(path.join(inboxDir, 'waiting-postgres.md'));
    expect(fs.existsSync(inboxPath)).toBe(true);

    const content = fs.readFileSync(inboxPath, 'utf-8');
    expect(content).toContain('# Waiting for Expert: EPIC-030-C-T2');
    expect(content).toContain('- Required Expertise: postgres');
    expect(content).toContain('- Retries: 1');
    expect(content).toContain('- Best Match Score: 0');
    expect(content).toContain('- Best Match Layer: none');
    expect(content).toContain('## 建议');
    expect(content).toContain('1. 手动注册匹配 expert');
  });

  it('AC2b: writeInboxHint sanitizes expertise to safe filename (slashes → underscores)', () => {
    const result = tracker.recordNoMatch({
      ticketId: 'EPIC-030-C-T2B',
      requiredExpertise: 'rust/bridge',
      trustResults: [buildTrustResult({ expertId: 'backend', score: 0 })],
    });
    const inboxPath = tracker.writeInboxHint(result);
    expect(inboxPath).toBe(path.join(inboxDir, 'waiting-rust_bridge.md'));
    expect(fs.existsSync(inboxPath)).toBe(true);
  });
});

describe('WaitingForExpert — 1:1 TrustScore wiring (EPIC-030-A joint)', () => {
  it('AC3: recordNoMatch uses BEST score/layer from TrustScoreResult[] (highest score wins)', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'EPIC-030-C-T3',
      title: 'rust serde serialization',
      description: 'json marshalling',
      keywords: ['rust', 'serde'],
    };
    const experts: readonly ExpertProfile[] = [
      { expertId: 'backend', keywords: ['sql', 'db'] },
      { expertId: 'rust-bridge', keywords: ['rust', 'serde', 'tokio'] },
      { expertId: 'frontend', keywords: ['css', 'react'] },
    ];
    const trustResults = scorer.matchAll(ticket, experts);
    const bestLayerFromScorer = trustResults[0]?.matchedLayer ?? null;
    const bestScoreFromScorer = trustResults[0]?.score ?? 0;

    const result = tracker.recordNoMatch({
      ticketId: 'EPIC-030-C-T3',
      requiredExpertise: 'rust',
      trustResults,
    });

    expect(result.entry.bestScore).toBe(bestScoreFromScorer);
    expect(result.entry.bestLayer).toBe(bestLayerFromScorer);
  });
});

describe('WaitingForExpert — increment retries + priority', () => {
  it('AC4: incrementRetries bumps retries on second call; does not lose previous bestScore/bestLayer', () => {
    const r1 = tracker.incrementRetries({
      ticketId: 'EPIC-030-C-T4',
      requiredExpertise: 'kafka',
      bestScore: 0.3,
      bestLayer: 'vector_cosine',
    });
    expect(r1.entry.retries).toBe(1);
    expect(r1.entry.bestScore).toBe(0.3);
    expect(r1.entry.bestLayer).toBe('vector_cosine');

    const r2 = tracker.incrementRetries({
      ticketId: 'EPIC-030-C-T4',
      requiredExpertise: 'kafka',
    });
    expect(r2.entry.retries).toBe(2);
    expect(r2.entry.bestScore).toBe(0.3);
    expect(r2.entry.bestLayer).toBe('vector_cosine');
    expect(r2.entry.lastAttempt).toBe('2026-06-25T12:00:00.000Z');
  });

  it('AC5: getPriorityOrder returns tickets sorted by retries DESC, then ticketId ASC', () => {
    tracker.incrementRetries({ ticketId: 'Z-TICKET', requiredExpertise: 'kafka' });
    tracker.incrementRetries({ ticketId: 'A-TICKET', requiredExpertise: 'kafka' });
    tracker.incrementRetries({ ticketId: 'A-TICKET', requiredExpertise: 'kafka' });
    tracker.incrementRetries({ ticketId: 'M-TICKET', requiredExpertise: 'kafka' });
    tracker.incrementRetries({ ticketId: 'M-TICKET', requiredExpertise: 'kafka' });
    tracker.incrementRetries({ ticketId: 'M-TICKET', requiredExpertise: 'kafka' });

    const order = tracker.getPriorityOrder();
    expect(order).toEqual(['M-TICKET', 'A-TICKET', 'Z-TICKET']);
  });
});

describe('WaitingForExpert — clear + state lifecycle', () => {
  it('AC6: clear(ticketId) removes ticket from state; isWaiting() reflects it; idempotent on missing', () => {
    tracker.incrementRetries({ ticketId: 'EPIC-030-C-T6', requiredExpertise: 'graphql' });
    expect(tracker.isWaiting('EPIC-030-C-T6')).toBe(true);
    expect(tracker.list().length).toBe(1);

    const removed = tracker.clear('EPIC-030-C-T6');
    expect(removed).toBe(true);
    expect(tracker.isWaiting('EPIC-030-C-T6')).toBe(false);
    expect(tracker.list().length).toBe(0);

    const removedAgain = tracker.clear('EPIC-030-C-T6');
    expect(removedAgain).toBe(false);
  });

  it('AC7: invalid ticketId / requiredExpertise throws before any state is written', () => {
    const before = fs.existsSync(stateFile);
    expect(() =>
      tracker.incrementRetries({ ticketId: 'bad/id', requiredExpertise: 'kafka' }),
    ).toThrow(/invalid characters/);

    expect(() =>
      tracker.incrementRetries({ ticketId: 'GOOD', requiredExpertise: '' }),
    ).toThrow(/must be non-empty/);

    const after = fs.existsSync(stateFile);
    if (before && after) {
      const persisted = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));
      expect(persisted).toEqual({});
    }
  });
});