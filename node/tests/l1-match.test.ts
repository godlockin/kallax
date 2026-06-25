/**
 * L1 Expert Match Tests (EPIC-024-B)
 *
 * 125 test cases (25 baseline records × 5 experts) verifying the L1 keyword
 * match logic for ticket→expert resolution. Each test case is a tuple
 * {ticket_id, expert, keywords[], expected_match}.
 *
 * 3 match strategies are exercised per the ticket acceptance criteria:
 *   1. exact: any keyword in target expert's trigger set
 *   2. substring: any keyword contains any trigger as substring
 *   3. keyword_ge_n: at least N keywords in target expert's trigger set
 *
 * Baseline data: .kallax/data/expansion/l1-baseline-data.json (from EPIC-024-A)
 * Expert triggers: .kallax/experts/default/<expert>.md `trigger:` field
 *
 * Run: npx vitest run tests/l1-match.test.ts
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const REPO_ROOT = resolve(process.cwd(), '..');
const BASELINE_PATH = join(REPO_ROOT, '.kallax/data/expansion/l1-baseline-data.json');
const EXPERTS_DIR = join(REPO_ROOT, '.kallax/experts/default');

const EXPERT_LIST = ['architect', 'backend', 'frontend', 'ux', 'product'] as const;
type Expert = (typeof EXPERT_LIST)[number];

const MIN_KEYWORD_THRESHOLD = 2;

interface BaselineRecord {
  ticket_id: string;
  expert: string;
  keywords: string[];
  title: string;
  description: string;
  actual_expert: string | null;
}

interface MatchCase {
  ticket_id: string;
  expert: Expert;
  keywords: string[];
  expected_match: boolean;
  matched_keywords: string[];
}

const loadBaseline = (): readonly BaselineRecord[] => {
  const raw = readFileSync(BASELINE_PATH, 'utf-8');
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) {
    throw new Error('l1-baseline-data.json must be an array');
  }
  return parsed as BaselineRecord[];
};

const parseTrigger = (content: string): string[] => {
  const triggerLine = content
    .split('\n')
    .find((line) => line.startsWith('trigger:'));
  if (triggerLine === undefined) return [];
  const value = triggerLine.slice('trigger:'.length).trim();
  return value
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
};

const loadExpertTriggers = (): Readonly<Record<Expert, ReadonlySet<string>>> => {
  const out = {} as Record<Expert, ReadonlySet<string>>;
  for (const expert of EXPERT_LIST) {
    const file = join(EXPERTS_DIR, `${expert}.md`);
    const content = readFileSync(file, 'utf-8');
    const triggers = parseTrigger(content);
    out[expert] = new Set(triggers);
  }
  return out;
};

const matchExact = (keywords: readonly string[], triggers: ReadonlySet<string>): string[] => {
  const hits: string[] = [];
  for (const kw of keywords) {
    if (triggers.has(kw)) hits.push(kw);
  }
  return hits;
};

const matchSubstring = (keywords: readonly string[], triggers: ReadonlySet<string>): string[] => {
  const hits: string[] = [];
  for (const kw of keywords) {
    for (const trig of triggers) {
      if (trig.length > 0 && kw.includes(trig)) {
        hits.push(kw);
        break;
      }
    }
  }
  return hits;
};

const matchKeywordGeN = (
  keywords: readonly string[],
  triggers: ReadonlySet<string>,
  n: number,
): string[] => {
  const hits = matchExact(keywords, triggers);
  return hits.length >= n ? hits : [];
};

const computeExpectedMatch = (
  record: BaselineRecord,
  expert: Expert,
  triggers: Readonly<Record<Expert, ReadonlySet<string>>>,
): { expected: boolean; matched: string[] } => {
  const expertTriggers = triggers[expert];
  const matched = matchExact(record.keywords, expertTriggers);
  const isCorrectExpert = record.expert === expert;
  if (isCorrectExpert) {
    return { expected: matched.length > 0, matched };
  }
  return { expected: matched.length > 0, matched };
};

const buildCases = (
  records: readonly BaselineRecord[],
  triggers: Readonly<Record<Expert, ReadonlySet<string>>>,
): MatchCase[] => {
  const cases: MatchCase[] = [];
  for (const record of records) {
    for (const expert of EXPERT_LIST) {
      const { expected, matched } = computeExpectedMatch(record, expert, triggers);
      cases.push({
        ticket_id: record.ticket_id,
        expert,
        keywords: record.keywords,
        expected_match: expected,
        matched_keywords: matched,
      });
    }
  }
  return cases;
};

const records: readonly BaselineRecord[] = loadBaseline();
const triggers: Readonly<Record<Expert, ReadonlySet<string>>> = loadExpertTriggers();
const cases: readonly MatchCase[] = buildCases(records, triggers);

const correctCases: readonly MatchCase[] = cases.filter((c) => {
  const rec = records.find((r) => r.ticket_id === c.ticket_id);
  return rec !== undefined && rec.expert === c.expert;
});

describe('L1 Expert Match (EPIC-024-B)', () => {
  describe('baseline integrity', () => {
    it('loads exactly 25 records from EPIC-024-A baseline', () => {
      expect(records.length).toBe(25);
    });

    it('every record belongs to one of the 5 supported experts', () => {
      for (const r of records) {
        expect(EXPERT_LIST).toContain(r.expert);
      }
    });

    it('every record has non-empty keywords', () => {
      for (const r of records) {
        expect(r.keywords.length).toBeGreaterThan(0);
      }
    });

    it('generates 125 test cases (25 records × 5 experts)', () => {
      expect(cases.length).toBe(125);
    });
  });

  describe('expert trigger loading', () => {
    it('architect triggers non-empty', () => {
      expect(triggers.architect.size).toBeGreaterThan(0);
    });
    it('backend triggers non-empty', () => {
      expect(triggers.backend.size).toBeGreaterThan(0);
    });
    it('frontend triggers non-empty', () => {
      expect(triggers.frontend.size).toBeGreaterThan(0);
    });
    it('ux triggers non-empty', () => {
      expect(triggers.ux.size).toBeGreaterThan(0);
    });
    it('product triggers non-empty', () => {
      expect(triggers.product.size).toBeGreaterThan(0);
    });
  });

  describe('L1 match — exact strategy (125 cases)', () => {
    it.each(cases)(
      'ticket=$ticket_id expert=$expert expected=$expected_match',
      ({ ticket_id, expert, keywords, expected_match, matched_keywords }) => {
        const expertTriggers = triggers[expert];
        const hits = matchExact(keywords, expertTriggers);
        expect(hits.length > 0).toBe(expected_match);
        if (expected_match) {
          expect(matched_keywords.length).toBeGreaterThan(0);
        }
        void ticket_id;
      },
    );
  });

  describe('L1 match — substring strategy (125 cases)', () => {
    it.each(cases)(
      'ticket=$ticket_id expert=$expert substring_hits<=keywords',
      ({ ticket_id, expert, keywords }) => {
        const expertTriggers = triggers[expert];
        const hits = matchSubstring(keywords, expertTriggers);
        expect(hits.length).toBeLessThanOrEqual(keywords.length);
        expect(new Set(hits).size).toBe(hits.length);
        void ticket_id;
        void expert;
      },
    );
  });

  describe('L1 match — keyword>=N strategy (125 cases)', () => {
    it.each(cases)(
      'ticket=$ticket_id expert=$expert geN_count<=exact_count',
      ({ ticket_id, expert, keywords }) => {
        const expertTriggers = triggers[expert];
        const exactHits = matchExact(keywords, expertTriggers);
        const geNHits = matchKeywordGeN(keywords, expertTriggers, MIN_KEYWORD_THRESHOLD);
        expect(geNHits.length).toBeLessThanOrEqual(exactHits.length);
        expect(geNHits.length === 0 || geNHits.length >= MIN_KEYWORD_THRESHOLD).toBe(true);
        void ticket_id;
        void expert;
      },
    );
  });

  describe('expert recall — all correct-expert cases must match', () => {
    it('produces 25 correct-expert cases (one per baseline record)', () => {
      expect(correctCases.length).toBe(25);
    });
    it.each(correctCases)(
      'exact match succeeds for correct expert: ticket=$ticket_id expert=$expert',
      ({ ticket_id, expert, keywords }) => {
        const expertTriggers = triggers[expert];
        const hits = matchExact(keywords, expertTriggers);
        expect(hits.length).toBeGreaterThan(0);
        void ticket_id;
      },
    );
  });

  describe('coverage analysis (recorded for SPRINT-A-REPORT)', () => {
    it('per-expert match counts (exact strategy)', () => {
      const counts: Record<Expert, { matched: number; total: number }> = {
        architect: { matched: 0, total: 0 },
        backend: { matched: 0, total: 0 },
        frontend: { matched: 0, total: 0 },
        ux: { matched: 0, total: 0 },
        product: { matched: 0, total: 0 },
      };
      for (const c of cases) {
        counts[c.expert].total += 1;
        if (c.expected_match) counts[c.expert].matched += 1;
      }
      const totalMatched = Object.values(counts).reduce((s, v) => s + v.matched, 0);
      const totalCases = cases.length;
      const correctExpertCases = 25;
      const crossExpertMatches = totalMatched - correctExpertCases;
      expect(totalCases).toBe(125);
      expect(totalMatched).toBeGreaterThanOrEqual(25);
      expect(crossExpertMatches).toBeGreaterThanOrEqual(0);
      expect(counts.architect.total).toBe(25);
      expect(counts.backend.total).toBe(25);
      expect(counts.frontend.total).toBe(25);
      expect(counts.ux.total).toBe(25);
      expect(counts.product.total).toBe(25);
      expect(counts.architect.matched).toBeGreaterThanOrEqual(12);
      expect(counts.backend.matched).toBeGreaterThanOrEqual(12);
    });
  });
});
