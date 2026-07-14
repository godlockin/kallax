/**
 * KALLAX TrustScore — 3-layer matching for ticket → expert assignment.
 *
 * EPIC-030-A: skeleton (basic structure, can be enhanced later).
 *
 * 3 layers (independent signals, priority L1 > L2 > L3):
 *   L1 exact            — ticket keyword equals expert.expertId
 *                         (e.g. ticket keyword "backend" against expert "backend")
 *   L2 keyword_threshold — ≥ 2 ticket keywords overlap with expert.keywords
 *   L3 vector_cosine   — bag-of-words cosine similarity ≥ 0.5 over tokenized text
 *
 * Decision logic (Conductor §5.1):
 *   - L1 hit            → score 1.0 (full confidence, expert name explicitly referenced)
 *   - else L2 hit       → score 0.7 (multiple keyword overlap, strong relevance)
 *   - else L3 cosine ≥ 0.5 → score = cosine (semantic similarity, soft signal)
 *   - else             → score 0 (no match, Conductor falls back)
 *
 * Source: EPIC-024-A keywords (.kallax/data/expansion/l1-baseline-data.json)
 *         EPIC-024-B L1 match test (node/tests/l1-match.test.ts)
 */
import { logger } from '../utils/logger.js';

export type MatchLayer = 'exact' | 'keyword_threshold' | 'vector_cosine';

export interface ExpertProfile {
  readonly expertId: string;
  readonly keywords: readonly string[];
  readonly description?: string;
}

export interface TicketProfile {
  readonly ticketId: string;
  readonly title: string;
  readonly description: string;
  readonly keywords?: readonly string[];
}

export interface TrustScoreResult {
  readonly ticketId: string;
  readonly expertId: string;
  readonly matchedLayer: MatchLayer | null;
  readonly score: number;
  readonly breakdown: {
    readonly exactHit: boolean;
    readonly keywordOverlap: number;
    readonly cosine: number;
  };
}

const KEYWORD_THRESHOLD = 2;
const COSINE_ACCEPT_THRESHOLD = 0.5;
const COSINE_SCORE_SCALE = 1.0;

const TOKEN_SPLIT_REGEX = /[\s,;:.!?()[\]{}<>"'/\\|+\-*]+/u;

export function tokenize(text: string): readonly string[] {
  if (!text) return [];
  return text
    .toLowerCase()
    .split(TOKEN_SPLIT_REGEX)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

export function buildVector(tokens: readonly string[]): Map<string, number> {
  const vec = new Map<string, number>();
  for (const token of tokens) {
    vec.set(token, (vec.get(token) ?? 0) + 1);
  }
  return vec;
}

export function cosineSimilarity(a: Map<string, number>, b: Map<string, number>): number {
  if (a.size === 0 || b.size === 0) return 0;

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (const [, count] of a) {
    normA += count * count;
  }
  for (const [, count] of b) {
    normB += count * count;
  }

  const [smaller, larger] = a.size <= b.size ? [a, b] : [b, a];
  for (const [token, count] of smaller) {
    const otherCount = larger.get(token);
    if (otherCount !== undefined) {
      dotProduct += count * otherCount;
    }
  }

  const denominator = Math.sqrt(normA) * Math.sqrt(normB);
  if (denominator === 0) return 0;
  return dotProduct / denominator;
}

export function matchExact(ticketKeywords: readonly string[], expertId: string): boolean {
  if (ticketKeywords.length === 0 || !expertId) return false;
  const expertIdLower = expertId.toLowerCase();
  return ticketKeywords.some((k) => k.toLowerCase() === expertIdLower);
}

export function countKeywordOverlap(
  ticketKeywords: readonly string[],
  expertKeywords: readonly string[],
): number {
  if (ticketKeywords.length === 0 || expertKeywords.length === 0) return 0;
  const expertLower = new Set(expertKeywords.map((k) => k.toLowerCase()));
  return ticketKeywords.filter((k) => expertLower.has(k.toLowerCase())).length;
}

export interface TrustScoreOptions {
  readonly keywordThreshold?: number;
  readonly cosineAcceptThreshold?: number;
  readonly cosineScoreScale?: number;
}

export class TrustScore {
  private readonly keywordThreshold: number;
  private readonly cosineAcceptThreshold: number;
  private readonly cosineScoreScale: number;

  constructor(options: TrustScoreOptions = {}) {
    this.keywordThreshold = options.keywordThreshold ?? KEYWORD_THRESHOLD;
    this.cosineAcceptThreshold = options.cosineAcceptThreshold ?? COSINE_ACCEPT_THRESHOLD;
    this.cosineScoreScale = options.cosineScoreScale ?? COSINE_SCORE_SCALE;
  }

  match(ticket: TicketProfile, expert: ExpertProfile): TrustScoreResult {
    const ticketKeywords = this.resolveTicketKeywords(ticket);
    const expertKeywords = expert.keywords;

    const exactHit = matchExact(ticketKeywords, expert.expertId);
    const overlap = countKeywordOverlap(ticketKeywords, expertKeywords);

    const ticketText = `${ticket.title} ${ticket.description} ${ticketKeywords.join(' ')}`;
    const expertText = `${expert.expertId} ${expertKeywords.join(' ')} ${expert.description ?? ''}`;
    const cosine = cosineSimilarity(
      buildVector(tokenize(ticketText)),
      buildVector(tokenize(expertText)),
    );

    const matchedLayer = this.selectLayer(exactHit, overlap, cosine);
    const score = this.scoreFromLayer(matchedLayer, cosine);

    const result: TrustScoreResult = {
      ticketId: ticket.ticketId,
      expertId: expert.expertId,
      matchedLayer,
      score,
      breakdown: { exactHit, keywordOverlap: overlap, cosine },
    };

    logger.info(
      {
        event: 'trust_score.match',
        ticketId: ticket.ticketId,
        expertId: expert.expertId,
        matchedLayer,
        score,
        breakdown: result.breakdown,
      },
      'trust score computed',
    );

    return result;
  }

  matchAll(ticket: TicketProfile, experts: readonly ExpertProfile[]): TrustScoreResult[] {
    return experts
      .map((expert) => this.match(ticket, expert))
      .sort((a, b) => b.score - a.score);
  }

  private resolveTicketKeywords(ticket: TicketProfile): readonly string[] {
    if (ticket.keywords && ticket.keywords.length > 0) return ticket.keywords;
    return tokenize(`${ticket.title} ${ticket.description}`);
  }

  private selectLayer(exactHit: boolean, overlap: number, cosine: number): MatchLayer | null {
    if (exactHit) return 'exact';
    if (overlap >= this.keywordThreshold) return 'keyword_threshold';
    if (cosine >= this.cosineAcceptThreshold) return 'vector_cosine';
    return null;
  }

  private scoreFromLayer(layer: MatchLayer | null, cosine: number): number {
    switch (layer) {
      case 'exact':
        return 1.0;
      case 'keyword_threshold':
        return 0.7;
      case 'vector_cosine':
        return cosine * this.cosineScoreScale;
      default:
        return 0;
    }
  }
}

export function createTrustScore(options?: TrustScoreOptions): TrustScore {
  return new TrustScore(options);
}
