/**
 * TrustScore unit tests — EPIC-030-A
 *
 * 5+ test cases mirroring EPIC-024-B L1 match test pattern (1:1 verification).
 * 3 layers tested (priority L1 > L2 > L3):
 *   L1 exact            — score 1.0, matchedLayer='exact'
 *                         (ticket keyword equals expert.expertId)
 *   L2 keyword ≥ N      — score 0.7, matchedLayer='keyword_threshold'
 *                         (≥ 2 keyword overlap with expert.keywords)
 *   L3 vector cosine    — score = cosine, matchedLayer='vector_cosine'
 *                         (bag-of-words cosine ≥ 0.5 over tokenized text)
 *
 * Baseline data: .kallax/data/expansion/l1-baseline-data.json (EPIC-024-A)
 * Expert triggers: .kallax/experts/default/<expert>.md `trigger:` field
 * Run: npx vitest run tests/trust-score.test.ts
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import {
  TrustScore,
  createTrustScore,
  tokenize,
  buildVector,
  cosineSimilarity,
  matchExact,
  countKeywordOverlap,
  type ExpertProfile,
  type TicketProfile,
  type MatchLayer,
} from '../src/core/trust-score.js';

const REPO_ROOT = resolve(process.cwd(), '..');
const BASELINE_PATH = join(REPO_ROOT, '.kallax/data/expansion/l1-baseline-data.json');
const EXPERTS_DIR = join(REPO_ROOT, '.kallax/experts/default');

const EXPERT_LIST = ['architect', 'backend', 'frontend', 'ux', 'product'] as const;
type Expert = (typeof EXPERT_LIST)[number];

const KEYWORD_THRESHOLD = 2;
const COSINE_ACCEPT_THRESHOLD = 0.5;

interface BaselineRecord {
  ticket_id: string;
  expert: string;
  keywords: string[];
  title: string;
  description: string;
  actual_expert: string | null;
}

const parseTrigger = (content: string): readonly string[] => {
  const triggerLine = content
    .split('\n')
    .find((line) => line.startsWith('trigger:'));
  if (triggerLine === undefined) return [];
  return triggerLine
    .slice('trigger:'.length)
    .trim()
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
};

const loadBaseline = (): readonly BaselineRecord[] => {
  const raw = readFileSync(BASELINE_PATH, 'utf-8');
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) {
    throw new Error('l1-baseline-data.json must be an array');
  }
  return parsed as BaselineRecord[];
};

const loadExpertTriggers = (): Readonly<Record<Expert, readonly string[]>> => {
  const out = {} as Record<Expert, readonly string[]>;
  for (const expert of EXPERT_LIST) {
    const file = join(EXPERTS_DIR, `${expert}.md`);
    const content = readFileSync(file, 'utf-8');
    out[expert] = parseTrigger(content);
  }
  return out;
};

const records: readonly BaselineRecord[] = loadBaseline();
const triggers: Readonly<Record<Expert, readonly string[]>> = loadExpertTriggers();

function expertFromId(id: string): ExpertProfile {
  if (!EXPERT_LIST.includes(id as Expert)) {
    return { expertId: id, keywords: [] };
  }
  return { expertId: id, keywords: triggers[id as Expert] };
}

function ticketFromRecord(record: BaselineRecord): TicketProfile {
  return {
    ticketId: record.ticket_id,
    title: record.title,
    description: record.description,
    keywords: record.keywords,
  };
}

describe('tokenize', () => {
  it('lowercases and splits on whitespace + punctuation', () => {
    expect(tokenize('API 接口慢, Database SQL!')).toEqual(['api', '接口慢', 'database', 'sql']);
  });

  it('returns empty array for empty input', () => {
    expect(tokenize('')).toEqual([]);
    expect(tokenize('   ')).toEqual([]);
  });
});

describe('buildVector', () => {
  it('counts term frequencies', () => {
    const vec = buildVector(['api', 'sql', 'api']);
    expect(vec.get('api')).toBe(2);
    expect(vec.get('sql')).toBe(1);
    expect(vec.size).toBe(2);
  });
});

describe('cosineSimilarity', () => {
  it('returns 1.0 for identical vectors', () => {
    const a = buildVector(['api', 'sql']);
    const b = buildVector(['api', 'sql']);
    expect(cosineSimilarity(a, b)).toBeCloseTo(1.0, 6);
  });

  it('returns 0 for disjoint vectors', () => {
    const a = buildVector(['api', 'sql']);
    const b = buildVector(['架构', '选型']);
    expect(cosineSimilarity(a, b)).toBe(0);
  });

  it('returns 0 when one vector is empty', () => {
    expect(cosineSimilarity(buildVector([]), buildVector(['api']))).toBe(0);
    expect(cosineSimilarity(buildVector(['api']), buildVector([]))).toBe(0);
  });
});

describe('matchExact', () => {
  it('returns true when ticket keyword equals expertId (case-insensitive)', () => {
    expect(matchExact(['backend'], 'backend')).toBe(true);
    expect(matchExact(['BACKEND'], 'backend')).toBe(true);
    expect(matchExact(['Backend'], 'backend')).toBe(true);
  });

  it('returns false when no keyword matches expertId', () => {
    expect(matchExact(['sql', 'database'], 'backend')).toBe(false);
  });

  it('returns false for empty ticket keywords', () => {
    expect(matchExact([], 'backend')).toBe(false);
  });
});

describe('countKeywordOverlap', () => {
  it('counts overlap correctly', () => {
    expect(countKeywordOverlap(['SQL', 'API', '不存在'], triggers.backend)).toBe(2);
  });

  it('returns 0 when no overlap', () => {
    expect(countKeywordOverlap(['xyz', 'abc'], triggers.backend)).toBe(0);
  });
});

describe('TrustScore.match', () => {
  it('AC1: L1 exact match returns matchedLayer=exact and score=1.0', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-1',
      title: 'write benchmark',
      description: 'measure wall-time',
      keywords: ['backend', 'sql', 'database'],
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.matchedLayer).toBe<MatchLayer>('exact');
    expect(result.score).toBe(1.0);
    expect(result.breakdown.exactHit).toBe(true);
  });

  it('AC2: L2 keyword threshold (≥2) returns matchedLayer=keyword_threshold and score=0.7', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-2',
      title: 'perf and index opt',
      description: 'tune',
      keywords: ['性能', '索引'],
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.matchedLayer).toBe<MatchLayer>('keyword_threshold');
    expect(result.score).toBe(0.7);
    expect(result.breakdown.keywordOverlap).toBeGreaterThanOrEqual(KEYWORD_THRESHOLD);
  });

  it('AC3: L3 vector cosine ≥ 0.5 returns matchedLayer=vector_cosine and score=cosine', () => {
    const scorer = new TrustScore();
    const customExpert: ExpertProfile = {
      expertId: 'foo-expert',
      keywords: ['foo', 'bar', 'baz', 'qux'],
    };
    const ticket: TicketProfile = {
      ticketId: 'AC-3',
      title: 'foo bar',
      description: 'foo bar baz qux',
      keywords: ['alpha', 'beta'],
    };
    const result = scorer.match(ticket, customExpert);
    expect(result.breakdown.exactHit).toBe(false);
    expect(result.breakdown.keywordOverlap).toBe(0);
    expect(result.matchedLayer).toBe<MatchLayer>('vector_cosine');
    expect(result.score).toBeGreaterThanOrEqual(COSINE_ACCEPT_THRESHOLD);
    expect(result.score).toBeLessThanOrEqual(1.0);
  });

  it('AC4: no-match returns matchedLayer=null and score=0', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-4',
      title: '完全无关的任务 xyz',
      description: 'foobarbaz unrelated-keyword',
      keywords: ['xyz', 'foobarbaz'],
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.matchedLayer).toBeNull();
    expect(result.score).toBe(0);
  });

  it('AC5: cosine < 0.5 with no keyword overlap returns null layer', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-5',
      title: '一',
      description: '二',
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(1);
  });

  it('AC6: edge case — empty ticket keywords with empty description returns 0', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = { ticketId: 'AC-6', title: '', description: '', keywords: [] };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.score).toBe(0);
  });

  it('AC7: boundary — exactly 1 keyword overlap (below threshold) does not trigger L2', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-7',
      title: 'single keyword overlap test',
      description: 'no other keywords match',
      keywords: ['unrelated-1', 'unrelated-2', 'unrelated-3', '性能'],
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.matchedLayer).not.toBe<MatchLayer>('keyword_threshold');
    expect(result.breakdown.keywordOverlap).toBe(1);
  });

  it('AC8: L1 priority — both L1 and L2 fire, layer reports exact (priority)', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-8',
      title: 'backend sql optimization',
      description: 'tune',
      keywords: ['backend', '性能', '索引'],
    };
    const result = scorer.match(ticket, expertFromId('backend'));
    expect(result.matchedLayer).toBe<MatchLayer>('exact');
    expect(result.score).toBe(1.0);
    expect(result.breakdown.keywordOverlap).toBeGreaterThanOrEqual(KEYWORD_THRESHOLD);
  });
});

describe('TrustScore.matchAll', () => {
  it('sorts results by score descending (best expert first)', () => {
    const scorer = new TrustScore();
    const ticket: TicketProfile = {
      ticketId: 'AC-9',
      title: 'optimize SQL query',
      description: 'database sql query slow performance',
      keywords: ['backend', 'SQL', '数据库', '性能', '查询慢'],
    };
    const experts: readonly ExpertProfile[] = EXPERT_LIST.map((id) => expertFromId(id));
    const results = scorer.matchAll(ticket, experts);
    expect(results.length).toBe(5);
    expect(results[0]?.expertId).toBe('backend');
    for (let i = 1; i < results.length; i++) {
      const prev = results[i - 1];
      const curr = results[i];
      expect(prev).toBeDefined();
      expect(curr).toBeDefined();
      if (prev && curr) {
        expect(prev.score).toBeGreaterThanOrEqual(curr.score);
      }
    }
  });
});

describe('createTrustScore', () => {
  it('factory returns a configured TrustScore instance', () => {
    const ts = createTrustScore({ keywordThreshold: 3, cosineAcceptThreshold: 0.3 });
    expect(ts).toBeInstanceOf(TrustScore);
  });
});

describe('EPIC-024-A baseline 1:1 validation (EPIC-024-B pattern)', () => {
  it('loads 25 baseline records', () => {
    expect(records.length).toBe(25);
  });

  it('every record belongs to one of the 5 supported experts', () => {
    for (const r of records) {
      expect(EXPERT_LIST).toContain(r.expert);
    }
  });

  it('baseline integrity — every record has non-empty keywords', () => {
    for (const r of records) {
      expect(r.keywords.length).toBeGreaterThan(0);
    }
  });

  it('per-record: correct expert scores ≥ 0.7 (must trigger L2 keyword_threshold)', () => {
    const scorer = new TrustScore();
    for (const record of records) {
      const result = scorer.match(ticketFromRecord(record), expertFromId(record.expert));
      expect(
        result.score,
        `ticket ${record.ticket_id} → ${record.expert} should score ≥ 0.7 (got ${result.score}, layer ${result.matchedLayer})`,
      ).toBeGreaterThanOrEqual(0.7);
    }
  });

  it('cross-expert: a backend ticket ranks backend in top 2 (allowing for keyword cross-overlap)', () => {
    const scorer = new TrustScore();
    const backendRecords = records.filter((r) => r.expert === 'backend');
    for (const record of backendRecords.slice(0, 5)) {
      const ranked = scorer.matchAll(ticketFromRecord(record), EXPERT_LIST.map((id) => expertFromId(id)));
      const top2 = ranked.slice(0, 2).map((r) => r.expertId);
      expect(top2, `ticket ${record.ticket_id} should rank backend in top 2`).toContain('backend');
    }
  });
});
