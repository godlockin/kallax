/**
 * ScoringTrace unit tests — EPIC-030-B
 *
 * 5+ test cases covering:
 *   1. Append: log() writes one JSON line per call to today's file
 *   2. Append-only: subsequent logs do not overwrite earlier entries
 *   3. Daily rotation: clock injection drives file path to new date partition
 *   4. Query filters: by date / ticketId / expertId / time range
 *   5. 1:1 TrustScore wiring: logFromTrustScore preserves matchedLayer + score + factors
 *   6. Stats aggregation: byDate / byExpert / byLayer
 *   7. Invalid date rejection: getFilePath throws on malformed date string
 *
 * Run: npx vitest run tests/scoring-trace.test.ts
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  createScoringTrace,
  type ScoringTraceEntry,
  type ScoringTrace,
  type ScoringTraceInput,
} from '../src/core/scoring-trace.js';
import { TrustScore, type ExpertProfile, type TicketProfile } from '../src/core/trust-score.js';

let tmpDir: string;
let fixedNow: Date;
let clockNow: () => Date;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'kallax-scoring-trace-'));
  fixedNow = new Date('2026-06-25T12:00:00.000Z');
  clockNow = () => new Date(fixedNow.getTime());
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

const makeFactors = (overrides: Partial<{ exactHit: boolean; keywordOverlap: number; cosine: number }> = {}) => ({
  exactHit: overrides.exactHit ?? false,
  keywordOverlap: overrides.keywordOverlap ?? 0,
  cosine: overrides.cosine ?? 0,
});

const makeInput = (overrides: Partial<ScoringTraceInput> = {}): ScoringTraceInput => ({
  ticketId: overrides.ticketId ?? 'TICKET-1',
  expertId: overrides.expertId ?? 'backend',
  matchedLayer: 'matchedLayer' in overrides ? overrides.matchedLayer : 'exact',
  score: overrides.score ?? 1.0,
  factors: overrides.factors ?? makeFactors({ exactHit: true }),
});

describe('createScoringTrace — file layout', () => {
  it('AC1: writes one JSON object per line to scoring-YYYY-MM-DD.jsonl', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    trace.log(makeInput({ ticketId: 'T-1', expertId: 'backend' }));

    const expectedPath = path.join(tmpDir, 'scoring-2026-06-25.jsonl');
    expect(fs.existsSync(expectedPath)).toBe(true);

    const content = fs.readFileSync(expectedPath, 'utf-8');
    const lines = content.split('\n').filter((l) => l.length > 0);
    expect(lines.length).toBe(1);
    const parsed = JSON.parse(lines[0]!);
    expect(parsed.ticketId).toBe('T-1');
    expect(parsed.expertId).toBe('backend');
    expect(parsed.date).toBe('2026-06-25');
  });

  it('AC2: append-only — multiple logs preserve insertion order, no overwrite', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    trace.log(makeInput({ ticketId: 'T-1' }));
    trace.log(makeInput({ ticketId: 'T-2' }));
    trace.log(makeInput({ ticketId: 'T-3' }));

    const filePath = path.join(tmpDir, 'scoring-2026-06-25.jsonl');
    const lines = fs.readFileSync(filePath, 'utf-8').split('\n').filter((l) => l.length > 0);
    expect(lines.length).toBe(3);

    const ids = lines.map((l) => JSON.parse(l).ticketId as string);
    expect(ids).toEqual(['T-1', 'T-2', 'T-3']);
  });
});

describe('createScoringTrace — daily rotation', () => {
  it('AC3: rotates to a new file when clock crosses midnight (date changes)', () => {
    let virtualDate = fixedNow;
    const trace = createScoringTrace({ auditDir: tmpDir, now: () => virtualDate });

    trace.log(makeInput({ ticketId: 'T-day1' }));
    const day1Path = trace.getFilePath();
    expect(day1Path).toBe(path.join(tmpDir, 'scoring-2026-06-25.jsonl'));

    virtualDate = new Date('2026-06-26T00:00:01.000Z');
    trace.log(makeInput({ ticketId: 'T-day2' }));
    const day2Path = trace.getFilePath();
    expect(day2Path).toBe(path.join(tmpDir, 'scoring-2026-06-26.jsonl'));

    expect(day1Path).not.toBe(day2Path);
    expect(fs.existsSync(day1Path)).toBe(true);
    expect(fs.existsSync(day2Path)).toBe(true);

    const day1Lines = fs.readFileSync(day1Path, 'utf-8').split('\n').filter((l) => l.length > 0);
    const day2Lines = fs.readFileSync(day2Path, 'utf-8').split('\n').filter((l) => l.length > 0);
    expect(day1Lines.length).toBe(1);
    expect(day2Lines.length).toBe(1);
    expect(JSON.parse(day1Lines[0]!).ticketId).toBe('T-day1');
    expect(JSON.parse(day2Lines[0]!).ticketId).toBe('T-day2');
  });

  it('getFilePath() with explicit date returns that date partition', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    expect(trace.getFilePath('2026-01-15')).toBe(path.join(tmpDir, 'scoring-2026-01-15.jsonl'));
  });

  it('getFilePath() rejects malformed date strings', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    expect(() => trace.getFilePath('2026/06/25')).toThrow(/invalid date format/);
    expect(() => trace.getFilePath('not-a-date')).toThrow(/invalid date format/);
  });
});

describe('createScoringTrace — query & stats', () => {
  it('AC4: query filters by date, ticketId, expertId, and time range', () => {
    let virtualDate = new Date('2026-06-25T08:00:00.000Z');
    const trace = createScoringTrace({ auditDir: tmpDir, now: () => virtualDate });

    trace.log(makeInput({ ticketId: 'T-1', expertId: 'backend' }));
    virtualDate = new Date('2026-06-25T09:00:00.000Z');
    trace.log(makeInput({ ticketId: 'T-2', expertId: 'frontend' }));
    virtualDate = new Date('2026-06-26T08:00:00.000Z');
    trace.log(makeInput({ ticketId: 'T-3', expertId: 'backend' }));

    const day1Only = trace.query({ date: '2026-06-25' });
    expect(day1Only.length).toBe(2);
    expect(day1Only.every((e) => e.date === '2026-06-25')).toBe(true);

    const allBackend = trace.query({ expertId: 'backend' });
    expect(allBackend.length).toBe(2);
    expect(allBackend.every((e) => e.expertId === 'backend')).toBe(true);

    const specificTicket = trace.query({ ticketId: 'T-2' });
    expect(specificTicket.length).toBe(1);
    expect(specificTicket[0]?.ticketId).toBe('T-2');

    const sinceMidDay = trace.query({ since: new Date('2026-06-25T08:30:00.000Z').getTime() });
    expect(sinceMidDay.length).toBe(2);
    expect(sinceMidDay.every((e) => e.ticketId !== 'T-1')).toBe(true);

    const limited = trace.query({ limit: 2 });
    expect(limited.length).toBe(2);
  });

  it('AC5: stats aggregates byDate / byExpert / byLayer correctly', () => {
    let virtualDate = new Date('2026-06-25T08:00:00.000Z');
    const trace = createScoringTrace({ auditDir: tmpDir, now: () => virtualDate });

    trace.log(makeInput({ ticketId: 'T-1', expertId: 'backend', matchedLayer: 'exact', score: 1.0 }));
    virtualDate = new Date('2026-06-25T09:00:00.000Z');
    trace.log(makeInput({ ticketId: 'T-2', expertId: 'frontend', matchedLayer: 'keyword_threshold', score: 0.7 }));
    virtualDate = new Date('2026-06-26T08:00:00.000Z');
    trace.log(makeInput({ ticketId: 'T-3', expertId: 'backend', matchedLayer: null, score: 0 }));

    const stats = trace.stats();
    expect(stats.totalEntries).toBe(3);
    expect(stats.byDate['2026-06-25']).toBe(2);
    expect(stats.byDate['2026-06-26']).toBe(1);
    expect(stats.byExpert['backend']).toBe(2);
    expect(stats.byExpert['frontend']).toBe(1);
    expect(stats.byLayer['exact']).toBe(1);
    expect(stats.byLayer['keyword_threshold']).toBe(1);
    expect(stats.byLayer['none']).toBe(1);
  });
});

describe('createScoringTrace — 1:1 TrustScore wiring (EPIC-030-A joint)', () => {
  it('AC6: logFromTrustScore preserves matchedLayer + score + factors verbatim', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    const scorer = new TrustScore();

    const expert: ExpertProfile = {
      expertId: 'backend',
      keywords: ['性能', '索引', 'sql'],
    };
    const ticket: TicketProfile = {
      ticketId: 'EPIC-030-A-T1',
      title: 'optimize backend sql',
      description: 'tune',
      keywords: ['backend', '性能', '索引'],
    };
    const trustResult = scorer.match(ticket, expert);
    expect(trustResult.matchedLayer).toBe('exact');

    const entry = trace.logFromTrustScore('EPIC-030-A-T1', 'backend', trustResult);

    expect(entry.ticketId).toBe('EPIC-030-A-T1');
    expect(entry.expertId).toBe('backend');
    expect(entry.matchedLayer).toBe(trustResult.matchedLayer);
    expect(entry.score).toBe(trustResult.score);
    expect(entry.factors.exactHit).toBe(trustResult.breakdown.exactHit);
    expect(entry.factors.keywordOverlap).toBe(trustResult.breakdown.keywordOverlap);
    expect(entry.factors.cosine).toBe(trustResult.breakdown.cosine);

    const filePath = path.join(tmpDir, 'scoring-2026-06-25.jsonl');
    const lines = fs.readFileSync(filePath, 'utf-8').split('\n').filter((l) => l.length > 0);
    expect(lines.length).toBe(1);
    const persisted: ScoringTraceEntry = JSON.parse(lines[0]!);
    expect(persisted.matchedLayer).toBe('exact');
    expect(persisted.score).toBe(1.0);
    expect(persisted.factors.exactHit).toBe(true);
  });

  it('AC7: logFromTrustScore captures all 3 layers (L1 exact / L2 keyword / L3 vector_cosine)', () => {
    const trace = createScoringTrace({ auditDir: tmpDir, now: clockNow });
    const scorer = new TrustScore();

    const exactExpert: ExpertProfile = { expertId: 'backend', keywords: ['sql', 'db'] };
    const exactTicket: TicketProfile = {
      ticketId: 'LAYER-L1',
      title: 't',
      description: 'd',
      keywords: ['backend', 'sql'],
    };

    const keywordExpert: ExpertProfile = { expertId: 'frontend', keywords: ['css', 'react', 'hook'] };
    const keywordTicket: TicketProfile = {
      ticketId: 'LAYER-L2',
      title: 't',
      description: 'd',
      keywords: ['css', 'react'],
    };

    const vectorExpert: ExpertProfile = { expertId: 'observer', keywords: ['alpha', 'beta', 'gamma'] };
    const vectorTicket: TicketProfile = {
      ticketId: 'LAYER-L3',
      title: 'alpha beta',
      description: 'alpha beta gamma',
      keywords: ['alpha'],
    };

    const r1 = scorer.match(exactTicket, exactExpert);
    const r2 = scorer.match(keywordTicket, keywordExpert);
    const r3 = scorer.match(vectorTicket, vectorExpert);

    trace.logFromTrustScore('LAYER-L1', 'backend', r1);
    trace.logFromTrustScore('LAYER-L2', 'frontend', r2);
    trace.logFromTrustScore('LAYER-L3', 'observer', r3);

    const all = trace.query();
    expect(all.length).toBe(3);

    const layers = all.map((e) => e.matchedLayer);
    expect(layers).toContain('exact');
    expect(layers).toContain('keyword_threshold');
    expect(layers).toContain('vector_cosine');
  });
});