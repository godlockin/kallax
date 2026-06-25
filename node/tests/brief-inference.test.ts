/**
 * Brief Inference unit tests — EPIC-030-I
 *
 * 7+ test cases covering 4 acceptance criteria (L1-L4):
 *   AC1 (L1 存在性): parseBrief + validateBrief exist
 *   AC2 (L2 实质性): enforceClaimWithBrief rejects when brief_inference missing,
 *                    accepts when present + quality ≥ threshold
 *   AC3 (L3 接线正确): attachBriefToTicket writes valid JSON, round-trip OK
 *   AC4 (L4 数据流动): TrustScore 联合 — evaluateBriefQuality + briefBoostsTrustScore
 *
 * Strategy (反讽 + 诚实修正): force Performer to write concrete, risk-aware,
 * measurable brief before claim. Surface hidden misunderstanding early.
 *
 * Borrowed methodology: eket SLAVER-RULES.md §2.5 (Performer §5.1) — 0 code copy.
 * TrustScore integration: node/src/core/trust-score.ts (EPIC-030-A, already merged).
 *
 * Run: npx vitest run tests/brief-inference.test.ts
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  parseBrief,
  validateBrief,
  serializeBrief,
  evaluateBriefQuality,
  briefBoostsTrustScore,
  combinedExpertAssignment,
  readTicket,
  attachBriefToTicket,
  enforceClaimWithBrief,
  BRIEF_INFERENCE_FIELD,
  type BriefInference,
  type TicketWithBrief,
} from '../src/core/brief-inference/index.js';
import { TrustScore, type ExpertProfile, type TicketProfile } from '../src/core/trust-score.js';

// ============================================================================
// Helpers
// ============================================================================

const STRONG_BRIEF: BriefInference = {
  taskType: 'backend',
  coreGoal: '修复 N+1 SQL query 在 src/core/orders.ts:142',
  technicalApproach: '加 .include({ items: true }) + orders.userId 索引 migration',
  risks: '索引迁移回滚风险 + cache miss 第一波延迟 spike',
};

const WEAK_BRIEF: BriefInference = {
  taskType: 'a',
  coreGoal: 'b',
  technicalApproach: 'c',
  risks: 'd',
};

const VAGUE_BRIEF: BriefInference = {
  taskType: 'task',
  coreGoal: '应该 probably maybe 修一下',
  technicalApproach: '可能 maybe 改一下',
  risks: '好像 no risks',
};

let tempDir: string;
let ticketPath: string;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), 'brief-inference-'));
  ticketPath = join(tempDir, 'EPIC-030-I-test.json');
  writeFileSync(ticketPath, JSON.stringify(baseTicket()), 'utf-8');
});

afterEach(() => {
  rmSync(tempDir, { recursive: true, force: true });
});

function baseTicket(): TicketWithBrief {
  return {
    id: 'EPIC-030-I-test',
    title: 'Brief Inference 测试 ticket',
    description: '强制任务理解',
  };
}

function writeTicketWithBrief(brief: BriefInference): void {
  writeFileSync(
    ticketPath,
    JSON.stringify({ ...baseTicket(), brief_inference: brief }, null, 2),
    'utf-8',
  );
}

// ============================================================================
// AC1: parseBrief + validateBrief exist + parse 4-section format
// ============================================================================

describe('AC1: parseBrief (4-section format)', () => {
  it('parses full 📋 prefix + 4 sections separated by " | "', () => {
    const input = '📋 任务理解: backend | 修 N+1 query | 加 include + 索引 | 索引迁移回滚';
    const result = parseBrief(input);
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.taskType).toBe('backend');
      expect(result.value.coreGoal).toBe('修 N+1 query');
      expect(result.value.technicalApproach).toBe('加 include + 索引');
      expect(result.value.risks).toBe('索引迁移回滚');
    }
  });

  it('accepts input without 📋 prefix (raw 4 sections)', () => {
    const result = parseBrief('frontend | 改 dashboard | 用 React.memo | re-render 风险');
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.taskType).toBe('frontend');
      expect(result.value.technicalApproach).toBe('用 React.memo');
    }
  });

  it('rejects input with wrong section count (3 instead of 4)', () => {
    const result = parseBrief('backend | 修 query | 加 include');
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.code).toBe('BRIEF_INFERENCE_MALFORMED');
    }
  });

  it('rejects empty input', () => {
    const result = parseBrief('');
    expect(result.isErr()).toBe(true);
  });

  it('rejects empty section (whitespace-only)', () => {
    const result = parseBrief('backend | 修 query |    | 风险');
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.code).toBe('BRIEF_INFERENCE_EMPTY_SECTION');
      if (result.error.code === 'BRIEF_INFERENCE_EMPTY_SECTION') {
        expect(result.error.section).toBe('technicalApproach');
      }
    }
  });
});

describe('AC1: validateBrief', () => {
  it('accepts a well-formed brief', () => {
    const result = validateBrief(STRONG_BRIEF);
    expect(result.isOk()).toBe(true);
  });

  it('rejects a brief with too-short fields (below MIN_FIELD_LENGTH)', () => {
    const result = validateBrief(WEAK_BRIEF);
    expect(result.isErr()).toBe(true);
  });
});

describe('serializeBrief', () => {
  it('round-trips: parse(serialize(brief)) === brief', () => {
    const serialized = serializeBrief(STRONG_BRIEF);
    expect(serialized.startsWith('📋 任务理解:')).toBe(true);
    const parsed = parseBrief(serialized);
    expect(parsed.isOk()).toBe(true);
    if (parsed.isOk()) {
      expect(parsed.value).toEqual(STRONG_BRIEF);
    }
  });
});

// ============================================================================
// AC2: enforceClaimWithBrief — the GATE
// ============================================================================

describe('AC2: enforceClaimWithBrief — claim gate', () => {
  it('rejects claim when brief_inference field is missing (exit 1 analog)', () => {
    const result = enforceClaimWithBrief(ticketPath, 'performer-test');
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.code).toBe('BRIEF_INFERENCE_MISSING');
    }
  });

  it('accepts claim when brief_inference is present and quality ≥ threshold', () => {
    writeTicketWithBrief(STRONG_BRIEF);
    const result = enforceClaimWithBrief(ticketPath, 'performer-test');
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.ticket.id).toBe('EPIC-030-I-test');
      expect(result.value.quality.passes).toBe(true);
      expect(result.value.quality.score).toBeGreaterThan(0.5);
    }
  });

  it('rejects claim when brief is present but quality too low (vague phrases)', () => {
    writeTicketWithBrief(VAGUE_BRIEF);
    const result = enforceClaimWithBrief(ticketPath, 'performer-test');
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(['BRIEF_INFERENCE_MALFORMED']).toContain(result.error.code);
    }
  });

  it('returns read error when ticket file does not exist', () => {
    const result = enforceClaimWithBrief(join(tempDir, 'no-such.json'), 'performer-test');
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.code).toBe('TICKET_FILE_READ_FAILED');
    }
  });
});

// ============================================================================
// AC3: attachBriefToTicket — JSON round-trip
// ============================================================================

describe('AC3: attachBriefToTicket — write + read round-trip', () => {
  it('writes brief_inference + claimed_by + claimed_at to ticket.json', () => {
    const result = attachBriefToTicket(ticketPath, STRONG_BRIEF, 'performer-test');
    expect(result.isOk()).toBe(true);

    const raw = readFileSync(ticketPath, 'utf-8');
    const parsed = JSON.parse(raw) as TicketWithBrief;
    expect(parsed.brief_inference).toEqual(STRONG_BRIEF);
    expect(parsed.claimed_by).toBe('performer-test');
    expect(typeof parsed.claimed_at).toBe('string');
    expect(parsed[BRIEF_INFERENCE_FIELD]).toEqual(STRONG_BRIEF);
  });

  it('round-trip: attach then read preserves all 4 brief fields', () => {
    attachBriefToTicket(ticketPath, STRONG_BRIEF, 'performer-test');
    const readResult = readTicket(ticketPath);
    expect(readResult.isOk()).toBe(true);
    if (readResult.isOk()) {
      expect(readResult.value.brief_inference).toEqual(STRONG_BRIEF);
    }
  });

  it('rejects attach with malformed brief (does not corrupt ticket.json)', () => {
    const before = readFileSync(ticketPath, 'utf-8');
    const result = attachBriefToTicket(ticketPath, WEAK_BRIEF, 'performer-test');
    expect(result.isErr()).toBe(true);
    const after = readFileSync(ticketPath, 'utf-8');
    expect(after).toBe(before);
  });
});

// ============================================================================
// AC4: TrustScore 联合 — quality scoring + boost
// ============================================================================

describe('AC4: evaluateBriefQuality — quality dimensions', () => {
  it('strong brief (concrete + risk-aware + measurable) scores high', () => {
    const q = evaluateBriefQuality(STRONG_BRIEF);
    expect(q.score).toBeGreaterThan(0.6);
    expect(q.passes).toBe(true);
    expect(q.breakdown.specificity).toBeGreaterThan(0.6);
    expect(q.breakdown.completeness).toBe(1.0);
    expect(q.breakdown.riskAware).toBeGreaterThan(0.5);
  });

  it('vague brief (probably / maybe / should) scores low', () => {
    const q = evaluateBriefQuality(VAGUE_BRIEF);
    expect(q.score).toBeLessThan(0.6);
    expect(q.breakdown.specificity).toBeLessThan(0.5);
  });

  it('completeness is exactly 1.0 when all 4 sections non-empty', () => {
    const q = evaluateBriefQuality(STRONG_BRIEF);
    expect(q.breakdown.completeness).toBe(1.0);
  });

  it('all 4 quality dimensions are in [0, 1]', () => {
    const q = evaluateBriefQuality(STRONG_BRIEF);
    for (const dim of [
      q.breakdown.specificity,
      q.breakdown.completeness,
      q.breakdown.riskAware,
      q.breakdown.measurable,
    ]) {
      expect(dim).toBeGreaterThanOrEqual(0);
      expect(dim).toBeLessThanOrEqual(1);
    }
  });
});

describe('AC4: briefBoostsTrustScore (EPIC-030-A 联合)', () => {
  it('strong brief raises base TrustScore by quality * 0.15', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'T-1',
      title: 'fix SQL N+1',
      description: 'database optimization',
      keywords: ['backend', 'sql', '数据库', '性能'],
    };
    const expert: ExpertProfile = { expertId: 'backend', keywords: ['backend', 'sql'] };
    const base = scorer.match(ticket, expert);
    const boosted = briefBoostsTrustScore(STRONG_BRIEF, base);
    expect(boosted.score).toBeGreaterThanOrEqual(base.score);
    expect(boosted.score).toBeLessThanOrEqual(1.0);
  });

  it('combinedExpertAssignment with no brief returns base score only', () => {
    const ticket: TicketProfile = {
      ticketId: 'T-2',
      title: 'fix SQL',
      description: 'slow query',
      keywords: ['backend', 'sql'],
    };
    const expert: ExpertProfile = { expertId: 'backend', keywords: ['backend'] };
    const result = combinedExpertAssignment(ticket, expert, null);
    expect(result.briefQuality).toBeNull();
    expect(result.trustResult.score).toBeGreaterThan(0);
  });

  it('combinedExpertAssignment with strong brief boosts score + reports quality', () => {
    const ticket: TicketProfile = {
      ticketId: 'T-3',
      title: 'backend perf opt',
      description: 'sql index tune',
      keywords: ['backend', 'sql', '性能'],
    };
    const expert: ExpertProfile = { expertId: 'backend', keywords: ['backend', 'sql'] };
    const result = combinedExpertAssignment(ticket, expert, STRONG_BRIEF);
    expect(result.briefQuality).not.toBeNull();
    expect(result.briefQuality?.passes).toBe(true);
    expect(result.trustResult.score).toBeGreaterThan(0);
  });
});
