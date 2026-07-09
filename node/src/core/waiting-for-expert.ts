/**
 * KALLAX WaitingForExpert — auto-degradation when no expert matches a ticket.
 *
 * EPIC-030-C: skeleton (basic structure, can be enhanced later).
 *
 * Trigger flow (跟 EPIC-030-A 联合):
 *   TrustScore.matchAll(ticket, experts) → TrustScoreResult[]
 *     if every result.score === 0 (no L1/L2/L3 hit) → waiting-for-expert kicks in
 *       1. increment retries in `.kallax/state/waiting-for-expert.json`
 *       2. write `.kallax/inbox/waiting-<expert>.md` 提示 (主公 needs to onboard expert)
 *       3. Conductor heartbeat will drain via getPriorityOrder() (retries DESC)
 *
 * Why "degradation"?
 *   TrustScore returns 0 across the expert roster — that's a system-level signal
 *   that no human / registered expert matches the ticket. Rather than fail loud,
 *   we gracefully park the ticket in a retry queue so the next heartbeat can
 *   re-evaluate (an expert may have registered in the meantime) and so the
 *   Conductor (or 主公) can see the gap via inbox hints.
 *
 * Schema (跟 eket `scripts/agent/waiting-for-expert.sh` 借方法论, 借不借代码):
 *   .kallax/state/waiting-for-expert.json
 *     {
 *       "<TICKET_ID>": {
 *         "requiredExpertise": "<keyword-or-expert>",
 *         "retries": <int>,
 *         "lastAttempt": "<ISO8601>",
 *         "bestScore": <number>,
 *         "bestLayer": "exact" | "keyword_threshold" | "vector_cosine" | null
 *       }
 *     }
 *
 * 1:1 TrustScore wiring (跟 EPIC-030-A 联合):
 *   recordNoMatch() accepts a TrustScoreResult[] (the full matchAll output) and
 *   uses the BEST result's score + matchedLayer as the recorded bestScore /
 *   bestLayer. If the caller already knows the ticket is unmatched they can
 *   still call incrementRetries(ticketId, expertise) directly — same data ends
 *   up in the JSON either way.
 *
 * Testability:
 *   `now` option injects a clock so timestamp assertions don't flake.
 *   `stateFile` / `inboxDir` are constructor options so tests can point at
 *   tmpdir without polluting the real `.kallax/` tree.
 *
 * Source: Conductor §5.3 waiting-for-expert.json + need-expert-*.md
 *         EPIC-030-A TrustScore (1:1 verification, score==0 触发)
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { logger } from '../utils/logger.js';
import type { TrustScoreResult, MatchLayer } from './trust-score.js';

export interface WaitingExpertEntry {
  readonly ticketId: string;
  readonly requiredExpertise: string;
  readonly retries: number;
  readonly lastAttempt: string;
  readonly bestScore: number;
  readonly bestLayer: MatchLayer | null;
}

export interface NoMatchInput {
  readonly ticketId: string;
  readonly requiredExpertise: string;
  readonly trustResults: readonly TrustScoreResult[];
}

export interface IncrementInput {
  readonly ticketId: string;
  readonly requiredExpertise: string;
  readonly bestScore?: number;
  readonly bestLayer?: MatchLayer | null;
}

export interface WaitingForExpertRecordResult {
  readonly entry: WaitingExpertEntry;
  readonly stateFile: string;
  readonly inboxFile: string;
}

export interface WaitingForExpertOptions {
  readonly stateFile?: string;
  readonly inboxDir?: string;
  readonly inboxPrefix?: string;
  readonly now?: () => Date;
}

export interface WaitingForExpert {
  recordNoMatch(input: NoMatchInput): WaitingForExpertRecordResult;
  incrementRetries(input: IncrementInput): WaitingForExpertRecordResult;
  writeInboxHint(input: WaitingForExpertRecordResult): string;
  list(): readonly WaitingExpertEntry[];
  getPriorityOrder(): readonly string[];
  isWaiting(ticketId: string): boolean;
  clear(ticketId: string): boolean;
  getStateFile(): string;
}

const DEFAULT_STATE_FILE = '.kallax/state/waiting-for-expert.json';
const DEFAULT_INBOX_DIR = '.kallax/inbox';
const DEFAULT_INBOX_PREFIX = 'waiting-';

const TICKET_ID_REGEX = /^[A-Za-z0-9_-]+$/;
const EXPERTISE_REGEX = /^[A-Za-z0-9_./\-\u4e00-\u9fff ]+$/;
const MATCH_LAYERS = ['exact', 'keyword_threshold', 'vector_cosine'] as const;

function formatTimestamp(d: Date): string {
  return d.toISOString();
}

function safeFilename(input: string): string {
  const sanitized = input.replace(/[^A-Za-z0-9_.-]/g, '_');
  return sanitized.length > 0 ? sanitized : 'unknown';
}

function ensureDir(dir: string): void {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function isMatchLayer(value: unknown): value is MatchLayer {
  return typeof value === 'string'
    && (MATCH_LAYERS as readonly string[]).includes(value);
}

function isTrustScoreResult(value: unknown): value is TrustScoreResult {
  if (value === null || typeof value !== 'object') return false;
  const obj = value as Record<string, unknown>;
  if (typeof obj['ticketId'] !== 'string') return false;
  if (typeof obj['expertId'] !== 'string') return false;
  if (obj['matchedLayer'] !== null && !isMatchLayer(obj['matchedLayer'])) return false;
  if (typeof obj['score'] !== 'number') return false;
  const breakdown = obj['breakdown'];
  if (breakdown === null || typeof breakdown !== 'object') return false;
  const bd = breakdown as Record<string, unknown>;
  if (typeof bd['exactHit'] !== 'boolean') return false;
  if (typeof bd['keywordOverlap'] !== 'number') return false;
  if (typeof bd['cosine'] !== 'number') return false;
  return true;
}

function isWaitingExpertEntry(value: unknown): value is WaitingExpertEntry {
  if (value === null || typeof value !== 'object') return false;
  const obj = value as Record<string, unknown>;
  if (typeof obj['ticketId'] !== 'string') return false;
  if (typeof obj['requiredExpertise'] !== 'string') return false;
  if (typeof obj['retries'] !== 'number') return false;
  if (typeof obj['lastAttempt'] !== 'string') return false;
  if (typeof obj['bestScore'] !== 'number') return false;
  if (obj['bestLayer'] !== null && !isMatchLayer(obj['bestLayer'])) return false;
  return true;
}

function validateTicketId(ticketId: string): void {
  if (ticketId.length === 0) {
    throw new Error('ticketId must be non-empty');
  }
  if (!TICKET_ID_REGEX.test(ticketId)) {
    throw new Error(`ticketId contains invalid characters: ${ticketId}`);
  }
}

function validateExpertise(expertise: string): void {
  if (expertise.length === 0) {
    throw new Error('requiredExpertise must be non-empty');
  }
  if (!EXPERTISE_REGEX.test(expertise)) {
    throw new Error(`requiredExpertise contains invalid characters: ${expertise}`);
  }
}

function pickBestResult(results: readonly TrustScoreResult[]): {
  readonly bestScore: number;
  readonly bestLayer: MatchLayer | null;
} {
  if (results.length === 0) {
    return { bestScore: 0, bestLayer: null };
  }
  let best: TrustScoreResult = results[0]!;
  for (let i = 1; i < results.length; i++) {
    const r = results[i];
    if (r !== undefined && r.score > best.score) {
      best = r;
    }
  }
  return { bestScore: best.score, bestLayer: best.matchedLayer };
}

export function createWaitingForExpert(options: WaitingForExpertOptions = {}): WaitingForExpert {
  const stateFile = options.stateFile ?? DEFAULT_STATE_FILE;
  const inboxDir = options.inboxDir ?? DEFAULT_INBOX_DIR;
  const inboxPrefix = options.inboxPrefix ?? DEFAULT_INBOX_PREFIX;
  const now = options.now ?? ((): Date => new Date());

  ensureDir(path.dirname(stateFile));
  ensureDir(inboxDir);

  const readState = (): Record<string, WaitingExpertEntry> => {
    if (!fs.existsSync(stateFile)) return {};
    try {
      const raw = fs.readFileSync(stateFile, 'utf-8');
      if (raw.trim().length === 0) return {};
      const parsed: unknown = JSON.parse(raw);
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
      }
      const out: Record<string, WaitingExpertEntry> = {};
      for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
        if (isWaitingExpertEntry(v)) {
          out[k] = v;
        }
      }
      return out;
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      logger.warn(
        { event: 'waiting_for_expert.read_failed', stateFile, error: message },
        'waiting-for-expert state file unreadable, starting empty',
      );
      return {};
    }
  };

  const writeState = (state: Record<string, WaitingExpertEntry>): void => {
    // EPIC-076 P1-10: TOCTOU 治根 — tmp 用 PID+timestamp 防并发写碰撞
    const tmpPath = `${stateFile}.tmp.${process.pid}.${Date.now()}`;
    try {
      fs.writeFileSync(tmpPath, JSON.stringify(state, null, 2) + '\n');
      fs.renameSync(tmpPath, stateFile);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      logger.error(
        { event: 'waiting_for_expert.write_failed', stateFile, error: message },
        'waiting-for-expert state write failed',
      );
      throw new Error(`waiting-for-expert state write failed: ${message}`);
    }
  };

  const buildInboxContent = (
    entry: WaitingExpertEntry,
    expertise: string,
  ): string => {
    const lines: string[] = [
      `# Waiting for Expert: ${entry.ticketId}`,
      '',
      '## Context',
      `- Mode: ai-auto`,
      `- Ticket: ${entry.ticketId}`,
      `- Required Expertise: ${expertise}`,
      `- Retries: ${entry.retries}`,
      `- Last Attempt: ${entry.lastAttempt}`,
      `- Best Match Score: ${entry.bestScore}`,
      `- Best Match Layer: ${entry.bestLayer ?? 'none'}`,
      '',
      '## 建议',
      '1. 手动注册匹配 expert (worktree_role / skills 字段)',
      '2. 修改 ticket 的 required_expertise 字段',
      '3. 接受 fallback 标签评分',
      '',
      '## 触发条件',
      'TrustScore 3 层匹配 (L1 exact / L2 keyword_threshold / L3 vector_cosine) 全部返回 score=0,',
      'Conductor 自动降级至 waiting-for-expert 队列, 下次 heartbeat 优先重试 (retries DESC)。',
      '',
    ];
    return lines.join('\n');
  };

  const buildEntry = (
    input: IncrementInput,
    prev: WaitingExpertEntry | undefined,
    ts: string,
  ): WaitingExpertEntry => {
    const previousRetries = prev?.retries ?? 0;
    const bestScore = input.bestScore ?? prev?.bestScore ?? 0;
    const bestLayer = input.bestLayer !== undefined ? input.bestLayer : prev?.bestLayer ?? null;
    return {
      ticketId: input.ticketId,
      requiredExpertise: input.requiredExpertise,
      retries: previousRetries + 1,
      lastAttempt: ts,
      bestScore,
      bestLayer,
    };
  };

  const increment = (input: IncrementInput): WaitingForExpertRecordResult => {
    validateTicketId(input.ticketId);
    validateExpertise(input.requiredExpertise);

    const state = readState();
    const prev = state[input.ticketId];
    const ts = formatTimestamp(now());
    const entry = buildEntry(input, prev, ts);
    state[input.ticketId] = entry;
    writeState(state);

    const inboxFile = path.join(inboxDir, `${inboxPrefix}${safeFilename(input.requiredExpertise)}.md`);
    const result: WaitingForExpertRecordResult = { entry, stateFile, inboxFile };

    logger.info(
      {
        event: 'waiting_for_expert.recorded',
        ticketId: input.ticketId,
        requiredExpertise: input.requiredExpertise,
        retries: entry.retries,
        bestScore: entry.bestScore,
        bestLayer: entry.bestLayer,
      },
      'ticket queued for waiting-for-expert',
    );

    return result;
  };

  const writeInboxHint = (input: WaitingForExpertRecordResult): string => {
    const target = input.inboxFile;
    const content = buildInboxContent(input.entry, input.entry.requiredExpertise);
    ensureDir(path.dirname(target));
    fs.writeFileSync(target, content);
    logger.info(
      { event: 'waiting_for_expert.inbox_written', path: target, ticketId: input.entry.ticketId },
      'inbox hint written',
    );
    return target;
  };

  const recordNoMatch = (input: NoMatchInput): WaitingForExpertRecordResult => {
    validateTicketId(input.ticketId);
    validateExpertise(input.requiredExpertise);

    for (const r of input.trustResults) {
      if (!isTrustScoreResult(r)) {
        throw new Error('trustResults contains invalid TrustScoreResult entry');
      }
    }

    const { bestScore, bestLayer } = pickBestResult(input.trustResults);
    const incremented = increment({
      ticketId: input.ticketId,
      requiredExpertise: input.requiredExpertise,
      bestScore,
      bestLayer,
    });
    return incremented;
  };

  const list = (): readonly WaitingExpertEntry[] => {
    const state = readState();
    return Object.values(state);
  };

  const getPriorityOrder = (): readonly string[] => {
    const state = readState();
    return Object.values(state)
      .sort((a, b) => {
        if (b.retries !== a.retries) return b.retries - a.retries;
        return a.ticketId.localeCompare(b.ticketId);
      })
      .map((e) => e.ticketId);
  };

  const isWaiting = (ticketId: string): boolean => {
    const state = readState();
    return Object.prototype.hasOwnProperty.call(state, ticketId);
  };

  const clear = (ticketId: string): boolean => {
    const state = readState();
    if (!Object.prototype.hasOwnProperty.call(state, ticketId)) {
      return false;
    }
    delete state[ticketId];
    writeState(state);
    logger.info(
      { event: 'waiting_for_expert.cleared', ticketId },
      'ticket removed from waiting-for-expert',
    );
    return true;
  };

  const getStateFile = (): string => stateFile;

  return {
    recordNoMatch,
    incrementRetries: increment,
    writeInboxHint,
    list,
    getPriorityOrder,
    isWaiting,
    clear,
    getStateFile,
  };
}