/**
 * KALLAX ScoringTrace — append-only daily-rotated audit log for TrustScore decisions.
 *
 * EPIC-030-B: skeleton (basic structure, can be enhanced later).
 *
 * Daily rotation strategy:
 *   File path = `<auditDir>/scoring-YYYY-MM-DD.jsonl`
 *   New day → new file (append-only, never mutates prior days).
 *   The `date` field on every entry mirrors the file partition so a query can
 *   scope to a single day's trace without parsing timestamps.
 *
 * Append-only baseline (跟 EPIC-024 enterprise-audit ):
 *   - log() opens file with 'a' flag, never reads-then-writes
 *   - No mutation, no deletion, no in-place rewrite
 *   - One JSON object per line (jsonl), trailing newline required
 *
 * 1:1 TrustScore wiring (跟 EPIC-030-A ):
 *   logFromTrustScore() accepts a TrustScoreResult and produces an entry
 *   with matchedLayer + score + factors breakdown preserved verbatim.
 *   The breakdown.exactHit / keywordOverlap / cosine triple is the same
 *   shape that TrustScore.match() returns — no data loss in the bridge.
 *
 * Testability:
 *   `now` option injects a clock so daily-rotation tests can drive the
 *   boundary at midnight without sleeping. Same DI pattern as
 *   enterprise-audit.ts / expert-invocations-queue.
 *
 * Source: Conductor §5.1 best_matching_slaver() audit requirement
 *         EPIC-030-A TrustScore (1:1 verification)
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { logger } from '../utils/logger.js';
import type { TrustScoreResult, MatchLayer } from './trust-score.js';

export interface ScoringTraceFactors {
  readonly exactHit: boolean;
  readonly keywordOverlap: number;
  readonly cosine: number;
}

export interface ScoringTraceEntry {
  readonly id: string;
  readonly timestamp: number;
  readonly date: string;
  readonly ticketId: string;
  readonly expertId: string;
  readonly matchedLayer: MatchLayer | null;
  readonly score: number;
  readonly factors: ScoringTraceFactors;
}

export interface ScoringTraceInput {
  readonly ticketId: string;
  readonly expertId: string;
  readonly matchedLayer: MatchLayer | null;
  readonly score: number;
  readonly factors: ScoringTraceFactors;
}

export interface ScoringTraceFilter {
  readonly date?: string;
  readonly ticketId?: string;
  readonly expertId?: string;
  readonly since?: number;
  readonly until?: number;
  readonly limit?: number;
}

export interface ScoringTraceStats {
  readonly totalEntries: number;
  readonly byDate: Readonly<Record<string, number>>;
  readonly byExpert: Readonly<Record<string, number>>;
  readonly byLayer: Readonly<Record<string, number>>;
}

export interface ScoringTraceOptions {
  readonly auditDir?: string;
  readonly filenamePrefix?: string;
  readonly now?: () => Date;
}

export interface ScoringTrace {
  log(entry: ScoringTraceInput): ScoringTraceEntry;
  logFromTrustScore(ticketId: string, expertId: string, result: TrustScoreResult): ScoringTraceEntry;
  query(filter?: ScoringTraceFilter): readonly ScoringTraceEntry[];
  stats(filter?: ScoringTraceFilter): ScoringTraceStats;
  getFilePath(date?: string): string;
}

const DEFAULT_AUDIT_DIR = '.kallax/audit';
const DEFAULT_FILENAME_PREFIX = 'scoring-';
const DATE_FORMAT_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const FACTORS_KEYS = ['exactHit', 'keywordOverlap', 'cosine'] as const;

function formatDate(d: Date): string {
  const yyyy = d.getUTCFullYear().toString().padStart(4, '0');
  const mm = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const dd = d.getUTCDate().toString().padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function isValidDateString(date: string): boolean {
  return DATE_FORMAT_REGEX.test(date);
}

function generateId(): string {
  return `trace_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function ensureDir(dir: string): void {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function isScoringTraceFactors(value: unknown): value is ScoringTraceFactors {
  if (value === null || typeof value !== 'object') return false;
  const obj = value as Record<string, unknown>;
  if (typeof obj['exactHit'] !== 'boolean') return false;
  if (typeof obj['keywordOverlap'] !== 'number') return false;
  if (typeof obj['cosine'] !== 'number') return false;
  for (const key of FACTORS_KEYS) {
    if (!(key in obj)) return false;
  }
  return true;
}

function isScoringTraceEntry(value: unknown): value is ScoringTraceEntry {
  if (value === null || typeof value !== 'object') return false;
  const obj = value as Record<string, unknown>;
  if (typeof obj['id'] !== 'string') return false;
  if (typeof obj['timestamp'] !== 'number') return false;
  if (typeof obj['date'] !== 'string') return false;
  if (typeof obj['ticketId'] !== 'string') return false;
  if (typeof obj['expertId'] !== 'string') return false;
  if (obj['matchedLayer'] !== null &&
      obj['matchedLayer'] !== 'exact' &&
      obj['matchedLayer'] !== 'keyword_threshold' &&
      obj['matchedLayer'] !== 'vector_cosine') {
    return false;
  }
  if (typeof obj['score'] !== 'number') return false;
  return isScoringTraceFactors(obj['factors']);
}

export function createScoringTrace(options: ScoringTraceOptions = {}): ScoringTrace {
  const auditDir = options.auditDir ?? DEFAULT_AUDIT_DIR;
  const filenamePrefix = options.filenamePrefix ?? DEFAULT_FILENAME_PREFIX;
  const now = options.now ?? ((): Date => new Date());

  ensureDir(auditDir);

  const getFilePath = (date?: string): string => {
    const target = date ?? formatDate(now());
    if (!isValidDateString(target)) {
      throw new Error(`invalid date format: ${target} (expected YYYY-MM-DD)`);
    }
    return path.join(auditDir, `${filenamePrefix}${target}.jsonl`);
  };

  const log = (input: ScoringTraceInput): ScoringTraceEntry => {
    const currentDate = formatDate(now());
    const entry: ScoringTraceEntry = {
      id: generateId(),
      timestamp: now().getTime(),
      date: currentDate,
      ticketId: input.ticketId,
      expertId: input.expertId,
      matchedLayer: input.matchedLayer,
      score: input.score,
      factors: {
        exactHit: input.factors.exactHit,
        keywordOverlap: input.factors.keywordOverlap,
        cosine: input.factors.cosine,
      },
    };

    const filePath = getFilePath(currentDate);
    try {
      fs.appendFileSync(filePath, JSON.stringify(entry) + '\n');
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      logger.error(
        { event: 'scoring_trace.log_failed', filePath, ticketId: input.ticketId, error: message },
        'scoring trace append failed',
      );
      throw new Error(`scoring trace append failed: ${message}`);
    }

    logger.info(
      {
        event: 'scoring_trace.logged',
        ticketId: input.ticketId,
        expertId: input.expertId,
        matchedLayer: input.matchedLayer,
        score: input.score,
        date: currentDate,
      },
      'scoring trace appended',
    );

    return entry;
  };

  const logFromTrustScore = (
    ticketId: string,
    expertId: string,
    result: TrustScoreResult,
  ): ScoringTraceEntry => {
    return log({
      ticketId,
      expertId,
      matchedLayer: result.matchedLayer,
      score: result.score,
      factors: {
        exactHit: result.breakdown.exactHit,
        keywordOverlap: result.breakdown.keywordOverlap,
        cosine: result.breakdown.cosine,
      },
    });
  };

  const readEntriesFromFile = (filePath: string): ScoringTraceEntry[] => {
    if (!fs.existsSync(filePath)) return [];
    const raw = fs.readFileSync(filePath, 'utf-8');
    const lines = raw.split('\n').filter((line) => line.length > 0);
    const entries: ScoringTraceEntry[] = [];
    for (const line of lines) {
      try {
        const parsed: unknown = JSON.parse(line);
        if (isScoringTraceEntry(parsed)) {
          entries.push(parsed);
        }
      } catch {
        // skip corrupt line — append-only invariant means we never
        // partially rewrite, but older versions may differ
      }
    }
    return entries;
  };

  const query = (filter: ScoringTraceFilter = {}): readonly ScoringTraceEntry[] => {
    let candidates: ScoringTraceEntry[];

    if (filter.date !== undefined) {
      candidates = readEntriesFromFile(getFilePath(filter.date));
    } else {
      // No date filter → scan every file in auditDir matching the prefix
      if (!fs.existsSync(auditDir)) {
        candidates = [];
      } else {
        const files = fs.readdirSync(auditDir)
          .filter((f) => f.startsWith(filenamePrefix) && f.endsWith('.jsonl'))
          .sort();
        candidates = [];
        for (const f of files) {
          for (const entry of readEntriesFromFile(path.join(auditDir, f))) {
            candidates.push(entry);
          }
        }
      }
    }

    if (filter.ticketId !== undefined) {
      const target = filter.ticketId;
      candidates = candidates.filter((e) => e.ticketId === target);
    }
    if (filter.expertId !== undefined) {
      const target = filter.expertId;
      candidates = candidates.filter((e) => e.expertId === target);
    }
    if (filter.since !== undefined) {
      const since = filter.since;
      candidates = candidates.filter((e) => e.timestamp >= since);
    }
    if (filter.until !== undefined) {
      const until = filter.until;
      candidates = candidates.filter((e) => e.timestamp <= until);
    }

    candidates.sort((a, b) => a.timestamp - b.timestamp);
    if (filter.limit !== undefined && filter.limit >= 0) {
      candidates = candidates.slice(0, filter.limit);
    }

    return candidates;
  };

  const stats = (filter: ScoringTraceFilter = {}): ScoringTraceStats => {
    const entries = query(filter);
    const byDate: Record<string, number> = {};
    const byExpert: Record<string, number> = {};
    const byLayer: Record<string, number> = {};
    for (const e of entries) {
      byDate[e.date] = (byDate[e.date] ?? 0) + 1;
      byExpert[e.expertId] = (byExpert[e.expertId] ?? 0) + 1;
      const layerKey = e.matchedLayer ?? 'none';
      byLayer[layerKey] = (byLayer[layerKey] ?? 0) + 1;
    }
    return {
      totalEntries: entries.length,
      byDate,
      byExpert,
      byLayer,
    };
  };

  return {
    log,
    logFromTrustScore,
    query,
    stats,
    getFilePath,
  };
}